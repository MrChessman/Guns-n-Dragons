extends Area2D

@export var ammo_amount: int = 30
@export var target_weapon_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.has_method("add_weapon"):
		for w in body.unlocked_weapons:
			if w.weapon_id == target_weapon_id:
				if w.reserve_ammo < w.max_ammo:
					w.reserve_ammo = min(w.reserve_ammo + ammo_amount, w.max_ammo)
					queue_free() 
				return
