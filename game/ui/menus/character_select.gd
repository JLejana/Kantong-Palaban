extends Control

const DISPLAY_FONT_PATH := "res://ui/fonts/Bangers-Regular.ttf"
const FIGHTER_IDS: Array[StringName] = [&"fighter_a", &"fighter_b"]

@onready var title: Label = $Layout/Title
@onready var first_card: Button = $Layout/Cards/FighterA
@onready var second_card: Button = $Layout/Cards/FighterB
@onready var summary: Label = $Layout/Summary
@onready var opponent_label: Label = $Layout/Opponent/Label
@onready var opponent_choice: OptionButton = $Layout/Opponent/Choice
@onready var continue_button: Button = $Layout/Continue
@onready var back_button: Button = $Layout/Back

var display_font: Font

func _ready() -> void:
	_configure_arcade_typography()
	first_card.pressed.connect(func() -> void: _select(&"fighter_a"))
	second_card.pressed.connect(func() -> void: _select(&"fighter_b"))
	continue_button.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.STAGE_SELECT))
	back_button.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	opponent_label.text = "%s CHARACTER" % _opponent_name().to_upper()
	for fighter_id in FIGHTER_IDS:
		opponent_choice.add_item(_name_for(fighter_id))
	opponent_choice.select(maxi(0, FIGHTER_IDS.find(GameManager.selected_player_two)))
	opponent_choice.item_selected.connect(_select_opponent)
	_select(GameManager.selected_player_one)

func _configure_arcade_typography() -> void:
	var title_font := _make_display_font(3)
	var card_font := _make_display_font(1)
	var control_font := _make_display_font(2)

	title.add_theme_font_override(&"font", title_font)
	title.add_theme_font_size_override(&"font_size", 46)
	title.add_theme_color_override(&"font_color", Color("ffd447"))
	title.add_theme_color_override(&"font_outline_color", Color("68141b"))
	title.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override(&"outline_size", 5)
	title.add_theme_constant_override(&"shadow_offset_x", 4)
	title.add_theme_constant_override(&"shadow_offset_y", 6)
	title.add_theme_constant_override(&"shadow_outline_size", 2)

	_apply_arcade_font(first_card, card_font, 22)
	first_card.add_theme_color_override(&"font_disabled_color", Color("78cfff"))
	first_card.add_theme_color_override(&"font_outline_color", Color("092943"))
	_apply_arcade_font(second_card, card_font, 22)
	second_card.add_theme_color_override(&"font_disabled_color", Color("ff8375"))
	second_card.add_theme_color_override(&"font_outline_color", Color("4d1014"))

	opponent_label.add_theme_font_override(&"font", control_font)
	opponent_label.add_theme_font_size_override(&"font_size", 22)
	opponent_label.add_theme_color_override(&"font_color", Color("ffd96a"))
	opponent_label.add_theme_color_override(&"font_outline_color", Color("3b1014"))
	opponent_label.add_theme_constant_override(&"outline_size", 2)

	_apply_arcade_font(opponent_choice, control_font, 21)
	_apply_arcade_font(continue_button, control_font, 22)
	_apply_arcade_font(back_button, control_font, 20)

	summary.add_theme_font_override(&"font", control_font)
	summary.add_theme_font_size_override(&"font_size", 22)
	summary.add_theme_color_override(&"font_color", Color("fff0c2"))
	summary.add_theme_color_override(&"font_outline_color", Color("361015"))
	summary.add_theme_constant_override(&"outline_size", 2)

func _apply_arcade_font(control: Control, font: Font, font_size: int) -> void:
	control.add_theme_font_override(&"font", font)
	control.add_theme_font_size_override(&"font_size", font_size)
	control.add_theme_color_override(&"font_outline_color", Color("3c0b10"))
	control.add_theme_constant_override(&"outline_size", 2)

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

func _select(fighter_id: StringName) -> void:
	GameManager.selected_player_one = fighter_id
	first_card.disabled = fighter_id == &"fighter_a"
	second_card.disabled = fighter_id == &"fighter_b"
	_update_summary()

func _select_opponent(index: int) -> void:
	GameManager.selected_player_two = FIGHTER_IDS[index]
	_update_summary()

func _update_summary() -> void:
	summary.text = "Player 1: %s     %s: %s" % [_name_for(GameManager.selected_player_one), _opponent_name(), _name_for(GameManager.selected_player_two)]

func _opponent_name() -> String:
	return "Training Dummy" if GameManager.game_mode == GameManager.GameMode.TRAINING else ("CPU" if GameManager.game_mode == GameManager.GameMode.CPU else "Player 2")

func _name_for(fighter_id: StringName) -> String:
	return "FighterA" if fighter_id == &"fighter_a" else "FighterB"

