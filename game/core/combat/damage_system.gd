class_name DamageSystem
extends RefCounted

static func apply_hit(attacker: Fighter, defender: Fighter, attack: AttackData) -> void:
	if defender == null or defender.is_ko():
		return
	var blocked := attack.can_be_blocked and defender.can_block_attack(attack, attacker)
	var base_damage := maxi(1, int(round(attack.damage * attacker.stats.damage_scale)))
	var applied_damage := base_damage
	if blocked:
		applied_damage = maxi(1, int(round(base_damage * 0.15)))
	else:
		var combo := attacker.get_node_or_null("ComboManager") as ComboManager
		if combo != null:
			applied_damage = maxi(1, int(round(base_damage * combo.damage_multiplier())))
	defender.receive_hit(attack, attacker.facing_direction, blocked, applied_damage)
	attacker.register_confirmed_hit(defender, attack, blocked, applied_damage)

