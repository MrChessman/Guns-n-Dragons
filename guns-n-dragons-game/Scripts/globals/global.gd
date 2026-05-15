extends Node
signal weapon_unlocked_signal(weapon_id: String)

var unlocked_weapons: Array[String] = []
var weapon_database: Dictionary = {
	"ak_47": "res://Scenes/weapons/ak_47.tscn",
	"neo_frontier": "res://Scenes/weapons/pistol.tscn" 
}

var spawned_weapons: Array[String] = []
var active_weapon: String = ""

func unlock_weapon(weapon_name: String) -> void:
	if not has_weapon(weapon_name):
		unlocked_weapons.append(weapon_name)
		weapon_unlocked_signal.emit(weapon_name)

func has_weapon(weapon_name: String) -> bool:
	return weapon_name in unlocked_weapons

func get_weapon_scene_path(weapon_id: String) -> String:
	if weapon_database.has(weapon_id):
		return weapon_database[weapon_id]
	return ""

func mark_weapon_dropped(weapon_id: String) -> void:
	if not weapon_id in spawned_weapons:
		spawned_weapons.append(weapon_id)

func mark_weapon_picked_up(weapon_id: String) -> void:
	spawned_weapons.erase(weapon_id)

func is_weapon_on_ground(weapon_id: String) -> bool:
	return weapon_id in spawned_weapons
