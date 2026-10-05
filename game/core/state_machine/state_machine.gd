class_name FighterStateMachine
extends Node

signal state_changed(previous: StringName, current: StringName)

var current_state: StringName = &"idle"

func transition_to(next_state: StringName) -> void:
	if next_state == current_state:
		return
	var previous := current_state
	current_state = next_state
	state_changed.emit(previous, current_state)

func is_state(state_name: StringName) -> bool:
	return current_state == state_name

