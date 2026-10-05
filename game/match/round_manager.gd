class_name RoundManager
extends Node

signal status_changed(text: String)
signal timer_changed(seconds: int)
signal score_changed(player_one_rounds: int, player_two_rounds: int)
signal match_finished(winner: Fighter)

@export var round_seconds: int = 99
@export var rounds_to_win: int = 2
@export var countdown_seconds: float = 3.0
@export var training_mode: bool = false

var player_one: Fighter
var player_two: Fighter
var player_one_spawn := Vector2(340.0, 548.0)
var player_two_spawn := Vector2(812.0, 548.0)
var player_one_rounds: int = 0
var player_two_rounds: int = 0
var time_remaining: float = 99.0
var phase: StringName = &"idle"
var phase_time: float = 0.0
var round_winner: Fighter
var training_reset_fighter: Fighter

func configure(first: Fighter, second: Fighter) -> void:
	player_one = first
	player_two = second
	player_one.knocked_out.connect(_on_fighter_knocked_out)
	player_two.knocked_out.connect(_on_fighter_knocked_out)
	start_match()

func _physics_process(delta: float) -> void:
	match phase:
		&"countdown":
			phase_time -= delta
			status_changed.emit(str(maxi(1, int(ceil(phase_time)))))
			if phase_time <= 0.0:
				phase = &"fight"
				player_one.input_enabled = true
				player_two.input_enabled = true
				status_changed.emit("FIGHT!")
		&"fight":
			if training_mode:
				return
			time_remaining = maxf(0.0, time_remaining - delta)
			timer_changed.emit(int(ceil(time_remaining)))
			if time_remaining <= 0.0:
				_finish_round(_timeout_winner(), "TIME")
		&"round_over":
			phase_time -= delta
			if phase_time <= 0.0:
				if player_one_rounds >= rounds_to_win or player_two_rounds >= rounds_to_win:
					phase = &"match_over"
					var winner := player_one if player_one_rounds > player_two_rounds else player_two
					status_changed.emit("%s WINS - R TO RESTART" % winner.stats.display_name)
					match_finished.emit(winner)
				else:
					_start_round()
		&"training_reset":
			phase_time -= delta
			if phase_time <= 0.0:
				_reset_training_fighter()

func start_match() -> void:
	player_one_rounds = 0
	player_two_rounds = 0
	score_changed.emit(0, 0)
	_start_round()

func _start_round() -> void:
	phase = &"fight" if training_mode else &"countdown"
	phase_time = countdown_seconds
	time_remaining = float(round_seconds)
	round_winner = null
	player_one.reset_for_round(player_one_spawn)
	player_two.reset_for_round(player_two_spawn)
	player_one.input_enabled = training_mode
	player_two.input_enabled = false
	timer_changed.emit(round_seconds)
	status_changed.emit("TRAINING" if training_mode else "3")

func _on_fighter_knocked_out(defeated: Fighter) -> void:
	if phase != &"fight":
		return
	if training_mode:
		phase = &"training_reset"
		phase_time = 1.0
		training_reset_fighter = defeated
		player_one.input_enabled = true
		player_two.input_enabled = false
		status_changed.emit("DUMMY RESET")
		return
	var winner := player_two if defeated == player_one else player_one
	_finish_round(winner, "KO!")

func _reset_training_fighter() -> void:
	if training_reset_fighter != null:
		var spawn_position := player_one_spawn if training_reset_fighter == player_one else player_two_spawn
		training_reset_fighter.reset_for_round(spawn_position)
	training_reset_fighter = null
	phase = &"fight"
	player_one.input_enabled = true
	player_two.input_enabled = false
	status_changed.emit("TRAINING")

func _timeout_winner() -> Fighter:
	if player_one.health == player_two.health:
		return null
	return player_one if player_one.health > player_two.health else player_two

func _finish_round(winner: Fighter, reason: String) -> void:
	if phase != &"fight":
		return
	phase = &"round_over"
	phase_time = 2.25
	round_winner = winner
	player_one.input_enabled = false
	player_two.input_enabled = false
	if winner == player_one:
		player_one_rounds += 1
	elif winner == player_two:
		player_two_rounds += 1
	score_changed.emit(player_one_rounds, player_two_rounds)
	status_changed.emit(reason if winner == null else "%s  %s" % [reason, winner.stats.display_name])

