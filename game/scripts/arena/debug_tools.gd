class_name DebugTools
extends Node
## Debug shortcuts for testing combat fast (F1 shows the list on screen).

## The godly gifts that make the Milestone 0 combo: slam ignites, lightning explodes the burning.
const COMBO_KIT := ["forge_searing_strikes", "storm_thunderclap", "storm_static_strikes", "duo_forge_storm"]

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
	elif (event.is_action("debug_godly_gift") or event.is_action("debug_combo_kit")) and arena is EndlessArena:
		return  # no godly gifts in the endless arena for now
	elif event.is_action("debug_godly_gift"):
		var god: String = RunRng.pick(arena.offer_gods)
		var offer: Array = player.godly_gifts.make_offer(god, 1)
		if not offer.is_empty():
			player.godly_gifts.add_godly_gift(offer[0])
			arena.hud.show_message("Debug: gained %s" % arena._godly_gift_name(offer[0]), 1.5)
	elif event.is_action("debug_combo_kit"):
		for id in COMBO_KIT:
			if not player.godly_gifts.has_godly_gift(id):
				player.godly_gifts.add_godly_gift(id)
		arena.hud.show_message("Debug: combo kit added. Slam a crowd with RMB!", 2.5)
	elif event.is_action("debug_god_mode") or event.is_action("god_mode"):
		player.god_mode = not player.god_mode
		player.flying = player.god_mode
		if player.flying and player.mount != null and player.mount.riding:
			player.mount.dismount()
		arena.hud.show_message("God mode: can't be hurt, fly with Space / Ctrl (Shift: fast)." if player.god_mode else "God mode off.", 3.0)
	elif event.is_action("debug_final_battle"):
		if arena.has_method("debug_final_battle"):
			arena.debug_final_battle()
	elif event.is_action("debug_kill_all"):
		for e in get_tree().get_nodes_in_group("enemies"):
			Combat.deal(e, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, player))
	elif event.is_action("debug_next_wave"):
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
