extends CharacterBody2D

@export var speed: float = 200.0
@export var min_aim_distance: float = 40.0
@export var max_health: int = 5
var current_health: int
@export var dodge_speed: float = 600.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.8
@export var invincibility_duration: float = 0.40
var is_dodging: bool = false
var can_dodge: bool = true
var dodge_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false
@onready var leon: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_holder: Marker2D = $WeaponHolder

var current_weapon: Weapon = null
var unlocked_weapons: Array[Weapon] = []

func _ready() -> void:
	Global.weapon_unlocked_signal.connect(_on_weapon_unlocked)
	current_health = max_health
	if weapon_holder.get_child_count() > 0:
		current_weapon = weapon_holder.get_child(0) as Weapon
		if current_weapon != null:
			unlocked_weapons.append(current_weapon)

func _physics_process(delta: float) -> void:
	handle_dodge()
	if is_dodging:
		velocity = dodge_direction * dodge_speed
	else:
		var input_dir := Input.get_vector("move_left","move_right","move_up","move_down")
		velocity = input_dir * speed
		
	move_and_slide()
	
	if not is_dodging:
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

func switch_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		# Hide all weapons
		for w in unlocked_weapons:
			w.visible = false
			
		# Show the newly selected one
		current_weapon = unlocked_weapons[index]
		current_weapon.visible = true

func add_weapon(new_weapon_node: Node) -> void:
	# 1. Grab the file path so we know EXACTLY what weapon to spawn a clean copy of
	var weapon_file_path = new_weapon_node.scene_file_path
	var raw_weapon_name = new_weapon_node.name
	
	# 2. Check if we already have it
	for w in unlocked_weapons:
		if w.scene_file_path == weapon_file_path:
			print("We already have a ", raw_weapon_name, " - Destroying duplicate!")
			# (Later we will add ammo to our existing gun here!)
			new_weapon_node.queue_free()
			return 
			
	# 3. Create a fresh, clean Player version of the weapon
	var clean_weapon_scene = load(weapon_file_path) as PackedScene
	var clean_weapon = clean_weapon_scene.instantiate() as Weapon
	
	# 4. Ensure it always uses the Player's bullet and ammo rules
	clean_weapon.bullet_scene = load("res://Scenes/bullets/bullet.tscn")
	clean_weapon.infinite_ammo = false
	
	# 5. Add our clean weapon to Leon, and destroy the dirty enemy one
	weapon_holder.add_child(clean_weapon)
	clean_weapon.position = Vector2.ZERO
	clean_weapon.rotation = 0
	new_weapon_node.queue_free()
	
	# 6. Add it to our inventory list and switch to it!
	unlocked_weapons.append(clean_weapon)
	switch_weapon(unlocked_weapons.size() - 1)

func _on_weapon_unlocked(weapon_id: String) -> void:
	# Ask Global for the path directly
	var scene_path: String = Global.get_weapon_scene_path(weapon_id)
		
	# If we found a valid path, spawn the gun into our hands!
	if scene_path != "":
		var weapon_scene = load(scene_path) as PackedScene
		var clean_weapon = weapon_scene.instantiate() as Weapon
		clean_weapon.rotation = 0
		weapon_holder.add_child(clean_weapon)
		
		# Add to our local inventory list and automatically switch to it
		unlocked_weapons.append(clean_weapon)
		switch_weapon(unlocked_weapons.size() - 1)

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	current_health -= amount
	print("Leon took damage! Health remaining: ", current_health)
	leon.modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.1).timeout
	leon.modulate = Color(1, 1, 1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Leon has died! Restarting level...")
	# For testing purposes, we simply restart the scene when you die
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
			
		# --- NEW: Independent Invincibility Timer ---
		# This turns off I-frames after the custom duration, even if we are still rolling!
		get_tree().create_timer(invincibility_duration).timeout.connect(func(): is_invincible = false)
		
		# Wait for the physical rolling movement to finish
		await get_tree().create_timer(dodge_duration).timeout
		is_dodging = false
		
		# Wait for the cooldown before allowing another roll
		await get_tree().create_timer(dodge_cooldown).timeout
		can_dodge = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_weapon(0) # Slot 1
		elif event.keycode == KEY_2:
			switch_weapon(1) # Slot 2
		elif event.keycode == KEY_3:
			switch_weapon(2) # Slot 3
		elif event.keycode == KEY_4:
			switch_weapon(3) # Slot 4
