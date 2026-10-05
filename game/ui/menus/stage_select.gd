extends Control

func _ready() -> void:
	$Layout/BarangayCourt.pressed.connect(_select_stage)
	$Layout/Back.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.CHARACTER_SELECT))

func _select_stage() -> void:
	GameManager.selected_stage = &"barangay_court"
	SceneManager.start_fight()

