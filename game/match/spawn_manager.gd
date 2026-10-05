class_name SpawnManager
extends RefCounted

static func place_fighters(first: Fighter, second: Fighter, first_spawn: Vector2, second_spawn: Vector2) -> void:
	first.reset_for_round(first_spawn)
	second.reset_for_round(second_spawn)

