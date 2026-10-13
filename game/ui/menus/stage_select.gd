extends Control

func _ready() -> void:
	$Layout/StageGrid/BarangayCourt.pressed.connect(_select_stage.bind(&"barangay_court"))
	$Layout/StageGrid/HallsOfJustice.pressed.connect(_select_stage.bind(&"halls_of_justice"))
	$Layout/StageGrid/LunetaSunset.pressed.connect(_select_stage.bind(&"luneta_sunset"))
	$Layout/StageGrid/MayonSummit.pressed.connect(_select_stage.bind(&"mayon_summit"))
	$Layout/Back.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.CHARACTER_SELECT))

func _select_stage(stage_id: StringName) -> void:
	GameManager.selected_stage = stage_id
	SceneManager.start_fight()

