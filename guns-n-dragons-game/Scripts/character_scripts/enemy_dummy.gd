extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 60.0
@export var wander_speed: float = 30.0 # Walks slower while guarding
@export var preferred_distance: float = 100.0

enum State {IDLE, WANDERING, STRAFING, SHOOTING, SEARCHING}
var current_state: State = State.IDLE

var current_health: int
var player: Node2D = null
var strafe_direction: Vector2 = Vector2.ZERO
var last_known_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var strafe_timer: Timer = $StrafeTimer
@onready var attack_delay_timer: Timer = $AttackDelayTimer

# We create these dynamically so you don't have to clutter your editor!
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
	
	# Start the guard duty loop!
	wander_timer.start(randf_range(1.0, 3.0))

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			update_animations(false, global_position + Vector2.DOWN)
			update_weapon_aiming(global_position + Vector2.DOWN) # Point gun down while resting
			
		State.WANDERING:
			wander_movement()
			update_animations(true, wander_target)
			update_weapon_aiming(wander_target) # Point gun where it's walking
			
		State.STRAFING:
			strafe_movement()
			last_known_position = player.global_position # Constantly update memory
			update_animations(true, player.global_position)
			update_weapon_aiming(player.global_position) # Aim directly at the player!
			
		State.SHOOTING:
			velocity = Vector2.ZERO 
			update_animations(false, player.global_position)
			update_weapon_aiming(player.global_position) # Aim directly at the player!
			
		State.SEARCHING:
			search_movement()
			update_animations(true, last_known_position)
			update_weapon_aiming(last_known_position) # Aim at the last place it saw you!
			
	move_and_slide()

func wander_movement() -> void:
	var dist = global_position.distance_to(wander_target)
	if dist > 5.0:
		velocity = global_position.direction_to(wander_target) * wander_speed
	else:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		wander_timer.start(randf_range(1.5, 3.0))

func search_movement() -> void:
	var dist = global_position.distance_to(last_known_position)
	if dist > 10.0:
		velocity = global_position.direction_to(last_known_position) * move_speed
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
	
	if abs(dir_to_target.x) > abs(dir_to_target.y):
		animated_sprite.flip_h = dir_to_target.x < 0
		animated_sprite.play("walk_right" if is_moving else "idle_right")
	else:
		animated_sprite.flip_h = false
		if dir_to_target.y > 0:
			animated_sprite.play("walk_down" if is_moving else "idle_down")
		else:
			animated_sprite.play("walk_up" if is_moving else "idle_up")

func update_weapon_aiming(target_pos: Vector2) -> void:
	var weapon_holder = $WeaponHolder
	if weapon_holder.get_child_count() > 0:
		var weapon = weapon_holder.get_child(0)
		
		weapon_holder.look_at(target_pos)
		if weapon.has_node("AnimatedSprite2D"):
			var weapon_sprite = weapon.get_node("AnimatedSprite2D")
			weapon_sprite.flip_v = target_pos.x < global_position.x

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("Player Detected! Getting ready to fight!")
		player = body
		current_state = State.STRAFING
		lose_interest_timer.stop()
		
		if attack_delay_timer.is_stopped():
			strafe_timer.start(0.5)
			attack_delay_timer.start(randf_range(2.0, 3.0))

func _on_detection_area_body_exited(body: Node2D) -> void:

		print("Lost sight! Checking last known position...")
		player = null
		current_state = State.SEARCHING
		lose_interest_timer.start(2.0)

func _on_lose_interest_timeout() -> void:
	if current_state == State.SEARCHING:
		print("Giving up. Going back to guard duty.")
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
		print("Enemy stopping to shoot a burst!")
		
		# --- BURST LOGIC ---
		var weapon_holder = $WeaponHolder
		if weapon_holder.get_child_count() > 0:
			var weapon = weapon_holder.get_child(0) as Weapon
			
			# Fire a 5-shot burst
			for i in range(5):
				if player == null or current_health <= 0:
					break # Stop shooting immediately if the player leaves or enemy dies
				
				# Pass the player's position so the weapon knows where to aim!
				weapon.shoot(player.global_position)
				
				# Wait exactly the length of the weapon's fire_rate before firing the next shot
				await get_tree().create_timer(weapon.fire_rate).timeout
		
		# Wait a small moment after the burst finishes before strafing again
		await get_tree().create_timer(1.0).timeout
		
		if current_state == State.SHOOTING: # Make sure we didn't die while shooting
			current_state = State.STRAFING
			attack_delay_timer.start(randf_range(2.0, 3.0))

func take_damage(amount: int) -> void:
	current_health -= amount
	animated_sprite.modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color(1, 1, 1)
	
	if current_health <= 0:
		queue_free()
