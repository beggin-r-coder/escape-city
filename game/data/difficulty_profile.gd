class_name DifficultyProfile
extends Resource
## Difficulty bands. Each band should raise primarily ONE variable:
## speed first, then pattern complexity (police count / intercept roles), then hazard density.
## Pressure/recovery waves give breathing room instead of limitless escalation.

@export var band_start_times: PackedFloat32Array = PackedFloat32Array([0.0, 30.0, 70.0, 120.0, 180.0, 260.0])
@export var player_cruise_speed: PackedFloat32Array = PackedFloat32Array([14.0, 16.0, 16.0, 18.0, 18.0, 20.0])
@export var police_count: PackedInt32Array = PackedInt32Array([1, 1, 2, 2, 3, 4])
@export var police_speed_factor: PackedFloat32Array = PackedFloat32Array([1.08, 1.12, 1.15, 1.18, 1.22, 1.28])
@export var police_aggression: PackedFloat32Array = PackedFloat32Array([0.3, 0.35, 0.5, 0.6, 0.8, 1.0])
@export var intercept_share: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.5, 0.34, 0.5])
@export var traffic_count: PackedInt32Array = PackedInt32Array([3, 4, 4, 6, 7, 8])
@export var hazard_density: PackedFloat32Array = PackedFloat32Array([0.3, 0.3, 0.4, 0.4, 0.7, 0.9])

@export_group("Police")
@export var rubber_band_cap: float = 7.0
@export var rubber_band_gain: float = 0.18
@export var spawn_interval: float = 4.0
@export var min_spawn_travel_seconds: float = 3.0

@export_group("Waves")
@export var pressure_seconds: float = 40.0
@export var recovery_seconds: float = 16.0

@export_group("Escape")
@export var engage_distance: float = 55.0
@export var escape_distance: float = 75.0
@export var escape_hold_seconds: float = 5.0
@export var escape_cooldown_seconds: float = 20.0


func band_count() -> int:
	return band_start_times.size()


func band_for_time(t: float) -> int:
	var band := 0
	for i in band_start_times.size():
		if t >= band_start_times[i]:
			band = i
	return band


static func pick_f(values: PackedFloat32Array, band: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(band, 0, values.size() - 1)]


static func pick_i(values: PackedInt32Array, band: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(band, 0, values.size() - 1)]
