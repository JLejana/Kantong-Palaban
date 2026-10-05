class_name HitboxDebug
extends Node

func set_enabled(value: bool) -> void:
	get_tree().debug_collisions_hint = value

