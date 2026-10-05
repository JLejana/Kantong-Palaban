extends Control

var bindings := {
	"Left": "p1_left", "Right": "p1_right", "Jump": "p1_jump", "Crouch": "p1_crouch",
	"LP": "p1_lp", "RP": "p1_rp", "LK": "p1_lk", "RK": "p1_rk", "Block": "p1_block"
}

func _ready() -> void:
	for node_name: String in bindings:
		var button := get_node(node_name) as Button
		var action: StringName = bindings[node_name]
		button.button_down.connect(func() -> void: Input.action_press(action))
		button.button_up.connect(func() -> void: Input.action_release(action))

func _exit_tree() -> void:
	for action: StringName in bindings.values():
		Input.action_release(action)

