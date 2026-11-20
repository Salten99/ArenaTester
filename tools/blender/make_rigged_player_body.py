"""Puts an already rigged character on the game's skeleton and saves it as
game/models/own/player_body.glb, every race's player, with no head: the game puts the god's element
there (CharacterModel.set_head_ball). Knows two rigs (PROFILES, picked by their bone names):
  - the Knight by Dawid2K (Downloads/Knight by Dawid2K - isC73B8SKq.glb), the player now (user, 2026-11-20);
  - the man from the Human animation packs (HumanM_Model.fbx in any "Human ... Animations FREE" zip;
    give the zip's Textures/HumanAnimations_ColorPalette.png too, his file has no colors).

    blender -b -P tools/blender/make_rigged_player_body.py -- "<model .glb/.fbx>" ["<palette .png>"]

The game skeleton's joints move onto the character's (each bone keeps its direction, so the
animations play unchanged) and the character's own skin weights are carried over, bone for bone.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RIG_SRC = os.path.join(ROOT, "game", "models", "gen", "race_human.glb")
OUT = os.path.join(ROOT, "game", "models", "own", "player_body.glb")
HEIGHT = 1.8  # m, feet to the top of its head (before the head is cut away)

# joints: game bone -> the character's joint it starts at; (a, b) = halfway between; {s} = where the side goes; None = the
# floor under the hips. weights: the character's weight groups (by name start) -> game bone.
# head: the groups whose faces are cut away.
PROFILES = {
    "B-hips": {
        "joints": {"root": "B-root", "hips": "B-hips", "spine": "B-spine", "chest": "B-chest", "head": "B-neck",
                   "upperarm": "B-upperArm", "lowerarm": "B-forearm", "wrist": "B-hand",
                   "hand": ("B-hand", "B-middleFinger01"), "handslot": "B-handProp",
                   "upperleg": "B-thigh", "lowerleg": "B-shin", "foot": "B-foot", "toes": "B-toe"},
        "weights": {"B-root": "hips", "B-hips": "hips", "B-spine": "spine", "B-chest": "chest", "B-shoulder": "chest",
                    "B-neck": "head", "B-head": "head", "B-jaw": "head", "B-upperArm": "upperarm",
                    "B-forearm": "lowerarm", "B-hand": "hand", "B-index": "hand", "B-middle": "hand",
                    "B-ring": "hand", "B-pinky": "hand", "B-thumb": "hand", "B-thigh": "upperleg",
                    "B-shin": "lowerleg", "B-foot": "foot", "B-toe": "toes"},
        "head": ("B-head", "B-jaw"),
    },
    "Spine2": {  # the Knight: no neck, wrists or toes
        "joints": {"root": None, "hips": "Root", "spine": "Spine1", "chest": "Spine2", "head": "Head",
                   "upperarm": "UpperArm", "lowerarm": "LowerArm", "wrist": "Hand", "hand": ("Hand", "Hand{s}_end"),
                   "handslot": ("Hand", "Hand{s}_end"), "upperleg": "UpperLeg", "lowerleg": "LowerLeg",
                   "foot": "Fot", "toes": ("Fot", "Fot{s}_end")},
        "weights": {"Root": "hips", "Spine1": "spine", "Spine2": "chest", "Shoulder": "chest", "Head": "head",
                    "UpperArm": "upperarm", "LowerArm": "lowerarm", "Hand": "hand", "UpperLeg": "upperleg",
                    "LowerLeg": "lowerleg", "Fot": "foot"},
        "head": ("Head",),
    },
}
MIDDLE = ("hips", "spine", "chest", "head")  # game bones with no side


def split(name):
    """'UpperArm.L' -> ('UpperArm', '.l'); 'upperarm.l' -> ('upperarm', '.l')."""
    base, _, side = name.partition(".")
    return base, ("." + side.lower()) if side else ""


def named(spec, side):
    """A joint's name on one side: 'UpperArm' -> 'UpperArm.L'; 'Hand{s}_end' -> 'Hand.L_end'."""
    return spec.format(s=side.upper()) if "{s}" in spec else spec + side.upper()


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, palette = args[0], (args[1] if len(args) > 1 else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if src.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=src)
    else:
        bpy.ops.import_scene.gltf(filepath=src)
    his = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
    body = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.vertex_groups][0]
    prof = next(p for key, p in PROFILES.items() if key in his.pose.bones)

    # Where it stands as shown (some files keep the bones posed away from their rest), scaled to HEIGHT,
    # feet on the floor, centred under the hips.
    joints = {pb.name: his.matrix_world @ pb.head for pb in his.pose.bones}
    shown = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    cos = [body.matrix_world @ v.co for v in shown.vertices]
    bottom = min(c.z for c in cos)
    k = HEIGHT / (max(c.z for c in cos) - bottom)
    hips = joints[prof["joints"]["hips"]]
    fit = Matrix.Scale(k, 4) @ Matrix.Translation(-Vector((hips.x, hips.y, bottom)))
    me = body.data
    for v, c in zip(me.vertices, cos):
        v.co = fit @ c
    joints = {n: fit @ p for n, p in joints.items()}
    body.modifiers.clear()
    body.parent = None
    body.matrix_world = Matrix.Identity(4)
    body.name = "player_body"
    for o in [o for o in bpy.context.scene.objects if o != body]:
        bpy.data.objects.remove(o)

    # Its weights, renamed to the game's bones (one group per game bone, weights added up).
    groups = {g.index: g.name for g in body.vertex_groups}
    weights = []
    for v in me.vertices:
        w = {}
        for g in v.groups:
            base, side = split(groups[g.group])
            prefix = next((p for p in prof["weights"] if base.startswith(p)), None)
            if prefix is not None and g.weight > 0.0:
                bone = prof["weights"][prefix] + ("" if prof["weights"][prefix] in MIDDLE else side)
                w[bone] = w.get(bone, 0.0) + g.weight
        head = sum(g.weight for g in v.groups if split(groups[g.group])[0] in prof["head"])
        weights.append((w, head))
    body.vertex_groups.clear()

    # Cut off the head: faces whose corners mostly follow its head bone.
    bm = bmesh.new()
    bm.from_mesh(me)
    if bm.verts.layers.deform.active is not None:  # the old weights, else they'd ride the new groups' numbers
        bm.verts.layers.deform.remove(bm.verts.layers.deform.active)
    orig = bm.verts.layers.int.new("orig")  # deleting renumbers the vertices
    for i, v in enumerate(bm.verts):
        v[orig] = i
    gone = [f for f in bm.faces if sum(weights[v[orig]][1] for v in f.verts) / len(f.verts) > 0.5]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    keep = [v[orig] for v in bm.verts]
    bm.verts.layers.int.remove(orig)
    bm.to_mesh(me)
    bm.free()
    weights = [weights[i] for i in keep]

    # The game skeleton, its joints moved onto the character's.
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
        spec = prof["joints"][base]
        if spec is None:
            p = Vector((0.0, 0.0, 0.0))
        elif isinstance(spec, tuple):
            p = (joints[named(spec[0], side)] + joints[named(spec[1], side)]) / 2
        else:
            p = joints[named(spec, side)]
        heads[b.name] = to_local @ p
    for b in eb:
        d = (b.tail - b.head).normalized()
        kids = [c for c in b.children if (heads[c.name] - heads[b.name]).length > 0.01]
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

    if palette:  # the pack man's colors live in a separate palette texture
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
    print("player_body: %d verts, scaled x%.3f, saved %s" % (len(me.vertices), k, OUT))


main()
