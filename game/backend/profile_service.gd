class_name ProfileService
extends Node

@export var client: SupabaseClient

func get_my_profile(user_id: String) -> void:
	client.api_request(&"profile", "/rest/v1/profiles?id=eq.%s&select=*" % user_id.uri_encode(), HTTPClient.METHOD_GET)

func update_my_profile(user_id: String, changes: Dictionary) -> void:
	client.api_request(&"profile_update", "/rest/v1/profiles?id=eq.%s" % user_id.uri_encode(), HTTPClient.METHOD_PATCH, changes)

