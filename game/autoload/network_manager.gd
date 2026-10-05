extends Node

signal connection_changed(connected: bool)
signal message_received(message: Dictionary)
signal status_changed(status: String)
signal authenticated(user_id: String, guest: bool)
signal lobby_updated(lobby: Dictionary)
signal match_found(match_data: Dictionary)
signal online_input_received(frame: int, player_id: String, input: Dictionary)
signal peer_disconnected(player_id: String)
signal peer_reconnected(player_id: String)
signal ping_updated(milliseconds: int)
signal request_failed(code: String, message: String)
signal webrtc_signal_received(from_player_id: String, signal_data: Dictionary)

var transport: FighterWebSocketClient
var server_url: String = ""
var access_token: String = ""
var player_id: String = ""
var user_id: String = ""
var resume_token: String = ""
var current_match_id: String = ""
var connected: bool = false
var authenticated_session: bool = false
var _ping_sent_at: int = 0
var _ping_accumulator: float = 0.0
var _reconnect_attempts: int = 0
var _reconnect_remaining: float = -1.0

func _ready() -> void:
	transport = FighterWebSocketClient.new()
	transport.name = "WebSocketTransport"
	add_child(transport)
	transport.connected.connect(_on_connected)
	transport.disconnected.connect(_on_disconnected)
	transport.json_received.connect(_on_message)

func _process(delta: float) -> void:
	if connected:
		_ping_accumulator += delta
		if _ping_accumulator >= 2.0:
			_ping_accumulator = 0.0
			_ping_sent_at = Time.get_ticks_msec()
			send_message({"type": "ping", "sentAt": _ping_sent_at})
	elif _reconnect_remaining >= 0.0:
		_reconnect_remaining -= delta
		if _reconnect_remaining <= 0.0:
			_reconnect_remaining = -1.0
			_connect_transport()

func connect_to_server(url: String, token: String = "") -> Error:
	server_url = url.strip_edges()
	access_token = token
	_reconnect_attempts = 0
	if server_url.is_empty():
		return ERR_INVALID_PARAMETER
	return _connect_transport()

func _connect_transport() -> Error:
	status_changed.emit("Connecting…")
	var error := transport.connect_to_server(server_url)
	if error != OK:
		status_changed.emit("Connection failed: " + error_string(error))
	return error

func set_transport(value: Node) -> void:
	if value is FighterWebSocketClient:
		transport = value as FighterWebSocketClient

func send_message(message: Dictionary) -> void:
	if transport != null:
		transport.send_json(message)

func create_lobby() -> void:
	send_message({"type": "lobby_create"})

func join_lobby(lobby_id: String) -> void:
	send_message({"type": "lobby_join", "lobbyId": lobby_id})

func set_ready(ready: bool) -> void:
	send_message({"type": "ready", "ready": ready})

func join_queue(region: String = "auto") -> void:
	send_message({"type": "queue_join", "region": region})

func leave_queue() -> void:
	send_message({"type": "queue_leave"})

func send_input(frame: int, input: Dictionary) -> void:
	if current_match_id.is_empty() or player_id.is_empty():
		return
	send_message({"type": "input", "matchId": current_match_id, "playerId": player_id, "frame": frame, "input": input})

func submit_match_result(winner_id: String, player_one_rounds: int, player_two_rounds: int, duration_seconds: int) -> void:
	if current_match_id.is_empty():
		return
	send_message({
		"type": "match_result", "matchId": current_match_id, "winnerId": winner_id,
		"playerOneRounds": player_one_rounds, "playerTwoRounds": player_two_rounds,
		"durationSeconds": duration_seconds
	})

func send_webrtc_signal(target_player_id: String, signal_data: Dictionary) -> void:
	if current_match_id.is_empty():
		return
	send_message({"type": "webrtc_signal", "matchId": current_match_id, "targetPlayerId": target_player_id, "signal": signal_data})

func disconnect_from_server() -> void:
	_reconnect_remaining = -1.0
	_reconnect_attempts = 0
	server_url = ""
	connected = false
	authenticated_session = false
	player_id = ""
	user_id = ""
	resume_token = ""
	current_match_id = ""
	transport.close()

func _on_connected() -> void:
	connected = true
	_reconnect_attempts = 0
	connection_changed.emit(true)
	status_changed.emit("Connected")

func _on_disconnected() -> void:
	connected = false
	authenticated_session = false
	connection_changed.emit(false)
	status_changed.emit("Disconnected")
	if not server_url.is_empty() and _reconnect_attempts < 5:
		_reconnect_attempts += 1
		_reconnect_remaining = minf(pow(2.0, _reconnect_attempts - 1), 8.0)
		status_changed.emit("Reconnecting in %.0f…" % _reconnect_remaining)

func _on_message(message: Dictionary) -> void:
	message_received.emit(message)
	match String(message.get("type", "")):
		"welcome":
			send_message({"type": "authenticate", "accessToken": access_token, "resumeToken": resume_token})
		"authenticated":
			authenticated_session = true
			player_id = str(message.get("playerId", ""))
			user_id = str(message.get("userId", ""))
			resume_token = str(message.get("resumeToken", ""))
			authenticated.emit(user_id, bool(message.get("guest", true)))
			status_changed.emit("Online as guest" if bool(message.get("guest", true)) else "Authenticated")
		"lobby_created":
			lobby_updated.emit(message)
		"lobby_state":
			lobby_updated.emit(message)
		"queue_joined":
			status_changed.emit("Searching for opponent…")
		"queue_left":
			status_changed.emit("Queue cancelled")
		"match_found":
			current_match_id = str(message.get("matchId", ""))
			GameManager.configure_online_match(message, player_id)
			match_found.emit(message)
		"input":
			online_input_received.emit(int(message.get("frame", 0)), str(message.get("playerId", "")), message.get("input", {}) as Dictionary)
		"peer_disconnected":
			peer_disconnected.emit(str(message.get("playerId", "")))
		"peer_reconnected":
			peer_reconnected.emit(str(message.get("playerId", "")))
		"pong":
			ping_updated.emit(maxi(0, Time.get_ticks_msec() - int(message.get("sentAt", _ping_sent_at))))
		"error":
			var code := str(message.get("code", "server_error"))
			if code in ["invalid_token", "auth_required"]:
				server_url = ""
			request_failed.emit(code, str(message.get("message", "Unknown server error")))
		"webrtc_signal":
			webrtc_signal_received.emit(str(message.get("fromPlayerId", "")), message.get("signal", {}) as Dictionary)

