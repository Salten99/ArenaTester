class_name SaveSystem
extends RefCounted
## Reads and writes the profile (unlocks, bestiary, settings) as JSON in user://.

## Where it goes. Tests point it at a test file so they never touch the real profile.
static var PROFILE_PATH := "user://profile.json"


static func save_profile(data: Dictionary) -> bool:
	return _write(PROFILE_PATH, data)


## An unreadable profile is moved aside to profile.broken.json, not overwritten, so it can be recovered.
static func load_profile() -> Dictionary:
	var d = _read(PROFILE_PATH)
	if d is Dictionary:
		return d
	for path in [PROFILE_PATH, PROFILE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			var aside := PROFILE_PATH.get_basename() + ".broken.json"
			if FileAccess.file_exists(aside):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(aside))
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(aside))
			push_warning("SaveSystem: the profile couldn't be read; kept it as %s" % aside)
			break
	return {}


## Writes to a temp file first, then swaps it in. A crash mid-write leaves the old file; a crash
## mid-swap leaves only the temp file, complete, and _read uses that.
static func _write(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: can't write %s" % tmp)
		return false
	var ok := f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if not ok:  # e.g. disk full: keep the good file, don't swap a cut-off one over it
		push_error("SaveSystem: writing %s failed" % tmp)
		return false
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK


static func _read(path: String):
	if not FileAccess.file_exists(path):
		path += ".tmp"
		if not FileAccess.file_exists(path):
			return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
