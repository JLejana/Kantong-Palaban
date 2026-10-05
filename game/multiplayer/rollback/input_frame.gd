class_name RollbackInputFrame
extends RefCounted

var frame: int
var player_id: String
var input: Dictionary
var predicted: bool = false

func _init(value_frame: int = 0, value_player_id: String = "", value_input: Dictionary = {}, value_predicted: bool = false) -> void:
	frame = value_frame
	player_id = value_player_id
	input = value_input.duplicate(true)
	predicted = value_predicted

