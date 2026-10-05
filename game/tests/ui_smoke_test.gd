extends Node

const SCENES: PackedStringArray = [
	"res://ui/menus/main_menu.tscn",
	"res://ui/menus/character_select.tscn",
	"res://ui/menus/stage_select.tscn",
	"res://ui/menus/settings.tscn",
	"res://ui/menus/controls.tscn",
	"res://ui/online/matchmaking_screen.tscn",
	"res://ui/online/lobby_screen.tscn",
	"res://ui/online/career_screen.tscn"
]

var failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			failures.append("Could not load " + path)
			continue
		var instance := packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		if instance.get_child_count() == 0:
			failures.append("Scene has no content: " + path)
		instance.queue_free()
		await get_tree().process_frame
	if failures.is_empty():
		print("UI_SMOKE_TEST: PASS (%d scenes)" % SCENES.size())
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

