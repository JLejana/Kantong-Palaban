extends Node

var failures: Array[String] = []
var rollback_frame: int = -1
var restore_called: bool = false
var simulated_frames: Array[int] = []

func _ready() -> void:
	var manager := RollbackManager.new()
	add_child(manager)
	manager.rollback_requested.connect(func(frame: int) -> void: rollback_frame = frame)
	var local := FighterInputMapper.empty_input()
	local["lp"] = true
	manager.record_local_input(RollbackInputFrame.new(5, "local", local))
	_assert(bool(manager.get_local_input(5)["lp"]), "local input history")
	manager.get_remote_input(5)
	var remote := FighterInputMapper.empty_input()
	remote["right"] = true
	manager.record_remote_input(RollbackInputFrame.new(5, "remote", remote))
	_assert(rollback_frame == 5, "prediction mismatch requests rollback")
	manager.save_snapshot(5, {"health": 100})
	var completed := manager.resimulate(5, 7, _restore, _simulate)
	_assert(completed and restore_called and simulated_frames == [5, 6, 7], "bounded restore and resimulation")
	if failures.is_empty():
		print("ROLLBACK_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _restore(_state: Dictionary) -> void:
	restore_called = true

func _simulate(frame: int, _local: Dictionary, _remote: Dictionary) -> void:
	simulated_frames.append(frame)

func _assert(condition: bool, description: String) -> void:
	if not condition:
		failures.append("ROLLBACK_TEST failed: " + description)

