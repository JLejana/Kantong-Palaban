class_name FighterWebSocketClient
extends Node

signal connected
signal disconnected
signal json_received(message: Dictionary)

var socket := WebSocketPeer.new()
var _was_open: bool = false

func connect_to_server(url: String) -> Error:
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 262144
	socket.max_queued_packets = 256
	return socket.connect_to_url(url)

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			connected.emit()
		while socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if value is Dictionary:
				json_received.emit(value)
	elif _was_open and state == WebSocketPeer.STATE_CLOSED:
		_was_open = false
		disconnected.emit()

func send_json(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))

func close() -> void:
	socket.close()

