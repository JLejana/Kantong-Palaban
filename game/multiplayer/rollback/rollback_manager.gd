class_name RollbackManager
extends Node

signal rollback_requested(from_frame: int)

@export var input_delay_frames: int = 3
@export var max_rollback_frames: int = 12
@export var history_limit: int = 180

var local_input_history: Dictionary = {}
var remote_input_history: Dictionary = {}
var snapshots: Dictionary = {}
var predicted_remote_history: Dictionary = {}
var last_remote_input: Dictionary = {}

func record_local_input(input_frame: RollbackInputFrame) -> void:
	local_input_history[input_frame.frame] = input_frame
	_prune(input_frame.frame)

func record_remote_input(input_frame: RollbackInputFrame) -> void:
	remote_input_history[input_frame.frame] = input_frame
	if predicted_remote_history.has(input_frame.frame):
		var predicted: Dictionary = predicted_remote_history[input_frame.frame] as Dictionary
		if predicted != input_frame.input:
			rollback_requested.emit(input_frame.frame)
		predicted_remote_history.erase(input_frame.frame)
	last_remote_input = input_frame.input.duplicate(true)
	_prune(input_frame.frame)

func get_local_input(frame: int) -> Dictionary:
	var entry := local_input_history.get(frame) as RollbackInputFrame
	return entry.input.duplicate() if entry != null else FighterInputMapper.empty_input()

func get_remote_input(frame: int) -> Dictionary:
	var entry := remote_input_history.get(frame) as RollbackInputFrame
	if entry != null:
		last_remote_input = entry.input.duplicate(true)
		return entry.input.duplicate()
	var prediction := last_remote_input.duplicate()
	if prediction.is_empty():
		prediction = FighterInputMapper.empty_input()
	predicted_remote_history[frame] = prediction.duplicate(true)
	return prediction

func save_snapshot(frame: int, state: Dictionary) -> void:
	snapshots[frame] = state.duplicate(true)
	_prune(frame)

func snapshot_for(frame: int) -> Dictionary:
	return (snapshots.get(frame, {}) as Dictionary).duplicate(true)

func resimulate(from_frame: int, through_frame: int, restore_state: Callable, simulate_frame: Callable) -> bool:
	if through_frame - from_frame > max_rollback_frames or not snapshots.has(from_frame):
		return false
	restore_state.call(snapshot_for(from_frame))
	for frame in range(from_frame, through_frame + 1):
		simulate_frame.call(frame, get_local_input(frame), get_remote_input(frame))
	return true

func reset() -> void:
	local_input_history.clear()
	remote_input_history.clear()
	snapshots.clear()
	predicted_remote_history.clear()
	last_remote_input.clear()

func _prune(current_frame: int) -> void:
	var oldest := current_frame - history_limit
	for history in [local_input_history, remote_input_history, snapshots, predicted_remote_history]:
		for frame: int in history.keys():
			if frame < oldest:
				history.erase(frame)

