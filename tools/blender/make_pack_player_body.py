"""Puts the man from the Human animation packs (HumanM_Model.fbx, in every "Human ... Animations FREE"
zip under Models/) on the game's skeleton and saves him as game/models/own/player_body.glb, every
race's player, with no head: the game puts the god's element there (CharacterModel.set_head_ball).
Stands in for the user's own base body (make_player_body.py) for now (user, 2026-11-20).

    blender -b -P tools/blender/make_pack_player_body.py -- "<HumanM_Model.fbx>" "<HumanAnimations_ColorPalette.png>"

The game skeleton's joints move onto his (each bone keeps its direction, so the animations play
unchanged) and his own skin weights are carried over, bone for bone (MAP).
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RIG_SRC = os.path.join(ROOT, "game", "models", "gen", "race_human.glb")
OUT = os.path.join(ROOT, "game", "models", "own", "player_body.glb")

# Game bone -> his joint it starts at. hand: between his wrist and knuckles.
JOINTS = {"root": "B-root", "hips": "B-hips", "spine": "B-spine", "chest": "B-chest", "head": "B-neck",
          "upperarm": "B-upperArm", "lowerarm": "B-forearm", "wrist": "B-hand", "handslot": "B-handProp",
          "upperleg": "B-thigh", "lowerleg": "B-shin", "foot": "B-foot", "toes": "B-toe"}
# His weight groups -> game bone (fingers ride the hand, the collarbones the chest).
MAP = {"B-root": "hips", "B-hips": "hips", "B-spine": "spine", "B-chest": "chest", "B-shoulder": "chest",
       "B-neck": "head", "B-head": "head", "B-jaw": "head", "B-upperArm": "upperarm", "B-forearm": "lowerarm",
       "B-hand": "hand", "B-handProp": "hand", "B-index": "hand", "B-middle": "hand", "B-ring": "hand",
       "B-pinky": "hand", "B-thumb": "hand", "B-thigh": "upperleg", "B-shin": "lowerleg", "B-foot": "foot",
       "B-toe": "toes"}
HEAD = ("B-head", "B-jaw")  # what these move is cut away


def split(name):
    """'B-upperArm.L' -> ('B-upperArm', '.l'); 'upperarm.l' -> ('upperarm', '.l')."""
    base, _, side = name.partition(".")
    return base, ("." + side.lower()) if side else ""


def main():
    fbx, palette = sys.argv[sys.argv.index("--") + 1:][:2]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    his = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
    body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    joints = {b.name: his.matrix_world @ b.head_local for b in his.data.bones}
    me = body.data
    me.transform(body.matrix_world)  # his rest pose, in metres
    body.modifiers.clear()
    body.parent = None
    body.matrix_world = Matrix.Identity(4)
    body.name = "player_body"
    bpy.data.objects.remove(his)

    # His weights, renamed to the game's bones (one group per game bone, weights added up).
    groups = {g.index: g.name for g in body.vertex_groups}
    weights = []
    for v in me.vertices:
        w = {}
        for g in v.groups:
            base, side = split(groups[g.group])
            prefix = next((k for k in MAP if base.startswith(k)), None)
            if prefix is not None and g.weight > 0.0:
                bone = MAP[prefix] + (side if MAP[prefix] not in ("hips", "spine", "chest", "head") else "")
                w[bone] = w.get(bone, 0.0) + g.weight
        head = sum(g.weight for g in v.groups if split(groups[g.group])[0] in HEAD)
        weights.append((w, head))
    body.vertex_groups.clear()

    # Cut off the head: faces whose corners mostly follow his head bone.
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    if bm.verts.layers.deform.active is not None:  # his old weights, else they'd ride the new groups' numbers
        bm.verts.layers.deform.remove(bm.verts.layers.deform.active)
    orig = bm.verts.layers.int.new("orig")  # deleting renumbers the vertices
    for v in bm.verts:
        v[orig] = v.index
    gone = [f for f in bm.faces if sum(weights[v.index][1] for v in f.verts) / len(f.verts) > 0.5]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    keep = [v[orig] for v in bm.verts]
    bm.verts.layers.int.remove(orig)
    bm.to_mesh(me)
    bm.free()
    weights = [weights[i] for i in keep]

    # The game skeleton, its joints moved onto his.
    bpy.ops.import_scene.gltf(filepath=RIG_SRC)
    arm = bpy.data.objects["Rig_Medium"]
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body]:
        bpy.data.objects.remove(o)
    to_local = arm.matrix_world.inverted()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    heads = {}
    for b in eb:
        base, side = split(b.name)
        if base in JOINTS:
            heads[b.name] = to_local @ joints[JOINTS[base] + side.upper()]
    for side in (".l", ".r"):  # the hand bone starts between his wrist and knuckles
        heads["hand" + side] = to_local @ ((joints["B-hand" + side.upper()] + joints["B-middleFinger01" + side.upper()]) / 2)
    for b in eb:
        d = (b.tail - b.head).normalized()
        kids = [c for c in b.children if c.name in heads and (heads[c.name] - heads[b.name]).length > 0.01]
        length = (heads[kids[0].name] - heads[b.name]).length if kids else b.length
        roll = b.roll
        b.head = heads[b.name]
        b.tail = heads[b.name] + d * length
        b.roll = roll
    for name in ("root", "handslot.l", "handslot.r"):
        eb[name].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")

    for v, (w, _) in zip(me.vertices, weights):
        for bone, x in w.items():
            g = body.vertex_groups.get(bone) or body.vertex_groups.new(name=bone)
            g.add([v.index], x, "ADD")
    body.parent = arm
    body.matrix_parent_inverse = arm.matrix_world.inverted()
    body.modifiers.new("Armature", "ARMATURE").object = arm

    # His colors: the packs' palette texture.
    mat = bpy.data.materials.new("human_palette")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(palette)
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.clear()
    me.materials.append(mat)

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
    print("player_body: %d verts, saved %s" % (len(me.vertices), OUT))


main()
