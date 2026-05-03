extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
@export var is_enemy_bullet: bool = false

var direction: Vector2 = Vector2.RIGHT

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_timer_timeout() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	# 1. Prevent enemy bullets from hurting other enemies
	if is_enemy_bullet and body.name != "Player" and body.has_method("take_damage"):
		return 
		
	# 2. Prevent player bullets from hurting the player
	if not is_enemy_bullet and body.name == "Player":
		return 
		
	# NEW: 3. If it's an enemy bullet hitting the player, check for I-frames!
	if is_enemy_bullet and body.name == "Player":
		# We check if the player has the 'is_invincible' property and if it is true
		if "is_invincible" in body and body.is_invincible:
			return # Ignore the collision! Let the bullet pass right through!
		
	# 4. If it's a valid target, deal damage!
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
	# 5. Destroy the bullet on impact (hits target or a wall)
	queue_free()
