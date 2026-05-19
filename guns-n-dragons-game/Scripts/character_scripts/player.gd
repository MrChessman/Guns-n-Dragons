extends CharacterBody2D

@export var speed: float = 200.0
@export var min_aim_distance: float = 40.0
@export var max_health: int = 5

@export_category("Camera Settings")
@export var default_zoom: Vector2 = Vector2(5.0, 5.0)
@export var sniper_zoom: Vector2 = Vector2(3.5, 3.5)
@export var zoom_speed: float = 0.4

@onready var camera: Camera2D = $Camera2D
var zoom_tween: Tween

var current_health: int
@export var dodge_speed: float = 600.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.8
@export var invincibility_duration: float = 0.40
var is_dodging: bool = false
var can_dodge: bool = true
var dodge_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false
var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
@onready var leon: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_holder: Marker2D = $WeaponHolder
@onready var reload_icon: Sprite2D = $ReloadIcon
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D



var current_weapon: Weapon = null
var unlocked_weapons: Array[Weapon] = []
var equip_system: WeaponEquipSystem = null

signal health_changed(current, max)
signal weapon_switched(new_weapon: Weapon)

func _ready() -> void:
	# Initialize equip system
	equip_system = WeaponEquipSystem.new()
	add_child(equip_system)
	equip_system.weapon_equipped.connect(_on_weapon_equipped)
	equip_system.equip_finished.connect(_on_equip_finished)
	
	Global.weapon_unlocked_signal.connect(_on_weapon_unlocked)
	current_health = max_health
	health_changed.emit(current_health, max_health)
	if weapon_holder.get_child_count() > 0:
		var initial_weapon: Weapon = weapon_holder.get_child(0) as Weapon
		if initial_weapon != null:
			unlocked_weapons.append(initial_weapon)
			# Link weapon to equip system
			initial_weapon.set_equip_system(equip_system)
			# Equip the starting weapon through equip_system (applies initial zoom + state)
			await get_tree().process_frame
			equip_system.request_equip(initial_weapon, initial_weapon.stats.weapon_id, initial_weapon.stats)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	handle_dodge()
	if is_dodging:
		velocity = dodge_direction * dodge_speed
	else:
		var input_dir := Input.get_vector("move_left","move_right","move_up","move_down")
		velocity = input_dir * speed
		
	# Apply knockback force and decay it smoothly
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		
	move_and_slide()
	
	if not is_dodging:
		var mouse_pos := get_global_mouse_position()
		var distance_to_mouse = global_position.distance_to(mouse_pos)

		update_facing_direction(mouse_pos)
		update_animations()

		if current_weapon != null:
			aim_weapon(mouse_pos)
			
			if current_weapon.is_reloading:
				reload_icon.visible = true
			else:
				reload_icon.visible = false

			if distance_to_mouse > min_aim_distance:
				if Input.is_action_pressed("shoot"):
					current_weapon.shoot()
			if Input.is_action_just_pressed("reload"):
				current_weapon.reload()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force

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

func switch_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		var new_weapon: Weapon = unlocked_weapons[index]
		# Request equip through equip_system
		equip_system.request_equip(new_weapon, new_weapon.stats.weapon_id, new_weapon.stats)

func add_weapon(new_weapon_node: Node) -> void:
	var weapon_file_path = new_weapon_node.scene_file_path
	var raw_weapon_name = new_weapon_node.name

	for w in unlocked_weapons:
		if w.scene_file_path == weapon_file_path:
			print("We already have a ", raw_weapon_name, " - Destroying duplicate!")
			new_weapon_node.queue_free()
			return 
			
	var clean_weapon_scene = load(weapon_file_path) as PackedScene
	var clean_weapon = clean_weapon_scene.instantiate() as Weapon
	clean_weapon.bullet_scene = load("res://Scenes/bullets/bullet.tscn")
	clean_weapon.infinite_ammo = false
	weapon_holder.add_child(clean_weapon)
	clean_weapon.position = Vector2.ZERO
	clean_weapon.rotation = 0
	new_weapon_node.queue_free()
	unlocked_weapons.append(clean_weapon)
	switch_weapon(unlocked_weapons.size() - 1)

func _on_weapon_equipped(weapon: Node, weapon_id: String) -> void:
	# Called when a weapon is equipped
	current_weapon = weapon as Weapon
	for w in unlocked_weapons:
		w.visible = false
	current_weapon.visible = true
	weapon_switched.emit(current_weapon)
	
	# Apply camera zoom based on weapon
	if weapon_id == "sniper":
		apply_camera_zoom(sniper_zoom)
	else:
		apply_camera_zoom(default_zoom)

func _on_equip_finished(weapon_id: String) -> void:
	# Called when equip cooldown finishes
	pass  # Equip is complete, weapon can now fire

func _on_weapon_unlocked(weapon_id: String) -> void:
	var scene_path: String = Global.get_weapon_scene_path(weapon_id)
		
	if scene_path != "":
		var weapon_scene = load(scene_path) as PackedScene
		var clean_weapon = weapon_scene.instantiate() as Weapon
		clean_weapon.rotation = 0
		weapon_holder.add_child(clean_weapon)
		unlocked_weapons.append(clean_weapon)
		# Link new weapon to equip system
		if equip_system != null:
			clean_weapon.set_equip_system(equip_system)
		switch_weapon(unlocked_weapons.size() - 1)

func take_damage(amount: int) -> void:
	if is_dead or is_invincible:
		return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	print("Leon took damage! Health remaining: ", current_health)
	leon.modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.1).timeout
	leon.modulate = Color(1, 1, 1)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead: return
	is_dead = true
	collision_shape_2d.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	leon.play("dead")
	if current_weapon != null:
		current_weapon.visible = false
		if current_weapon.is_reloading:
			reload_icon.visible = false
	await get_tree().create_timer(2.0).timeout
	
	# Then restart the scene
	get_tree().reload_current_scene()
func handle_dodge() -> void:
	if Input.is_action_just_pressed("dodge") and can_dodge and not is_dodging:
		is_dodging = true
		can_dodge = false
		is_invincible = true
		
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			dodge_direction = input_dir.normalized()
		else:
			dodge_direction = (get_global_mouse_position() - global_position).normalized()
			
		leon.play("dodge")
		get_tree().create_timer(invincibility_duration).timeout.connect(func(): is_invincible = false)
		await get_tree().create_timer(dodge_duration).timeout
		is_dodging = false

		await get_tree().create_timer(dodge_cooldown).timeout
		can_dodge = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_weapon(0)
		elif event.keycode == KEY_2:
			switch_weapon(1)
		elif event.keycode == KEY_3:
			switch_weapon(2)
		elif event.keycode == KEY_4:
			switch_weapon(3)

func apply_camera_zoom(target_zoom: Vector2) -> void:
	# If a zoom is currently happening, stop it so we can start the new one smoothly
	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()
		
	# Create a new tween (smooth transition) for the camera
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera, "zoom", target_zoom, zoom_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
