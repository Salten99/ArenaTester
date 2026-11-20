# Architecture

How the game code is organized. The first part is for you (the developer); the rest is the map Claude reads at the start of every session. Keep it current when systems change.

## In plain English

**The game:** a mythical gladiator arena. You pick a weapon and a god's element in the arena menu and fight endless waves of mythical foes (skeleton warriors and archers, gorgons, minotaurs, cyclopes) in one arena, in first or third person, until you fall. Your score is the wave and the kills. It began as a copy of Pantheon Valley (`C:\Users\samue\Desktop\GodsGame`); the valley, its world, the run flow and the saves were removed on 2026-11-19.

**What you edit vs. what Claude edits:**

| You | Ask Claude |
|---|---|
| `data/*.json` (gods, weapons, godly gifts, races, units), edited by hand | Any `.gd` script |
| `tuning/combat_tuning.tres` in the Inspector (feel, waves, the arena's motes) | New weapon types, godly gift effects, god passives |
| `scenes/gladiator_arena.tscn` in the editor (the arena's sun, sky, haze, glow) | Hooking models up (`ModelRegistry`) |
| Models in `models/own/` (.glb from Blender; they win over the generated ones) | Fixing anything a test or playtest finds |

## The game at a glance (code view)

```
endless_arena.tscn (main scene): EndlessArena extends Arena
   Arena._prepare_run: Run.start_new(race, god, seed, weapon)  (god and weapon from the arena menu, Flow)
   Arena._build_level: gladiator_arena.tscn (lighting, sky), the arena_ground shader, magic motes, 8 throwables
   Player (movement, WeaponMoveset, AbilityRunner, Grabber, Chain, GodlyGiftManager)
   WaveDirector (EndlessArena.wave_units: ON_FIELD at a time, the rest as reserve)
   Enemies + CrowdDirector, Combat.deal(), Hud, ArenaMenu (loadout, Esc), ArenaHazard (spikes, fire pits)
main.tscn: a plain Arena, the practice waves from tuning with godly gifts and level-ups (the tests use it)
```

## Folders

```
ArenaGame/
  CLAUDE.md               working rules
  tools/                  run_tests.bat (headless tests), play.bat, open_editor.bat, art_checklist.bat
  game/                   the Godot 4.7 project (open game/project.godot)
    data/                 game data, one JSON file per table (edited by hand)
    tuning/combat_tuning.tres   feel numbers, edited in the Inspector
    models/               free/, gen/ (generated stand-ins), own/ (the user's models, they win over gen/)
    scenes/               endless_arena.tscn (main), main.tscn (practice arena), gladiator_arena.tscn (the level)
    scripts/
      autoload/           global services (see below), DataCheck (data cross-check)
      arena/              Arena, EndlessArena, WaveDirector, ArenaHazard, ArenaPickup, DebugTools
      combat/             damage, health, statuses, godly gifts, movesets, projectiles, Breakable, Throwable, ElementFx, Vfx, UltimateFx
      player/             Player, input, camera, AbilityRunner, Grabber, Chain, RaceActive
      enemies/            Enemy AI, CrowdDirector
      progression/        LevelSystem
      run/                RunState (who you are this fight), SaveSystem (the profile only)
      visual/             CharacterModel, BeastModel, ModelRegistry
      ui/                 Hud, ArenaMenu, Bestiary, ControlsMenu, UiStyle
    shaders/              arena_ground (grass and stone pictures on the arena), blood overlay, effects
    tests/                test_main.tscn (automated tests), art_checklist.tscn, move_shots and clip_shots (run by hand)
```

## Autoloads (global services)

| Name | File | Job |
|---|---|---|
| `GameData` | autoload/game_data.gd | Loads `data/*.json` and the tuning resource. `row`, `rows`, `where`, `num`, `text`, plus helpers (`god`, `race`, `status`, `godly_gifts_for`, `abilities_for`, `unit`). |
| `RunRng` | autoload/run_rng.gd | The only gameplay randomness, seeded per fight. |
| `HitStop` | autoload/hit_stop.gd | Brief game slowdown on impact (real-time timed). |
| `Controls` | autoload/controls.gd | Registers input actions and key bindings in code. |
| `Combat` | autoload/combat.gd | The only place damage is applied: `Combat.deal(target, DamageInfo)`. Statuses, lightning chains, feedback, game clock and the signals godly gifts listen to. |
| `Meta` | autoload/meta.gd | The profile (`user://profile.json`): unlocked races and gods, the bestiary (codex). |
| `Run` | autoload/run.gd | The fight's player state: `start_new`, `note` (recap counts), `end`. Holds `Run.state` (a `RunState`: race, weapon, god, godly gifts, level). |
| `Flow` | autoload/flow.gd | Keeps the god and weapon picked in the arena menu across a scene reload; sets the UI theme. |
| `Playtest` | autoload/playtest.gd | The F11 overlay: session time, deaths, kills, frame time. Deaths go to `user://playtest_log.txt`. Tests set `persist = false`. |

## Rules (keep these)

1. **Input is separate from logic.** The player reads a `PlayerIntent` each physics frame from `input_source` (keyboard via `PlayerInput`, scripted input in tests). Gameplay code never reads `Input` directly.
2. **Seeded randomness.** Gameplay uses `RunRng`. Visual-only effects may use the globals.
3. **Game time, not wall time.** Godly gift cooldowns and timed buffs use `Combat.now_msec()`. Only `HitStop` uses the real clock.
4. **All damage goes through `Combat.deal()`.** Build a `DamageInfo` and hand it over. `DamageInfo.Kind` stops godly gifts re-triggering on their own damage.
5. **Data lives in `data/*.json`; feel numbers in `combat_tuning.tres`.** Anything the data can't express yet goes in a small, commented table in code (`GodlyGiftRules.RULES`, `ModelRegistry`). `DataCheck.run()` cross-checks the data on load; its problems print as warnings and fail a test.
6. **The build lives in `RunState`.** `GodlyGiftManager` writes godly gifts back to `state.godly_gifts`; `Player.apply_run_state(state)` rebuilds the player from it.
7. **Scenes stay minimal; nodes are built in code.** Claude can edit and test everything as text. Models come from `ModelRegistry`; the capsule is the fallback.

## The arena

- **Roster** (fantasy pivot, 2026-11-19): `WaveDirector.BASIC_UNIT` (skeleton warrior; a `#shield` token adds a shield), `EndlessArena.SHOOTER` (skeleton archer), `EndlessArena.CASTER` (gorgon, role Magic: ground circles and an element), `WaveDirector.TOUGH_UNIT` (minotaur, `Enemy.CHARGER`: it charges) and `WaveDirector.LARGE_UNIT` (cyclops, every `LARGE_EVERY` waves). `EndlessArena.HITS_TO_KILL` sets their health from your light hit. More mythical units with models wait in the data (harpy, mummy, necromancer, cerberus, chimera, frost giant and others).
- **Look:** full-resolution rendering (a 1920x1080 window, 4x MSAA, 16x anisotropic filtering). `scenes/gladiator_arena.tscn` holds the golden-hour sun, the dusk sky, the AgX tone map, SSAO, glow and a thin haze. `Arena._add_motes` adds glowing motes of magic (`arena_motes`, `arena_mote_color`).
- **Arena tactics** (`Enemy.tactics`, on for the endless arena): posture breaks and grab finishers, shields from the front, shooters that keep their distance, casters' ground circles (`WitchCircle`), element reactions (`ElementReactions`), the charger, traps (`ArenaHazard`) and pickups (`ArenaPickup`).

## Damage flow

```
Player attack ──> WeaponMoveset.light_hit/heavy_hit
               ──> Player.hit_targets() or fire_projectile()  ──> Player.make_hit() (race % + god % + godly_gift % + crit)
               ──> Combat.deal(enemy, info)
                     ├─ enemy.take_hit()         health, knockback, stagger
                     ├─ statuses applied          StatusEffects.apply()
                     ├─ hit-stop, shake, number   feedback
                     ├─ signals: hit_landed, element_hit, status_applied, killed
                     └─ Lightning from the player chains to 2 (+chain_bonus) enemies
Player ──> GodlyGiftManager.trigger(event, ctx)   twice per swing:
             phase "target" once per enemy hit (statuses, single-target damage)
             phase "swing"  once per swing (area blasts, buffs)
```

## Godly Gifts

**Classes** (2026-11-09): a class is its melee weapon. The class columns on the Weapons sheet (`class_name`, the `_mod_pct` stats, `armor_pct`, `stealth_pct`) become the `class` `PlayerStats` source in `Player.equip`; `stealth_pct` shrinks `Enemy._notice_distance`. C or the wheel only switches to the sidearm; chests offer only the other sidearm. **Class looks per race** (2026-11-17): every race has the same classes; `ModelRegistry.class_part(race, class, part)` finds your `own/<race>/<class>/body|weapon|shield.glb` and `race_part(race, name)` your `own/<race>/bow|staff|knife.glb`. `for_race(race, class)` and `weapon_model` try those first, then the old lookups; `Player.equip` rebuilds the body when the class has its own (`_body`). `own()` also finds people files in `own/<race>/people/` (`_own_people`, `rescan()` after an import). The art checklist groups them as `Race: <name>`. Blender sources live in `art_src/`, outside the Godot project. **Guardian parry** (2026-11-17): `Player.parries()` (Guardian class, main weapon out) turns the dodge key into `State.PARRY`; `take_hit` asks `_parries_hit` (enemy hit, from the front, within `parry_window`); a melee blow calls `Enemy.parried()` (STAGGER for `parry_stagger`) and `_parry` adds the riposte buffs with `PlayerStats.add_timed`; a hit with `DamageInfo.shot` (set by `Projectile`) is only blocked. The shield is `gear_shield.glb` (`make_weapons.py`) on `handslot.l` via `CharacterModel.set_offhand`; the greatsword file is no longer `TWO_HANDED`.

`GodlyGiftManager` (under the player) owns godly gifts, ranks them up, makes offers (rarity-weighted, plus a duo godly gift once both gods are in the build) and runs effects by `effect_type`: Apply Status, Bonus Damage, Area Blast (or a lingering `Hazard`), Projectile, Stat Buff, Heal, Shield, Knockback/Pull. Passive godly gifts become a `PlayerStats` source. `suppress(seconds)` switches every godly gift off (the Void mark). Godly gifts the code can't run yet (effect type not handled, a trigger that never fires such as on_block, or a stat nobody reads: `PlayerStats.READ_STATS`) are never offered: `GodlyGiftManager.is_implemented()` filters offers and duos, `unbuilt()` lists them, and GameData prints them at startup. Level-ups are filtered the same way (`LevelSystem.is_implemented`). `load_from(state)` restores godly gifts from a save.

Triggers: the sheet's `trigger_event` plus `on_element_hit` (code-only, used by Fire + Lightning).

## Weapons and abilities

- **Weapons** are picked in the arena menu (`RunState.weapon_id`, Weapons sheet; `GameData.weapon_options(race)` reads the race's `weapon_options`, blank = all). `Player.weapon()` is the weapon's row (stats, class, attack category); `Player.element()` is the pledged god's element.
- **5 weapon movesets** (`WeaponMoveset.for_class(weapon_class)`): **Heavy** (3-hit combo, 4 m ground slam), **Blade** (wide arcs, spin finisher, dash-slash heavy), **Polearm** (line thrusts, sweep finisher, 360° heavy), **Ranged** (arrows, 3-arrow finisher, piercing heavy), **Caster** (element bolts, triple-bolt finisher, blast at range). Each also names its animations.
- `RaceActive` runs your race's active skill (V): one branch per race in `cast()`, numbers from the Races sheet. A race with no branch gets a plain blast.
- `AbilityRunner` runs any god's 3 abilities from the God Abilities columns. **Shapes:** `shape` Cone is the Fire Lance: you lunge `lance_lunge_m`, a magic circle opens before your brow and a beam (`range_m` long, `radius_m` wide each side, your `forge_fire_lance.tscn` stretched to fit) fires from it for `lance_beam_time`, following your aim (`AbilityRunner._update_beam`). The Fire ultimate lifts you on boot jets and fires three giant beams (`_fire_ultimate`). The row's `animation_name` plays if the rig has that clip (else Throw). **Aimed ultimates:** holding the key sets `PlayerIntent.ultimate_held` and `aim_point` (the camera's ground point, `PlayerInput._camera_ground_point`); `Player._update_aim` shows a ring at `aim_target()` (clamped to `AbilityRunner.aim_range()`) and casts on release with `cast(slot, player, dir, at)`. Scripted input with no aim point lands ahead (ranged ultimates) or where you stand. **Every ultimate** goes through `UltimateFx.play(element, spot, radius)` (`combat/ultimate_fx.gd`): a `MagicCircle` node (two counter-spinning layers of flat line ribbons built with SurfaceTool, tilted to the ground normal under the spot) at `ult_circle_height`, then after `ult_circle_delay` the element's strike falls for `ult_fall_time` (`_strike`: meteor, storm, icicles, shards, tornado, gas bomb + cloud, laser). `AbilityRunner` deals the damage once at `UltimateFx.impact_time()` (`_blast`, or `_multi_hit` with no radius, its hits coming from the circle); your own `<ability_id>.tscn` still plays at the spot on cast and then only the circle is drawn. The player holds `Ranged_Magic_Raise` for `ult_raise_time` unless the rig has the row's `animation_name`.
- God passives are a `match god_id` in `Player._god_passive_on_hit` (only Fire Passive so far).

## Movement

`Player._move()` is the sam-movement controller ported to the intent system: walk/sprint, fading momentum, speed-scaled jumps, a speed-adding slide, wall-jumps, crouch and a speed cap. Constants are in the tuning resource. The dodge (Ctrl) is separate from the slide.

## Models and animation

`CharacterModel` loads a rigged model, merges the KayKit Rig_Medium animation files into one `AnimationLibrary` per skeleton shape (rigs share one only if every `POSITION_BONES` bone rests within a centimetre; the animations' position keys for hips, shoulders, hip joints and hand slots are refitted to the model's own bone lengths, so any proportions work), walks and gallops four extra leg bones in code when a model has them (`quad_*`: the centaur, the mammoth), keeps a rider's posed hips on the saddle (`set_seat`), attaches the weapon to the `handslot.r` bone, and tints the model through a material overlay (hit flash, telegraph, burning, Void). **Your own models:** `ModelRegistry.own(file)` returns `models/own/<file>` when the sheet's model file exists there; every lookup (`for_race`, `weapon_model`, `for_unit`, `for_tribe`, `for_beast`, `for_mount`) checks it first, then the generated set in `models/gen` (`held.json`: what each person holds; `mounts.json`: each mount's saddle height; your converted mounts list theirs in `models/own/mounts.json`), then free animated animals in `models/free` (Quaternius CC0: livestock, wild herds, dinosaurs, the Raptor mount; `tools/blender/make_free_animals.py`) (docs/ART_SWAP.md). Units of faction `Animal` are `civilian`: they never fight and run from whoever hurts them (`_calm_left`). Two-handed weapons (`CharacterModel.TWO_HANDED`, by file name) swap in two-handed animations (`TWO_HANDED_ANIMS`) and pull the left hand onto the handle with a `TwoBoneIK3D` (target: the point of the handle nearest the left shoulder, each frame). `BeastModel` (extends CharacterModel) plays an animal's own clips (Idle, Walk, Gallop, Attack, HitReact, Death, Jump; a model with only a run clip walks on it at `WALK_ON_RUN` speed) behind the same play() names, or moves unanimated models in code (bob, lunge, flinch, fall); `ModelRegistry.BEASTS` lists them. `ModelRegistry` maps races, weapons and units to files; real art replaces entries there (later: the sheets' `model_file` columns). The player picks animations from its state each frame; enemies play the wind-up chop so the hit lands as the telegraph ends.

## Effects

`ElementFx` gives every damage type its look (`STYLES`: colors, particle shape, motion). `Combat._feedback` calls `hit()` on every non-status hit (bigger for heavy hits and crits), `Combat.deal` calls `kill()` on elemental kills, statuses add an `aura()` to the unit while they last (`StatusEffects.auras`, sized by `aura_size`), abilities and godly gift blasts use `area()`, shots use `beam()` (lightning zig-zags), projectiles carry a `trail()`. At most `HITS_PER_FRAME` hit bursts per frame. All particles are CPUParticles3D built in code: swap the table for hand-made effects later.

**Combat feel plan, part 1** (user, 2026-11-18; `docs/COMBAT_FEEL_PLAN.md`): `Vfx.blood` throws round drops scaled by `gore_amount` (the gore slider; 0 = none); `Combat._feedback` adds `Vfx.blood_stains` (splashes raycast onto the ground ahead of the blow, stretched its way, kept `blood_stain_seconds`, oldest gone past `blood_stain_max`) and on a kill a `blood_kill_drops` cloud; hits on `Enemy.wears_metal()` units (by role: Melee, Cavalry, Champion; not barbarians or beasts) throw `Vfx.sparks`, and a killing blow knocks off a `Vfx.armor_piece` (a RigidBody3D helmet or plate, at most `armor_pieces_max`). `CameraRig.kick(dir, amount)` pushes the view toward your blows (`camera_kick`, double for heavy). `CharacterModel.push_ragdoll` spins a launched body end over end (`launch_spin`). `SwingTrail` (combat/swing_trail.gd, made by `Player._update_animation`) draws a ribbon from the weapon's grip to `weapon_tip()` during LIGHT and HEAVY swings, steel tinted `swing_trail_tint` toward your element. **Part 2:** melee light attacks are `light_speed_mult` (1.25) faster (`Player._light_duration`; sidearms unchanged); `Player.charge_shown()` drives the HUD's charge bar under the crosshair (`Hud._charge`, red, orange, yellow by thirds). **Part 3:** `WeaponMoveset.launch_scale()` (Heavy 1.3, Polearm 1.1, Blade/Ranged/Caster 1.0, Twin 0.8) multiplies your launches in `Enemy.launch_from_hit`; spell bolts (`fire_projectile` with `elemental`) freeze `hitstop_heavy` and shake, and `launch_bolt_scale` is 1. No sound yet, so no sound weight. **Part 4, grab, crush and hurl:** `Player._light_hold` waits on a held light attack (`intent.light` with `light_held`; a tap swings at once as before): past `grab_hold_time` it calls `_try_grab()` (melee out, on foot) or swings. `Grabber` (player/grabber.gd, `Player.grabber`) finds the minion (`Grabber.grabbable`: not Large, champion, mini boss or boss) within `grab_reach`/`grab_arc_degrees`, holds it (`State.GRAB`, `Enemy.grab_by`: no collision, `_follow_hand` to `hold_point()`), crushes it after `crush_time`, drops it when you let go (`Enemy.release_grab`) and hurls it on right click (`Enemy.hurl`: a limp `throw` that deals your heavy damage to everyone it passes and, on a wall found by a ray ahead, bursts within `hurl_burst_radius`). `Grabber.shields` redirects an enemy's blow from the front to the held minion. `CharacterModel.free_left_hand` lets go of a two-handed handle meanwhile. **Part 5, the chain grab:** with no minion in reach, `_try_grab(intent)` fires `Chain` (player/chain.gd, `Player.chain`, `State.CHAIN`) at `find_target` (any enemy within `chain_cone_deg` of the crosshair, `chain_range`). A minion is hooked (`Enemy.grab_by`; `Player.hold_point_for` asks the hand or the chain where it hangs); `PlayerIntent.wheel_back` (the wheel turned back, read by `PlayerInput`) reels it into the hand grab (`Player._take_into_hand`), a fast drop in `aim_pitch` (`chain_flick_rate`) slams it (heavy blow within `hurl_burst_radius`), a fast turn of `aim_yaw` (`chain_swing_rate`) swings it at `chain_swing_radius` hitting what it sweeps, and letting go flings it (`Enemy.hurl`) or drops it. Large units, mini bosses and bosses (`Chain.pulls_you`) pull you in at `chain_pull_speed` (`Player._move` uses `pull_velocity`) for a drop kick (a heavy, `Melee_Unarmed_Attack_Kick`). While the chain is out the wheel doesn't switch weapons. The chain is a stretched steel bar until the user makes a chain model. **Part 6, throwable items:** `Throwable` (combat/throwable.gd, group `throwables`) is a barrel, crate, boulder or branch: `grab_by`/`release_grab`/`hurl` like a minion, held where its holder's `hold_point_for` says, flying under gravity, hitting with your heavy (`hit_targets`) or, thrown by an enemy, with its blow x `item_throw_damage_mult`, and breaking where it lands (barrels and crates through `Breakable.smash`, the rest into `Vfx.chunk`s). `Grabber.target` and `Chain.find_target` take items too (`Grabber.is_item`), nearest the aim wins; items aren't crushed. Large enemies lift one within `item_pickup_reach` and throw it (`Enemy._carry_item`). The arena lays out eight. Your own `models/own/world/<kind>.glb` win; the branch is built in code until there's a model. **Part 7, the body split:** `Player._update_animation` calls `CharacterModel.set_split(legs)` while you move (on the ground, faster than 0.6 m/s) during any move (LIGHT, HEAVY, CAST, PARRY, GRAB, CHAIN but not its pull or kick): `anim` plays the walk or run (`Player._legs_clip`) and `play()` sends moves to `_upper`, a second AnimationPlayer (non-deterministic, after `anim`) whose library is a copy of every clip keeping only bones from the spine up (`_upper_body_library`, cached per library). `set_split("")` hands the move back to the whole body. `current()` is the move either way. **Part 8, the crowd split (merged 2026-11-18 with the user's approval):** `CrowdDirector._rank_crowd` (each grid build) marks all but the `crowd_full_fighters` (80) units nearest you `Enemy.in_crowd`; in a crowd they take turns and walk without collisions like far units, and `CharacterModel.in_crowd` steps their animation as if far. Measured in a window on the dev PC, 150 raiders within 2-18 m: 15.9 ms a frame before, 15.2 after (about 63 and 67 fps); `crowd_bench.tscn` takes `BENCH=150,0`, `BENCH_NEAR`, `BENCH_FAR`. The MultiMesh crowd with GPU-baked animation stays for when 500 must run at 60. **Strike frames (the reels, frame by frame, 2026-11-18; `docs/COMBAT_FEEL_PLAN.md` has the sheet):** `CharacterModel.STRIKES` holds each shared clip's blow moment (measured by `tests/clip_probe.tscn`, the right hand at its fastest); `play_strike(clip, windup, total, hold)` plays fast to that frame so it lands with the hit, slow after it, and with `hold` waits `STRIKE_LEAD` before it until `release_strike()` (the charged heavy; `_update_strike` in `_process`; paused clips are tracked by `assigned_animation`). Swings use it with `light_windup_fraction` 0.25; the grab is a compressed `Melee_Unarmed_Attack_Punch_A` (`Player.GRAB_CLAMP`) then `Melee_Blocking`; right click winds up `Throw` for `Grabber.THROW_WINDUP` with the minion swung over your shoulder before it lets go; the squeeze trembles harder (`Grabber.hold_point`) and the crush calls `Player.screen_flash` (`Hud.flash`, red); the chain holds the punch pose, swings on `Melee_2H_Attack_Spinning`, slams on a timed `Melee_2H_Attack_Chop` and starts the kick `Chain.KICK_LEAD` early; Large units lift on `Ranged_Magic_Raise` and throw on a timed `Throw`. Heavy blows flash white (`Combat._feedback`), the hammer slam adds a white ring, `launch_lift` is 7. `tests/clip_shots.tscn` and `tests/move_shots.tscn` (by hand, in a window) picture the clips and your moves.

## Enemy shots, being stuck, ragdolls

- **Shots:** `Enemy` shooters (attack range > 5 m) lock `_aim_at` `ranged_aim_lock` seconds before firing, then `_shoot` fires a `Projectile` (`hostile` = hits you and the "allies" group). Magic-role shots get `homing` + `pull_deg`; your own shots never home: they go where the crosshair is, arrows aimed high enough to drop onto it (`Player.aim_direction`), with the camera over your right shoulder (`aim_shoulder_offset`) and a gold reticle for bows and spell weapons.
- **Stuck:** `Enemy._check_stuck` side-steps (`_detour`) when a unit barely moves while trying to. The Movement leap follows `Player.floor_below`.
- **Ragdolls:** `CharacterModel.ragdoll(push)` adds a `PhysicalBoneSimulator3D` with capsule `PhysicalBone3D`s (`RAGDOLL_BONES`, layer 6, world mask) and starts it; `MAX_RAGDOLLS` at once; `sink_ragdoll()` drops it through the ground before removal. The skeleton only takes the bodies' pose while drawing, so tests check the bodies.

## Testing

- `tools\run_tests.bat` runs `tests/test_main.tscn` headless with `--fixed-fps 60` through `tools/run_tests.py`, which also fails the run on any engine `ERROR:` line it doesn't expect (`EXPECTED`). Tests set `Meta.persist = false` so they never touch the real profile.
- Add a test for every new system.

## Adding things

- **A godly gift:** a row in `data/godly_gifts.json`; a special radius, duration or condition (Claude) goes in `GodlyGiftRules.RULES`.
- **A god:** rows in gods, god_abilities and godly_gifts; a passive (Claude) in `_god_passive_on_hit`.
- **A weapon:** a row in weapons with one of the classes; its model in `ModelRegistry.WEAPONS`.
- **A weapon type (Claude):** a subclass in `weapon_moveset.gd` and a case in `for_class`.
- **An enemy in the waves (Claude):** its id in `WaveDirector` or `EndlessArena` and in `HITS_TO_KILL`; its model through `ModelRegistry`.

## Controls

`Controls` (autoload) registers every input action from its `KEYS` / `MOUSE` lists, then applies the player's saved bindings (`user://controls.cfg`). `ControlsMenu` (scripts/ui) rebinds the `Controls.REBINDABLE` actions (click, then press a key or mouse button; a clash unbinds the other action); it opens from the arena's Esc menu.
