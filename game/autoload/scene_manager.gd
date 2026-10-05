extends Node

const MAIN_MENU := "res://ui/menus/main_menu.tscn"
const CHARACTER_SELECT := "res://ui/menus/character_select.tscn"
const STAGE_SELECT := "res://ui/menus/stage_select.tscn"
const SETTINGS := "res://ui/menus/settings.tscn"
const CONTROLS := "res://ui/menus/controls.tscn"
const CAREER := "res://ui/online/career_screen.tscn"
const MATCHMAKING := "res://ui/online/matchmaking_screen.tscn"
const LOBBY := "res://ui/online/lobby_screen.tscn"
const FIGHT := "res://match/fight_scene.tscn"

func change_scene(path: String) -> Error:
	return get_tree().change_scene_to_file(path)

func reload_current_scene() -> Error:
	return get_tree().reload_current_scene()

func go_to_main_menu() -> Error:
	GameManager.clear_online_match()
	return change_scene(MAIN_MENU)

func start_fight() -> Error:
	return change_scene(FIGHT)

