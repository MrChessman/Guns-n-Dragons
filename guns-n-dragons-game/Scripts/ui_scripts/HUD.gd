extends CanvasLayer

@onready var ammo_count: Label = $PortraitBox/HBoxContainer/AmmoCount
@onready var current_infinity_icon: TextureRect = $PortraitBox/HBoxContainer/CurrentInfinityIcon
@onready var max_reserve_icon: TextureRect = $PortraitBox/HBoxContainer/MaxReserveIcon
@onready var reserve_ammo_count: Label = $PortraitBox/HBoxContainer/ReserveAmmocount
@onready var reserve_infinity_icon: TextureRect = $PortraitBox/HBoxContainer/ReserveInfinityIcon

@onready var health_bar: TextureProgressBar = $PortraitBox/HealthBar

func _ready() -> void:
	var player = get_tree().get_current_scene().get_node("Player")
	if player != null:
		initialize_player_health(player)

func _process(_delta: float) -> void:
	var player = get_tree().get_current_scene().get_node("Player")
	if player == null:
		return
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
	player_node.health_changed.connect(update_health)
	update_health(player_node.current_health, player_node.max_health)

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

func _update_ammo_display(current: int, reserve: int, max_ammo: int, infinite: bool) -> void:
	if infinite:
		ammo_count.visible = false
		current_infinity_icon.visible = true
		
		max_reserve_icon.visible = true 
		
		reserve_ammo_count.visible = false
		reserve_infinity_icon.visible = true
	else:
		ammo_count.visible = true
		current_infinity_icon.visible = false
		
		max_reserve_icon.visible = true
		
		reserve_ammo_count.visible = true
		reserve_infinity_icon.visible = false

		ammo_count.text = str(current)
		reserve_ammo_count.text = "%d / %d" % [reserve, max_ammo]
