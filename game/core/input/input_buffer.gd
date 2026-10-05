class_name FighterInputBuffer
extends RefCounted

var buffer_window_frames: int = 18
var history: Array[Dictionary] = []
var _previous: Dictionary = {}

func push(frame: int, input_state: Dictionary, facing_direction: float) -> void:
	for command: String in input_state:
		if bool(input_state[command]) and not bool(_previous.get(command, false)):
			var normalized := command
			if command == "right":
				normalized = "forward" if facing_direction > 0.0 else "back"
			elif command == "left":
				normalized = "back" if facing_direction > 0.0 else "forward"
			history.append({"frame": frame, "command": normalized})
	_previous = input_state.duplicate()
	while not history.is_empty() and frame - int(history[0]["frame"]) > buffer_window_frames:
		history.pop_front()

func just_pressed(command: String, frame: int, tolerance: int = 2) -> bool:
	for entry in history:
		if entry["command"] == command and frame - int(entry["frame"]) <= tolerance:
			return true
	return false

func matches(sequence: PackedStringArray) -> bool:
	if sequence.is_empty():
		return false
	var sequence_index := sequence.size() - 1
	for history_index in range(history.size() - 1, -1, -1):
		if history[history_index]["command"] == sequence[sequence_index]:
			sequence_index -= 1
			if sequence_index < 0:
				return true
	return false

func consume() -> void:
	history.clear()

