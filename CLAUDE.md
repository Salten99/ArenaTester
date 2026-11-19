# Arena Game (working title)

Solo hobby side project: Godot 4.7, a mythical gladiator arena horde fighter. Endless survival in one arena, a close third-person camera. Its purpose is to work out movement, combat feel, animations and effects; what works here goes back to Pantheon Valley (`C:\Users\samue\Desktop\GodsGame`). The user makes the models; Claude writes the code and explains it in plain terms (the user is new to Godot).

## Origin
Copied from Pantheon Valley's `game/` folder on 2026-11-19 (Pantheon Valley commit `ed3b96e`). The valley, races, raids and run code are still in the copy and still tested; they can be removed once the arena no longer needs them.

## Working rules
- Main scene: `game/scenes/endless_arena.tscn` (`scripts/arena/endless_arena.gd`, built on `Arena`).
- Run `tools\run_tests.bat` after every change; all checks must pass. Add a test for each new system.
- Feel numbers belong in `game/tuning/combat_tuning.tres` so the user can tune them in the Inspector.
- Game data is `game/data/*.json`. There is no spreadsheet here; edit the JSON directly.
- Commit after each working step; end commit messages with the attribution line.
- Python: `C:/ProgramData/anaconda3/python.exe`. Godot console: `%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
- Godot gotchas: a parse error in a headless scene makes Godot idle until the timeout. Values from untyped Arrays/Dictionaries need explicit types. A new `class_name` needs `godot --headless --path game --import` before tests.
- Coding style: Ponytail, full level (the smallest complete change, reuse what exists).
- Never invent names, except places. Gods go by titles (for example, Lord of the Forge).
