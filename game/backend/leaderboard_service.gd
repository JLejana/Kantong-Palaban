class_name LeaderboardService
extends Node

@export var client: SupabaseClient

func fetch_top(limit: int = 100) -> void:
	client.api_request(&"leaderboard", "/rest/v1/rankings?select=user_id,rating,wins,losses,rank_tier,profiles(display_name,username)&order=rating.desc&limit=%d" % clampi(limit, 1, 100), HTTPClient.METHOD_GET)

