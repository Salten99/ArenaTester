class_name RunState
extends RefCounted
## Everything about the current fight's player: who you are, what you've picked up, your level.

var seed := 0
var race_id := ""
var weapon_id := ""           ## what you start holding (fists; weapons are picked up in the arena)
var god_id := ""              ## your god (the core of the build)
var godly_gifts: Array = []   ## [{id, rank}]. The only record of the build; GodlyGiftManager mirrors it.
var level := 1
var xp := 0
var level_picks: Array = []   ## upgrade ids chosen at level-ups, in order
var pending_level_ups := 0    ## upgrades earned and not chosen yet
var stats := {}               ## counts for the recap (Run.note): damage dealt and taken, kills
