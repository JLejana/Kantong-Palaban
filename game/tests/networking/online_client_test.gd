extends Node

var failed: bool = false

func _ready() -> void:
	NetworkManager.authenticated.connect(_on_authenticated)
	NetworkManager.match_found.connect(_on_match_found)
	NetworkManager.online_input_received.connect(_on_online_input)
	NetworkManager.request_failed.connect(_on_failed)
	get_tree().create_timer(8.0).timeout.connect(func() -> void: _finish(false, "online client timed out"))
	var error := NetworkManager.connect_to_server("ws://127.0.0.1:18082")
	if error != OK:
		_finish(false, error_string(error))

func _on_authenticated(_user_id: String, guest: bool) -> void:
	if not guest:
		_finish(false, "test server did not create a guest session")
		return
	NetworkManager.join_queue("test")

func _on_match_found(_match: Dictionary) -> void:
	var input := FighterInputMapper.empty_input()
	input["lp"] = true
	NetworkManager.send_input(0, input)

func _on_online_input(frame: int, player_id: String, input: Dictionary) -> void:
	if frame == 0 and player_id != NetworkManager.player_id and bool(input.get("right", false)):
		_finish(true, "")

func _on_failed(code: String, message: String) -> void:
	_finish(false, "%s: %s" % [code, message])

func _finish(success: bool, reason: String) -> void:
	if failed or not is_inside_tree():
		return
	failed = not success
	NetworkManager.disconnect_from_server()
	if success:
		print("GODOT_ONLINE_CLIENT_TEST: PASS")
		get_tree().quit(0)
	else:
		push_error("GODOT_ONLINE_CLIENT_TEST failed: " + reason)
		get_tree().quit(1)

