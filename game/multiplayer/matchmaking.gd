class_name MatchmakingClient
extends Node

@export var transport: FighterWebSocketClient

func join_queue(region: String = "auto") -> void:
	transport.send_json({"type": "queue_join", "region": region})

func leave_queue() -> void:
	transport.send_json({"type": "queue_leave"})

