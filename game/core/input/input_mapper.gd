class_name FighterInputMapper
extends RefCounted

const COMMANDS: PackedStringArray = ["left", "right", "jump", "crouch", "lp", "rp", "lk", "rk", "block"]

static func read_player(player_index: int) -> Dictionary:
	var prefix := "p%d_" % player_index
	var result := {}
	for command in COMMANDS:
		result[command] = Input.is_action_pressed(prefix + command)
	return result

static func empty_input() -> Dictionary:
	var result := {}
	for command in COMMANDS:
		result[command] = false
	return result

