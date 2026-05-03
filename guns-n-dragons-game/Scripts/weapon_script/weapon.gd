extends Node2D

class_name Weapon

#Weapon Stats
@export_category("Weapon Stats")
@export var bullet_scene: PackedScene
@export var damage: int = 1
@export var fire_rate: float = 0.5
@export var mag_size: int = 6
@export var max_ammo: int = 30
@export var infinite_ammo: bool = true
@export var reload_time: float = 1.5

#Recoil
@export_category("Recoil Stats")
@export var accurate_shots: int = 2 
@export var spread_per_shot: float = 5.0
@export var max_spread: float = 15.0
@export var recoil_reset_time: float = 0.4

#State
var current_ammo: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var consecutive_shots: int = 0
var current_spread: float = 0.0

#References
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

#Timers
var fire_rate_timer: Timer
var reload_timer: Timer
var recoil_reset_timer: Timer

func _ready() -> void:
	current_ammo = mag_size
	
	fire_rate_timer = Timer.new()
	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(_on_fire_rate_timeout)
	add_child(fire_rate_timer)
	
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_timeout)
	add_child(reload_timer)
	
	recoil_reset_timer = Timer.new()
	recoil_reset_timer.one_shot = true
	recoil_reset_timer.timeout.connect(_on_recoil_reset_timeout)
	add_child(recoil_reset_timer)

func shoot(target_pos: Vector2 = Vector2.ZERO) -> void:
	if not can_shoot or is_reloading:
		return
	
	if current_ammo <= 0 and not infinite_ammo:
		reload()
		return
	
	can_shoot = false
	if not infinite_ammo:
		current_ammo -= 1
	
	animated_sprite_2d.speed_scale = 1.0 / fire_rate
	animated_sprite_2d.play("shoot")
	
	var spread_angle_rad = 0.0
	
	if consecutive_shots >= accurate_shots:
		spread_angle_rad = deg_to_rad(randf_range(-current_spread, current_spread))
		current_spread = min(current_spread + spread_per_shot, max_spread)
	elif consecutive_shots == accurate_shots - 1:
		current_spread += spread_per_shot
	consecutive_shots += 1
	recoil_reset_timer.start(recoil_reset_time)
	
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
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
		bullet.damage = damage
		get_tree().root.add_child(bullet)
	
	fire_rate_timer.start(fire_rate)

func reload() -> void:
	if is_reloading or current_ammo == mag_size or (max_ammo <= 0 and not infinite_ammo):
		return
	
	is_reloading = true
	
	if animated_sprite_2d.sprite_frames.has_animation("reload"):
		animated_sprite_2d.speed_scale = 1.0 / reload_time
		animated_sprite_2d.play("reload")
	
	reload_timer.start(reload_time)

func _on_fire_rate_timeout() -> void:
	can_shoot = true

func _on_reload_timeout() -> void:
	var needed_ammo = mag_size - current_ammo
	
	if infinite_ammo:
		current_ammo = mag_size
	else:
		var ammo_to_add = min(needed_ammo, max_ammo)
		current_ammo += ammo_to_add
		max_ammo -= ammo_to_add
	
	is_reloading = false
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.play("idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite_2d.animation == "shoot" and not is_reloading:
		animated_sprite_2d.speed_scale = 1.0
		animated_sprite_2d.play("idle")

func _on_recoil_reset_timeout() -> void:
	consecutive_shots = 0
	current_spread = 0.0
