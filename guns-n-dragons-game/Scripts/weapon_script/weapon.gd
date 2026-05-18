extends Node2D

class_name Weapon
signal ammo_changed(current: int, reserve: int, max: int, is_inf: bool)
signal reload_started
signal reload_finished
@export var stats: WeaponStats

#State
var current_ammo: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var consecutive_shots: int = 0
var current_spread: float = 0.0
@onready var area = get_node_or_null("Area2D")
@onready var inspect_ui = get_node_or_null("InspectUI")
#References
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
var is_player_near: bool = false
var player_ref: Node2D = null

#Timers
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var recoil_reset_timer: Timer = $RecoilResetTimer

func _ready() -> void:
	if get_parent() != null and get_parent().name != "WeaponHolder":
		Global.mark_weapon_dropped(stats.weapon_id)
	current_ammo = stats.mag_size
	
	fire_rate_timer.timeout.connect(_on_fire_rate_timeout)
	reload_timer.timeout.connect(_on_reload_timeout)
	recoil_reset_timer.timeout.connect(_on_recoil_reset_timeout)
	
	 # Turn on pick-up detection if the gun has the Area2D and InspectUI attached
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		
func shoot(target_pos: Vector2 = Vector2.ZERO) -> void:
	if not can_shoot or is_reloading:
		return
	
	if current_ammo <= 0 and not stats.infinite_ammo:
		reload()
		return
	
	can_shoot = false
	if not stats.infinite_ammo:
		current_ammo -= 1
		ammo_changed.emit(current_ammo, stats.reserve_ammo, stats.max_ammo, stats.infinite_ammo)
	
	# We removed the animation lines here!
	# (Later we will add muzzle flash visibility code here)
	
	var spread_angle_rad = 0.0
	
	if consecutive_shots >= stats.accurate_shots:
		spread_angle_rad = deg_to_rad(randf_range(-current_spread, current_spread))
		current_spread = min(current_spread + stats.spread_per_shot, stats.max_spread)
	elif consecutive_shots == stats.accurate_shots - 1:
		current_spread += stats.spread_per_shot
	consecutive_shots += 1
	recoil_reset_timer.start(stats.recoil_reset_time)
	
	if stats.bullet_scene:
		var bullet = stats.bullet_scene.instantiate()
		bullet.global_position = muzzle.global_position
		
		# --- NEW TARGETING LOGIC ---
		var aim_pos: Vector2
		if target_pos != Vector2.ZERO:
			aim_pos = target_pos
		else:
			aim_pos = get_global_mouse_position()
			
		var base_aim_direction = (aim_pos - muzzle.global_position).normalized()
		var final_aim_direction = base_aim_direction.rotated(spread_angle_rad)
		
		bullet.direction = final_aim_direction
		bullet.global_rotation = final_aim_direction.angle()
		bullet.damage = stats.damage
		var main_level = get_tree().current_scene
		main_level.add_child(bullet)
	
	fire_rate_timer.start(stats.fire_rate)

func reload() -> void:
	if is_reloading or current_ammo == stats.mag_size or (stats.reserve_ammo <= 0 and not stats.infinite_ammo):
		return
	
	is_reloading = true
	reload_started.emit()
	reload_timer.start(stats.reload_time)

func _on_fire_rate_timeout() -> void:
	can_shoot = true

func _on_reload_timeout() -> void:
	var needed_ammo = stats.mag_size - current_ammo
	
	if stats.infinite_ammo:
		current_ammo = stats.mag_size
	else:
		var ammo_to_add = min(needed_ammo, stats.reserve_ammo)
		current_ammo += ammo_to_add
		stats.reserve_ammo -= ammo_to_add
	
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, stats.reserve_ammo, stats.max_ammo, stats.infinite_ammo)

func _on_recoil_reset_timeout() -> void:
	consecutive_shots = 0
	current_spread = 0.0

func _on_body_entered(body: Node2D) -> void:
	if get_parent().name != "WeaponHolder" and body.has_method("add_weapon"):
		is_player_near = true
		player_ref = body
		if inspect_ui != null:
			inspect_ui.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("add_weapon"):
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
