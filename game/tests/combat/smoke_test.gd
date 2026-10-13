extends Node

var failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	GameManager.selected_stage = &"halls_of_justice"
	var packed := load("res://match/fight_scene.tscn") as PackedScene
	_assert(packed != null, "fight scene loads")
	if packed == null:
		get_tree().quit(1)
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().physics_frame

	var first := scene.get_node("FighterA") as Fighter
	var second := scene.get_node("FighterB") as Fighter
	var rounds := scene.get_node("RoundManager") as RoundManager
	var loaded_stage := scene.get_node("StageRoot").get_child(0)
	var player_one_health := scene.get_node("HUD/PlayerOneHealth") as ProgressBar
	var player_two_health := scene.get_node("HUD/PlayerTwoHealth") as ProgressBar
	var player_one_controls := scene.get_node("HUD/PlayerOneControls") as Label
	var player_two_controls := scene.get_node("HUD/PlayerTwoControls") as Label
	var round_popup := scene.get_node("HUD/RoundPopup") as Control
	var round_popup_label := scene.get_node("HUD/RoundPopup/Banner/RoundLabel") as Label
	_assert(loaded_stage.name == &"HallsOfJustice", "selected stage is loaded into the fight")
	_assert(first.scale.is_equal_approx(Vector2(1.5, 1.5)) and second.scale.is_equal_approx(Vector2(1.5, 1.5)), "fighters use the enlarged gameplay scale")
	var player_one_fill := player_one_health.get_theme_stylebox("fill") as StyleBoxFlat
	var player_two_fill := player_two_health.get_theme_stylebox("fill") as StyleBoxFlat
	_assert(player_one_fill != null and player_one_fill.bg_color.is_equal_approx(Color("28c76f")), "health bars start green")
	_assert("MOVE" in player_one_controls.text and "SPECIAL" in player_one_controls.text, "player one controls are shown on the fight HUD")
	_assert("MOVE" in player_two_controls.text and "SPECIAL" in player_two_controls.text, "player two controls are shown on the fight HUD")
	_assert(rounds.phase == &"round_intro" and rounds.round_number == 1, "the match starts with a locked round-one intro")
	_assert(round_popup.visible and round_popup_label.text == "ROUND 1", "the arcade popup announces round one")
	second.ai_controlled = false
	first.global_position = Vector2(500.0, 548.0)
	second.global_position = Vector2(585.0, 548.0)
	second.health = 5
	rounds.phase = &"fight"
	first.input_enabled = true
	second.input_enabled = false

	Input.action_press("p1_rp")
	await get_tree().physics_frame
	Input.action_release("p1_rp")
	for _frame in range(30):
		await get_tree().physics_frame

	_assert(second.health == 0, "active attack frames damage the opponent")
	_assert(second.is_ko(), "lethal damage enters KO state")
	_assert(rounds.player_one_rounds == 1, "KO awards the round")
	_assert(player_two_fill != null and player_two_fill.bg_color.is_equal_approx(Color("e63946")), "an empty health bar smoothly reaches red")
	rounds.phase_time = 0.0
	await get_tree().physics_frame
	_assert(rounds.phase == &"round_intro" and rounds.round_number == 2, "the next fight starts with a locked round-two intro")
	_assert(round_popup.visible and round_popup_label.text == "ROUND 2", "the arcade popup advances to round two")
	Input.action_release("p1_rp")

	if failures.is_empty():
		print("COMBAT_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, description: String) -> void:
	if not condition:
		failures.append("COMBAT_SMOKE_TEST failed: " + description)


