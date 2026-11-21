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
## Slow motion after a perfect dodge and on a finisher: how long (real s) and the game speed.
@export_range(0.0, 2.0, 0.05) var perfect_dodge_slow_time := 0.35
@export_range(0.05, 1.0, 0.05) var perfect_dodge_slow_scale := 0.3
@export_range(0.0, 2.0, 0.05) var finisher_slow_time := 0.25
@export_range(0.05, 1.0, 0.05) var finisher_slow_scale := 0.25
## Your dash slows every enemy (user, 2026-11-20): for this long (s) they move and animate at this speed.
@export_range(0.0, 2.0, 0.05) var dash_enemy_slow_time := 0.33
@export_range(0.05, 1.0, 0.05) var dash_enemy_slow_scale := 0.4

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
## Walking speed, m/s (sam-movement SPEED 5.0, lowered 45% on 2026-10-22; 33% faster on 2026-11-20).
@export_range(1.0, 15.0, 0.05) var move_speed := 3.65
## Speed while holding Sprint (sam-movement 15, lowered 45%; 33% faster on 2026-11-20).
@export_range(1.0, 40.0, 0.05) var sprint_speed := 11.0
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
## Landing this fast or faster (m/s down) kicks up the landing dust (models/own/fx/movement/landing.tscn).
## A standing jump lands at about jump_velocity_base, so the default skips those.
@export_range(1.0, 40.0, 0.5) var landing_fx_speed := 10.0
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
## Camera drop while sliding or crouching, in meters.
@export_range(-2.0, 0.0, 0.05) var slide_camera_offset := -0.6
## Movement speed while doing a light attack or casting (fraction of walk speed).
@export_range(0.0, 1.0, 0.05) var attack_move_factor := 0.3
@export_range(1.0, 40.0, 0.5) var dodge_speed := 16.0
@export_range(0.05, 1.0, 0.01) var dodge_duration := 0.22
## Invulnerable for this long at the start of a dodge.
@export_range(0.0, 1.0, 0.01) var dodge_iframes := 0.2
@export_range(0.0, 100.0, 1.0) var dodge_stamina_cost := 25.0
## The dash's after-images: one left behind every this many seconds, fading out over dash_ghost_fade.
@export_range(0.01, 0.5, 0.01) var dash_ghost_every := 0.05
@export_range(0.05, 2.0, 0.05) var dash_ghost_fade := 0.3
@export var dash_ghost_color := Color(0.55, 0.8, 1.0, 0.45)
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
## Stamina per second while sprinting.
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
## A jump crouches at least this long (s) first: knees bend even on a tap (user, 2026-11-06).
@export_range(0.0, 0.4, 0.02) var jump_crouch_min := 0.12
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
## The Fire Lance's beam (user, 2026-11-19): how long it stays on, following your aim (s). It fires
## from a magic circle this wide (m) this far in front of your forehead (m). Its length and width
## are range_m and radius_m (half its width) on the God Abilities data.
@export_range(0.1, 3.0, 0.05) var lance_beam_time := 0.8
@export_range(0.2, 3.0, 0.05) var lance_circle_diameter := 1.0
@export_range(0.0, 1.5, 0.05) var lance_circle_ahead := 0.4
## The Fire Lance's circle sits this far (m) in front of your chest instead (user, 2026-11-20), and
## the beam and circle are tinted this color (user, 2026-11-20: deeper, but still fire: orange to red;
## white keeps your scene's own colors).
@export_range(0.0, 3.0, 0.05) var lance_chest_ahead := 1.0
@export var lance_tint := Color(1.0, 0.6, 0.3)
## Fired in the air pointing down (user, 2026-11-20), the lance's push carries you: away from where
## it points, this fast (m/s), so aiming at the ground under you lifts you up.
@export_range(0.0, 40.0, 0.5) var lance_fly_speed := 12.0
## How much faster the circle spins while the beam fires (degrees a second, on top of its own turn; user, 2026-11-19).
@export_range(0.0, 2000.0, 10.0) var lance_circle_beam_spin := 540.0
## The Lightning beam (E, user 2026-11-20): it shoots from a magic circle before your forehead for this long (s).
@export_range(0.1, 3.0, 0.05) var lightning_beam_time := 0.5
## The Magma ball (Fire Q, user 2026-11-20): you reach into the ground and pull it out over this long (s),
## hold it this long (s), then hurl it where you aimed: the throw releases this long (s) after it starts
## and the ball flies nearly flat this fast (m/s), dropping this much (m/s each second), this big
## (radius, m), bursting on the first thing it touches (user, 2026-11-20: faster, no lob).
@export_range(0.05, 1.5, 0.05) var magma_pull_time := 0.25
@export_range(0.0, 1.0, 0.05) var magma_hold_time := 0.05
@export_range(0.05, 1.0, 0.05) var magma_throw_windup := 0.1
@export_range(5.0, 120.0, 1.0) var magma_speed := 45.0
@export_range(0.0, 20.0, 0.5) var magma_drop := 4.0
@export_range(0.1, 2.0, 0.05) var magma_ball_size := 0.45

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
## Fire (user, 2026-11-20): you rise this high (m) off the ground over this long (s), and hang there
## until the dragons land.
@export_range(0.0, 15.0, 0.5) var ult_lift_height := 5.0
@export_range(0.1, 2.0, 0.05) var ult_lift_time := 0.4
## Five magic circles open in an arc over your head, this far above it (m),
## the arc this wide (radius, m), each circle this big (radius, m), one after another this far apart
## (s). After this long (s) a flame dragon pours out of each, snakes out and up, and they all dive
## into the aimed spot, taking this long (s) from the circle to the ground; the blast lands then.
## Its body is this many pieces, this thick at the head (radius, m), weaving this far each side (m)
## this many times on the way.
@export_range(0.5, 6.0, 0.1) var ult_arc_height := 1.6
@export_range(0.5, 6.0, 0.1) var ult_arc_radius := 2.2
@export_range(0.2, 3.0, 0.05) var ult_arc_circle_size := 0.7
@export_range(0.0, 0.5, 0.01) var ult_arc_gap := 0.08
## How far round from straight up (degrees) the two circles beside the middle one sit, and the two
## outer ones (user, 2026-11-20: wider; 35 and 70 before).
@export_range(0.0, 90.0, 1.0) var ult_arc_inner_angle := 45.0
@export_range(0.0, 120.0, 1.0) var ult_arc_outer_angle := 90.0
@export_range(0.1, 3.0, 0.05) var ult_dragon_delay := 0.6
@export_range(0.3, 4.0, 0.05) var ult_dragon_time := 1.35  # 0.9 until 2026-11-20 (user: 33% slower)
@export_range(6, 80) var ult_dragon_segments := 30
@export_range(0.2, 3.0, 0.05) var ult_dragon_size := 0.9
@export_range(0.5, 3.0, 0.05) var ult_dragon_head_scale := 1.25  ## the head, this much bigger than the body
## Each dragon's path is pushed up to this far (m) a random way every cast; they still land on the spot.
@export_range(0.0, 10.0, 0.25) var ult_dragon_wander := 4.0
## Each dragon leaves its circle any way at all, pulled this far (m) that way, and dives onto its spot
## from any side, from this far (m) and at least ult_dragon_dive_rise up (0 flat, 1 straight down)
## (user, 2026-11-20: not just up). Its path never dips below ult_dragon_floor (m) off the ground.
@export_range(0.0, 20.0, 0.5) var ult_dragon_launch_m := 7.0
@export_range(0.0, 20.0, 0.5) var ult_dragon_dive_m := 9.0
@export_range(0.0, 1.0, 0.05) var ult_dragon_dive_rise := 0.35
@export_range(0.0, 10.0, 0.5) var ult_dragon_floor := 3.0
@export_range(0.0, 8.0, 0.1) var ult_dragon_wave := 3.75  # 2.5 until 2026-11-20 (user: bigger curves)
@export_range(0.0, 6.0, 0.25) var ult_dragon_coils := 2.0
## Each dragon weaves its own number of times (user, 2026-11-20): ult_dragon_coils, give or take this.
@export_range(0.0, 4.0, 0.25) var ult_dragon_coils_spread := 1.25
## The other four dragons land up to this much (of ult_dragon_time) sooner or later than the middle
## one (user, 2026-11-20), never after the spell ends (you come back down).
@export_range(0.0, 1.0, 0.05) var ult_dragon_land_spread := 0.3
## The other four land at random spots this far out (of the ultimate's radius) from the aimed one (user, 2026-11-20).
@export_range(0.0, 1.5, 0.05) var ult_dragon_land_scatter := 0.8
@export_range(0.0, 2.0, 0.05) var ult_dragon_wave_up := 0.6  ## its up-and-down weave, this much of the side-to-side (0.3 until 2026-11-20)
## How much slower it goes through bends than down straights (0 = the same speed everywhere).
@export_range(0.0, 30.0, 0.5) var ult_dragon_bend_slow := 15.0  # 12 until 2026-11-20 (user: 25% sharper)
## Where the dragon lands the ground burns this long (s), over this much of the ultimate's radius,
## setting alight whoever is in it and dealing this much of the ultimate's damage a second.
@export_range(0.0, 15.0, 0.5) var ult_fire_ground_time := 4.0
@export_range(0.1, 2.0, 0.05) var ult_fire_ground_radius := 0.5
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

@export_group("Spells")
## The arena's spells (Arena Magic Attacks sheet, user 2026-11-20; scripts/player/spells.gd).
## From the key press to the slam or chop that sets a spell off (s): Lava Ripple, Ring of Ice,
## Thunder Crash, Bolt Fan, Stone Slab.
@export_range(0.0, 1.0, 0.01) var spell_release_delay := 0.22
## Lava Ripple and Ring of Ice: how fast the rings roll out (m/s), how many you see, the time
## between them (s), and how hard the edge hits next to the middle (1 = as hard).
@export_range(2.0, 40.0, 0.5) var ripple_speed := 12.0
@export_range(1, 6) var ripple_rings := 3
@export_range(0.0, 0.5, 0.01) var ripple_ring_gap := 0.12
@export_range(0.0, 1.0, 0.05) var ripple_edge_strength := 0.35
## Ring of Ice: how long a hit enemy stays frozen (s), how tall the icicles are (m) and how long
## they stand before shattering (s).
@export_range(0.0, 6.0, 0.1) var ice_ring_freeze := 2.0
@export_range(0.3, 4.0, 0.1) var icicle_height := 1.4
@export_range(0.1, 4.0, 0.1) var icicle_stay := 1.0
## Bolt Fan: how wide the fan of bolts spreads in front of you (degrees).
@export_range(10.0, 360.0, 5.0) var fan_arc_deg := 130.0
## Kaminari (user, 2026-11-20): press R once and you fly up; click to place cage_pillars pillars where you aim, within
## cage_place_time s (after that the rest stand at random round the ones placed). Then bolts bounce between
## them for cage_time s at cage_bolt_speed m/s (each bounce cage_speedup times faster, at most
## cage_max_bolts at once), each carried by a lightning hawk cage_hawk_size m across the wings, and
## the same enemy is struck again after cage_rehit s at the soonest.
@export_range(1.0, 30.0, 0.5) var cage_time := 5.0
@export_range(2, 10) var cage_pillars := 3  # 5 until 2026-11-20 (user)
@export_range(0.5, 30.0, 0.5) var cage_place_time := 3.0
## Each click throws: the throw's release this many s in.
@export_range(0.05, 1.0, 0.05) var cage_throw_windup := 0.1
@export_range(2.0, 80.0, 0.5) var cage_bolt_speed := 28.0
@export_range(1.0, 1.5, 0.01) var cage_speedup := 1.0
@export_range(1, 60) var cage_max_bolts := 24
@export_range(0.05, 2.0, 0.05) var cage_rehit := 0.4
@export_range(0.2, 15.0, 0.1) var cage_hawk_size := 5.0
## Each pillar is a large lightning bolt (your bolt pictures) this tall and wide (m), a new picture every this many s.
@export_range(2.0, 40.0, 0.5) var cage_pillar_height := 14.0
@export_range(0.5, 10.0, 0.25) var cage_pillar_width := 3.0
@export_range(0.02, 0.5, 0.01) var cage_pillar_frame := 0.06
## Whoever stands inside the pillars when it starts is caught there until it ends, struck every
## cage_rehit s for this much of its damage. You float this high (m) while it lasts.
@export_range(0.0, 1.0, 0.05) var cage_trap_damage := 0.25
@export_range(0.0, 20.0, 0.5) var cage_lift_height := 7.0  # 10 until 2026-11-20 (user: 3 m lower)
## Ice Slide: how long the slide takes (s) and how long its ice trail stays (s).
@export_range(0.1, 2.0, 0.05) var slide_time := 0.4
@export_range(0.5, 10.0, 0.5) var ice_trail_time := 3.0
## Ice Snake (the Ice ultimate): how long you ride it (s), how fast it flies (m/s), how fast it turns
## where you look, the lowest it flies (m), how near its body freezes (m) and for how long (s), how
## many pieces long it is and how big, and the highest it flies (m).
@export_range(1.0, 15.0, 0.5) var ice_snake_time := 5.0
@export_range(2.0, 40.0, 0.5) var ice_snake_speed := 13.0
@export_range(0.5, 20.0, 0.5) var ice_snake_turn := 4.0
@export_range(0.0, 6.0, 0.1) var ice_snake_height := 1.8
@export_range(0.2, 5.0, 0.1) var ice_snake_reach := 1.6
@export_range(0.5, 10.0, 0.25) var ice_snake_freeze := 3.0
@export_range(6, 80) var ice_snake_segments := 28
@export_range(0.2, 4.0, 0.05) var ice_snake_size := 1.5
@export_range(1.0, 40.0, 0.5) var ice_snake_max_height := 12.0
## Its icicle breath (a click while riding): icicles a breath, how wide they fan (degrees), how fast
## they fly (m/s), the damage each, and the time between breaths (s).
@export_range(1, 15) var ice_breath_icicles := 5
@export_range(0.0, 90.0, 1.0) var ice_breath_spread_deg := 24.0
@export_range(5.0, 120.0, 1.0) var ice_breath_speed := 45.0
@export_range(0.0, 200.0, 1.0) var ice_breath_damage := 20.0
@export_range(0.05, 2.0, 0.05) var ice_breath_gap := 0.3
## Stone Slab: how long the shape stands before it bursts into dust (s).
@export_range(0.1, 5.0, 0.1) var slab_stay := 1.0
## Stone Slab: what comes up out of the ground; Random picks one each cast.
@export_enum("Random", "Fist", "Hammer", "Tree", "Dolphin") var slab_shape := "Random"
## Stone Slab: how fast it throws you up when you cast it under yourself (m/s; 16 is about 8 m high).
@export_range(0.0, 40.0, 0.5) var slab_player_launch := 16.0
## Crushing Pillars: how wide the clash knocks enemies out (m across; half of it each side of the spot),
## and how long the rams take to rise out of their circles (s). (user 2026-11-20: rams, no charge.)
@export_range(4.0, 30.0, 0.5) var pillar_gap := 16.0
@export_range(0.0, 2.0, 0.05) var pillar_delay := 0.5
## Crushing Pillars: how big the two stone rams are (1 = the war ram mount's own size), and the stone
## bits each sheds 20 times a second while rearing.
@export_range(0.5, 4.0, 0.1) var ram_size := 2.6
@export_range(0, 10) var ram_shed_chunks := 2
## Crushing Pillars: how long the rams stand reared up on their hind legs before they lunge (s), and
## how long the lunge into the clash takes (s).
@export_range(0.0, 3.0, 0.05) var ram_rear_time := 1.0
@export_range(0.05, 1.0, 0.05) var ram_lunge_time := 0.1

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
## After any blow (yours or a spell's) an enemy can't land a strike for this long, large ones too (user, 2026-11-20).
@export_range(0.0, 2.0, 0.05) var enemy_hit_attack_lock := 0.25
## A blow rocks it back: its body leans this far (degrees) the way it was hit, straightening over this long (s).
@export_range(0.0, 45.0, 1.0) var enemy_hit_lean_deg := 15.0
@export_range(0.05, 1.5, 0.05) var enemy_hit_lean_time := 0.3
@export_range(0.3, 3.0, 0.05) var separation_radius := 1.2

## Outside fights you heal this % of your max health per second...
@export_range(0.0, 20.0, 0.5) var rest_regen_pct := 4.0
## ...starting this many seconds after you were last hit.
@export_range(0.0, 30.0, 0.5) var rest_regen_delay := 5.0

@export_group("Progression")
## XP needed scales with this; lower = faster level-ups.
@export_range(0.1, 5.0, 0.05) var xp_scale := 1.0

@export_group("Weapons, shots and launches")
## Every weapon in a hand is drawn this much bigger (user, 2026-11-01: 30%).
@export_range(0.5, 3.0, 0.05) var weapon_scale := 1.3
## A thrown weapon's hit: the launch is this much harder, and if it carries the enemy into a wall,
## tree or rock it's pinned there this long, taking this damage.
@export_range(1.0, 4.0, 0.05) var pin_launch_scale := 1.6
## An explosion launches the ones it ragdolls this much faster (user, 2026-11-08: 33%).
@export_range(1.0, 3.0, 0.05) var explosion_launch_scale := 1.33
@export_range(0.5, 20.0, 0.5) var pin_seconds := 5.0
@export_range(0.0, 500.0, 5.0) var pin_damage := 40.0
## Throwing your weapon (G, user 2026-11-20): it flies through every enemy in its path and pins them
## to walls, then lies where it lands (or sticks in a wall, a new one laid out). A tap throws at weapon_throw_speed; held
## for weapon_throw_charge_time it flies at weapon_throw_speed_max and hits twice as hard.
## Its hit is the weapon's damage times weapon_throw_damage_mult.
@export_range(5.0, 150.0, 1.0) var weapon_throw_speed := 35.0
@export_range(5.0, 150.0, 1.0) var weapon_throw_speed_max := 70.0
@export_range(0.05, 3.0, 0.05) var weapon_throw_charge_time := 0.6
@export_range(0.5, 10.0, 0.1) var weapon_throw_damage_mult := 3.0
## How fast a thrown weapon falls (m/s per second).
@export_range(0.0, 30.0, 0.25) var weapon_throw_drop := 6.0
## How many weapons lie about the arena; more are laid out after each wave to make up the count.
@export_range(0, 20, 1) var weapon_pickups := 6
## Your heavy and magic hits launch enemies: how fast and how high (m/s), before launch_velocity_mult.
@export_range(0.0, 40.0, 0.5) var launch_speed := 9.0
## A weapon's hit (melee heavies, the kick, thrown weapons and bodies; user 2026-11-20) launches back,
## not up: this fast and this high instead. The body knocks into enemies behind it for ram_damage and
## launches them the same way, each one ram_chain_falloff as hard as the one that hit it.
@export_range(0.0, 40.0, 0.5) var weapon_launch_speed := 14.0
@export_range(0.0, 20.0, 0.5) var weapon_launch_lift := 2.5
@export_range(0.0, 200.0, 1.0) var ram_damage := 10.0
@export_range(0.1, 1.0, 0.05) var ram_chain_falloff := 0.8
@export_range(0.0, 20.0, 0.5) var launch_lift := 7.0  # 4 before the reels' frame-by-frame (2026-11-18): launched enemies hang high
## Every launched enemy flies this many times faster (user, 2026-11-01: 30% more).
@export_range(0.5, 3.0, 0.05) var launch_velocity_mult := 1.3
## A flying enemy falls this many times harder than it rises (user, 2026-11-19: a heavier descent).
@export_range(1.0, 4.0, 0.05) var enemy_fall_gravity_mult := 1.6
## Blood drops from a hit, and from being slammed into something (x gore_amount; 24 since the
## combat feel plan, 2026-11-18: over the top).
@export_range(0, 60) var blood_hit_drops := 24
@export_range(0, 120) var blood_slam_drops := 40
## A thrown enemy that suddenly loses this much speed hit something (a tree, a
## house, a rock) and takes this much damage per m/s lost.
@export_range(1.0, 20.0, 0.5) var throw_impact_min := 6.0
@export_range(0.0, 20.0, 0.25) var throw_impact_damage := 3.0
## Falling (user, 2026-11-05): an enemy landing faster than this (m/s; 12 is about a 5 m drop) takes
## fall_damage per m/s over it. You take none for now.
@export_range(1.0, 40.0, 0.5) var fall_safe_speed := 12.0
@export_range(0.0, 50.0, 0.5) var fall_damage := 6.0
## With a bow, crossbow or spell weapon the camera sits this far to the right (m), over your shoulder.
@export_range(0.0, 2.0, 0.05) var aim_shoulder_offset := 0.8
## The third-person camera swings this many degrees round to your right, still looking at you in the
## middle of the screen (user, 2026-11-20: 15; 0 = straight behind you).
@export_range(0.0, 60.0, 1.0) var camera_side_deg := 15.0

@export_group("Waves")
## Enemies per wave; the arena runs through them in order.
@export var wave_sizes: PackedInt32Array = PackedInt32Array([8, 14, 22, 30, 40])
@export_range(0.0, 10.0, 0.5) var time_between_waves := 2.0
## Show a godly gift choice after every cleared wave.
@export var godly_gift_after_each_wave := true

@export_group("Feedback")
@export var show_damage_numbers := true
@export var hitstop_enabled := true

@export_group("Battles")
## Enemies on the field at once; the rest of a wave waits its turn (WaveDirector.reserve).
@export_range(5, 80) var battle_size := 35

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
## What you pull in (reel or yank) throws enemies in its path aside this fast (m/s; a heavy launch is launch_speed).
@export_range(0.0, 60.0, 0.5) var chain_plow_knockback := 22.0
## A flick of the mouse down this fast (radians/s of camera pitch) yanks it into a slam, this high (m).
@export_range(0.5, 20.0, 0.1) var chain_flick_rate := 3.0
@export_range(0.5, 10.0, 0.1) var chain_slam_height := 3.0
## A sweep of the mouse sideways this fast (radians/s of camera turn) swings it around you, at
## this radius (m) and at least this spin (radians/s).
@export_range(0.5, 20.0, 0.1) var chain_swing_rate := 4.0
@export_range(1.0, 8.0, 0.1) var chain_swing_radius := 3.5
@export_range(1.0, 30.0, 0.5) var chain_swing_spin := 9.0
## Each full turn of the swing (user, 2026-11-19) adds this much spin (radians/s), up to the cap.
@export_range(0.0, 10.0, 0.25) var chain_swing_spin_per_turn := 2.5
@export_range(1.0, 60.0, 0.5) var chain_swing_spin_max := 24.0
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

@export_group("Crowd split")
## In a crowd bigger than this, only this many nearest you fight at full rate; the rest take turns
## (combat feel plan, 2026-11-18: 150 crushable minions at 60 fps).
@export_range(10, 300) var crowd_full_fighters := 80

@export_group("Arena look")
## Glowing motes of magic drifting over the arena floor (fantasy pivot, 2026-11-19): how many are
## in the air at once (0 = none), and their color.
@export_range(0, 1000, 10) var arena_motes := 240
@export var arena_mote_color := Color(1.0, 0.78, 0.4)
