extends CharacterBody2D

@export var speed: float = 200.0
@export var min_aim_distance: float = 40.0
@export var max_health: int = 5
var current_health: int
@onready var leon: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_holder: Marker2D = $WeaponHolder

var current_weapon: Weapon = null

func _ready() -> void:
	current_health = max_health
	if weapon_holder.get_child_count() > 0:
		current_weapon = weapon_holder.get_child(0) as Weapon

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left","move_right","move_up","move_down")
	velocity = input_dir * speed
	move_and_slide()
	
	var mouse_pos := get_global_mouse_position()
	var distance_to_mouse = global_position.distance_to(mouse_pos)
	
	update_facing_direction(mouse_pos)
	update_animations()
	
	if current_weapon != null:
		aim_weapon(mouse_pos)
		if distance_to_mouse > min_aim_distance:
			if Input.is_action_pressed("shoot"):
				current_weapon.shoot()
		if Input.is_action_just_pressed("reload"):
			current_weapon.reload()

func aim_weapon(mouse_pos: Vector2) -> void:
	weapon_holder.look_at(mouse_pos)
	
	if mouse_pos.x < global_position.x:
		weapon_holder.scale.y = -1
	else:
		weapon_holder.scale.y = 1

func update_facing_direction(mouse_pos: Vector2) -> void:
	leon.flip_h = mouse_pos.x < global_position.x

func update_animations() -> void:
	if velocity.length() > 0:
		leon.play("walk")
	else:
		leon.play("idle") 

func equip_weapon(new_weapon_scene: PackedScene) -> void:
	if current_weapon != null:
		current_weapon.queue_free()
	
	var weapon_instance = new_weapon_scene.instantiate() as Weapon
	weapon_holder.add_child(weapon_instance)
	current_weapon = weapon_instance

func take_damage(amount: int) -> void:
	current_health -= amount
	print("Leon took damage! Health remaining: ", current_health)
	
	# Damage Flash (turns red for 0.1 seconds)
	leon.modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.1).timeout
	leon.modulate = Color(1, 1, 1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Leon has died! Restarting level...")
	# For testing purposes, we simply restart the scene when you die
	get_tree().reload_current_scene()
