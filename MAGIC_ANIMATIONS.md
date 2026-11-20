# Magic attack animations: plan

Written 2026-11-20. Covers the arena's magic types: Fire, Lightning, Ice and Stone (3 abilities each, in
`game/data/god_abilities.json`). The other 11 gods stay set aside
(`SHELVED_GODS` in `game_data.gd`). Race actives come after this.

## Where things stand

- Each ability names its body animation in the `animation_name` column. All but one name a clip
  that doesn't exist (`forge_signature`, `storm_ultimate`, ...), so those spells play
  `Throw` (ultimates play `Ranged_Magic_Raise`). Only the Fire Lance has a real clip (`Melee_1H_Attack_Stab`).
- Every cast is squeezed into the same 0.4 s (`CAST_CLIP` in `player.gd`), whatever the clip.
- The damage and the effect fire the moment you press the key, not when the hand comes down.
- Effects: Fire, Lightning and Stone have your own hand-made scenes in `models/own/fx/`.
  Ice use the code particles in `element_fx.gd` (colored bursts).

## The idea: every spell has three beats

1. **Wind-up**: the body gathers (arm back, weapon raised). The hand glows in the element's color.
2. **Release**: the strike frame. Damage, the effect, a small camera shake and hit-stop all land here.
3. **Recovery**: the follow-through. You can cancel it with a dodge.

Melee swings already work this way (`play_strike` in `character_model.gd` plays fast up to the
clip's strike frame, then slow). Spells will reuse it.

## Phases

### Phase 1: real body clips (data only, quick)
Replace the placeholder names in `animation_name` with the KayKit clips in the table below.
Add a test that every `animation_name` exists on the player rig.

### Phase 2: timing
- A `cast_time_s` column per ability (default 0.4) so a big summon can take 0.9 s and a quick shot 0.3 s.
- Fire the damage and the effect on the clip's strike frame instead of on the key press
  (add the magic clips to the `STRIKES` table).
- Camera shake and hit-stop per slot (Signature small, Ultimate big), numbers in `combat_tuning.tres`.

### Phase 3: one shared magic look
- Hand glow during the wind-up, in the element's color (reuses `ElementFx` colors).
- The magic circle that the Fire Lance and the ultimates already open, on every Signature too.
- This gives every element a finished feel before any hand-made effect exists.

### Phase 4: your hand-made effects
Make them in the same way as Fire, Lightning and Stone; any file you add replaces the code effect:
- `models/own/fx/<element>_blast.tscn` covers every blast of that element (the biggest win).
- `models/own/fx/<ability_id>.tscn` for one ability (for example `storm_thunder_crash.tscn`).

Missing now: Ice (`ice_blast.tscn` or per-ability scenes).

### Phase 5: your own body clips (Blender)
KayKit has no clip for these; the table marks them **custom**. Until you make them, the stand-in clip plays.
None needed for the four kept gods.

## The attacks
Each attack, what it should do and its clip live in the Arena Magic Attacks sheet:
https://claude.ai/artifact/2Q2LqRmfXS7nyVMWxi1KWe
Its clips are in the `animation_name` column of `game/data/god_abilities.json`.
