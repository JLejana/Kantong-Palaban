class_name SupabaseClient
extends Node

signal request_completed(context: StringName, status_code: int, body: Variant)

var base_url: String = OS.get_environment("SUPABASE_URL")
var anon_key: String = OS.get_environment("SUPABASE_ANON_KEY")
var access_token: String = ""

func _ready() -> void:
	if base_url.is_empty():
		base_url = BackendConfig.supabase_url
	if anon_key.is_empty():
		anon_key = BackendConfig.supabase_anon_key

func is_configured() -> bool:
	return not base_url.is_empty() and not anon_key.is_empty()

func api_request(context: StringName, path: String, method: HTTPClient.Method, payload: Dictionary = {}) -> void:
	if not is_configured():
		request_completed.emit(context, 0, {"error": "Supabase is not configured"})
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_request_completed.bind(context, request))
	var token := access_token if not access_token.is_empty() else anon_key
	var headers := PackedStringArray([
		"apikey: %s" % anon_key,
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json"
	])
	var body := JSON.stringify(payload) if not payload.is_empty() else ""
	var error := request.request(base_url.trim_suffix("/") + path, headers, method, body)
	if error != OK:
		request_completed.emit(context, 0, {"error": error_string(error)})
		request.queue_free()

func _on_request_completed(_result: int, status_code: int, _headers: PackedStringArray, body: PackedByteArray, context: StringName, request: HTTPRequest) -> void:
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	request_completed.emit(context, status_code, parsed if parsed != null else {"raw": text})
	request.queue_free()

