class_name AttackData
extends Resource

@export var id: StringName = &"lp"
@export var display_name: String = "Left Punch"
@export var input_command: PackedStringArray = ["lp"]
@export_range(0, 1000) var damage: int = 5
@export_range(1, 120) var startup_frames: int = 5
@export_range(1, 120) var active_frames: int = 3
@export_range(0, 180) var recovery_frames: int = 7
@export_range(0, 180) var hit_stun_frames: int = 14
@export_range(0, 180) var block_stun_frames: int = 8
@export var knockback: Vector2 = Vector2(180.0, 0.0)
@export var launch_force: float = 0.0
@export_enum("high", "mid", "low") var attack_height: String = "mid"
@export var can_be_blocked: bool = true
@export var causes_knockdown: bool = false
@export var meter_gain: int = 5
@export var animation_name: StringName = &"attack"
@export var can_hit_multiple_times: bool = false
@export var hitbox_size: Vector2 = Vector2(72.0, 46.0)
@export var hitbox_offset: Vector2 = Vector2(56.0, -58.0)

func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames

