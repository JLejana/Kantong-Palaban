extends Control

@onready var volume_slider: HSlider = $Layout/Volume
@onready var difficulty: OptionButton = $Layout/Difficulty
@onready var touch_mode: OptionButton = $Layout/TouchMode
@onready var debug_box: CheckBox = $Layout/Debug
@onready var shake_slider: HSlider = $Layout/Shake
@onready var vibration_box: CheckBox = $Layout/Vibration

func _ready() -> void:
	difficulty.add_item("Easy")
	difficulty.add_item("Normal")
	difficulty.add_item("Hard")
	touch_mode.add_item("Auto")
	touch_mode.add_item("Always")
	touch_mode.add_item("Never")
	volume_slider.value = GameManager.master_volume * 100.0
	difficulty.select([&"easy", &"normal", &"hard"].find(GameManager.ai_difficulty))
	touch_mode.select([&"auto", &"always", &"never"].find(GameManager.touch_controls_mode))
	debug_box.button_pressed = GameManager.debug_enabled
	shake_slider.value = GameManager.screen_shake_intensity * 100.0
	vibration_box.button_pressed = GameManager.vibration_enabled
	volume_slider.value_changed.connect(func(value: float) -> void: GameManager.set_master_volume(value / 100.0))
	difficulty.item_selected.connect(_on_difficulty_selected)
	touch_mode.item_selected.connect(_on_touch_selected)
	debug_box.toggled.connect(_on_debug_toggled)
	shake_slider.value_changed.connect(_on_shake_changed)
	vibration_box.toggled.connect(_on_vibration_toggled)
	$Layout/Controls.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.CONTROLS))
	$Layout/Back.pressed.connect(func() -> void: SceneManager.go_to_main_menu())

func _on_difficulty_selected(index: int) -> void:
	GameManager.ai_difficulty = [&"easy", &"normal", &"hard"][index]
	GameManager.save_settings()

func _on_touch_selected(index: int) -> void:
	GameManager.touch_controls_mode = [&"auto", &"always", &"never"][index]
	GameManager.save_settings()

func _on_debug_toggled(enabled: bool) -> void:
	GameManager.debug_enabled = enabled
	GameManager.save_settings()
	GameManager.settings_changed.emit()

func _on_shake_changed(value: float) -> void:
	GameManager.screen_shake_intensity = value / 100.0
	GameManager.save_settings()

func _on_vibration_toggled(enabled: bool) -> void:
	GameManager.vibration_enabled = enabled
	GameManager.save_settings()

