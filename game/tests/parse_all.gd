extends Node

var failures: Array[String] = []
var script_count: int = 0
var resource_count: int = 0

func _ready() -> void:
	_scan("res://")
	if failures.is_empty():
		print("RESOURCE_PARSE_TEST: PASS (%d scripts, %d scenes/resources)" % [script_count, resource_count])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _scan(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		failures.append("Cannot open " + path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			if entry != ".godot":
				_scan(child_path)
		elif entry.ends_with(".gd"):
			script_count += 1
			if child_path == get_script().resource_path:
				entry = directory.get_next()
				continue
			var script := ResourceLoader.load(child_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
			if script == null:
				failures.append("Failed to parse " + child_path)
		elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
			resource_count += 1
			if ResourceLoader.load(child_path, "", ResourceLoader.CACHE_MODE_IGNORE) == null:
				failures.append("Failed to load " + child_path)
		entry = directory.get_next()
	directory.list_dir_end()


