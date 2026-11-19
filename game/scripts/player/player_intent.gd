class_name PlayerIntent
extends RefCounted
## What the player wants to do this frame. Produced by PlayerInput (keyboard and
## mouse), by tests, or later by the network. The Player only ever reads intents,
## never the keyboard (network-ready rule 1).

var move := Vector2.ZERO      ## x = right, y = forward, relative to aim_yaw
var aim_yaw := 0.0            ## camera facing, radians
var light := false            ## just pressed
var light_held := false       ## held (the crosshair shows while you hold an attack)
var heavy := false
var heavy_held := false          ## held: charging a heavy attack
var spyglass_held := false       ## held: looking through the spyglass
var sidearm := false             ## just pressed: switch to your sidearm (bow or spells) or back
var jump_held := false           ## held: flying up (god mode)
var dodge_held := false          ## held: flying down (god mode)
var dodge := false
var jump := false             ## just pressed
var sprint := false           ## held
var slide := false            ## just pressed
var slide_held := false       ## held (stationary slide = crouch while held)
var signature := false
var movement := false
var ultimate := false          ## just pressed
var ultimate_held := false     ## held: aiming the ultimate
var ultimate_released := false ## just released: cast it at aim_point
## What the crosshair is on: the first thing at the middle of the screen (INF = unknown: scripted input).
var crosshair := Vector3.INF
## How far the camera looks up (+) or down (-), radians.
var aim_pitch := 0.0
## Where the camera's center points on the ground (INF = unknown: scripted input).
var aim_point := Vector3.INF
var mount := false            ## just pressed: get on or off the mount
var switch_weapon := false    ## just pressed (the mouse wheel): swap between your melee weapon and your bow or staff
var wheel_back := false       ## the wheel turned back (down) this frame: reels in a hooked minion
var mount_held := false       ## held: on foot, a long press tells your mount to stay
var race_active := false      ## just pressed: your race's active skill
var throw_knife := false      ## just pressed: the homing throwing knife
var race_active_held := false ## held: the Minotaur's charge lasts as long as this
