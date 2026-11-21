extends Node3D
## Holds Kaminari's caught enemies where spells.gd flings them: each one asks hold_point_for every
## frame (Enemy._follow_hand), and lets go by itself once its spot is gone.

var spots := {}  ## enemy -> where it is now


func hold_point_for(item: Node3D) -> Vector3:
	var p: Vector3 = spots.get(item, Vector3.INF)
	return p
