class_name CaptureResolver
extends RefCounted
## Capture = player below a speed threshold AND within radius of police for N continuous
## seconds. Progress resets as soon as either condition clears.

signal captured

var speed_threshold: float = 4.0
var radius: float = 9.0
var required_seconds: float = 3.0
var progress: float = 0.0
var enabled: bool = true
var _fired: bool = false


func configure(threshold: float, capture_radius: float, seconds: float) -> void:
	speed_threshold = threshold
	radius = capture_radius
	required_seconds = seconds


func reset() -> void:
	progress = 0.0
	_fired = false


func ratio() -> float:
	return clampf(progress / required_seconds, 0.0, 1.0)


func update(delta: float, player_speed: float, nearest_police_distance: float) -> float:
	if not enabled or _fired:
		return progress
	if player_speed < speed_threshold and nearest_police_distance <= radius:
		progress += delta
		if progress >= required_seconds:
			_fired = true
			captured.emit()
	else:
		progress = 0.0
	return progress
