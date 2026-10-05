class_name FighterWebRTCClient
extends Node

signal signal_created(signal_data: Dictionary)
signal channel_opened
signal channel_closed
signal packet_received(packet: PackedByteArray)

var peer: WebRTCPeerConnection
var channel: WebRTCDataChannel
var initialized: bool = false
var _channel_was_open: bool = false

func initialize(ice_servers: Array = []) -> Error:
	peer = WebRTCPeerConnection.new()
	var configuration := {}
	if not ice_servers.is_empty():
		configuration["iceServers"] = ice_servers
	var error := peer.initialize(configuration)
	if error != OK:
		return error
	peer.session_description_created.connect(_on_session_description_created)
	peer.ice_candidate_created.connect(_on_ice_candidate_created)
	channel = peer.create_data_channel("combat", {"id": 1, "negotiated": true, "ordered": false, "maxRetransmits": 0})
	initialized = channel != null
	return OK if initialized else ERR_CANT_CREATE

func create_offer() -> Error:
	if not initialized:
		return ERR_UNCONFIGURED
	return peer.create_offer()

func handle_signal(signal_data: Dictionary) -> Error:
	if not initialized:
		return ERR_UNCONFIGURED
	match String(signal_data.get("kind", "")):
		"offer":
			var offer_error := peer.set_remote_description("offer", str(signal_data.get("sdp", "")))
			if offer_error != OK:
				return offer_error
			return peer.create_answer()
		"answer":
			return peer.set_remote_description("answer", str(signal_data.get("sdp", "")))
		"ice":
			return peer.add_ice_candidate(str(signal_data.get("mid", "")), int(signal_data.get("index", 0)), str(signal_data.get("candidate", "")))
	return ERR_INVALID_DATA

func _process(_delta: float) -> void:
	if not initialized:
		return
	peer.poll()
	if channel == null:
		return
	var state := channel.get_ready_state()
	if state == WebRTCDataChannel.STATE_OPEN:
		if not _channel_was_open:
			_channel_was_open = true
			channel_opened.emit()
		while channel.get_available_packet_count() > 0:
			packet_received.emit(channel.get_packet())
	elif _channel_was_open and state == WebRTCDataChannel.STATE_CLOSED:
		_channel_was_open = false
		channel_closed.emit()

func send_packet(packet: PackedByteArray) -> Error:
	if channel == null or channel.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
		return ERR_UNAVAILABLE
	return channel.put_packet(packet)

func close() -> void:
	if channel != null:
		channel.close()
	if peer != null:
		peer.close()
	initialized = false
	_channel_was_open = false
	channel_closed.emit()

func is_available() -> bool:
	return WebRTCPeerConnection.new() != null

func _on_session_description_created(type: String, sdp: String) -> void:
	peer.set_local_description(type, sdp)
	signal_created.emit({"kind": type, "sdp": sdp})

func _on_ice_candidate_created(media: String, index: int, candidate: String) -> void:
	signal_created.emit({"kind": "ice", "mid": media, "index": index, "candidate": candidate})

