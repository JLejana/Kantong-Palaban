class_name Hurtbox
extends Area2D

@export var owner_fighter: Fighter

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	if owner_fighter == null:
		owner_fighter = get_parent() as Fighter

