Models the game loads (see docs/ART_SWAP.md):
- `own/`  your models, named as in the spreadsheet's model columns. They always win.
- `free/`  free packs: KayKit weapons (`make_kaykit_weapons.py`) and Quaternius animals (`make_free_animals.py`, `make_pack_animals.py`). Lookup order: own, gen, free.
- `gen/`  the generated low-poly set: people, the other weapons and gear, mounts and beasts (`tools/blender/make_characters.py`,
  `make_weapons.py`, `make_creatures.py`); `gen/held.json` says what each generated person holds.
- `gen/world/`  trees, rocks, bushes, grass, village buildings and props, the arena (`make_trees.py`, `make_props.py`).
- `kaykit/animations/`  the shared character animations (KayKit, CC0). Every person model uses this skeleton.
