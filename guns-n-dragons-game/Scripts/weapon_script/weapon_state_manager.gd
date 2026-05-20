extends Node
class_name WeaponStateManager
# Tracks ammo state per weapon ID
var weapon_ammo_state: Dictionary = {}  # weapon_id -> {"current_mag": int, "reserve": int}
func _init() -> void:
	pass
# Called when a weapon is unequipped — save its current ammo
func save_weapon_state(weapon_id: String, current_mag: int, reserve_ammo: int) -> void:
	weapon_ammo_state[weapon_id] = {
		"current_mag": current_mag,
		"reserve": reserve_ammo
	}
# Called when a weapon is equipped — restore its previous ammo
func restore_weapon_state(weapon_id: String, weapon_stats: WeaponStats) -> Dictionary:
	# If we have saved state, return it
	if weapon_id in weapon_ammo_state:
		return weapon_ammo_state[weapon_id]
	
	# First time equipping this weapon — use defaults from WeaponStats
	var default_state: Dictionary = {
		"current_mag": weapon_stats.mag_size,
		"reserve": weapon_stats.reserve_ammo
	}
	weapon_ammo_state[weapon_id] = default_state
	return default_state
# Check if a weapon needs reload
func is_magazine_empty(weapon_id: String) -> bool:
	if weapon_id in weapon_ammo_state:
		return weapon_ammo_state[weapon_id]["current_mag"] == 0
	return false
# Debug: print all weapon states
func debug_print_all_states() -> void:
	print("\n=== WEAPON AMMO STATES ===")
	for weapon_id: String in weapon_ammo_state:
		var state: Dictionary = weapon_ammo_state[weapon_id]
		print("  %s: mag=%d, reserve=%d" % [weapon_id, state["current_mag"], state["reserve"]])
	print("=========================\n")
