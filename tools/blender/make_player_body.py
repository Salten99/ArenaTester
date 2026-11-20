"""Rigs the user's humanoid base (local models/humanoid_base.glb: one unrigged A-pose mesh) onto the
game's human skeleton (models/gen/race_human.glb, the Rig_Medium bones every animation uses) and saves
it as game/models/own/player_body.glb, the player's body for every race.

    blender -b -P tools/blender/make_player_body.py -- "<path to humanoid_base.glb>"

The head is cut off at the neck: the game puts the god's element there (a fireball, a ball of ice,
a ball of lightning, a boulder; CharacterModel.set_head_ball). The skeleton's arms and legs are turned
to the mesh's A-pose before the weights are made; the animations set each bone's rotation outright,
so a different rest pose plays the same moves.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RIG_SRC = os.path.join(ROOT, "game", "models", "gen", "race_human.glb")
OUT = os.path.join(ROOT, "game", "models", "own", "player_body.glb")
NECK_FRACTION = 0.88  # shortcut: the neck's height on the user's base (read off a render); a new base needs it measured


def chain(arm, first):
    out = [arm.data.edit_bones[first]]
    out += list(out[0].children_recursive)
    return out


def turn_chain(arm, first, tip_bone, target):
    """Turns (and stretches) a limb about its first joint so tip_bone's tail lands on target (world)."""
    to_world = arm.matrix_world
    bones = chain(arm, first)
    pivot = to_world @ bones[0].head
    tip = to_world @ arm.data.edit_bones[tip_bone].tail
    rot = (tip - pivot).rotation_difference(target - pivot).to_matrix().to_4x4()
    k = (target - pivot).length / (tip - pivot).length
    m = Matrix.Translation(pivot) @ rot @ Matrix.Scale(k, 4) @ Matrix.Translation(-pivot)
    local = to_world.inverted() @ m @ to_world
    for b in bones:
        b.transform(local, scale=False, roll=True)  # scale=False: stretch the joints' places, not bone widths


def main():
    src = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)

    bpy.ops.import_scene.gltf(filepath=RIG_SRC)
    arm = bpy.data.objects["Rig_Medium"]
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o)

    bpy.ops.import_scene.gltf(filepath=src)
    body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    for o in [o for o in bpy.context.scene.objects if o.type == "EMPTY"]:
        bpy.data.objects.remove(o)
    body.name = "player_body"
    me = body.data
    me.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)

    # Face -Y (the base faces -X), feet on the floor, centered, neck at the rig's neck.
    me.transform(Matrix.Rotation(1.5708, 4, "Z"))
    vs = [v.co for v in me.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    rig_neck = (arm.matrix_world @ arm.data.bones["head"].head_local).z
    k = rig_neck / ((hi.z - lo.z) * NECK_FRACTION)
    me.transform(Matrix.Scale(k, 4) @ Matrix.Translation(Vector(((-(lo.x + hi.x) / 2), -(lo.y + hi.y) / 2, -lo.z))))

    # Cut off the head.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)  # glTF splits every hard edge; heat weights need it whole
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > rig_neck], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()

    # Turn the rig's T-pose limbs into the base's A-pose.
    vs = [v.co.copy() for v in me.vertices]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for side, s in ((".l", 1), (".r", -1)):
        hand = max(vs, key=lambda v: v.x * s)  # the fingertips: farthest out
        turn_chain(arm, "upperarm" + side, "hand" + side, hand)
        feet = [v for v in vs if v.x * s > 0 and v.z < 0.15]
        ankle = sum(feet, Vector()) / len(feet)
        ankle.z = (arm.matrix_world @ arm.data.edit_bones["lowerleg" + side].tail).z
        ankle.y = (arm.matrix_world @ arm.data.edit_bones["lowerleg" + side].tail).y
        turn_chain(arm, "upperleg" + side, "lowerleg" + side, ankle)
    for name in ("root", "handslot.l", "handslot.r"):
        arm.data.edit_bones[name].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")

    # Skin it: heat weights, then any vertex the heat missed goes to its nearest bone.
    mat = bpy.data.materials.new("player_skin")
    mat.diffuse_color = (0.55, 0.42, 0.33, 1.0)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.42, 0.33, 1.0)
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    deform = [b for b in arm.data.bones if b.use_deform]
    missed = 0
    for v in me.vertices:
        if any(g.weight > 0.01 for g in v.groups):
            continue
        missed += 1
        p = v.co

        def dist(b):
            h, t = arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local
            ab = t - h
            f = max(0.0, min(1.0, (p - h).dot(ab) / ab.length_squared))
            return (h + ab * f - p).length

        b = min(deform, key=dist)
        g = body.vertex_groups.get(b.name) or body.vertex_groups.new(name=b.name)
        g.add([v.index], 1.0, "REPLACE")
    print("player_body: %d verts, %d had no heat weight" % (len(me.vertices), missed))

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
    print("player_body: saved", OUT)


main()
