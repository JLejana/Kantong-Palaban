class_name ComboManager
extends Node

signal combo_changed(hit_count: int, damage: int)

@export var combo_timeout_frames: int = 90
var hit_count: int = 0
var total_damage: int = 0
var frames_since_hit: int = 0

func _physics_process(_delta: float) -> void:
	if hit_count == 0:
		return
	frames_since_hit += 1
	if frames_since_hit > combo_timeout_frames:
		reset_combo()

func add_hit(damage: int) -> void:
	hit_count += 1
	total_damage += damage
	frames_since_hit = 0
	combo_changed.emit(hit_count, total_damage)

func damage_multiplier() -> float:
	return maxf(0.4, 1.0 - float(hit_count) * 0.1)

func reset_combo() -> void:
	hit_count = 0
	total_damage = 0
	frames_since_hit = 0
	combo_changed.emit(0, 0)

