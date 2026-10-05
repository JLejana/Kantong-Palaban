class_name LobbyClient
extends Node

@export var transport: FighterWebSocketClient

func create_lobby() -> void:
	transport.send_json({"type": "lobby_create"})

func join_lobby(lobby_id: String) -> void:
	transport.send_json({"type": "lobby_join", "lobbyId": lobby_id})

func set_ready(ready: bool) -> void:
	transport.send_json({"type": "ready", "ready": ready})

