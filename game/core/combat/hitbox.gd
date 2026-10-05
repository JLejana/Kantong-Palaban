class_name Hitbox
extends Area2D

var attacker: Fighter
var attack_data: AttackData
var already_hit: Dictionary = {}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func activate(source: Fighter, data: AttackData) -> void:
	attacker = source
	attack_data = data
	already_hit.clear()
	monitoring = true
	visible = true

func deactivate() -> void:
	monitoring = false
	visible = false
	attack_data = null

func _on_area_entered(area: Area2D) -> void:
	if not area is Hurtbox or attack_data == null:
		return
	var hurtbox := area as Hurtbox
	var target := hurtbox.owner_fighter
	if target == null or target == attacker:
		return
	var key := target.get_instance_id()
	if already_hit.has(key) and not attack_data.can_hit_multiple_times:
		return
	already_hit[key] = true
	DamageSystem.apply_hit(attacker, target, attack_data)

