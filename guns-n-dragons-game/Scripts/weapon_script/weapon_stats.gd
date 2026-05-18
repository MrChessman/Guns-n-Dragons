extends Resource

class_name WeaponStats

@export_category("Weapon Stats")
@export var weapon_id: String = ""
@export var bullet_scene: PackedScene
@export var damage: int = 1
@export var fire_rate: float = 0.5
@export var mag_size: int = 6
@export var max_ammo: int = 30
@export var reserve_ammo: int = 60 
@export var infinite_ammo: bool = true
@export var reload_time: float = 1.5

@export_category("Multishot Stats")
@export var pellet_count: int = 1

@export_category("Recoil Stats")
@export var accurate_shots: int = 2 
@export var spread_per_shot: float = 5.0
@export var max_spread: float = 15.0
@export var recoil_reset_time: float = 0.4
