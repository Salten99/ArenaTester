class_name DebugTools
extends Node
## Debug shortcuts for testing combat fast (F1 shows the list on screen).

var arena: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not OS.is_debug_build() and not event.is_action("god_mode") and not "--perf" in OS.get_cmdline_user_args():
		return  # the F-key cheats stay out of a release .exe (unless started with -- --perf, to measure it)
	var player: Player = arena.player
	if event.is_action("debug_help"):
		arena.hud.toggle_help()
	elif event.is_action("debug_restart"):
		arena.restart()
	elif get_tree().paused:
		return
	elif event.is_action("debug_spawn"):
		for i in 10:
			arena.waves.spawn(WaveDirector.BASIC_UNIT, player.global_position)
	elif event.is_action("debug_spawn_large"):
		arena.waves.spawn(WaveDirector.LARGE_UNIT, player.global_position)
	elif event.is_action("debug_god_mode") or event.is_action("god_mode"):
		player.god_mode = not player.god_mode
		player.flying = player.god_mode
		arena.hud.show_message("God mode: can't be hurt, fly with Space / Ctrl (Shift: fast)." if player.god_mode else "God mode off.", 3.0)
	elif event.is_action("debug_kill_all"):
		for e in get_tree().get_nodes_in_group("enemies"):
			Combat.deal(e, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, player))
	elif event.is_action("debug_next_wave"):
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
