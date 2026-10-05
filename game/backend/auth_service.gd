class_name AuthService
extends Node

signal auth_result(success: bool, data: Dictionary)
signal session_changed(session: Dictionary)

@export var client: SupabaseClient
var guest_mode: bool = true
var current_user: Dictionary = {}
var refresh_token: String = ""
var expires_at: int = 0

func _ready() -> void:
	if client != null:
		client.request_completed.connect(_on_request_completed)

func register(email: String, password: String) -> void:
	client.api_request(&"register", "/auth/v1/signup", HTTPClient.METHOD_POST, {"email": email, "password": password})

func login(email: String, password: String) -> void:
	client.api_request(&"login", "/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": email, "password": password})

func logout() -> void:
	if client.access_token.is_empty():
		_enter_guest_mode()
		return
	client.api_request(&"logout", "/auth/v1/logout", HTTPClient.METHOD_POST)

func refresh_session() -> void:
	if refresh_token.is_empty():
		auth_result.emit(false, {"error": "No refresh token is available"})
		return
	client.api_request(&"refresh", "/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": refresh_token})

func get_current_session() -> Dictionary:
	if guest_mode:
		return {"guest": true}
	return {
		"guest": false, "user": current_user.duplicate(true), "access_token": client.access_token,
		"refresh_token": refresh_token, "expires_at": expires_at
	}

func use_guest_mode() -> void:
	_enter_guest_mode()

func _on_request_completed(context: StringName, status_code: int, body: Variant) -> void:
	if context not in [&"register", &"login", &"refresh", &"logout"]:
		return
	var data: Dictionary = body if body is Dictionary else {}
	var success := status_code >= 200 and status_code < 300
	if success and context in [&"register", &"login", &"refresh"]:
		client.access_token = str(data.get("access_token", ""))
		refresh_token = str(data.get("refresh_token", refresh_token))
		expires_at = int(Time.get_unix_time_from_system()) + int(data.get("expires_in", 3600))
		current_user = data.get("user", {}) as Dictionary
		guest_mode = false
	elif success and context == &"logout":
		_enter_guest_mode()
	auth_result.emit(success, data)
	if success:
		session_changed.emit(get_current_session())

func _enter_guest_mode() -> void:
	guest_mode = true
	current_user.clear()
	refresh_token = ""
	expires_at = 0
	if client != null:
		client.access_token = ""

