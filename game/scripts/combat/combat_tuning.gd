class_name CombatTuning
extends Resource
## Every "feel" number in one place. Open res://tuning/combat_tuning.tres in the
## Godot editor to change these in the Inspector without touching code.

@export_group("Hit-stop")
## Freeze length on a light hit, in seconds of real time.
@export_range(0.0, 0.3, 0.005) var hitstop_light := 0.04
## Freeze length on a heavy hit or slam.
@export_range(0.0, 0.3, 0.005) var hitstop_heavy := 0.09
## Game speed during a freeze (0 = full stop).
@export_range(0.0, 1.0, 0.01) var hitstop_time_scale := 0.05

@export_group("Camera shake")
@export_range(0.0, 1.0, 0.01) var shake_light := 0.12
@export_range(0.0, 1.0, 0.01) var shake_heavy := 0.35
@export_range(0.0, 1.0, 0.01) var shake_explosion := 0.25
@export_range(0.0, 1.0, 0.01) var shake_player_hit := 0.3
## How fast shake fades, per second.
@export_range(0.1, 10.0, 0.1) var shake_decay := 2.2
@export_range(0.0, 2.0, 0.01) var shake_max_offset := 0.35

@export_group("Knockback")
@export_range(0.0, 30.0, 0.5) var knockback_light := 4.0
@export_range(0.0, 30.0, 0.5) var knockback_heavy := 11.0
@export_range(0.0, 30.0, 0.5) var knockback_explosion := 7.0
## Seconds an enemy stays down after a knockdown.
@export_range(0.0, 3.0, 0.05) var knockdown_time := 1.0
## How fast knockback slows down (higher = shorter slide).
@export_range(1.0, 30.0, 0.5) var knockback_friction := 9.0

@export_group("Player movement")
## Walking speed, m/s (sam-movement SPEED 5.0, lowered 45% on 2026-10-22).
@export_range(1.0, 15.0, 0.05) var move_speed := 2.75
## Speed while holding Sprint (sam-movement 15, lowered 45%).
@export_range(1.0, 40.0, 0.05) var sprint_speed := 8.25
## Hard ceiling on horizontal speed, whatever the source.
@export_range(1.0, 60.0, 0.5) var max_speed := 30.0
@export_range(1.0, 40.0, 0.5) var gravity := 15.0
## Angels and bird people (Player.GLIDERS): how much harder they jump, and their fastest fall (m/s).
@export_range(1.0, 4.0, 0.05) var glide_jump_mult := 1.8
@export_range(0.5, 15.0, 0.25) var glide_fall_speed := 3.0
## Jump velocity when standing still.
@export_range(1.0, 30.0, 0.5) var jump_velocity_base := 8.0
## Extra jump velocity per m/s of horizontal speed.
@export_range(0.0, 2.0, 0.01) var jump_speed_scale := 0.25
@export_range(1.0, 40.0, 0.5) var jump_velocity_max := 18.0
## Speed added on top of current speed when a slide starts.
@export_range(0.0, 20.0, 0.1) var slide_speed_gain := 2.5
## Extra speed when jumping out of a slide.
@export_range(0.0, 20.0, 0.1) var slide_jump_speed_gain := 1.5
@export_range(0.05, 5.0, 0.05) var slide_duration := 0.6
## Slide length when sliding out of a sprint.
@export_range(0.05, 5.0, 0.05) var slide_duration_sprint := 1.5
## How fast a slide loses speed, m/s per second.
@export_range(0.0, 30.0, 0.5) var slide_friction := 4.0
## How fast speed above walk/sprint fades while still moving (0 = never).
@export_range(0.0, 20.0, 0.1) var momentum_decay := 1.5
## How fast you stop when no movement key is held on the ground.
@export_range(0.0, 80.0, 0.5) var ground_friction := 32.0
@export_range(0.0, 2.0, 0.05) var wall_jump_cooldown := 0.3
## Walking speed while crouched (hold Slide while standing still, then move), m/s.
@export_range(0.5, 6.0, 0.1) var crouch_speed := 2.2
## Stealth (user, 2026-11-05): crouched, enemies notice you only this fraction as far away...
@export_range(0.1, 1.0, 0.05) var stealth_notice_scale := 0.45
## ...and this fraction of that again when you're behind them (out of their sight).
@export_range(0.1, 1.0, 0.05) var stealth_behind_scale := 0.5
## A siege (user, 2026-11-16): seconds to get ready before the attack reaches the village (F starts it sooner).
@export_range(5.0, 180.0, 5.0) var siege_prep_seconds := 60.0
## Camera drop while sliding or crouching, in meters.
@export_range(-2.0, 0.0, 0.05) var slide_camera_offset := -0.6
## Movement speed while doing a light attack or casting (fraction of walk speed).
@export_range(0.0, 1.0, 0.05) var attack_move_factor := 0.3
@export_range(1.0, 40.0, 0.5) var dodge_speed := 16.0
@export_range(0.05, 1.0, 0.01) var dodge_duration := 0.22
## Invulnerable for this long at the start of a dodge.
@export_range(0.0, 1.0, 0.01) var dodge_iframes := 0.2
@export_range(0.0, 100.0, 1.0) var dodge_stamina_cost := 25.0
## The Guardian parries on the dodge key (shield up). A hit from the front in the
## first parry_window seconds is parried; later in the raise it lands as normal.
@export_range(0.05, 1.0, 0.01) var parry_window := 0.25
## How long the shield stays up (you can't attack or move meanwhile).
@export_range(0.05, 1.5, 0.01) var parry_duration := 0.45
@export_range(0.0, 100.0, 1.0) var parry_stamina_cost := 15.0
## A parried attacker reels this long (large ones half as long).
@export_range(0.1, 4.0, 0.05) var parry_stagger := 1.4
## After a parry: this long of faster, harder light attacks (the follow-up).
@export_range(0.1, 5.0, 0.1) var riposte_time := 1.5
@export_range(0.0, 300.0, 5.0) var riposte_speed_pct := 60.0
@export_range(0.0, 300.0, 5.0) var riposte_damage_pct := 50.0
@export_range(0.0, 200.0, 1.0) var base_stamina := 100.0
@export_range(0.0, 200.0, 1.0) var stamina_regen := 35.0
## Seconds after spending stamina before it starts coming back.
@export_range(0.0, 3.0, 0.05) var stamina_regen_delay := 0.6
## Stamina per second while sprinting on foot (riding: the mount runs, free).
@export_range(0.0, 100.0, 1.0) var sprint_stamina := 12.0
## Hostile people (not animals or monsters without a body like yours) get this x
## their sheet health (user, 2026-10-30: +50%), except minions (Melee, Ranged and
## Magic roles), which keep their sheet health so they fall in 1-2 hits (pivot, 2026-11-18).
@export_range(0.5, 5.0, 0.05) var humanoid_health_mult := 1.5
## Run out and you can't sprint again until stamina is back to this % of the bar.
@export_range(0.0, 100.0, 1.0) var sprint_recover_pct := 25.0
## Stamina each spell costs (god abilities). Not enough: the spell doesn't cast.
@export_range(0.0, 100.0, 1.0) var signature_stamina := 20.0
@export_range(0.0, 100.0, 1.0) var movement_stamina := 15.0
@export_range(0.0, 100.0, 1.0) var ultimate_stamina := 35.0
@export_range(10.0, 3000.0, 5.0) var base_health := 400.0  # 600 until 2026-11-05 (user: a third less, fights felt too easy)

@export_group("Player attacks")
## Fraction of a light attack spent winding up before the hit lands.
@export_range(0.0, 1.0, 0.01) var light_windup_fraction := 0.25  # 0.35 before the reels: a short wind-up, the blow lands fast, a long follow-through
@export_range(0.05, 1.5, 0.01) var heavy_windup := 0.42
@export_range(0.05, 1.5, 0.01) var heavy_recovery := 0.35
## Heavy attack damage = weapon damage x this.
@export_range(1.0, 5.0, 0.05) var heavy_multiplier := 1.5
## Holding heavy charges it after the windup: up to this many seconds more,
## draining stamina, for up to heavy_charge_bonus more damage (1 = double).
@export_range(0.0, 3.0, 0.05) var heavy_charge_time := 1.0
@export_range(0.0, 3.0, 0.05) var heavy_charge_bonus := 1.0
@export_range(0.0, 100.0, 1.0) var heavy_charge_stamina := 30.0
## A full charge also knocks back this much harder (1 = double), and sends a heavy shot this much faster.
@export_range(0.0, 3.0, 0.05) var heavy_charge_knockback := 1.0
@export_range(0.0, 3.0, 0.05) var heavy_charge_speed := 0.6
## Holding jump (user, 2026-11-05): a tap jumps 100%, held it rises to jump_charge_max after jump_charge_time seconds.
@export_range(0.0, 5.0, 0.1) var jump_charge_time := 2.0
@export_range(1.0, 2.0, 0.05) var jump_charge_max := 1.3
## How far your arrows fly (m).
@export_range(10.0, 200.0, 5.0) var missile_range := 75.0
## Aiming help (user, 2026-11-05): an enemy this close to the crosshair (degrees), within the weapon's
## sure range, is hit: the bow aims true at it.
@export_range(0.0, 15.0, 0.5) var aim_cone_missile_deg := 3.0
@export_range(5.0, 100.0, 1.0) var sure_range_bow := 30.0
## A jump crouches at least this long (s) first: knees bend even on a tap (user, 2026-11-06).
@export_range(0.0, 0.4, 0.02) var jump_crouch_min := 0.12
## The spyglass: how narrow the view gets (degrees) and how far it identifies creatures (m).
@export_range(4.0, 40.0, 1.0) var spyglass_fov := 12.0
@export_range(50.0, 1000.0, 10.0) var spyglass_range := 450.0
## The camera's view while you hold an attack with a bow or spell weapon (it's 70 otherwise).
@export_range(30.0, 90.0, 1.0) var aim_fov := 58.0
## Half-angle of the light attack arc, in degrees.
@export_range(10.0, 180.0, 1.0) var light_arc_degrees := 70.0
## Seconds after a light attack in which the next combo hit can start.
@export_range(0.05, 1.5, 0.01) var combo_window := 0.45
@export_range(0.0, 100.0, 0.5) var base_crit_chance := 5.0
@export_range(100.0, 400.0, 5.0) var base_crit_damage := 150.0

@export_group("Abilities")
## How far away you can aim an ultimate (hold the key, release to cast). An
## ultimate with a longer range_m on the God Abilities sheet uses that.
@export_range(2.0, 60.0, 0.5) var ultimate_aim_range := 20.0
## How far a cone Movement ability (Fire Lance) lunges you before the cone bursts out.
@export_range(0.0, 10.0, 0.25) var lance_lunge_m := 3.0
## The Fire Lance's stab animation plays this many times longer than other casts (user, 2026-11-08: 50% slower).
@export_range(0.5, 3.0, 0.05) var lance_stab_slow := 1.5
## The Fire Lance's beam (user, 2026-11-19): how long it stays on, following your aim (s), and how
## thick it looks (1 = your lance scene's own thickness).
@export_range(0.1, 3.0, 0.05) var lance_beam_time := 0.8
@export_range(0.1, 2.0, 0.05) var lance_beam_thickness := 0.5

@export_group("Ultimate magic circle")
## Every Ultimate (user, 2026-11-10): you raise your weapon, a magic circle opens in the sky over
## where you aimed, then the element falls from it (UltimateFx).
## How long you hold your weapon up (s).
@export_range(0.2, 2.0, 0.05) var ult_raise_time := 0.8
## How high the circle hangs over the aimed spot (m).
@export_range(3.0, 30.0, 0.5) var ult_circle_height := 10.0
## The circle's size, times the ultimate's blast radius.
@export_range(0.3, 3.0, 0.05) var ult_circle_scale := 1.15
## How fast the circle spins (degrees per second; the inner rings turn the other way, 1.5x faster).
@export_range(0.0, 720.0, 5.0) var ult_circle_spin := 60.0
## From the cast until the attack leaves the circle (s).
@export_range(0.1, 3.0, 0.05) var ult_circle_delay := 0.7
## How long the meteor, icicles, bomb or shards take to fall to the ground (s). The damage lands
## at delay + fall.
@export_range(0.05, 2.0, 0.05) var ult_fall_time := 0.4
## How long the storm, the tornado, the poison cloud and the circle last after the hit (s).
@export_range(0.2, 6.0, 0.1) var ult_tail_time := 1.6
## Lightning: how many strikes in the storm (the first one deals the damage).
@export_range(1, 30) var ult_storm_strikes := 7
## Stone: how many rock shards rain down.
@export_range(1, 80) var ult_shard_count := 26
## Fire (user, 2026-11-19): instead of one circle in the sky, a circle opens diagonally above each
## shoulder, this high over you (m), this far out to the side (m) and this big (radius, m); after
## this long (s) a meteor shoots from each at this speed (m/s) toward where you aimed, landing this
## far apart to each side (m). Each meteor deals this much of the ultimate's damage, over this much
## of its blast radius.
@export_range(1.0, 5.0, 0.1) var ult_shoulder_height := 2.4
@export_range(0.3, 3.0, 0.05) var ult_shoulder_out := 1.1
@export_range(0.2, 3.0, 0.05) var ult_shoulder_circle := 0.8
@export_range(0.0, 2.0, 0.05) var ult_meteor_delay := 0.35
@export_range(5.0, 150.0, 1.0) var ult_meteor_speed := 45.0
@export_range(0.0, 6.0, 0.1) var ult_meteor_spread := 1.5
@export_range(0.1, 1.0, 0.05) var ult_meteor_share := 0.6
@export_range(0.1, 1.5, 0.05) var ult_meteor_radius := 0.6
## Each meteor's size (radius, m). Where it lands the ground burns this long (s), over this much of
## its blast, setting alight whoever is in it and dealing this much of the ultimate's damage a second.
@export_range(0.1, 3.0, 0.05) var ult_meteor_size := 0.9
@export_range(0.0, 15.0, 0.5) var ult_fire_ground_time := 4.0
@export_range(0.1, 2.0, 0.05) var ult_fire_ground_radius := 0.8
@export_range(0.0, 1.0, 0.01) var ult_fire_ground_damage := 0.1


@export_group("Stone eruption")
## The Stone special (user, 2026-11-16): a magic circle on the aimed ground, then spikes erupt from it.
## From the cast until the spikes come up (s).
@export_range(0.1, 2.0, 0.05) var erupt_delay := 0.5
## How tall a spike is (m; one under an impaled enemy grows with its size).
@export_range(0.5, 6.0, 0.1) var erupt_spike_height := 2.4
## Spikes coming up around the ones under enemies, for the look.
@export_range(0, 40) var erupt_spike_count := 10
## How long the ground cracks stay before fading (s).
@export_range(0.5, 20.0, 0.5) var erupt_crack_time := 5.0

@export_group("Enemies")
## How many enemies may be winding up or striking at once (attack tokens).
@export_range(1, 20) var max_attackers := 3
## Wind-up telegraph before an enemy strike, in seconds.
@export_range(0.1, 2.0, 0.05) var enemy_telegraph := 0.6
## Pause after an enemy strikes before it can wind up again (first playtest: 0.6 felt relentless).
@export_range(0.0, 2.0, 0.05) var enemy_recovery := 1.0
## At most this many of the attackers may be shooters or casters (they hit from range).
@export_range(0, 20) var max_ranged_attackers := 1
## Large units, champions and bosses wind up and recover this many times slower
## than others: slow, heavy, dodgeable hits.
@export_range(1.0, 3.0, 0.05) var large_slowdown := 1.5
## Shooters and casters wait this long between shots.
@export_range(0.0, 5.0, 0.05) var ranged_recovery := 2.0
## Shooters and casters stop following you this long before they shoot, and aim
## where you were: keep running (or dodge) and the shot misses (user, 2026-10-29).
@export_range(0.0, 2.0, 0.05) var ranged_aim_lock := 0.5
## Speed of enemy arrows, sling stones and bolts (m/s), and of enemy spells.
@export_range(5.0, 80.0, 1.0) var enemy_shot_speed := 30.0
@export_range(5.0, 80.0, 1.0) var enemy_spell_speed := 18.0
## Magic shots bend toward their target by up to this many degrees per second
## (a slight pull); arrows, bolts and stones fly straight. Enemy spells only: yours fly where you aim them.
@export_range(0.0, 360.0, 5.0) var enemy_magic_pull_deg := 40.0
## Enemy hits on you do this fraction of their sheet damage (first playtest, 2026-10-26:
## at 1.0 three attackers took a Birdman's 540 health in about 35 s; raised from 0.35 to 0.7 on
## 2026-11-10: a logged Short run had no deaths and a beginner ended raids at 94% health).
@export_range(0.05, 2.0, 0.05) var enemy_damage_scale := 0.7
## Enemies without an attack token circle at this distance.
@export_range(1.0, 15.0, 0.1) var wait_ring_distance := 4.5
@export_range(0.1, 3.0, 0.05) var enemy_speed_scale := 1.0
## Short stagger when hit, in seconds.
@export_range(0.0, 1.0, 0.01) var hit_stagger := 0.18
@export_range(0.3, 3.0, 0.05) var separation_radius := 1.2

## Outside fights you heal this % of your max health per second...
@export_range(0.0, 20.0, 0.5) var rest_regen_pct := 4.0
## ...starting this many seconds after you were last hit.
@export_range(0.0, 30.0, 0.5) var rest_regen_delay := 5.0

@export_group("Progression")
## XP needed scales with this; lower = faster level-ups.
@export_range(0.1, 5.0, 0.05) var xp_scale := 1.0

@export_group("Mounts")
## Multiplies the Mounts sheet's speed_mps / sprint_mps. 1.0 = the sheet's speeds
## (a horse sprints 16 m/s, about twice your 8.25 m/s run).
@export_range(0.5, 4.0, 0.05) var mount_speed_scale := 1.0
## Count Fuckula's pushes come this many times the sheet's advance_interval_min apart
## (user, 2026-10-30: more time between them).
@export_range(0.5, 4.0, 0.05) var evil_push_scale := 1.75
## Seconds to reach a village under attack before its region falls (120 x run length until 2026-10-30).
@export_range(30.0, 900.0, 10.0) var border_defense_seconds := 300.0
## A mount's health = its sheet hp x this (user, 2026-10-30: half).
@export_range(0.1, 3.0, 0.05) var mount_health_mult := 0.5
## Trampled at a full gallop (sprinting): the enemy is thrown back this fast (m/s,
## Your mount on foot walks this far to your side (m).
@export_range(1.0, 15.0, 0.5) var mount_follow_gap := 2.5  # 3.5 until 2026-11-05 (user: within 3 m of you)
## Your mount on foot fights only enemies this close to you, so it stays at your side.
@export_range(1.0, 30.0, 0.5) var mount_leash := 6.0
## Every weapon in a hand is drawn this much bigger (user, 2026-11-01: 30%).
@export_range(0.5, 3.0, 0.05) var weapon_scale := 1.3
## A heavy shot from a bow or crossbow: the launch is this much harder, and if it carries
## the enemy into a wall, tree or rock it's pinned there this long, taking this damage.
@export_range(1.0, 4.0, 0.05) var pin_launch_scale := 1.6
## An explosion launches the ones it ragdolls this much faster (user, 2026-11-08: 33%).
@export_range(1.0, 3.0, 0.05) var explosion_launch_scale := 1.33
@export_range(0.5, 20.0, 0.5) var pin_seconds := 5.0
## The bow fires one bolt, then waits this long (s) before the next (user, 2026-11-19).
@export_range(0.0, 60.0, 0.5) var bow_cooldown := 10.0
## How fast the bow's bolt flies (m/s).
@export_range(10.0, 200.0, 5.0) var bow_bolt_speed := 80.0
@export_range(0.0, 500.0, 5.0) var pin_damage := 40.0
## How fast your arrows and bolts fall (m/s per second): a little drop over distance.
@export_range(0.0, 30.0, 0.25) var missile_gravity := 5.0
## The throwing knife on G (HomingKnife).
@export_range(0.0, 500.0, 1.0) var knife_damage := 40.0
@export_range(0.5, 15.0, 0.25) var knife_radius := 4.5
@export_range(0.0, 30.0, 0.25) var knife_cooldown := 4.0
@export_range(5.0, 80.0, 1.0) var knife_speed := 20.0
## How far it looks for someone to chase (m).
@export_range(5.0, 120.0, 1.0) var knife_range := 40.0
## Your heavy and magic hits launch enemies: how fast and how high (m/s), before launch_velocity_mult.
@export_range(0.0, 40.0, 0.5) var launch_speed := 9.0
@export_range(0.0, 20.0, 0.5) var launch_lift := 7.0  # 4 before the reels' frame-by-frame (2026-11-18): launched enemies hang high
## Every launched enemy flies this many times faster (user, 2026-11-01: 30% more).
@export_range(0.5, 3.0, 0.05) var launch_velocity_mult := 1.3
## Blood drops from a hit, and from being slammed into something (x gore_amount; 24 since the
## combat feel plan, 2026-11-18: over the top).
@export_range(0, 60) var blood_hit_drops := 24
@export_range(0, 120) var blood_slam_drops := 40
## and up), goes ragdoll (people; animals fly whole) and gets back up if it lives.
@export_range(0.0, 40.0, 0.5) var mount_throw_speed := 16.0
@export_range(0.0, 20.0, 0.5) var mount_throw_lift := 6.0
## A charging mount attacks just before it hits someone (user, 2026-11-01): it starts this
## many seconds before reaching them, and the attack plays over mount_butt_time seconds.
## The head comes down about a third of the way through, so keep lead near time x 0.36.
@export_range(0.0, 1.0, 0.05) var mount_butt_lead := 0.25
@export_range(0.2, 1.5, 0.05) var mount_butt_time := 0.7
## A thrown enemy that suddenly loses this much speed hit something (a tree, a
## house, a rock) and takes this much damage per m/s lost.
@export_range(1.0, 20.0, 0.5) var throw_impact_min := 6.0
@export_range(0.0, 20.0, 0.25) var throw_impact_damage := 3.0
## Falling (user, 2026-11-05): an enemy landing faster than this (m/s; 12 is about a 5 m drop) takes
## fall_damage per m/s over it. You take none for now.
@export_range(1.0, 40.0, 0.5) var fall_safe_speed := 12.0
@export_range(0.0, 50.0, 0.5) var fall_damage := 6.0
## Upward speed of a mount's jump (Space while riding). Gravity is 15, so 6.5 is
## about 0.9 s in the air: a full gallop clears about 25 m (the narrow parts of a river).
@export_range(0.0, 20.0, 0.5) var mount_jump_velocity := 6.5
## The war chest's help in the final battle (WarChest): a catapult's stone and a meteor.
@export_range(1.0, 30.0, 0.5) var catapult_interval := 5.0
@export_range(0.0, 1000.0, 5.0) var catapult_damage := 90.0
@export_range(0.5, 15.0, 0.5) var catapult_radius := 4.0
@export_range(1, 30, 1) var meteors_per_volley := 8
@export_range(0.0, 2000.0, 10.0) var meteor_damage := 250.0
@export_range(0.5, 20.0, 0.5) var meteor_radius := 6.0
## With a bow, crossbow or spell weapon the camera sits this far to the right (m), over your shoulder.
@export_range(0.0, 2.0, 0.05) var aim_shoulder_offset := 0.8
## Trampled enemies are thrown only after this many seconds at a full gallop (user, 2026-11-05).
@export_range(0.0, 10.0, 0.1) var mount_throw_after := 2.0
## A mount on a road goes this much faster (user, 2026-11-05: roads you can ride).
@export_range(1.0, 2.0, 0.05) var road_mount_speed := 1.25

@export_group("Swimming")
## Swimming speed (Shift for faster), on foot. A swimming mount goes swim_mount_factor x that.
@export_range(0.5, 15.0, 0.05) var swim_speed := 2.2
@export_range(0.5, 15.0, 0.05) var swim_sprint_speed := 3.3
@export_range(0.5, 4.0, 0.1) var swim_mount_factor := 1.5
## Stamina per second while swimming fast (Shift).
@export_range(0.0, 100.0, 1.0) var swim_sprint_stamina := 15.0

@export_group("Battles")
## Enemy health per second the player clears at level 1 with no godly gifts, measured
## by tests/battle_sim.tscn. Battles are sized from this and the Encounters
## sheet's target_minutes, so raise it if fights end too fast.
@export_range(1.0, 300.0, 0.5) var battle_player_dps := 114.0  # measured 114.6, 106.8, 119.6 after the combat feel plan (2026-11-18; was 91, before that 39)
## What warriors beside you add: battle_ally_dps x (number of warriors ^ battle_ally_scaling).
## Each extra warrior adds less (they get swarmed and fall during long fights).
## Measured: 4 warriors add ~21, 10 add ~29 enemy HP per second.
@export_range(0.0, 100.0, 0.5) var battle_ally_dps := 0.0  # measured 0 on 3 seeds (2026-11-18): a raid's guards don't speed you up
@export_range(0.1, 1.0, 0.05) var battle_ally_scaling := 0.35
## How much stronger you count per level and per godly gift (0.06 = +6% each).
@export_range(0.0, 0.5, 0.01) var battle_level_growth := 0.06
@export_range(0.0, 0.5, 0.01) var battle_godly_gift_growth := 0.04
## The final battle is a pitched battle (user, 2026-10-30): your tribe's warriors,
## each allied tribe's, and each tribe Count Fuckula converted (on his side).
@export_range(0, 60) var battle_home_warriors := 14
@export_range(0, 40) var battle_ally_warriors := 10
@export_range(0, 40) var battle_converted_warriors := 8
## The final battle has at least this many on each side (user, 2026-11-05: 30 against 30).
@export_range(0, 1000) var final_battle_min_side := 30
## The final battle keeps at most this many of his army on the field; the rest march in
## from behind his line as they fall (user, 2026-11-12: 500 on screen).
@export_range(35, 1000) var final_battle_on_field := 500
## Warriors fighting beside you are this much tougher than their sheet health (so they last the fight).
@export_range(0.5, 10.0, 0.1) var ally_health_mult := 3.0
## ...and take only this fraction of damage (0.12 = 12%), so they last a whole fight.
@export_range(0.05, 1.0, 0.05) var ally_damage_taken := 0.12
## The next wave comes when this fraction of the current one is left (keeps fights flowing).
@export_range(0.0, 0.9, 0.05) var wave_overlap := 0.25
## The most enemies in one wave.
@export_range(5, 80) var max_wave_size := 28
## Every fight: this many waves, each wave_growth times bigger than the one before,
## then a mini boss once the last wave is down (user, 2026-10-29).
@export_range(1, 10) var wave_count := 3
@export_range(1.0, 3.0, 0.05) var wave_growth := 1.5
## The first wave's size, from the fight's health budget, kept between these.
@export_range(1, 40) var first_wave_min := 4
@export_range(1, 40) var first_wave_max := 12
## A mini boss has this many times its sheet health (and is drawn 2x size).
@export_range(1.0, 10.0, 0.1) var mini_boss_hp_mult := 3.0

@export_group("Waves")
## Enemies per wave; the arena runs through them in order.
@export var wave_sizes: PackedInt32Array = PackedInt32Array([8, 14, 22, 30, 40])
@export_range(0.0, 10.0, 0.5) var time_between_waves := 2.0
## Show a godly gift choice after every cleared wave.
@export var godly_gift_after_each_wave := true

@export_group("Feedback")
@export var show_damage_numbers := true
@export var hitstop_enabled := true

@export_group("Giant animals")
## How often a wild pack has a giant among it (user, 2026-11-03: giant animals as mini bosses).
@export_range(0.0, 1.0) var giant_chance := 0.16
## x its normal size.
@export var giant_scale := 2.6
## x its normal health, damage and the XP it gives.
@export var giant_health_mult := 5.0
@export var giant_damage_mult := 2.2
@export var giant_xp_mult := 10.0
## A giant of an animal that never fought before hits at least this hard.
@export var giant_min_damage := 18.0

@export_group("Chests in caves and towers")
## A cave's chest; a tower's pays double.
@export var loot_supplies_min := 15
@export var loot_supplies_max := 35
@export var loot_xp := 18.0
@export_range(0.0, 100.0) var loot_heal_pct := 40.0
## Percent chance of a godly gift offer as well.
@export_range(0.0, 100.0) var loot_gift_chance_cave := 35.0
## Clearing a dungeon (a cave, or a castle down to its boss; user, 2026-11-06): XP and supplies,
## plus a godly gift or a weapon.
@export_range(0.0, 400.0, 5.0) var dungeon_xp := 60.0
@export_range(0, 300, 5) var dungeon_supplies := 50
## Chance (%) a chest also holds a weapon you can swap for (user, 2026-11-06).
@export_range(0.0, 100.0) var loot_weapon_chance := 60.0
@export_range(0.0, 100.0) var loot_gift_chance_tower := 70.0

@export_group("Battles")
## A fight is one big battle, not waves (user, 2026-11-09): this many enemies at once...
@export_range(5, 80) var battle_size := 35
## ...and the mini boss (or champion) comes in when only this many are left.
@export_range(0, 40) var boss_when_left := 10

@export_group("Gore and hit effects")
## Combat feel plan (user, 2026-11-18): over-the-top blood. Every drop count below is
## multiplied by this; 0 turns blood off, 1 is the plan's amount.
@export_range(0.0, 3.0, 0.05) var gore_amount := 1.0
## Drops from a kill (on top of the hit's own drops).
@export_range(0, 200) var blood_kill_drops := 70
## Stains a hit leaves on the ground, stretched the way the blow went (a kill leaves twice as many).
@export_range(0, 12) var blood_stains_per_hit := 3
## How long a stain stays before it fades (user: 20 s), and how many at most (the oldest fade first).
@export_range(1.0, 120.0, 1.0) var blood_stain_seconds := 20.0
@export_range(10, 1000) var blood_stain_max := 300
## The swing trail: how long a point of it lasts (s), and how much of your god's element tints the steel (user: a slight tinge).
@export_range(0.03, 0.5, 0.01) var swing_trail_time := 0.14
@export_range(0.0, 1.0, 0.05) var swing_trail_tint := 0.25
## A launched person tumbles end over end this fast (radians per second).
@export_range(0.0, 30.0, 0.5) var launch_spin := 9.0
## The camera's kick toward a blow you land (m); heavy hits kick twice as far.
@export_range(0.0, 1.0, 0.01) var camera_kick := 0.1
## Sparks from a hit on armour, and how many armour pieces may be flying at once.
@export_range(0, 60) var metal_sparks := 14
@export_range(0, 60) var armor_pieces_max := 20
## Melee light attacks are this much faster than the sheet's attacks per second (user: 25%).
@export_range(0.5, 2.0, 0.05) var light_speed_mult := 1.25

@export_group("Grab, crush and hurl")
## Hold light attack this long (s) with a minion in reach to grab it (user: 0.3 s); let go sooner
## and it's a normal swing (combat feel plan, 2026-11-18).
@export_range(0.05, 1.0, 0.01) var grab_hold_time := 0.3
## How far (m) and how wide (degrees each side of your facing) your hand reaches.
@export_range(0.5, 5.0, 0.1) var grab_reach := 2.4
@export_range(10.0, 90.0, 1.0) var grab_arc_degrees := 60.0
## Keep holding this long (s) and the minion is crushed (user: 1 s).
@export_range(0.1, 5.0, 0.05) var crush_time := 1.0
## A hurled minion flies this fast ahead (m/s) and this much up; its wall burst hurts everyone this close (m).
@export_range(5.0, 50.0, 0.5) var hurl_speed := 20.0
@export_range(0.0, 15.0, 0.5) var hurl_lift := 3.0
@export_range(0.5, 8.0, 0.1) var hurl_burst_radius := 3.0
## How fast you walk while holding something (x your speed).
@export_range(0.0, 1.0, 0.05) var grab_move_factor := 0.6
## The chain grab (user, 2026-11-18): it reaches this far (m, user: 15) at what's within this many
## degrees of your crosshair, and flies this fast (m/s). No cooldown.
@export_range(3.0, 40.0, 0.5) var chain_range := 15.0
@export_range(1.0, 30.0, 0.5) var chain_cone_deg := 8.0
@export_range(10.0, 200.0, 1.0) var chain_speed := 70.0
## Scrolling the wheel back reels a hooked minion in this fast (m/s).
@export_range(2.0, 80.0, 1.0) var chain_reel_speed := 22.0
## A flick of the mouse down this fast (radians/s of camera pitch) yanks it into a slam, this high (m).
@export_range(0.5, 20.0, 0.1) var chain_flick_rate := 3.0
@export_range(0.5, 10.0, 0.1) var chain_slam_height := 3.0
## A sweep of the mouse sideways this fast (radians/s of camera turn) swings it around you, at
## this radius (m) and at least this spin (radians/s).
@export_range(0.5, 20.0, 0.1) var chain_swing_rate := 4.0
@export_range(1.0, 8.0, 0.1) var chain_swing_radius := 3.5
@export_range(1.0, 30.0, 0.5) var chain_swing_spin := 9.0
## The chain's weight (user, 2026-11-19). The swing winds up to speed this fast (radians/s each
## second: lower is heavier); the body follows the chain's pull this hard (lower trails farther
## behind); and the chain is this much longer than the gap it spans (1 = taut, more = more sag).
@export_range(5.0, 200.0, 1.0) var chain_swing_windup := 40.0
@export_range(2.0, 60.0, 0.5) var chain_swing_pull := 14.0
@export_range(1.0, 1.3, 0.01) var chain_slack := 1.04
## Walk away from a hooked minion and you drag it limp along the ground: the chain hauls it this hard
## (higher keeps it closer behind you), and while it's moving it takes this much damage a second
## (x your base hit).
@export_range(1.0, 40.0, 0.5) var chain_drag_pull := 12.0
@export_range(0.0, 5.0, 0.05) var chain_drag_damage := 0.6
## On a Large unit or boss the chain pulls you this fast (m/s) to within this reach (m) for the drop kick.
@export_range(5.0, 80.0, 1.0) var chain_pull_speed := 28.0
@export_range(0.5, 5.0, 0.1) var chain_kick_reach := 2.2
## The chain kick (user, 2026-11-19) sends a Large unit or boss it doesn't kill sliding back on its
## feet at this speed (m/s); it slows like any knockback. Small ones are launched instead.
@export_range(0.0, 60.0, 1.0) var chain_kick_push := 28.0

@export_group("Throwable items")
## Barrels, crates, loose boulders and branches (user, 2026-11-18). Large enemies pick one up within
## this reach (m), lift it this long (s), throw it at targets this far away (m), then wait this long (s).
@export_range(1.0, 10.0, 0.5) var item_pickup_reach := 4.0
@export_range(0.1, 3.0, 0.05) var item_lift_time := 0.7
@export_range(0.0, 20.0, 0.5) var item_throw_min := 5.0
@export_range(5.0, 40.0, 0.5) var item_throw_max := 20.0
@export_range(0.5, 30.0, 0.5) var item_throw_cooldown := 6.0
## A Large enemy's thrown item hits this many times as hard as its own blow.
@export_range(0.5, 5.0, 0.1) var item_throw_damage_mult := 1.5
## Loose boulders and branches around you in the valley: one cell of this size (m) in so many
## holds one (x the biome's rocks or trees), out to item_field_radius.
@export_range(5.0, 60.0, 1.0) var item_field_cell := 16.0
@export_range(0.0, 1.0, 0.01) var item_field_chance := 0.35
@export_range(20.0, 200.0, 5.0) var item_field_radius := 70.0

@export_group("Crowd split")
## In a crowd bigger than this, only this many nearest you fight at full rate; the rest take turns
## (combat feel plan, 2026-11-18: 150 crushable minions at 60 fps).
@export_range(10, 300) var crowd_full_fighters := 80
