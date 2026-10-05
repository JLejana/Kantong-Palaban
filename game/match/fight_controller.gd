extends Node2D

@onready var player_one: Fighter = $FighterA
@onready var player_two: Fighter = $FighterB
@onready var round_manager: RoundManager = $RoundManager
@onready var rollback_manager: RollbackManager = $RollbackManager
@onready var player_one_health: ProgressBar = $HUD/PlayerOneHealth
@onready var player_two_health: ProgressBar = $HUD/PlayerTwoHealth
@onready var timer_label: Label = $HUD/TimerLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var mode_label: Label = $HUD/ModeLabel
@onready var debug_label: Label = $HUD/DebugLabel
@onready var ping_label: Label = $HUD/PingLabel
@onready var player_one_controls: Label = $HUD/PlayerOneControls
@onready var player_two_controls: Label = $HUD/PlayerTwoControls
@onready var training_panel: ColorRect = $HUD/TrainingPanel
@onready var training_skill_list: Label = $HUD/TrainingPanel/SkillList
@onready var mobile_controls: Control = $HUD/MobileControls
@onready var fight_camera: Camera2D = $FightCamera
@onready var impact_flash: ColorRect = $HUD/ImpactFlash

var local_fighter: Fighter
var remote_fighter: Fighter
var network_frame: int = 0
var match_started_at: int = 0
var shake_time: float = 0.0
var shake_strength: float = 0.0

func _ready() -> void:
	_configure_selected_fighters()
	player_one.opponent = player_two
	player_two.opponent = player_one
	_configure_mode()
	player_one.health_changed.connect(_on_player_one_health)
	player_two.health_changed.connect(_on_player_two_health)
	player_one.hit_confirmed.connect(_on_hit_confirmed)
	player_two.hit_confirmed.connect(_on_hit_confirmed)
	(player_one.get_node("ComboManager") as ComboManager).combo_changed.connect(func(hits: int, damage: int) -> void: _show_combo($HUD/PlayerOneCombo, hits, damage))
	(player_two.get_node("ComboManager") as ComboManager).combo_changed.connect(func(hits: int, damage: int) -> void: _show_combo($HUD/PlayerTwoCombo, hits, damage))
	round_manager.status_changed.connect(func(text: String) -> void: status_label.text = text)
	round_manager.timer_changed.connect(func(value: int) -> void: timer_label.text = str(value))
	round_manager.score_changed.connect(_on_score_changed)
	round_manager.match_finished.connect(_on_match_finished)
	GameManager.settings_changed.connect(_apply_debug_visibility)
	GameManager.settings_changed.connect(_refresh_control_guide)
	mobile_controls.visible = GameManager.should_show_touch_controls()
	$HUD/BackButton.pressed.connect(_leave_match)
	_apply_debug_visibility()
	_refresh_control_guide()
	_update_mode_label()
	match_started_at = Time.get_ticks_msec()
	round_manager.configure(player_one, player_two)
	_refresh_training_panel()

func _process(delta: float) -> void:
	_update_camera_shake(delta)
	if Input.is_action_just_pressed("restart_match") and GameManager.game_mode != GameManager.GameMode.ONLINE:
		round_manager.start_match()
		_refresh_training_panel()
	if Input.is_action_just_pressed("toggle_cpu") and GameManager.game_mode in [GameManager.GameMode.CPU, GameManager.GameMode.LOCAL]:
		GameManager.set_mode(GameManager.GameMode.LOCAL if GameManager.game_mode == GameManager.GameMode.CPU else GameManager.GameMode.CPU)
		_configure_mode()
		_update_mode_label()
		round_manager.start_match()
	if Input.is_action_just_pressed("toggle_debug"):
		GameManager.toggle_debug()
	if Input.is_action_just_pressed("ui_cancel"):
		_leave_match()
	if GameManager.debug_enabled:
		debug_label.text = "%s\n%s\nFPS %d" % [player_one.get_debug_text(), player_two.get_debug_text(), Engine.get_frames_per_second()]

func _physics_process(_delta: float) -> void:
	if GameManager.game_mode != GameManager.GameMode.ONLINE or local_fighter == null:
		return
	network_frame += 1
	var raw_input := FighterInputMapper.read_player(1)
	rollback_manager.record_local_input(RollbackInputFrame.new(network_frame, NetworkManager.player_id, raw_input))
	NetworkManager.send_input(network_frame, raw_input)
	var simulation_input_frame := network_frame - rollback_manager.input_delay_frames
	if simulation_input_frame >= 0:
		local_fighter.set_external_input(rollback_manager.get_local_input(simulation_input_frame))
		remote_fighter.set_external_input(rollback_manager.get_remote_input(simulation_input_frame))
	rollback_manager.save_snapshot(network_frame, {
		"player_one": player_one.capture_simulation_state(),
		"player_two": player_two.capture_simulation_state(),
		"round_phase": round_manager.phase,
		"round_time": round_manager.time_remaining
	})

func _on_player_one_health(current: int, maximum: int) -> void:
	player_one_health.max_value = maximum
	player_one_health.value = current

func _on_player_two_health(current: int, maximum: int) -> void:
	player_two_health.max_value = maximum
	player_two_health.value = current

func _on_score_changed(first: int, second: int) -> void:
	score_label.text = "%d  -  %d" % [first, second]

func _show_combo(label: Label, hits: int, damage: int) -> void:
	label.visible = hits >= 2
	label.text = "%d HITS\n%d DAMAGE" % [hits, damage]
	if label.visible:
		label.scale = Vector2(1.28, 1.28)
		create_tween().tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_mode_label() -> void:
	match GameManager.game_mode:
		GameManager.GameMode.CPU: mode_label.text = "P1 VS CPU"
		GameManager.GameMode.LOCAL: mode_label.text = "LOCAL PVP"
		GameManager.GameMode.ONLINE: mode_label.text = "ONLINE"
		GameManager.GameMode.TRAINING: mode_label.text = "CHARACTER TEST"

func _refresh_control_guide() -> void:
	player_one_controls.text = _format_player_controls(1)
	player_two_controls.text = _format_player_controls(2)

func _format_player_controls(player: int) -> String:
	var prefix := "p%d_" % player
	var left := GameManager.get_keyboard_binding_label(StringName(prefix + "left"))
	var right := GameManager.get_keyboard_binding_label(StringName(prefix + "right"))
	var jump := GameManager.get_keyboard_binding_label(StringName(prefix + "jump"))
	var crouch := GameManager.get_keyboard_binding_label(StringName(prefix + "crouch"))
	var lp := GameManager.get_keyboard_binding_label(StringName(prefix + "lp"))
	var rp := GameManager.get_keyboard_binding_label(StringName(prefix + "rp"))
	var lk := GameManager.get_keyboard_binding_label(StringName(prefix + "lk"))
	var rk := GameManager.get_keyboard_binding_label(StringName(prefix + "rk"))
	var block := GameManager.get_keyboard_binding_label(StringName(prefix + "block"))
	return "P%d  MOVE %s/%s  |  JUMP %s  |  CROUCH %s\nLP %s  |  RP %s  |  LK %s  |  RK %s  |  BLOCK %s\nSPECIAL FORWARD+%s  |  LOW GUARD %s+%s" % [
		player, left, right, jump, crouch, lp, rp, lk, rk, block, rp, crouch, block
	]

func _refresh_training_panel() -> void:
	var active := GameManager.game_mode == GameManager.GameMode.TRAINING
	training_panel.visible = active
	player_two_controls.visible = not active
	if not active:
		return
	$HUD/PlayerTwoName.text = "TRAINING DUMMY"
	timer_label.text = "∞"
	score_label.text = "PRACTICE"
	var lines: PackedStringArray = ["%s MOVE LIST" % player_one.stats.display_name.to_upper(), ""]
	for attack in player_one.stats.attacks:
		if attack == null:
			continue
		lines.append(attack.display_name.to_upper())
		lines.append("  %s  •  %d DAMAGE" % [_format_command(attack.input_command), attack.damage])
	lines.append("")
	lines.append("DUMMY RECOVERS AFTER KO")
	lines.append("R  •  RESET TRAINING")
	training_skill_list.text = "\n".join(lines)

func _format_command(command: PackedStringArray) -> String:
	var tokens := PackedStringArray()
	for part in command:
		tokens.append("FORWARD" if part == "forward" else part.to_upper())
	return " + ".join(tokens)

func _apply_debug_visibility() -> void:
	debug_label.visible = GameManager.debug_enabled
	get_tree().debug_collisions_hint = GameManager.debug_enabled

func _configure_selected_fighters() -> void:
	_apply_fighter_selection(player_one, GameManager.selected_player_one)
	_apply_fighter_selection(player_two, GameManager.selected_player_two)
	$HUD/PlayerOneName.text = player_one.stats.display_name
	$HUD/PlayerTwoName.text = player_two.stats.display_name

func _apply_fighter_selection(fighter: Fighter, selection: StringName) -> void:
	if selection == &"fighter_b":
		fighter.stats = load("res://fighters/fighter_b/fighter_b.tres") as FighterStats
	else:
		fighter.stats = load("res://fighters/fighter_a/fighter_a.tres") as FighterStats
	fighter.health = fighter.stats.max_health
	fighter.apply_visual_identity()

func _on_hit_confirmed(target: Fighter, attack: AttackData, blocked: bool, damage: int) -> void:
	var strength := clampf(float(damage) / 14.0, 0.35, 1.25)
	shake_strength = maxf(shake_strength, (3.0 if blocked else 7.0) * strength * GameManager.screen_shake_intensity)
	shake_time = maxf(shake_time, 0.07 if blocked else 0.13)
	_spawn_impact(target.global_position + Vector2(0.0, -58.0), blocked, strength)
	_flash_fighter(target, blocked)
	if GameManager.game_mode != GameManager.GameMode.ONLINE:
		var stop_frames := 2 if blocked else clampi(2 + attack.damage / 6, 3, 6)
		player_one.apply_hit_stop(stop_frames)
		player_two.apply_hit_stop(stop_frames)
	if GameManager.vibration_enabled:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.2 * strength, (0.35 if blocked else 0.65) * strength, 0.09)

func _update_camera_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		fight_camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = move_toward(shake_strength, 0.0, delta * 34.0)
	else:
		fight_camera.offset = fight_camera.offset.lerp(Vector2.ZERO, minf(1.0, delta * 24.0))

func _spawn_impact(position: Vector2, blocked: bool, strength: float) -> void:
	var burst := Polygon2D.new()
	burst.z_index = 40
	burst.global_position = position
	burst.color = Color(0.45, 0.82, 1.0, 0.9) if blocked else Color(1.0, 0.78, 0.18, 1.0)
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var radius := (30.0 if index % 2 == 0 else 9.0) * strength
		points.append(Vector2.from_angle(angle) * radius)
	burst.polygon = points
	add_child(burst)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(1.7, 1.7), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(burst.queue_free)
	impact_flash.color = Color(0.4, 0.75, 1.0, 0.08) if blocked else Color(1.0, 0.72, 0.2, 0.12)
	create_tween().tween_property(impact_flash, "color:a", 0.0, 0.12)

func _flash_fighter(target: Fighter, blocked: bool) -> void:
	var visual := target.get_active_visual()
	visual.modulate = Color(0.5, 0.85, 1.5, 1.0) if blocked else Color(2.2, 1.55, 0.75, 1.0)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.13)

func _configure_mode() -> void:
	round_manager.training_mode = GameManager.game_mode == GameManager.GameMode.TRAINING
	player_one.ai_controlled = false
	player_two.ai_controlled = GameManager.game_mode == GameManager.GameMode.CPU
	player_one.external_controlled = false
	player_two.external_controlled = false
	if player_two.ai_controlled:
		var ai := player_two.get_node_or_null("FighterAI") as FighterAI
		if ai != null:
			ai.difficulty = String(GameManager.ai_difficulty)
	if GameManager.game_mode != GameManager.GameMode.ONLINE:
		return
	local_fighter = player_one if GameManager.online_local_slot == 1 else player_two
	remote_fighter = player_two if local_fighter == player_one else player_one
	local_fighter.ai_controlled = false
	remote_fighter.ai_controlled = false
	local_fighter.external_controlled = true
	remote_fighter.external_controlled = true
	local_fighter.player_index = 1
	NetworkManager.online_input_received.connect(_on_online_input)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.peer_reconnected.connect(_on_peer_reconnected)
	NetworkManager.connection_changed.connect(_on_connection_changed)
	NetworkManager.ping_updated.connect(func(milliseconds: int) -> void: ping_label.text = "%d ms" % milliseconds)
	ping_label.visible = true

func _on_online_input(frame: int, player_id: String, input: Dictionary) -> void:
	if player_id == NetworkManager.player_id:
		return
	rollback_manager.record_remote_input(RollbackInputFrame.new(frame, player_id, input))

func _on_peer_disconnected(_player_id: String) -> void:
	round_manager.phase = &"paused"
	player_one.input_enabled = false
	player_two.input_enabled = false
	status_label.text = "OPPONENT DISCONNECTED"

func _on_peer_reconnected(_player_id: String) -> void:
	if round_manager.phase == &"paused":
		round_manager.phase = &"countdown"
		round_manager.phase_time = 3.0
		status_label.text = "OPPONENT RECONNECTED"

func _on_connection_changed(is_connected: bool) -> void:
	if not is_connected and GameManager.game_mode == GameManager.GameMode.ONLINE:
		round_manager.phase = &"paused"
		player_one.input_enabled = false
		player_two.input_enabled = false
		status_label.text = "RECONNECTING…"

func _on_match_finished(winner: Fighter) -> void:
	if GameManager.game_mode != GameManager.GameMode.ONLINE:
		return
	var players: Array = GameManager.online_match.get("players", []) as Array
	var winner_slot := 0 if winner == player_one else 1
	var winner_id := str(players[winner_slot]) if players.size() > winner_slot else ""
	var duration := int((Time.get_ticks_msec() - match_started_at) / 1000)
	NetworkManager.submit_match_result(winner_id, round_manager.player_one_rounds, round_manager.player_two_rounds, duration)

func _leave_match() -> void:
	if GameManager.game_mode == GameManager.GameMode.ONLINE:
		NetworkManager.send_message({"type": "match_leave", "matchId": NetworkManager.current_match_id})
	SceneManager.go_to_main_menu()

