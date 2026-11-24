class_name HandlingConfig
extends Resource
## All player-car feel tuning in one typed resource. Edit handling_default.tres.

@export_group("Speed")
@export var max_speed: float = 22.0
@export var acceleration: float = 7.0
@export var brake_deceleration: float = 16.0
@export var drift_brake_deceleration: float = 5.0
@export var min_brake_speed: float = 0.0

@export_group("Steering")
@export var steer_rate_low_speed: float = 2.5
@export var steer_rate_high_speed: float = 1.7
@export var steer_full_speed: float = 6.0
@export var steer_response: float = 9.0

@export_group("Drift")
@export var drift_min_speed: float = 8.0
@export var drift_steer_threshold: float = 0.3
@export var drift_yaw_multiplier: float = 1.45
@export var drift_slip_accel: float = 14.0
@export var max_lateral_slip: float = 6.0
@export var grip: float = 16.0
@export var drift_grip: float = 4.0

@export_group("Damage")
@export var max_health: float = 100.0
@export var wall_damage_min_speed: float = 6.0
@export var wall_damage_per_mps: float = 2.2
@export var vehicle_damage_per_mps: float = 1.6
@export var vehicle_slowdown: float = 0.6
@export var head_on_speed_keep: float = 0.3
@export var contact_cooldown: float = 0.5
@export var prop_slowdown: float = 0.9

@export_group("Capture")
@export var capture_speed_threshold: float = 4.0
@export var capture_radius: float = 9.0
@export var capture_seconds: float = 3.0
