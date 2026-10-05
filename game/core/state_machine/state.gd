class_name FighterState
extends RefCounted

var name: StringName

func _init(state_name: StringName = &"idle") -> void:
	name = state_name

