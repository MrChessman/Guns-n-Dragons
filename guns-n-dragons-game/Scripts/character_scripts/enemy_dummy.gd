extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 60.0
@export var wander_speed: float = 30.0 
@export var preferred_distance: float = 100.0
@export var shots_firing: int = 1

@export_category("Loot Drops")
@export var drops_weapon_id: String = "" 
@export var drops_ammo_scene: PackedScene 
@export var drops_skill_point_chance: float = 0.20
@export var drop_weapon_chance: float = 0.50
@export var drops_ammo_chance: float = 0.50

@export_category("Movement Settings")
@export var is_flying: bool = false 

@export_category("Attack Settings")
@export var attack_delay_min: float = 2.0
@export var attack_delay_max: float = 4.0

enum State {IDLE, WANDERING, STRAFING, SHOOTING, SEARCHING, DEAD}
var current_state: State = State.IDLE

var current_health: int
var player: Node2D = null
var strafe_direction: Vector2 = Vector2.ZERO
var last_known_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var locked_aim_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var last_stuck_position: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var strafe_timer: Timer = $StrafeTimer
@onready var attack_delay_timer: Timer = $AttackDelayTimer
@onready var weapon_holder: Marker2D = $WeaponHolder

var lose_interest_timer: Timer
var wander_timer: Timer

func _ready() -> void:
	current_health = max_health
	lose_interest_timer = Timer.new()
	lose_interest_timer.one_shot = true
	lose_interest_timer.timeout.connect(_on_lose_interest_timeout)
	add_child(lose_interest_timer)
	wander_timer = Timer.new()
	wander_timer.one_shot = true
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	add_child(wander_timer)
	wander_timer.start(randf_range(1.0, 3.0))
	
	if is_flying:
		# Flying enemies ignore Layer 1 (Walls) and Layer 8 (Trees)
		# We set the mask to only collide with the Player (Layer 2) 
		# and potentially a dedicated Boundary Layer if you add one later.
		collision_mask &= ~1   # Remove Layer 1 (Walls)
		collision_mask &= ~128 # Remove Layer 8 (Trees)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if current_state in [State.WANDERING, State.SEARCHING, State.STRAFING]:
		stuck_timer += delta
		if stuck_timer >= 2.0: 
			if global_position.distance_to(last_stuck_position) < 20.0:
				force_unstuck()
			last_stuck_position = global_position
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_stuck_position = global_position
		
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			update_animations(false, global_position + Vector2.DOWN)
			update_weapon_aiming(global_position + Vector2.DOWN)
			
		State.WANDERING:
			wander_movement()
			update_animations(true, wander_target)
			update_weapon_aiming(wander_target)
			
		State.STRAFING:
			strafe_movement()
			last_known_position = player.global_position
			update_animations(true, player.global_position)
			update_weapon_aiming(player.global_position)
			
		State.SHOOTING:
			velocity = Vector2.ZERO 
			update_animations(false, locked_aim_position)
			update_weapon_aiming(locked_aim_position)
			
		State.SEARCHING:
			search_movement()
			update_animations(true, last_known_position)
			update_weapon_aiming(last_known_position)
			
	# Apply knockback force and decay it smoothly
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
			
	move_and_slide()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force

func wander_movement() -> void:
	var dist = global_position.distance_to(wander_target)
	var move_dir = global_position.direction_to(wander_target)

	if dist > 5.0:
		velocity = move_dir * wander_speed
	else:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		wander_timer.start(randf_range(0.5, 1.5))

func search_movement() -> void:
	var dist = global_position.distance_to(last_known_position)
	var move_dir = global_position.direction_to(last_known_position)

	if dist > 10.0:
		velocity = move_dir * move_speed
	else:
		velocity = Vector2.ZERO

func strafe_movement() -> void:
	if player == null: return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	var dir_to_player = global_position.direction_to(player.global_position)
	var movement_dir = Vector2.ZERO
	
	if distance_to_player > preferred_distance + 20.0:
		movement_dir = dir_to_player
	elif distance_to_player < preferred_distance - 20.0:
		movement_dir = -dir_to_player
	else:
		movement_dir = strafe_direction
			
	velocity = movement_dir.normalized() * move_speed

func update_animations(is_moving: bool, look_target: Vector2) -> void:
	var dir_to_target = global_position.direction_to(look_target)
	animated_sprite.flip_h = dir_to_target.x < 0
	if is_moving:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

func update_weapon_aiming(target_pos: Vector2) -> void:
	weapon_holder.look_at(target_pos)
	
	if target_pos.x < global_position.x:
		weapon_holder.scale.y = -1
	else:
		weapon_holder.scale.y = 1

func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body.name == "Player":
		player = body
		current_state = State.STRAFING
		lose_interest_timer.stop()
		if attack_delay_timer.is_stopped():
			strafe_timer.start(0.5)
			attack_delay_timer.start(randf_range(attack_delay_min, attack_delay_max))

func _on_detection_area_body_exited(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body.name == "Player":
		player = null
		if current_state != State.SHOOTING:
			current_state = State.SEARCHING
			lose_interest_timer.start(2.0)

func _on_lose_interest_timeout() -> void:
	if current_state == State.SEARCHING:
		current_state = State.IDLE
		wander_timer.start(randf_range(1.0, 3.0))
		attack_delay_timer.stop()

func _on_wander_timer_timeout() -> void:
	if current_state == State.IDLE:
		current_state = State.WANDERING
		var random_angle = randf() * 2 * PI
		var random_dist = randf_range(30.0, 60.0)
		wander_target = global_position + Vector2(cos(random_angle), sin(random_angle)) * random_dist
	elif current_state == State.WANDERING:
		current_state = State.IDLE
		wander_timer.start(randf_range(1.5, 3.0))

func _on_strafe_timer_timeout() -> void:
	if player != null:
		var dir_to_player = global_position.direction_to(player.global_position)
		var angle = PI/2 if randf() > 0.5 else -PI/2
		strafe_direction = dir_to_player.rotated(angle)
		strafe_timer.start(randf_range(0.8, 1.5))

func _on_attack_delay_timer_timeout() -> void:
	if player != null and current_state == State.STRAFING:
		current_state = State.SHOOTING
		locked_aim_position = player.global_position
		var weapon_holder = $WeaponHolder
		if weapon_holder.get_child_count() > 0:
			var weapon = weapon_holder.get_child(0) as Weapon
			for i in range(shots_firing):
				if current_health <= 0: return 
				weapon.shoot(locked_aim_position)
				await get_tree().create_timer(weapon.stats.fire_rate + 0.05).timeout
		await get_tree().create_timer(1.0).timeout
		if current_health > 0 and current_state == State.SHOOTING:
			if player != null:
				current_state = State.STRAFING
				attack_delay_timer.start(randf_range(attack_delay_min + 1.0, attack_delay_max + 1.0))
			else:
				current_state = State.SEARCHING
				lose_interest_timer.start(2.0)

func take_damage(amount: int) -> void:
	if current_state == State.DEAD: return
	current_health -= amount
	
	if current_health <= 0:
		die()
	else:
		animated_sprite.modulate = Color(1, 0, 0)
		await get_tree().create_timer(0.1).timeout
		animated_sprite.modulate = Color(1, 1, 1)

func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	attack_delay_timer.stop()
	strafe_timer.stop()

	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("HurtBox/CollisionShape2D"):
		$HurtBox/CollisionShape2D.set_deferred("disabled", true)

	if $WeaponHolder.get_child_count() > 0:
		$WeaponHolder.get_child(0).visible = false

	animated_sprite.modulate = Color(1, 0, 0)
	var tilt_amount = 1.5
	
	if player != null:
		if player.global_position.x < global_position.x:
			tilt_amount = 1.5
		else:
			tilt_amount = -1.5
	
	var tween = create_tween()
	tween.tween_property(self, "rotation", tilt_amount, 0.2)
	await tween.finished
	
	animated_sprite.modulate = Color(0.4, 0.4, 0.4) 
	await get_tree().create_timer(0.3).timeout
	
	drop_loot()
	queue_free()

func drop_loot() -> void:
	# 1. Skill Point Logic
	if randf() <= drops_skill_point_chance:
		print("Dropped a skill point!")
		
	# Stop here if the enemy doesn't have a weapon assigned (like the Slime)
	if drops_weapon_id == "":
		return
		
	# 2. Check the current status of the weapon
	var knows_weapon = Global.has_weapon(drops_weapon_id)
	var weapon_on_ground = Global.is_weapon_on_ground(drops_weapon_id)
	
	if not knows_weapon and not weapon_on_ground:
		# RULE A: Player doesn't have it and it's not on the ground. Roll for WEAPON.
		if randf() <= drop_weapon_chance:
			var weapon_path = Global.get_weapon_scene_path(drops_weapon_id)
			if weapon_path != "":
				spawn_drop(load(weapon_path))
				Global.mark_weapon_dropped(drops_weapon_id)
	else:
		# RULE B: Player already has it OR it's already on the ground. Roll for AMMO.
		# (This also guarantees they never get ammo if they don't have the gun!)
		if drops_ammo_scene != null and randf() <= drops_ammo_chance:
			spawn_drop(drops_ammo_scene)

func spawn_drop(scene_to_spawn: PackedScene) -> void:
	if scene_to_spawn:
		var instance = scene_to_spawn.instantiate()
		# Use our new function to find a safe spot instead of dropping it directly inside walls
		instance.global_position = get_safe_drop_position(global_position)
		get_tree().current_scene.call_deferred("add_child", instance)

func get_safe_drop_position(start_pos: Vector2) -> Vector2:
	# Access Godot's physics engine
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	# Check Environment (1) + Water (64) + Props (128) + Walls (256) = 449
	params.collision_mask = 449
	
	var current_pos = start_pos
	var radius = 16.0
	var angle = 0.0
	
	# Try up to 50 times in a growing spiral
	for i in range(50):
		params.position = current_pos
		var results = space_state.intersect_point(params)
		
		# If the results array is empty, nothing is blocking this spot! It's safe!
		if results.is_empty():
			return current_pos
			
		# Otherwise, move slightly outward in a circle and check again
		angle += PI / 4.0 # Rotate 45 degrees
		radius += 4.0     # Move 4 pixels further out
		current_pos = start_pos + Vector2(cos(angle), sin(angle)) * radius
		
	# Fallback if no safe spot is found after 50 tries (very rare)
	return start_pos

func force_unstuck() -> void:
	print("Enemy got stuck! Reversing direction smoothly.")
	match current_state:
		State.WANDERING:
			wander_target = global_position + (global_position.direction_to(wander_target) * -50.0)
			wander_timer.start(randf_range(1.5, 3.0))
		State.SEARCHING:
			velocity = Vector2.ZERO
			lose_interest_timer.stop()
			_on_lose_interest_timeout()
		State.STRAFING:
			strafe_direction = -strafe_direction
