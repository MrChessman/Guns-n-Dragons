extends CanvasLayer

@onready var ammo_count: Label = $PanelContainer/HBoxContainer/AmmoCount
@onready var reserve_ammo_count: Label = $PanelContainer/HBoxContainer/ReserveAmmocount
@onready var max_reserve_icon: TextureRect = $PanelContainer/HBoxContainer/MaxReserveIcon
@onready var current_infinity_icon: TextureRect = $PanelContainer/HBoxContainer/CurrentInfinityIcon
@onready var reserve_infinity_icon: TextureRect = $PanelContainer/HBoxContainer/ReserveInfinityIcon
@onready var health_bar: TextureProgressBar = $PortraitBox/HealthBar

func _ready() -> void:
	var player = get_tree().get_current_scene().get_node("Player")
	if player != null:
		initialize_player_health(player)

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

func initialize_player_health(player_node) -> void:
	# 1. Connect to the signal for future damage
	player_node.health_changed.connect(update_health)
	
	# 2. INSTANTLY update the bar using the player's current stats!
	update_health(player_node.current_health, player_node.max_health)

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

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
