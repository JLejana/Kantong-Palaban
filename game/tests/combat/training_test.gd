extends Node

var failures: Array[String] = []

func _ready() -> void:
	await _run()

func _run() -> void:
	GameManager.set_mode(GameManager.GameMode.TRAINING)
	GameManager.selected_player_one = &"fighter_a"
	GameManager.selected_player_two = &"fighter_b"
	var packed := load("res://match/fight_scene.tscn") as PackedScene
	_assert(packed != null, "fight scene loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().physics_frame

	var first := scene.get_node("FighterA") as Fighter
	var dummy := scene.get_node("FighterB") as Fighter
	var rounds := scene.get_node("RoundManager") as RoundManager
	var panel := scene.get_node("HUD/TrainingPanel") as ColorRect
	var skill_list := scene.get_node("HUD/TrainingPanel/SkillList") as Label
	_assert(rounds.training_mode, "round manager enters training mode")
	_assert(rounds.phase == &"fight", "training starts without a countdown")
	_assert(first.input_enabled, "test character accepts input")
	_assert(not dummy.input_enabled and not dummy.ai_controlled, "training dummy is passive")
	_assert(panel.visible, "training move list is visible")
	_assert(not (scene.get_node("HUD/PlayerTwoControls") as Label).visible, "unused player-two controls are hidden")
	_assert((scene.get_node("HUD/PlayerTwoName") as Label).text == "TRAINING DUMMY", "dummy is identified on the HUD")
	_assert("SKYLINE STRIKE" in skill_list.text and "DAMAGE" in skill_list.text, "move list shows character attacks and damage")
	_assert((scene.get_node("HUD/TimerLabel") as Label).text == "∞", "training timer is infinite")
	_assert((scene.get_node("HUD/ScoreLabel") as Label).text == "PRACTICE", "training HUD replaces the round score")

	first.set_physics_process(false)
	first.transition(&"crouch")
	var crouch_start_frame := first.sprite_visual.frame
	for _frame in range(12):
		await get_tree().process_frame
	_assert(first.sprite_visual.frame > crouch_start_frame, "crouch entry animation advances while held")
	for _frame in range(40):
		await get_tree().process_frame
	_assert(first.sprite_visual.animation == &"crouch_hold", "crouch changes to its stable held-pose animation")
	_assert(first.sprite_visual.is_playing(), "held crouch remains subtly animated")
	first.transition(&"idle")
	first.set_physics_process(true)

	dummy.health = 1
	dummy.receive_hit(first.stats.find_attack(&"lp"), 1.0, false, 1)
	_assert(rounds.phase == &"training_reset", "KO schedules a dummy reset")
	for _frame in range(70):
		await get_tree().physics_frame
	_assert(rounds.phase == &"fight", "training resumes after the reset")
	_assert(dummy.health == dummy.stats.max_health, "dummy health is restored")
	_assert(not dummy.input_enabled, "dummy remains passive after reset")
	_assert(rounds.player_one_rounds == 0 and rounds.player_two_rounds == 0, "training does not award rounds")

	GameManager.set_mode(GameManager.GameMode.CPU)
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("TRAINING_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, description: String) -> void:
	if not condition:
		failures.append("TRAINING_TEST failed: " + description)
