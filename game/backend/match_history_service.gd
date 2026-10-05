class_name MatchHistoryService
extends Node

@export var client: SupabaseClient

func fetch_for_player(user_id: String, limit: int = 25) -> void:
	var query := "/rest/v1/matches?or=(player_1_id.eq.%s,player_2_id.eq.%s)&order=created_at.desc&limit=%d" % [user_id.uri_encode(), user_id.uri_encode(), clampi(limit, 1, 100)]
	client.api_request(&"match_history", query, HTTPClient.METHOD_GET)

