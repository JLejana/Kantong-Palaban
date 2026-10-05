extends Node

var failures: Array[String] = []

func _ready() -> void:
	var fighter_a := load("res://fighters/fighter_a/fighter_a.tres") as FighterStats
	var fighter_b := load("res://fighters/fighter_b/fighter_b.tres") as FighterStats
	_assert(fighter_a != null and fighter_b != null, "fighter resources load")
	_assert(fighter_a.find_attack(&"forward_rp") != null, "FighterA has a command special")
	_assert(fighter_b.find_attack(&"forward_rp") != null, "FighterB has a command special")
	_assert(fighter_a.silhouette_style != fighter_b.silhouette_style, "fighter silhouettes are distinct")
	_assert(not is_equal_approx(fighter_a.damage_scale, fighter_b.damage_scale), "fighter damage profiles are distinct")
	_test_fighter_a_sprite_animations(fighter_a)
	_assert(_has_event_type(&"p1_left", InputEventJoypadMotion), "player one analog movement is mapped")
	_assert(_has_event_type(&"p1_lp", InputEventJoypadButton), "player one gamepad attacks are mapped")
	_assert(_has_device_button(&"p2_block", 1), "player two gamepad is mapped independently")
	_assert(not GameManager.get_binding_label(&"p1_lp").is_empty(), "binding labels are available to settings UI")
	if failures.is_empty():
		print("POLISH_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _test_fighter_a_sprite_animations(fighter_a: FighterStats) -> void:
	var frames := fighter_a.build_sprite_frames()
	_assert(frames != null, "FighterA sprite frames build")
	if frames == null:
		return
	for animation: StringName in [&"idle", &"walk_forward", &"walk_backward", &"crouch", &"block", &"crouch_block", &"jump"]:
		_assert(frames.has_animation(animation), "FighterA %s animation is registered" % animation)
		var expected_frames := 4 if animation in [&"crouch", &"block", &"crouch_block"] else 8
		_assert(frames.get_frame_count(animation) == expected_frames, "FighterA %s animation has the expected frames" % animation)
	for animation: StringName in [&"crouch", &"block", &"crouch_block"]:
		_assert(not frames.get_animation_loop(animation), "FighterA %s holds its final pose instead of looping" % animation)
		var held_animation := StringName("%s_hold" % animation)
		_assert(frames.has_animation(held_animation), "FighterA %s held-pose animation is registered" % animation)
		_assert(frames.get_frame_count(held_animation) == 4, "FighterA %s held pose uses four stable frames" % animation)
		_assert(frames.get_animation_loop(held_animation), "FighterA %s held pose remains animated" % animation)
	var fighter_scene := load("res://fighters/base/fighter.tscn") as PackedScene
	var fighter := fighter_scene.instantiate() as Fighter
	fighter.stats = fighter_a
	add_child(fighter)
	_assert(fighter.sprite_visual.visible, "FighterA uses its sprite visual at runtime")
	_assert(not fighter.body_visual.visible, "FighterA placeholder visual is hidden")
	_assert(fighter.sprite_visual.animation == &"idle", "FighterA starts in its idle animation")
	fighter.transition(&"walk_backward")
	_assert(fighter.sprite_visual.animation == &"walk_backward", "FighterA uses its dedicated backward-walk animation")
	fighter.transition(&"crouch")
	_assert(fighter.sprite_visual.animation == &"crouch", "FighterA uses its crouch animation")
	fighter.last_controls["crouch"] = true
	fighter.transition(&"block")
	_assert(fighter.sprite_visual.animation == &"crouch_block", "FighterA selects crouch-block while crouching")
	fighter.last_controls["crouch"] = false
	fighter.transition(&"idle")
	fighter.transition(&"block")
	_assert(fighter.sprite_visual.animation == &"block", "FighterA selects standing block")
	fighter.transition(&"jump")
	_assert(fighter.sprite_visual.animation == &"jump", "FighterA uses its jump animation")
	fighter.queue_free()

func _has_event_type(action: StringName, event_type: Variant) -> bool:
	for event in InputMap.action_get_events(action):
		if is_instance_of(event, event_type):
			return true
	return false

func _has_device_button(action: StringName, device: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.device == device:
			return true
	return false

func _assert(condition: bool, description: String) -> void:
	if not condition:
		failures.append("POLISH_TEST failed: " + description)
