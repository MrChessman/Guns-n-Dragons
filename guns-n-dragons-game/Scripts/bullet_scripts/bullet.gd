extends Area2D
@export var speed: float = 400.0
# These are no longer exported. They are strictly controlled by the Weapon!
var damage: int = 0
var knockback_power: float = 0.0
var direction: Vector2 = Vector2.RIGHT
func _physics_process(delta: float) -> void:
	position += direction * speed * delta
func _on_timer_timeout() -> void:
	queue_free()
func _on_body_entered(body: Node2D) -> void:
	# Godot's Collision Layers already filter out who this bullet can hit.
	# If this function triggers, we ALREADY know it hit a valid target!
	
	if body.has_method("take_damage"):
		if knockback_power > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback_power)
		
		# For Player invincibility
		if "is_invincible" in body and body.is_invincible:
			return
			
		body.take_damage(damage)
		
	# Destroy the bullet regardless of what valid thing it hit (enemy, player, or tree)
	queue_free()
