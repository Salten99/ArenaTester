"""Turns a pixelfx sprite sheet (https://github.com/patch-gg/pixelfx, MIT) into an effect scene for
models/own/fx: a camera-facing AnimatedSprite3D, its pivot (the floor under the effect) at the origin.

Render the sheet first, in the pixelfx folder:   node tools/render.mjs fire/fire-ring --sheet --no-actor
Then:   python tools/pixelfx_scene.py <sheet.json> <res://...scene.tscn> <pixels per metre> [frames to skip]
The sheet's PNG is copied next to the scene. Pixels per metre sets its size: an effect played at
size 1 (an area at 1 m radius) is that many sheet pixels to the metre. Skip drops lead-in frames (the
splash's falling stone). It draws over the floor: half of a ground ring is below its pivot.
"""
import json
import shutil
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent / "game"


def main(sheet_json: str, scene_res: str, px_per_m: float, skip: int = 0) -> None:
    sheet = json.loads(Path(sheet_json).read_text())
    meta = sheet["meta"]["pixelfx"]
    w, h = meta["frameSize"]
    px, py = meta["pivot"]
    frames = sheet["frames"]
    frames = (list(frames.values()) if isinstance(frames, dict) else frames)[skip:]
    scene = GAME / scene_res.removeprefix("res://")
    scene.parent.mkdir(parents=True, exist_ok=True)
    png = scene.with_suffix(".png")
    shutil.copyfile(Path(sheet_json).with_name(sheet["meta"]["image"]), png)
    png_res = "res://" + png.relative_to(GAME).as_posix()

    out = ['[gd_scene format=3]', '', f'[ext_resource type="Texture2D" path="{png_res}" id="sheet"]', '']
    for i, f in enumerate(frames):
        r = f["frame"]
        out += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("sheet")',
                f'region = Rect2({r["x"]}, {r["y"]}, {r["w"]}, {r["h"]})', '']
    listed = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % i for i in range(len(frames)))
    out += ['[sub_resource type="SpriteFrames" id="frames"]', 'animations = [{', f'"frames": [{listed}],',
            f'"loop": {"true" if meta["loop"] else "false"},', '"name": &"default",', f'"speed": {float(meta["fps"])}', '}]', '',
            f'[node name="{scene.stem}" type="Node3D"]', '',
            '[node name="Sprite" type="AnimatedSprite3D" parent="."]', 'centered = false',
            f'offset = Vector2({-px}, {-(h - py)})',  # the pivot (where it touches the floor) at the origin
            f'pixel_size = {1.0 / px_per_m:.5f}', 'billboard = 2', 'no_depth_test = true', 'texture_filter = 0',
            'sprite_frames = SubResource("frames")', 'autoplay = "default"', '']
    scene.write_text("\n".join(out))
    print(f"{scene_res}: {len(frames)} frames of {w}x{h}, {len(frames) / meta['fps']:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4]) if len(sys.argv) > 4 else 0)
