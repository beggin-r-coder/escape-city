class_name HandlingConfig
extends Resource
## All player-car feel tuning in one typed resource. Edit handling_default.tres.

@export_group("Speed")
@export var max_speed: float = 22.0
@export var acceleration: float = 7.0
@export var brake_deceleration: float = 16.0
@export var min_brake_speed: float = 0.0

@export_group("Steering")
@export var steer_rate_low_speed: float = 2.5
@export var steer_rate_high_speed: float = 1.7
@export var steer_full_speed: float = 6.0
@export var steer_response: float = 9.0
## How fast the yaw rate can change (rad/s^2). Lower = heavier, smoother turn-in.
@export var yaw_response: float = 10.0

@export_group("Drift")
## Momentum model: steering turns the nose, velocity follows only as fast as the tyres
## allow. Lateral (sideways) speed is pulled to zero at `grip` m/s^2 while gripping.
@export var grip: float = 22.0
## Once sideways speed passes slip_threshold the tyres break loose and grip falls to
## drift_grip until it drops below regrip_threshold (hysteresis = long, holdable slides).
@export var drift_grip: float = 6.5
@export var slip_threshold: float = 3.0
@export var regrip_threshold: float = 1.2
## Braking while turning works like a handbrake: grip multiplied by this.
@export var brake_grip_factor: float = 0.3
@export var drift_min_speed: float = 7.0
@export var drift_yaw_multiplier: float = 1.3
@export var max_lateral_slip: float = 9.0
## Forward speed scrubbed per second while sliding.
@export var drift_drag: float = 2.5
## Rear-heavy feel: sideways slip keeps rotating the car into the slide (oversteer),
## in rad/s per m/s of slip, capped at max_oversteer_yaw.
@export var rear_bias: float = 0.055
@export var max_oversteer_yaw: float = 0.6
## When the tyres regrip, the tail snaps back past centre: this fraction of the slide
## is thrown the other way, producing a fishtail wiggle.
@export var fishtail_strength: float = 0.35
## "Grippy" handling option multiplies grip by this (accessibility / easier mode).
@export var grippy_multiplier: float = 1.8

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
