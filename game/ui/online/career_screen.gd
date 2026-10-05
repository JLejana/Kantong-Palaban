extends Control

@onready var status: Label = $Layout/Status
@onready var account_label: Label = $Layout/Columns/Profile/Account
@onready var display_name: LineEdit = $Layout/Columns/Profile/DisplayName
@onready var profile_stats: RichTextLabel = $Layout/Columns/Profile/Stats
@onready var leaderboard_list: RichTextLabel = $Layout/Columns/Leaderboard/List
@onready var history_list: RichTextLabel = $Layout/Columns/History/List
@onready var save_button: Button = $Layout/Columns/Profile/Save

var client: SupabaseClient
var profile_service: ProfileService
var leaderboard_service: LeaderboardService
var history_service: MatchHistoryService

func _ready() -> void:
	client = SupabaseClient.new()
	client.access_token = NetworkManager.access_token
	add_child(client)
	client.request_completed.connect(_on_request_completed)
	profile_service = ProfileService.new()
	profile_service.client = client
	add_child(profile_service)
	leaderboard_service = LeaderboardService.new()
	leaderboard_service.client = client
	add_child(leaderboard_service)
	history_service = MatchHistoryService.new()
	history_service.client = client
	add_child(history_service)
	$Layout/Actions/Refresh.pressed.connect(_refresh)
	$Layout/Actions/SignIn.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.MATCHMAKING))
	$Layout/Actions/Back.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	save_button.pressed.connect(_save_profile)
	_refresh()

func _refresh() -> void:
	if not client.is_configured():
		_show_offline("Supabase is not configured. Add the public URL and anon key to view online career data.")
		return
	if NetworkManager.user_id.is_empty() or NetworkManager.access_token.is_empty():
		_show_offline("You are playing as a guest. Sign in through Online to load your profile and match history.")
		leaderboard_service.fetch_top(20)
		return
	status.text = "Refreshing career dataâ€¦"
	account_label.text = "Account %sâ€¦" % NetworkManager.user_id.left(8)
	display_name.editable = true
	save_button.disabled = false
	profile_service.get_my_profile(NetworkManager.user_id)
	leaderboard_service.fetch_top(20)
	history_service.fetch_for_player(NetworkManager.user_id, 20)

func _show_offline(message: String) -> void:
	status.text = message
	account_label.text = "Guest fighter"
	display_name.text = ""
	display_name.editable = false
	save_button.disabled = true
	profile_stats.text = "Offline matches remain fully available."
	leaderboard_list.text = "Configure Supabase to load rankings."
	history_list.text = "Sign in to load match history."

func _save_profile() -> void:
	var value := display_name.text.strip_edges()
	if value.length() < 1 or value.length() > 40:
		status.text = "Display name must be between 1 and 40 characters."
		return
	status.text = "Saving profileâ€¦"
	profile_service.update_my_profile(NetworkManager.user_id, {"display_name": value})

func _on_request_completed(context: StringName, status_code: int, body: Variant) -> void:
	if status_code < 200 or status_code >= 300:
		var message := "Request failed (%d)" % status_code
		if body is Dictionary:
			message = str((body as Dictionary).get("message", (body as Dictionary).get("error", message)))
		status.text = message
		return
	match context:
		&"profile":
			_render_profile(body)
		&"profile_update":
			status.text = "Profile saved."
			profile_service.get_my_profile(NetworkManager.user_id)
		&"leaderboard":
			_render_leaderboard(body)
		&"match_history":
			_render_history(body)

func _render_profile(body: Variant) -> void:
	var rows: Array = body as Array if body is Array else []
	if rows.is_empty():
		status.text = "No profile was returned for this account."
		return
	var profile := rows[0] as Dictionary
	display_name.text = str(profile.get("display_name", "Fighter"))
	account_label.text = "@%s" % str(profile.get("username", "fighter"))
	profile_stats.text = "[b]LEVEL %d[/b]\n%d XP\n%d COINS" % [int(profile.get("level", 1)), int(profile.get("xp", 0)), int(profile.get("coins", 0))]
	status.text = "Career data loaded."

func _render_leaderboard(body: Variant) -> void:
	var rows: Array = body as Array if body is Array else []
	if rows.is_empty():
		leaderboard_list.text = "No ranked players yet."
		return
	var lines: Array[String] = []
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var linked_profile: Variant = row.get("profiles", {})
		var profile: Dictionary = linked_profile as Dictionary if linked_profile is Dictionary else {}
		var name := str(profile.get("display_name", profile.get("username", str(row.get("user_id", "Fighter")).left(8))))
		lines.append("%2d. %-18s %4d  %s" % [index + 1, name.left(18), int(row.get("rating", 1000)), str(row.get("rank_tier", "rookie")).to_upper()])
	leaderboard_list.text = "\n".join(lines)

func _render_history(body: Variant) -> void:
	var rows: Array = body as Array if body is Array else []
	if rows.is_empty():
		history_list.text = "No online matches recorded yet."
		return
	var lines: Array[String] = []
	for row_value in rows:
		var row := row_value as Dictionary
		var won := str(row.get("winner_id", "")) == NetworkManager.user_id
		var result := "WIN" if won else "LOSS"
		var score := "%d-%d" % [int(row.get("player_1_rounds", 0)), int(row.get("player_2_rounds", 0))]
		var date := str(row.get("created_at", "")).left(10)
		lines.append("%s  %s  %s  %ds" % [result, score, date, int(row.get("duration_seconds", 0))])
	history_list.text = "\n".join(lines)
