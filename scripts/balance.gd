class_name GameBalance
extends Resource

@export_category("Wizard")
@export var player_health: float = 100.0
@export var player_speed: float = 5.2
@export var village_heal_per_second: float = 7.0
@export_category("Fireball")
@export var fire_damage: float = 24.0
@export var fire_cooldown: float = 1.2
@export var fire_speed: float = 17.0
@export var fire_range: float = 17.0
@export var fire_upgrade_multiplier: float = 1.6
@export_category("Frost")
@export var frost_damage: float = 18.0
@export var frost_cooldown: float = 5.0
@export var frost_range: float = 10.0
@export var frost_radius: float = 2.8
@export var frost_slow_multiplier: float = 0.42
@export var frost_slow_duration: float = 3.0
@export var frost_upgrade_multiplier: float = 1.55
@export_category("Forest")
@export var enemy_health: float = 110.0
@export var enemy_speed: float = 2.6
@export var enemy_damage: float = 12.0
@export var enemy_attack_interval: float = 1.5
@export var enemy_attack_range: float = 1.2
@export var enemy_detection_range: float = 9.0
@export var enemy_leash_range: float = 15.0
@export var enemy_count: int = 10
@export var enemy_respawn_delay: float = 12.0
@export var quest_target: int = 5

