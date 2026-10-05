class_name AIStateMachine
extends RefCounted

var current_behavior: StringName = &"wait"
var frames_remaining: int = 0

func set_behavior(next_behavior: StringName, duration_frames: int = 1) -> void:
	current_behavior = next_behavior
	frames_remaining = maxi(1, duration_frames)

func tick() -> bool:
	frames_remaining = maxi(0, frames_remaining - 1)
	return frames_remaining == 0

func is_behavior(value: StringName) -> bool:
	return current_behavior == value
