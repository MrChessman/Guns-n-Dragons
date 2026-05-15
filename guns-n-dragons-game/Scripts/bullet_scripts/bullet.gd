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
	if is_enemy_bullet and body.name != "Player" and body.has_method("take_damage"):
		return 
	if not is_enemy_bullet and body.name == "Player":
		return 
	if is_enemy_bullet and body.name == "Player":
		if "is_invincible" in body and body.is_invincible:
			return 
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
