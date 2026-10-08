extends Control

@onready var first_card: Button = $Layout/Cards/FighterA
@onready var second_card: Button = $Layout/Cards/FighterB
@onready var summary: Label = $Layout/Summary
@onready var opponent_label: Label = $Layout/Opponent/Label
@onready var opponent_choice: OptionButton = $Layout/Opponent/Choice

const FIGHTER_IDS: Array[StringName] = [&"fighter_a", &"fighter_b"]

func _ready() -> void:
	first_card.pressed.connect(func() -> void: _select(&"fighter_a"))
	second_card.pressed.connect(func() -> void: _select(&"fighter_b"))
	$Layout/Continue.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.STAGE_SELECT))
	$Layout/Back.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	opponent_label.text = "%s CHARACTER" % _opponent_name().to_upper()
	for fighter_id in FIGHTER_IDS:
		opponent_choice.add_item(_name_for(fighter_id))
	opponent_choice.select(maxi(0, FIGHTER_IDS.find(GameManager.selected_player_two)))
	opponent_choice.item_selected.connect(_select_opponent)
	_select(GameManager.selected_player_one)

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

