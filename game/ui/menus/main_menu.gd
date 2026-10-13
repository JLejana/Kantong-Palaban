extends Control

const DISPLAY_FONT_PATH := "res://ui/fonts/Bangers-Regular.ttf"

@onready var title: Label = $Layout/Title
@onready var subtitle: Label = $Layout/Subtitle

var display_font: Font

const MENU_BUTTON_PATHS: Array[NodePath] = [
	^"VsCpu",
	^"CharacterTest",
	^"LocalVersus",
	^"Online",
	^"Career",
	^"Settings",
	^"Quit",
]

func _ready() -> void:
	_configure_title()
	_configure_menu_buttons()
	$Layout/VsCpu.pressed.connect(_start_cpu)
	$Layout/CharacterTest.pressed.connect(_start_training)
	$Layout/LocalVersus.pressed.connect(_start_local)
	$Layout/Online.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.MATCHMAKING))
	$Layout/Career.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.CAREER))
	$Layout/Settings.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.SETTINGS))
	$Layout/Quit.pressed.connect(get_tree().quit)
	$Layout/Quit.visible = not OS.has_feature("web") and not OS.has_feature("mobile")
	subtitle.text = "Original Filipino-inspired arcade fighting game"

func _configure_title() -> void:
	var title_font := _make_display_font(3)
	title.add_theme_font_override(&"font", title_font)
	title.add_theme_font_size_override(&"font_size", 56)
	title.add_theme_color_override(&"font_color", Color("ffd23f"))
	title.add_theme_color_override(&"font_outline_color", Color("5a0b12"))
	title.add_theme_color_override(&"font_shadow_color", Color(0.02, 0.02, 0.05, 0.9))
	title.add_theme_constant_override(&"outline_size", 6)
	title.add_theme_constant_override(&"shadow_offset_x", 5)
	title.add_theme_constant_override(&"shadow_offset_y", 7)
	title.add_theme_constant_override(&"shadow_outline_size", 2)

func _configure_menu_buttons() -> void:
	var button_font := _make_display_font(2)
	var normal_style := _make_embossed_style(
		Color("9f2825"), Color("ef7254"), Color("3b080d"), Vector2(0.0, 5.0), 4
	)
	var hover_style := _make_embossed_style(
		Color("bd3930"), Color("ffad63"), Color("3b080d"), Vector2(0.0, 6.0), 5
	)
	var pressed_style := _make_embossed_style(
		Color("761c20"), Color("d94b3d"), Color("24050a"), Vector2(0.0, 1.0), 1
	)
	pressed_style.content_margin_top = 5.0
	pressed_style.content_margin_bottom = 1.0

	var disabled_style := _make_embossed_style(
		Color("4f3237"), Color("77545a"), Color("24171a"), Vector2(0.0, 3.0), 2
	)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_style.border_color = Color("ffd45b")
	_set_style_border(focus_style, 3, 10)
	focus_style.expand_margin_left = 3.0
	focus_style.expand_margin_top = 3.0
	focus_style.expand_margin_right = 3.0
	focus_style.expand_margin_bottom = 7.0

	for button_path: NodePath in MENU_BUTTON_PATHS:
		var button := $Layout.get_node(button_path) as Button
		button.add_theme_stylebox_override(&"normal", normal_style)
		button.add_theme_stylebox_override(&"hover", hover_style)
		button.add_theme_stylebox_override(&"pressed", pressed_style)
		button.add_theme_stylebox_override(&"hover_pressed", pressed_style)
		button.add_theme_stylebox_override(&"disabled", disabled_style)
		button.add_theme_stylebox_override(&"focus", focus_style)
		button.add_theme_font_override(&"font", button_font)
		button.add_theme_font_size_override(&"font_size", 22)
		button.add_theme_color_override(&"font_color", Color("fff4d6"))
		button.add_theme_color_override(&"font_hover_color", Color.WHITE)
		button.add_theme_color_override(&"font_pressed_color", Color("ffe0a0"))
		button.add_theme_color_override(&"font_focus_color", Color.WHITE)
		button.add_theme_color_override(&"font_outline_color", Color("4c090d"))
		button.add_theme_constant_override(&"outline_size", 2)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_display_font(letter_spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = _get_display_font()
	font.spacing_glyph = letter_spacing
	return font

func _get_display_font() -> Font:
	if display_font != null:
		return display_font

	var bundled_font := FontFile.new()
	if bundled_font.load_dynamic_font(DISPLAY_FONT_PATH) == OK:
		display_font = bundled_font
		return display_font

	var fallback_font := SystemFont.new()
	fallback_font.font_names = PackedStringArray(["Impact", "Arial Black", "DejaVu Sans"])
	fallback_font.font_weight = 900
	fallback_font.font_stretch = 110
	display_font = fallback_font
	return display_font

func _make_embossed_style(
	background_color: Color,
	edge_color: Color,
	shadow_color: Color,
	shadow_offset: Vector2,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = edge_color
	style.shadow_color = shadow_color
	style.shadow_offset = shadow_offset
	style.shadow_size = shadow_size
	style.content_margin_left = 18.0
	style.content_margin_top = 1.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 5.0
	_set_style_border(style, 2, 9)
	return style

func _set_style_border(style: StyleBoxFlat, width: int, radius: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius

func _start_cpu() -> void:
	GameManager.set_mode(GameManager.GameMode.CPU)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)

func _start_training() -> void:
	GameManager.set_mode(GameManager.GameMode.TRAINING)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)

func _start_local() -> void:
	GameManager.set_mode(GameManager.GameMode.LOCAL)
	SceneManager.change_scene(SceneManager.CHARACTER_SELECT)
