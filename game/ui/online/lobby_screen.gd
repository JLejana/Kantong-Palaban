extends Control

@onready var lobby_code: LineEdit = $Layout/LobbyCode
@onready var status: Label = $Layout/Status
@onready var ready_button: Button = $Layout/Ready
var is_ready: bool = false

func _ready() -> void:
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.match_found.connect(func(_data: Dictionary) -> void: SceneManager.start_fight())
	NetworkManager.status_changed.connect(func(text: String) -> void: status.text = text)
	NetworkManager.request_failed.connect(func(code: String, message: String) -> void: status.text = "%s: %s" % [code, message])
	$Layout/Create.pressed.connect(NetworkManager.create_lobby)
	$Layout/Join.pressed.connect(func() -> void: NetworkManager.join_lobby(lobby_code.text.strip_edges()))
	ready_button.pressed.connect(_toggle_ready)
	$Layout/Back.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.MATCHMAKING))
	ready_button.disabled = true
	if not NetworkManager.authenticated_session:
		status.text = "Connect from the Online screen first."

func _toggle_ready() -> void:
	is_ready = not is_ready
	NetworkManager.set_ready(is_ready)
	ready_button.text = "NOT READY" if is_ready else "READY"

func _on_lobby_updated(data: Dictionary) -> void:
	var id := str(data.get("lobbyId", ""))
	if not id.is_empty():
		lobby_code.text = id
	ready_button.disabled = false
	var players: Array = data.get("players", []) as Array
	status.text = "Lobby %s\nPlayers: %d / 2" % [id, players.size()]

