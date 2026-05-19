extends Node
class_name WeaponEquipSystem
# References to the systems
var weapon_state_manager: WeaponStateManager
var weapon_state_machine: WeaponStateMachine
# Current weapon tracking
var current_weapon: Node = null
var current_weapon_id: String = ""
# Equip settings
@export var equip_duration: float = 0.2  # Time before new weapon can fire after equip
# Signals
signal weapon_equipped(weapon: Node, weapon_id: String)
signal weapon_unequipped(weapon: Node, weapon_id: String)
signal equip_started(weapon_id: String)
signal equip_finished(weapon_id: String)
func _init() -> void:
	weapon_state_manager = WeaponStateManager.new()
	weapon_state_machine = WeaponStateMachine.new()
func _ready() -> void:
	# Add child nodes so they process
	add_child(weapon_state_manager)
	add_child(weapon_state_machine)
	
	# Connect to state changes for debug
	weapon_state_machine.state_changed.connect(_on_state_changed)
	print("[WeaponEquipSystem] Initialized and ready")
# Request to equip a weapon
func request_equip(new_weapon: Node, weapon_id: String, weapon_stats: WeaponStats) -> bool:
	# Can't equip while already equipping
	if not weapon_state_machine.can_perform_action(WeaponStateMachine.State.EQUIPPING):
		print("[WeaponEquipSystem] Cannot equip — weapon busy in state: %s" % weapon_state_machine.get_state_name())
		return false
	
	# Save old weapon state
	if current_weapon != null and current_weapon.has_meta("weapon_id"):
		var old_weapon_id: String = current_weapon.get_meta("weapon_id")
		if current_weapon.has_method("get_ammo_state"):
			var ammo_state: Dictionary = current_weapon.get_ammo_state()
			weapon_state_manager.save_weapon_state(old_weapon_id, ammo_state["current_mag"], ammo_state["reserve"])
		
		# Cancel reload if active
		if current_weapon.has_method("cancel_reload"):
			current_weapon.cancel_reload()
		
		weapon_unequipped.emit(current_weapon, old_weapon_id)
	
	# Enter equip state
	weapon_state_machine.enter_state(WeaponStateMachine.State.EQUIPPING, equip_duration)
	equip_started.emit(weapon_id)
	
	# Switch weapon
	current_weapon = new_weapon
	current_weapon_id = weapon_id
	
	# Restore ammo state
	var restored_state: Dictionary = weapon_state_manager.restore_weapon_state(weapon_id, weapon_stats)
	if new_weapon.has_method("set_ammo_state"):
		new_weapon.set_ammo_state(restored_state["current_mag"], restored_state["reserve"])
	
	# Emit signals
	weapon_equipped.emit(new_weapon, weapon_id)
	
	# Schedule transition to IDLE after equip duration
	await get_tree().create_timer(equip_duration).timeout
	weapon_state_machine.enter_state(WeaponStateMachine.State.IDLE)
	equip_finished.emit(weapon_id)
	
	return true
# Can the current weapon fire?
func can_fire() -> bool:
	return weapon_state_machine.can_perform_action(WeaponStateMachine.State.FIRING)
# Notify that weapon started firing
func on_weapon_fire_start() -> void:
	weapon_state_machine.enter_state(WeaponStateMachine.State.FIRING)
# Notify that weapon stopped firing
func on_weapon_fire_end() -> void:
	if weapon_state_machine.current_state == WeaponStateMachine.State.FIRING:
		weapon_state_machine.enter_state(WeaponStateMachine.State.IDLE)
# Notify that weapon started reloading
func on_weapon_reload_start() -> void:
	weapon_state_machine.enter_state(WeaponStateMachine.State.RELOADING)
# Notify that weapon finished reloading
func on_weapon_reload_end() -> void:
	if weapon_state_machine.current_state == WeaponStateMachine.State.RELOADING:
		weapon_state_machine.enter_state(WeaponStateMachine.State.IDLE)
# Get current weapon reference
func get_current_weapon() -> Node:
	return current_weapon
# Get current weapon ID
func get_current_weapon_id() -> String:
	return current_weapon_id
# Debug
func _on_state_changed(new_state: WeaponStateMachine.State, old_state: WeaponStateMachine.State) -> void:
	var state_name: String = WeaponStateMachine.State.keys()[new_state]
	print("[WeaponEquipSystem] State changed: %s → %s (weapon: %s)" % [WeaponStateMachine.State.keys()[old_state], state_name, current_weapon_id])
func debug_print_status() -> void:
	print("\n=== WEAPON EQUIP SYSTEM STATUS ===")
	print("  Current Weapon: %s" % current_weapon_id)
	print("  Current State: %s" % weapon_state_machine.get_state_name())
	weapon_state_manager.debug_print_all_states()
	print("===================================\n")
