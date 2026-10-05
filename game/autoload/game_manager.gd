extends Node

signal settings_changed
signal mode_changed(mode: GameMode)

enum GameMode { CPU, LOCAL, ONLINE, TRAINING }

var debug_enabled: bool = OS.is_debug_build()
var player_two_is_cpu: bool = true
var ai_difficulty: StringName = &"normal"
var game_mode: GameMode = GameMode.CPU
var selected_player_one: StringName = &"fighter_a"
var selected_player_two: StringName = &"fighter_b"
var selected_stage: StringName = &"barangay_court"
var online_match: Dictionary = {}
var online_local_slot: int = 1
var master_volume: float = 0.8
var touch_controls_mode: StringName = &"auto"
var screen_shake_intensity: float = 1.0
var vibration_enabled: bool = true
var control_bindings: Dictionary = {}
var _default_input_events: Dictionary = {}

func _ready() -> void:
	_ensure_default_gamepad_bindings()
	_capture_default_input_events()
	var saved := SaveManager.load_settings()
	debug_enabled = bool(saved.get("debug_enabled", debug_enabled))
	ai_difficulty = StringName(saved.get("ai_difficulty", String(ai_difficulty)))
	master_volume = clampf(float(saved.get("master_volume", master_volume)), 0.0, 1.0)
	touch_controls_mode = StringName(saved.get("touch_controls_mode", String(touch_controls_mode)))
	screen_shake_intensity = clampf(float(saved.get("screen_shake_intensity", screen_shake_intensity)), 0.0, 1.0)
	vibration_enabled = bool(saved.get("vibration_enabled", vibration_enabled))
	control_bindings = saved.get("control_bindings", {}) as Dictionary
	_apply_saved_control_bindings()
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_mode(value: GameMode) -> void:
	game_mode = value
	player_two_is_cpu = value == GameMode.CPU
	mode_changed.emit(game_mode)

func configure_online_match(data: Dictionary, local_player_id: String) -> void:
	online_match = data.duplicate(true)
	var players: Array = data.get("players", []) as Array
	online_local_slot = players.find(local_player_id) + 1
	if online_local_slot < 1:
		online_local_slot = 1
	set_mode(GameMode.ONLINE)

func clear_online_match() -> void:
	online_match.clear()
	online_local_slot = 1

func save_settings() -> void:
	SaveManager.save_settings({
		"debug_enabled": debug_enabled,
		"ai_difficulty": String(ai_difficulty),
		"master_volume": master_volume,
		"touch_controls_mode": String(touch_controls_mode),
		"screen_shake_intensity": screen_shake_intensity,
		"vibration_enabled": vibration_enabled,
		"control_bindings": control_bindings
	})

func toggle_debug() -> void:
	debug_enabled = not debug_enabled
	save_settings()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	save_settings()
	settings_changed.emit()

func should_show_touch_controls() -> bool:
	if touch_controls_mode == &"always":
		return true
	if touch_controls_mode == &"never":
		return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func rebind_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var binding_type := _binding_type(event)
	if binding_type.is_empty():
		return
	var normalized := _normalize_binding(action, event)
	for existing in InputMap.action_get_events(action):
		if _binding_type(existing) == binding_type:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, normalized)
	var action_bindings: Dictionary = control_bindings.get(String(action), {}) as Dictionary
	action_bindings[binding_type] = _serialize_binding(normalized)
	control_bindings[String(action)] = action_bindings
	save_settings()
	settings_changed.emit()

func reset_control_bindings() -> void:
	for action_name: String in _default_input_events:
		var action := StringName(action_name)
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_input_events[action_name]:
			InputMap.action_add_event(action, event.duplicate(true))
	control_bindings.clear()
	save_settings()
	settings_changed.emit()

func get_binding_label(action: StringName) -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		var label := _event_label(event)
		if not label.is_empty() and label not in labels:
			labels.append(label)
	return " / ".join(labels)

func get_keyboard_binding_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var label := _event_label(event)
			if not label.is_empty():
				return label
	var fallback := get_binding_label(action)
	return fallback if not fallback.is_empty() else "--"

func _ensure_default_gamepad_bindings() -> void:
	_add_axis_pair(&"p1_left", &"p1_right", 0)
	_add_axis_pair(&"p2_left", &"p2_right", 1)
	_add_pad_button(&"p1_left", 0, JOY_BUTTON_DPAD_LEFT)
	_add_pad_button(&"p1_right", 0, JOY_BUTTON_DPAD_RIGHT)
	_add_pad_button(&"p1_jump", 0, JOY_BUTTON_DPAD_UP)
	_add_pad_button(&"p1_crouch", 0, JOY_BUTTON_DPAD_DOWN)
	_add_pad_button(&"p1_lp", 0, JOY_BUTTON_X)
	_add_pad_button(&"p1_rp", 0, JOY_BUTTON_Y)
	_add_pad_button(&"p1_lk", 0, JOY_BUTTON_A)
	_add_pad_button(&"p1_rk", 0, JOY_BUTTON_B)
	_add_pad_button(&"p1_block", 0, JOY_BUTTON_RIGHT_SHOULDER)
	_add_pad_button(&"p2_left", 1, JOY_BUTTON_DPAD_LEFT)
	_add_pad_button(&"p2_right", 1, JOY_BUTTON_DPAD_RIGHT)
	_add_pad_button(&"p2_jump", 1, JOY_BUTTON_DPAD_UP)
	_add_pad_button(&"p2_crouch", 1, JOY_BUTTON_DPAD_DOWN)
	_add_pad_button(&"p2_lp", 1, JOY_BUTTON_X)
	_add_pad_button(&"p2_rp", 1, JOY_BUTTON_Y)
	_add_pad_button(&"p2_lk", 1, JOY_BUTTON_A)
	_add_pad_button(&"p2_rk", 1, JOY_BUTTON_B)
	_add_pad_button(&"p2_block", 1, JOY_BUTTON_RIGHT_SHOULDER)

func _add_axis_pair(left_action: StringName, right_action: StringName, device: int) -> void:
	var left := InputEventJoypadMotion.new()
	left.device = device
	left.axis = JOY_AXIS_LEFT_X
	left.axis_value = -1.0
	InputMap.action_add_event(left_action, left)
	var right := InputEventJoypadMotion.new()
	right.device = device
	right.axis = JOY_AXIS_LEFT_X
	right.axis_value = 1.0
	InputMap.action_add_event(right_action, right)

func _add_pad_button(action: StringName, device: int, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _capture_default_input_events() -> void:
	for player in [1, 2]:
		for command in FighterInputMapper.COMMANDS:
			var action := "p%d_%s" % [player, command]
			var events: Array[InputEvent] = []
			for event in InputMap.action_get_events(action):
				events.append(event.duplicate(true))
			_default_input_events[action] = events

func _apply_saved_control_bindings() -> void:
	for action_name: String in control_bindings:
		var action := StringName(action_name)
		if not InputMap.has_action(action):
			continue
		var bindings: Dictionary = control_bindings[action_name] as Dictionary
		for binding_type: String in bindings:
			var event := _deserialize_binding(bindings[binding_type] as Dictionary)
			if event == null:
				continue
			for existing in InputMap.action_get_events(action):
				if _binding_type(existing) == binding_type:
					InputMap.action_erase_event(action, existing)
			InputMap.action_add_event(action, event)

func _binding_type(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key"
	if event is InputEventJoypadButton:
		return "button"
	return ""

func _normalize_binding(action: StringName, event: InputEvent) -> InputEvent:
	var result := event.duplicate(true) as InputEvent
	if result is InputEventKey:
		(result as InputEventKey).pressed = false
	elif result is InputEventJoypadButton:
		var player_device := 1 if String(action).begins_with("p2_") else 0
		(result as InputEventJoypadButton).device = player_device
		(result as InputEventJoypadButton).pressed = false
	return result

func _serialize_binding(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {"type": "key", "physical_keycode": key.physical_keycode}
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return {"type": "button", "button_index": button.button_index, "device": button.device}
	return {}

func _deserialize_binding(data: Dictionary) -> InputEvent:
	if data.get("type", "") == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(data.get("physical_keycode", 0)) as Key
		return key
	if data.get("type", "") == "button":
		var button := InputEventJoypadButton.new()
		button.button_index = int(data.get("button_index", 0)) as JoyButton
		button.device = int(data.get("device", 0))
		return button
	return null

func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "Pad %d Stick %s" % [motion.device + 1, "Left" if motion.axis_value < 0.0 else "Right"]
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down", JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right"}
		return "Pad %d %s" % [button.device + 1, names.get(button.button_index, "Button %d" % button.button_index)]
	return ""

