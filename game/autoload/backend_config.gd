extends Node

const PUBLIC_CONFIG_PATH := "res://data/backend/public_config.json"

var supabase_url: String = ""
var supabase_anon_key: String = ""
var multiplayer_url: String = "ws://127.0.0.1:8080"

func _ready() -> void:
	_load_public_config()
	supabase_url = OS.get_environment("SUPABASE_URL") if not OS.get_environment("SUPABASE_URL").is_empty() else supabase_url
	supabase_anon_key = OS.get_environment("SUPABASE_ANON_KEY") if not OS.get_environment("SUPABASE_ANON_KEY").is_empty() else supabase_anon_key
	multiplayer_url = OS.get_environment("MULTIPLAYER_URL") if not OS.get_environment("MULTIPLAYER_URL").is_empty() else multiplayer_url

func _load_public_config() -> void:
	if not FileAccess.file_exists(PUBLIC_CONFIG_PATH):
		return
	var file := FileAccess.open(PUBLIC_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Public backend config is not valid JSON")
		return
	var data := parsed as Dictionary
	supabase_url = str(data.get("supabase_url", ""))
	supabase_anon_key = str(data.get("supabase_anon_key", ""))
	multiplayer_url = str(data.get("multiplayer_url", multiplayer_url))

