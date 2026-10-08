extends Control

@onready var server_url: LineEdit = $Layout/ServerUrl
@onready var email: LineEdit = $Layout/Email
@onready var password: LineEdit = $Layout/Password
@onready var status: Label = $Layout/Status
@onready var find_button: Button = $Layout/FindMatch
@onready var cancel_button: Button = $Layout/CancelQueue

var supabase: SupabaseClient
var auth: AuthService
var pending_action: StringName = &"guest"

func _ready() -> void:
	supabase = SupabaseClient.new()
	auth = AuthService.new()
	auth.client = supabase
	add_child(supabase)
	add_child(auth)
	auth.auth_result.connect(_on_auth_result)
	NetworkManager.status_changed.connect(_set_status)
	NetworkManager.authenticated.connect(_on_server_authenticated)
	NetworkManager.match_found.connect(_on_match_found)
	NetworkManager.request_failed.connect(func(code: String, message: String) -> void: _set_status("%s: %s" % [code, message]))
	server_url.text = BackendConfig.multiplayer_url
	$Layout/AuthButtons/Login.pressed.connect(func() -> void: _authenticate(&"login"))
	$Layout/AuthButtons/Register.pressed.connect(func() -> void: _authenticate(&"register"))
	$Layout/Guest.pressed.connect(_connect_as_guest)
	find_button.pressed.connect(_join_queue)
	cancel_button.pressed.connect(_cancel_queue)
	$Layout/PrivateLobby.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.LOBBY))
	$Layout/Back.pressed.connect(_go_back)
	find_button.disabled = not NetworkManager.authenticated_session
	cancel_button.disabled = true
	_set_status("Sign in or continue as guest. Offline modes never require an account.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()

func _authenticate(action: StringName) -> void:
	if not supabase.is_configured():
		_set_status("Supabase is not configured. Use Guest or set SUPABASE_URL and SUPABASE_ANON_KEY.")
		return
	if email.text.is_empty() or password.text.length() < 6:
		_set_status("Enter an email and a password of at least 6 characters.")
		return
	pending_action = action
	if action == &"login":
		auth.login(email.text, password.text)
	else:
		auth.register(email.text, password.text)
	_set_status("Contacting Supabase…")

func _on_auth_result(success: bool, data: Dictionary) -> void:
	if not success:
		_set_status(str(data.get("msg", data.get("error_description", "Authentication failed"))))
		return
	var token := supabase.access_token
	if token.is_empty():
		_set_status("Registration succeeded. Confirm email if required, then log in.")
		return
	_connect(token)

func _connect_as_guest() -> void:
	auth.use_guest_mode()
	_connect("")

func _connect(token: String) -> void:
	var error := NetworkManager.connect_to_server(server_url.text, token)
	if error != OK:
		_set_status("Unable to connect: " + error_string(error))

func _on_server_authenticated(_user_id: String, _guest: bool) -> void:
	find_button.disabled = false

func _join_queue() -> void:
	NetworkManager.join_queue()
	find_button.disabled = true
	cancel_button.disabled = false

func _cancel_queue() -> void:
	NetworkManager.leave_queue()
	find_button.disabled = false
	cancel_button.disabled = true

func _on_match_found(_data: Dictionary) -> void:
	SceneManager.start_fight()

func _go_back() -> void:
	NetworkManager.leave_queue()
	SceneManager.go_to_main_menu()

func _set_status(text: String) -> void:
	status.text = text

