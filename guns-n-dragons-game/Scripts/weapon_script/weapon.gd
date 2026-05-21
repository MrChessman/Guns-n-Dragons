extends Node2D

class_name Weapon

signal ammo_changed(current: int, reserve: int, max: int, is_inf: bool)
signal reload_started
signal reload_finished

@export var stats: WeaponStats

# State
var current_ammo: int = 0
var reserve_ammo: int = 0  # LOCAL tracking (not from stats)
var can_shoot: bool = true
var is_reloading: bool = false
var consecutive_shots: int = 0
var current_spread: float = 0.0

# References
@onready var area: Node = get_node_or_null("Area2D")
@onready var inspect_ui: Node = get_node_or_null("InspectUI")
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
var is_player_near: bool = false
var player_ref: Node2D = null

# Modular system references
var equip_system: WeaponEquipSystem = null

# Timers
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var recoil_reset_timer: Timer = $RecoilResetTimer

func _ready() -> void:
	if get_parent() != null and get_parent().name != "WeaponHolder":
		Global.mark_weapon_dropped(stats.weapon_id)
	
	# Initialize ammo from stats
	current_ammo = stats.mag_size
	reserve_ammo = stats.reserve_ammo
	
	# Store weapon ID as metadata for equip_system to identify
	set_meta("weapon_id", stats.weapon_id)
	
	# Connect timers
	fire_rate_timer.timeout.connect(_on_fire_rate_timeout)
	reload_timer.timeout.connect(_on_reload_timeout)
	recoil_reset_timer.timeout.connect(_on_recoil_reset_timeout)
	
	# Turn on pick-up detection if the gun has the Area2D and InspectUI attached
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

# Called by weapon_equip_system to set a reference
func set_equip_system(system: WeaponEquipSystem) -> void:
	equip_system = system

func shoot(target_pos: Vector2 = Vector2.ZERO) -> void:
	# Check equip cooldown
	if equip_system != null and not equip_system.can_fire():
		return
	
	if not can_shoot or is_reloading:
		return
	
	if current_ammo <= 0 and not stats.infinite_ammo:
		reload()
		return
	
	# Notify equip system that firing started
	if equip_system != null:
		equip_system.on_weapon_fire_start()
	
	can_shoot = false
	if not stats.infinite_ammo:
		current_ammo -= 1
		ammo_changed.emit(current_ammo, reserve_ammo, stats.max_ammo, stats.infinite_ammo)
	
	var flash = get_node_or_null("Muzzle/Flash")
	if flash:
		flash.visible = true
		flash.stop() # Reset the animation if we shoot really fast
		flash.play("default")
		# Tell the flash to hide itself automatically as soon as the animation is done
		if not flash.animation_finished.is_connected(flash.hide):
			flash.animation_finished.connect(flash.hide)
	var spread_angle_rad = 0.0
	
	if consecutive_shots >= stats.accurate_shots:
		spread_angle_rad = deg_to_rad(randf_range(-current_spread, current_spread))
		current_spread = min(current_spread + stats.spread_per_shot, stats.max_spread)
	elif consecutive_shots == stats.accurate_shots - 1:
		current_spread += stats.spread_per_shot
	consecutive_shots += 1
	recoil_reset_timer.start(stats.recoil_reset_time)
	
	if stats.bullet_scene:
		var aim_pos: Vector2
		if target_pos != Vector2.ZERO:
			aim_pos = target_pos
		else:
			aim_pos = get_global_mouse_position()
			
		var base_aim_direction = (aim_pos - muzzle.global_position).normalized()
		var main_level = get_tree().current_scene
		
		# Loop to fire multiple pellets
		for i in range(stats.pellet_count):
			var bullet = stats.bullet_scene.instantiate()
			bullet.global_position = muzzle.global_position
			
			# Add random spread to each pellet if it's a shotgun
			var pellet_spread = spread_angle_rad
			if stats.pellet_count > 1:
				pellet_spread += deg_to_rad(randf_range(-stats.max_spread, stats.max_spread))
				
			var final_aim_direction = base_aim_direction.rotated(pellet_spread)
			
			bullet.direction = final_aim_direction
			bullet.global_rotation = final_aim_direction.angle()
			bullet.damage = stats.damage
			
			# NEW: Tell the bullet hodw much knockback it carries!
			if "knockback_power" in stats:
				bullet.knockback_power = stats.knockback_power
			
			main_level.add_child(bullet)
			
		# NEW: Apply recoil knockback to the shooter
		if "knockback_power" in stats and stats.knockback_power > 0:
			var shooter = get_parent().get_parent() # Gets the Player or Enemy wielding the gun
			if shooter.has_method("apply_knockback"):
				var recoil_direction = -base_aim_direction # Push backwards from the aim
				shooter.apply_knockback(recoil_direction * stats.knockback_power)
	
	fire_rate_timer.start(stats.fire_rate)

func reload() -> void:
	if is_reloading or current_ammo == stats.mag_size or (reserve_ammo <= 0 and not stats.infinite_ammo):
		return
	
	# Only allow reload if weapon is currently equipped (for active reload requirement)
	if equip_system != null and equip_system.get_current_weapon() != self:
		return
	
	is_reloading = true
	reload_started.emit()
	reload_timer.start(stats.reload_time)
	
	# Notify equip system that reload started
	if equip_system != null:
		equip_system.on_weapon_reload_start()

func _on_fire_rate_timeout() -> void:
	can_shoot = true
	# Notify equip system that firing ended
	if equip_system != null:
		equip_system.on_weapon_fire_end()

func _on_reload_timeout() -> void:
	var needed_ammo = stats.mag_size - current_ammo
	
	if stats.infinite_ammo:
		current_ammo = stats.mag_size
	else:
		var ammo_to_add = min(needed_ammo, reserve_ammo)
		current_ammo += ammo_to_add
		reserve_ammo -= ammo_to_add
	
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, reserve_ammo, stats.max_ammo, stats.infinite_ammo)
	
	# Notify equip system that reload finished
	if equip_system != null:
		equip_system.on_weapon_reload_end()

func _on_recoil_reset_timeout() -> void:
	consecutive_shots = 0
	current_spread = 0.0

func _on_body_entered(body: Node2D) -> void:
	if get_parent() != null and get_parent().name != "WeaponHolder" and body.name == "Player":
		is_player_near = true
		player_ref = body
		if inspect_ui != null:
			inspect_ui.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		is_player_near = false
		player_ref = null
		if inspect_ui != null:
			inspect_ui.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_near and event.is_action_pressed("grab") and player_ref != null:
		if get_parent().name != "WeaponHolder":
			is_player_near = false
			if inspect_ui != null:
				inspect_ui.visible = false
			Global.unlock_weapon(stats.weapon_id)
			Global.mark_weapon_picked_up(stats.weapon_id)
			queue_free()

# Called by weapon_equip_system to get current ammo state for persistence
func get_ammo_state() -> Dictionary:
	return {
		"current_mag": current_ammo,
		"reserve": reserve_ammo
	}

# Called by weapon_equip_system to restore ammo state from persistence
func set_ammo_state(mag: int, reserve: int) -> void:
	current_ammo = mag
	reserve_ammo = reserve
	ammo_changed.emit(current_ammo, reserve_ammo, stats.max_ammo, stats.infinite_ammo)

# Called by weapon_equip_system when switching away — cancel any active reload
func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer.stop()
