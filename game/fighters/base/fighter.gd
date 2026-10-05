class_name Fighter
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal state_changed(state: StringName)
signal knocked_out(fighter: Fighter)
signal attack_started(attack: AttackData)
signal hit_confirmed(target: Fighter, attack: AttackData, blocked: bool, damage: int)

@export var stats: FighterStats
@export_range(1, 2) var player_index: int = 1
@export var ai_controlled: bool = false
@export var external_controlled: bool = false
@export var body_color: Color = Color("36a9e1")

@onready var state_machine: FighterStateMachine = $StateMachine
@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body_visual: Polygon2D = $BodyVisual
@onready var sprite_visual: AnimatedSprite2D = $SpriteVisual

var opponent: Fighter
var input_enabled: bool = false
var facing_direction: float = 1.0
var health: int = 100
var simulation_frame: int = 0
var current_attack: AttackData
var attack_frame: int = -1
var stun_frames: int = 0
var knockdown_frames: int = 0
var hit_stop_frames: int = 0
var external_input: Dictionary = {}
var last_controls: Dictionary = {}
var input_buffer := FighterInputBuffer.new()

func _ready() -> void:
	if stats == null:
		push_error("Fighter requires a FighterStats resource")
		set_physics_process(false)
		return
	health = stats.max_health
	if not sprite_visual.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite_visual.animation_finished.connect(_on_sprite_animation_finished)
	apply_visual_identity()
	hurtbox.owner_fighter = self
	hitbox.deactivate()
	state_machine.state_changed.connect(_on_state_changed)
	health_changed.emit(health, stats.max_health)

func _physics_process(delta: float) -> void:
	if hit_stop_frames > 0:
		hit_stop_frames -= 1
		return
	simulation_frame += 1
	_update_facing()
	if not is_on_floor():
		velocity.y += stats.gravity * delta

	if state_machine.is_state(&"ko"):
		velocity.x = move_toward(velocity.x, 0.0, 12.0)
		move_and_slide()
		return

	var controls := _read_controls()
	last_controls = controls.duplicate()
	input_buffer.push(simulation_frame, controls, facing_direction)

	if stun_frames > 0:
		stun_frames -= 1
		velocity.x = move_toward(velocity.x, 0.0, 10.0 / stats.weight)
		if stun_frames == 0 and not state_machine.is_state(&"knockdown"):
			transition(&"idle")
	elif state_machine.is_state(&"knockdown"):
		_process_knockdown()
	elif state_machine.is_state(&"get_up"):
		_process_get_up()
	elif current_attack != null:
		_process_attack()
	elif input_enabled:
		_process_actions(controls)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 28.0)
		if is_on_floor():
			transition(&"idle")

	move_and_slide()
	if is_on_floor() and state_machine.is_state(&"jump") and velocity.y >= 0.0:
		transition(&"idle")

func _read_controls() -> Dictionary:
	if external_controlled:
		return external_input.duplicate()
	if ai_controlled:
		var ai := get_node_or_null("FighterAI")
		if ai != null and ai.has_method("get_input"):
			return ai.get_input(self, opponent, simulation_frame)
		return FighterInputMapper.empty_input()
	if not input_enabled:
		return FighterInputMapper.empty_input()
	return FighterInputMapper.read_player(player_index)

func _process_actions(controls: Dictionary) -> void:
	var attack_id := _requested_attack(controls)
	if attack_id != &"":
		_start_attack(attack_id)
		return

	if bool(controls.get("block", false)) and is_on_floor():
		velocity.x = 0.0
		transition(&"block")
		_play_visual_animation(&"block")
		return
	if bool(controls.get("crouch", false)) and is_on_floor():
		velocity.x = 0.0
		transition(&"crouch")
		_play_visual_animation(&"crouch")
		return
	if bool(controls.get("jump", false)) and is_on_floor():
		velocity.y = -stats.jump_force
		transition(&"jump")
		return

	var horizontal := float(bool(controls.get("right", false))) - float(bool(controls.get("left", false)))
	if not is_zero_approx(horizontal):
		var moving_forward := signf(horizontal) == signf(facing_direction)
		velocity.x = horizontal * (stats.walk_speed if moving_forward else stats.backward_walk_speed)
		transition(&"walk_forward" if moving_forward else &"walk_backward")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 42.0)
		if is_on_floor():
			transition(&"idle")

func _requested_attack(controls: Dictionary) -> StringName:
	var lp := input_buffer.just_pressed("lp", simulation_frame)
	var rp := input_buffer.just_pressed("rp", simulation_frame)
	var lk := input_buffer.just_pressed("lk", simulation_frame)
	var rk := input_buffer.just_pressed("rk", simulation_frame)
	if lp and rk:
		return &"lp_rk" if stats.find_attack(&"lp_rk") != null else &"rk"
	if rp and input_buffer.matches(PackedStringArray(["forward", "rp"])):
		return &"forward_rp" if stats.find_attack(&"forward_rp") != null else &"rp"
	if lk and bool(controls.get("crouch", false)):
		return &"down_lk" if stats.find_attack(&"down_lk") != null else &"lk"
	if lp:
		return &"lp"
	if rp:
		return &"rp"
	if lk:
		return &"lk"
	if rk:
		return &"rk"
	return &""

func _start_attack(attack_id: StringName) -> void:
	var attack := stats.find_attack(attack_id)
	if attack == null:
		return
	current_attack = attack
	attack_frame = 0
	velocity.x = 0.0
	transition(&"attack")
	attack_started.emit(attack)
	input_buffer.consume()

func _process_attack() -> void:
	attack_frame += 1
	_update_attack_pose()
	var active_start := current_attack.startup_frames
	var active_end := active_start + current_attack.active_frames
	if attack_frame == active_start:
		_configure_hitbox(current_attack)
		hitbox.activate(self, current_attack)
	elif attack_frame >= active_end:
		hitbox.deactivate()
	if attack_frame >= current_attack.total_frames():
		current_attack = null
		attack_frame = -1
		transition(&"idle")

func _configure_hitbox(attack: AttackData) -> void:
	var rectangle := hitbox_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = attack.hitbox_size
	hitbox.position = Vector2(attack.hitbox_offset.x * facing_direction, attack.hitbox_offset.y)

func receive_hit(attack: AttackData, source_direction: float, blocked: bool, applied_damage: int) -> void:
	current_attack = null
	attack_frame = -1
	hitbox.deactivate()
	health = maxi(0, health - applied_damage)
	health_changed.emit(health, stats.max_health)
	if health <= 0:
		velocity = Vector2(attack.knockback.x * source_direction, -maxf(attack.launch_force, 120.0))
		transition(&"ko")
		knocked_out.emit(self)
		return
	if blocked:
		stun_frames = attack.block_stun_frames
		velocity.x = attack.knockback.x * 0.2 * source_direction
		transition(&"block_stun")
	elif attack.causes_knockdown:
		knockdown_frames = 70
		velocity = Vector2(attack.knockback.x * source_direction / stats.weight, -attack.launch_force)
		transition(&"knockdown")
	else:
		stun_frames = attack.hit_stun_frames
		velocity.x = attack.knockback.x * source_direction / stats.weight
		transition(&"hit_stun")

func can_block_attack(attack: AttackData, attacker: Fighter) -> bool:
	if not state_machine.is_state(&"block"):
		return false
	var attacker_is_in_front := signf(attacker.global_position.x - global_position.x) == signf(facing_direction)
	if not attacker_is_in_front:
		return false
	var crouching := bool(last_controls.get("crouch", false))
	if attack.attack_height == "low":
		return crouching
	return not crouching or attack.attack_height == "mid"

func register_confirmed_hit(_target: Fighter, _attack: AttackData, blocked: bool, applied_damage: int) -> void:
	if not blocked:
		var combo := get_node_or_null("ComboManager") as ComboManager
		if combo != null:
			combo.add_hit(applied_damage)
	hit_confirmed.emit(_target, _attack, blocked, applied_damage)

func apply_hit_stop(frames: int) -> void:
	hit_stop_frames = maxi(hit_stop_frames, frames)

func apply_visual_identity() -> void:
	if stats == null or not is_node_ready():
		return
	body_color = stats.body_color
	body_visual.color = body_color
	var face := body_visual.get_node_or_null("FaceMark") as Polygon2D
	if face != null:
		face.color = stats.skin_color
	var accent_one := body_visual.get_node_or_null("AccentOne") as Polygon2D
	var accent_two := body_visual.get_node_or_null("AccentTwo") as Polygon2D
	var accent_three := body_visual.get_node_or_null("AccentThree") as Polygon2D
	for accent in [accent_one, accent_two, accent_three]:
		if accent != null:
			accent.color = stats.accent_color
	if stats.silhouette_style == "power":
		accent_one.polygon = PackedVector2Array([Vector2(-36, -82), Vector2(-18, -92), Vector2(-12, -66), Vector2(-35, -62)])
		accent_two.polygon = PackedVector2Array([Vector2(36, -82), Vector2(18, -92), Vector2(12, -66), Vector2(35, -62)])
		accent_three.polygon = PackedVector2Array([Vector2(-28, -48), Vector2(28, -48), Vector2(30, -37), Vector2(-30, -37)])
	else:
		accent_one.polygon = PackedVector2Array([Vector2(-19, -101), Vector2(20, -101), Vector2(20, -94), Vector2(-19, -94)])
		accent_two.polygon = PackedVector2Array([Vector2(-27, -72), Vector2(-17, -80), Vector2(28, -35), Vector2(23, -24)])
		accent_three.polygon = PackedVector2Array([Vector2(19, -99), Vector2(43, -91), Vector2(20, -88)])
	var frames := stats.build_sprite_frames()
	if frames != null:
		sprite_visual.sprite_frames = frames
		sprite_visual.position = stats.sprite_offset
		sprite_visual.scale = stats.sprite_scale
		sprite_visual.visible = true
		body_visual.visible = false
		_play_visual_animation(state_machine.current_state)
	else:
		sprite_visual.visible = false
		body_visual.visible = true

func get_active_visual() -> CanvasItem:
	return sprite_visual if sprite_visual.visible else body_visual

func _play_visual_animation(state: StringName) -> void:
	if not sprite_visual.visible or sprite_visual.sprite_frames == null:
		return
	var requested := state
	if state == &"attack" and current_attack != null:
		requested = current_attack.animation_name
	elif state == &"block" and bool(last_controls.get("crouch", false)) and sprite_visual.sprite_frames.has_animation(&"crouch_block"):
		requested = &"crouch_block"
	if sprite_visual.sprite_frames.has_animation(requested):
		var held_animation := StringName("%s_hold" % requested)
		if sprite_visual.animation == requested or sprite_visual.animation == held_animation:
			return
		sprite_visual.play(requested)
		sprite_visual.frame = 0
		sprite_visual.frame_progress = 0.0
	elif state == &"walk_backward" and sprite_visual.sprite_frames.has_animation(&"walk_forward"):
		sprite_visual.play_backwards(&"walk_forward")
	elif sprite_visual.sprite_frames.has_animation(&"idle"):
		sprite_visual.play(&"idle")

func _on_sprite_animation_finished() -> void:
	if sprite_visual.sprite_frames == null:
		return
	var held_animation := StringName("%s_hold" % sprite_visual.animation)
	if sprite_visual.sprite_frames.has_animation(held_animation):
		sprite_visual.play(held_animation)

func _update_attack_pose() -> void:
	if current_attack == null:
		return
	var progress := clampf(float(attack_frame) / float(maxi(1, current_attack.total_frames())), 0.0, 1.0)
	var reach := sin(progress * PI)
	body_visual.scale = Vector2(1.0 + reach * 0.14, 1.0 - reach * 0.05)
	body_visual.rotation = facing_direction * reach * 0.045

func _process_knockdown() -> void:
	knockdown_frames -= 1
	velocity.x = move_toward(velocity.x, 0.0, 8.0)
	if knockdown_frames <= 0 and is_on_floor():
		knockdown_frames = 24
		transition(&"get_up")

func _process_get_up() -> void:
	knockdown_frames -= 1
	velocity.x = 0.0
	if knockdown_frames <= 0:
		transition(&"idle")

func _update_facing() -> void:
	if opponent == null or current_attack != null or not is_on_floor():
		return
	var distance := opponent.global_position.x - global_position.x
	if not is_zero_approx(distance):
		facing_direction = signf(distance)
	if sprite_visual.visible:
		sprite_visual.flip_h = facing_direction < 0.0 if stats.sprite_faces_right else facing_direction > 0.0

func transition(next_state: StringName) -> void:
	state_machine.transition_to(next_state)

func _on_state_changed(_previous: StringName, current: StringName) -> void:
	state_changed.emit(current)
	_play_visual_animation(current)
	if current == &"crouch":
		body_visual.scale.y = 0.68
		body_visual.position.y = 18.0
	elif current == &"knockdown" or current == &"ko":
		body_visual.rotation = PI * 0.5
		body_visual.position.y = 34.0
	else:
		body_visual.scale.y = 1.0
		body_visual.rotation = 0.0
		body_visual.position.y = 0.0

func reset_for_round(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = stats.max_health
	current_attack = null
	attack_frame = -1
	stun_frames = 0
	knockdown_frames = 0
	input_buffer.consume()
	external_input = FighterInputMapper.empty_input()
	last_controls = FighterInputMapper.empty_input()
	hitbox.deactivate()
	hit_stop_frames = 0
	body_visual.modulate = Color.WHITE
	sprite_visual.modulate = Color.WHITE
	transition(&"idle")
	health_changed.emit(health, stats.max_health)

func is_ko() -> bool:
	return state_machine.is_state(&"ko")

func get_debug_text() -> String:
	var attack_text := String(current_attack.id) + ":" + str(attack_frame) if current_attack != null else "none"
	return "%s | HP %d | %s | atk %s | f%d" % [stats.display_name, health, state_machine.current_state, attack_text, simulation_frame]

func set_external_input(value: Dictionary) -> void:
	external_input = value.duplicate()

func capture_simulation_state() -> Dictionary:
	return {
		"position": global_position, "velocity": velocity, "health": health,
		"facing": facing_direction, "state": state_machine.current_state,
		"attack": current_attack.id if current_attack != null else &"",
		"attack_frame": attack_frame, "stun_frames": stun_frames,
		"knockdown_frames": knockdown_frames, "simulation_frame": simulation_frame
	}

func restore_simulation_state(snapshot: Dictionary) -> void:
	global_position = snapshot.get("position", global_position) as Vector2
	velocity = snapshot.get("velocity", velocity) as Vector2
	health = int(snapshot.get("health", health))
	facing_direction = float(snapshot.get("facing", facing_direction))
	attack_frame = int(snapshot.get("attack_frame", -1))
	stun_frames = int(snapshot.get("stun_frames", 0))
	knockdown_frames = int(snapshot.get("knockdown_frames", 0))
	simulation_frame = int(snapshot.get("simulation_frame", simulation_frame))
	var attack_id := StringName(snapshot.get("attack", &""))
	current_attack = stats.find_attack(attack_id) if attack_id != &"" else null
	transition(StringName(snapshot.get("state", &"idle")))
	health_changed.emit(health, stats.max_health)

