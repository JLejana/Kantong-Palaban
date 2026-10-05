extends Control

const COMMAND_LABELS := {
	"left": "Move left", "right": "Move right", "jump": "Jump", "crouch": "Crouch",
	"lp": "Left punch", "rp": "Right punch", "lk": "Left kick", "rk": "Right kick", "block": "Block"
}

@onready var content: VBoxContainer = $Layout/Bindings/Content
@onready var instruction: Label = $Layout/Instruction

var binding_buttons: Dictionary = {}
var listening_action: StringName = &""

func _ready() -> void:
	_build_binding_rows()
	$Layout/Actions/Reset.pressed.connect(_reset_bindings)
	$Layout/Actions/Back.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.SETTINGS))

func _build_binding_rows() -> void:
	for player in [1, 2]:
		var heading := Label.new()
		heading.text = "PLAYER %d" % player
		heading.add_theme_font_size_override("font_size", 22)
		heading.add_theme_color_override("font_color", Color("ffd447"))
		content.add_child(heading)
		for command in FighterInputMapper.COMMANDS:
			var action := StringName("p%d_%s" % [player, command])
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = COMMAND_LABELS.get(command, command.capitalize())
			label.custom_minimum_size = Vector2(170.0, 38.0)
			var button := Button.new()
			button.text = GameManager.get_binding_label(action)
			button.custom_minimum_size = Vector2(330.0, 38.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_begin_rebind.bind(action, button))
			row.add_child(label)
			row.add_child(button)
			content.add_child(row)
			binding_buttons[action] = button

func _begin_rebind(action: StringName, button: Button) -> void:
	listening_action = action
	button.text = "Press a keyboard or gamepad buttonâ€¦"
	instruction.text = "Assigning %s. Escape cancels." % String(action).replace("_", " ").capitalize()

func _unhandled_input(event: InputEvent) -> void:
	if listening_action == &"":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		if key.physical_keycode == 0:
			key.physical_keycode = key.keycode
		_commit_rebind(key)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_commit_rebind(event)

func _commit_rebind(event: InputEvent) -> void:
	var action := listening_action
	listening_action = &""
	GameManager.rebind_action(action, event)
	(binding_buttons[action] as Button).text = GameManager.get_binding_label(action)
	instruction.text = "Select a binding, then press a keyboard or gamepad button. Analog movement remains enabled."
	get_viewport().set_input_as_handled()

func _cancel_rebind() -> void:
	var action := listening_action
	listening_action = &""
	(binding_buttons[action] as Button).text = GameManager.get_binding_label(action)
	instruction.text = "Binding unchanged."

func _reset_bindings() -> void:
	listening_action = &""
	GameManager.reset_control_bindings()
	for action: StringName in binding_buttons:
		(binding_buttons[action] as Button).text = GameManager.get_binding_label(action)
	instruction.text = "Default keyboard and gamepad controls restored."
