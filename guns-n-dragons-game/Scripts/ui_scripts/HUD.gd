extends CanvasLayer

@onready var ammo_count: Label = $PanelContainer/HBoxContainer/AmmoCount
@onready var reserve_ammo_count: Label = $PanelContainer/HBoxContainer/ReserveAmmocount
@onready var max_reserve_icon: TextureRect = $PanelContainer/HBoxContainer/MaxReserveIcon
@onready var current_infinity_icon: TextureRect = $PanelContainer/HBoxContainer/CurrentInfinityIcon
@onready var reserve_infinity_icon: TextureRect = $PanelContainer/HBoxContainer/ReserveInfinityIcon

func _process(_delta: float) -> void:
	# 1) Find your Player node in the current scene:
	var player = get_tree().get_current_scene().get_node("Player")
	if player == null:
		return
	# 2) Grab the active weapon (adjust this to your Player API):
	var weapon = player.current_weapon
	if weapon == null:
		return
	_update_ammo_display(
		weapon.current_ammo,
		weapon.reserve_ammo, 
		weapon.max_ammo, 
		weapon.infinite_ammo
	)
func _update_ammo_display(current: int, reserve: int, max_ammo: int, infinite: bool) -> void:
	if infinite:
		# Hide text numbers, show BOTH infinity icons
		ammo_count.visible = false
		current_infinity_icon.visible = true
		
		max_reserve_icon.visible = true 
		
		reserve_ammo_count.visible = false
		reserve_infinity_icon.visible = true
	else:
		# Show text numbers, hide BOTH infinity icons
		ammo_count.visible = true
		current_infinity_icon.visible = false
		
		max_reserve_icon.visible = true
		
		reserve_ammo_count.visible = true
		reserve_infinity_icon.visible = false
		
		# Update text
		ammo_count.text = str(current)
		reserve_ammo_count.text = "%d / %d" % [reserve, max_ammo]
