extends Control

@onready var first_card: Button = $Layout/Cards/FighterA
@onready var second_card: Button = $Layout/Cards/FighterB
@onready var summary: Label = $Layout/Summary

func _ready() -> void:
	first_card.pressed.connect(func() -> void: _select(&"fighter_a"))
	second_card.pressed.connect(func() -> void: _select(&"fighter_b"))
	$Layout/Continue.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.STAGE_SELECT))
	$Layout/Back.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	_select(GameManager.selected_player_one)

func _select(fighter_id: StringName) -> void:
	GameManager.selected_player_one = fighter_id
	GameManager.selected_player_two = &"fighter_b" if fighter_id == &"fighter_a" else &"fighter_a"
	first_card.disabled = fighter_id == &"fighter_a"
	second_card.disabled = fighter_id == &"fighter_b"
	var opponent_label := "Training Dummy" if GameManager.game_mode == GameManager.GameMode.TRAINING else ("CPU" if GameManager.game_mode == GameManager.GameMode.CPU else "Player 2")
	summary.text = "Player 1: %s     %s: %s" % [_name_for(GameManager.selected_player_one), opponent_label, _name_for(GameManager.selected_player_two)]

func _name_for(fighter_id: StringName) -> String:
	return "FighterA" if fighter_id == &"fighter_a" else "FighterB"

