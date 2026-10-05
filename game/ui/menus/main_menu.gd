extends Control

@onready var subtitle: Label = $Layout/Subtitle

func _ready() -> void:
	$Layout/VsCpu.pressed.connect(_start_cpu)
	$Layout/CharacterTest.pressed.connect(_start_training)
	$Layout/LocalVersus.pressed.connect(_start_local)
	$Layout/Online.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.MATCHMAKING))
	$Layout/Career.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.CAREER))
	$Layout/Settings.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.SETTINGS))
	$Layout/Quit.pressed.connect(get_tree().quit)
	$Layout/Quit.visible = not OS.has_feature("web") and not OS.has_feature("mobile")
	subtitle.text = "Original Filipino-inspired arcade fighting game"

func _start_cpu() -> void:
	GameManager.set_mode(GameManager.GameMode.CPU)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)

func _start_training() -> void:
	GameManager.set_mode(GameManager.GameMode.TRAINING)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)

func _start_local() -> void:
	GameManager.set_mode(GameManager.GameMode.LOCAL)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)

