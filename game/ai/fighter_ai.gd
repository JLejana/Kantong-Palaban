class_name FighterAI
extends Node

@export_enum("easy", "normal", "hard") var difficulty: String = "normal"

var decision_frames: int = 0
var current_input: Dictionary = {}
var rng := RandomNumberGenerator.new()
var behavior_machine := AIStateMachine.new()
var approach_behavior := AIApproachBehavior.new()
var retreat_behavior := AIRetreatBehavior.new()
var attack_behavior := AIAttackBehavior.new()
var defend_behavior := AIDefendBehavior.new()

func _ready() -> void:
	rng.randomize()
	current_input = FighterInputMapper.empty_input()

func get_input(self_fighter: Fighter, opponent: Fighter, _frame: int) -> Dictionary:
	if opponent == null or not self_fighter.input_enabled:
		return FighterInputMapper.empty_input()
	decision_frames -= 1
	behavior_machine.tick()
	if decision_frames <= 0:
		_choose_behavior(self_fighter, opponent)
	return current_input

func _choose_behavior(self_fighter: Fighter, opponent: Fighter) -> void:
	current_input = FighterInputMapper.empty_input()
	var distance := absf(opponent.global_position.x - self_fighter.global_position.x)
	var toward := "right" if opponent.global_position.x > self_fighter.global_position.x else "left"
	var away := "left" if toward == "right" else "right"
	var reaction: int = int({"easy": 36, "normal": 22, "hard": 12}.get(difficulty, 22))
	decision_frames = reaction + rng.randi_range(0, 12)
	var roll := rng.randf()
	var opponent_attacking := opponent.current_attack != null
	if approach_behavior.score(distance) > 0.55:
		behavior_machine.set_behavior(&"approach", decision_frames)
		current_input[toward] = true
		if roll < 0.08:
			current_input["jump"] = true
	elif retreat_behavior.score(distance) > 0.5 and roll < 0.20:
		behavior_machine.set_behavior(&"retreat", decision_frames)
		current_input[away] = true
	elif roll < _block_chance() * defend_behavior.score(opponent_attacking):
		behavior_machine.set_behavior(&"defend", decision_frames)
		current_input["block"] = true
	elif attack_behavior.score(distance) > 0.5 and roll < 0.92:
		behavior_machine.set_behavior(&"attack", decision_frames)
		var choices: PackedStringArray = ["lp", "rp", "lk", "rk"]
		current_input[choices[rng.randi_range(0, choices.size() - 1)]] = true
	else:
		behavior_machine.set_behavior(&"crouch", decision_frames)
		current_input["crouch"] = true

func _block_chance() -> float:
	return float({"easy": 0.12, "normal": 0.28, "hard": 0.46}.get(difficulty, 0.28))
