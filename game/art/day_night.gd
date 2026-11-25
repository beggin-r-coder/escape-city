class_name DayNight
extends Node
## Time of day. Modes: "day", "night", "cycle" (a full day-night loop; runs start at dusk).
## One darkness value drives sun/moon, ambient, sky, fog, colour grading, the shared
## night materials (lit windows, lamp heads, light pools, car lights) and a small pool of
## real OmniLights that follow the street lamps nearest the player.

signal lights_toggled(on: bool)

const CYCLE_SECONDS := 240.0
const START_PHASE := 1.266  # acos(0.3): start at darkness 0.35 and getting darker
const POOL_SIZE := 6
const LIGHTS_ON_AT := 0.42

var mode: String = "cycle"
var darkness: float = 0.0
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var world: StreamingWorld
var player: Node3D

var _t: float = 0.0
var _pool: Array[OmniLight3D] = []
var _pool_timer: float = 0.0


func setup(environment: Environment, sun_light: DirectionalLight3D, sky: ProceduralSkyMaterial, streaming: StreamingWorld, player_node: Node3D) -> void:
	env = environment
	sun = sun_light
	sky_mat = sky
	world = streaming
	player = player_node
	for i in POOL_SIZE:
		var l := OmniLight3D.new()
		l.light_color = ChunkBuilder.LAMP_LIGHT
		l.omni_range = 15.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)
	apply(darkness_now())


func set_mode(new_mode: String) -> void:
	mode = new_mode
	_t = 0.0
	apply(darkness_now())


## Restart the cycle (new run starts at dusk again).
func restart() -> void:
	_t = 0.0
	apply(darkness_now())


func darkness_now() -> float:
	match mode:
		"day":
			return 0.0
		"night":
			return 1.0
	return 0.5 - 0.5 * cos(TAU * _t / CYCLE_SECONDS + START_PHASE)


func _process(delta: float) -> void:
	if mode == "cycle":
		_t += delta
		apply(darkness_now())
	_pool_timer -= delta
	if _pool_timer <= 0.0:
		_pool_timer = 0.2
		_update_pool()


static func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


func apply(d: float) -> void:
	darkness = clampf(d, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(darkness - 0.5) * 2.0, 0.0, 1.0)  # peaks at 0.5
	if sun != null:
		sun.light_energy = lerpf(0.92, 0.1, darkness)
		var day_col := Color("ffe0b5")
		var dusk_col := Color("ffb27a")
		var moon_col := Color("a7b6e0")
		sun.light_color = _mix(_mix(day_col, dusk_col, dusk), moon_col, smoothstep(0.55, 0.9, darkness))
		sun.rotation_degrees = Vector3(lerpf(-52.0, -30.0, dusk * 0.8 + darkness * 0.2), -38.0, 0.0)
		sun.shadow_opacity = lerpf(0.75, 0.35, darkness)
	if env != null:
		env.ambient_light_color = _mix(Color("8fa3c4"), Color("39425a"), darkness)
		env.ambient_light_energy = lerpf(0.34, 0.24, darkness)
		env.fog_light_color = _mix(_mix(Color("8fa8c6"), Color("b48a7a"), dusk * 0.35), Color("10141f"), smoothstep(0.5, 1.0, darkness))
		env.fog_density = lerpf(0.0018, 0.0042, darkness) - 0.0006 * dusk
		env.adjustment_saturation = lerpf(1.3, 0.92, darkness)
		env.tonemap_exposure = lerpf(0.92, 1.0, darkness)
	if sky_mat != null:
		sky_mat.sky_top_color = _mix(_mix(Color("3a6ec8"), Color("4a4f8a"), dusk), Color("04060f"), smoothstep(0.5, 1.0, darkness))
		sky_mat.sky_horizon_color = _mix(_mix(Color("a9c6e6"), Color("ff9e6b"), dusk), Color("151a2a"), smoothstep(0.55, 1.0, darkness))
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	ArtKit.set_night(smoothstep(0.3, 0.75, darkness))
	var on := darkness >= LIGHTS_ON_AT
	if on != ArtKit.lights_on:
		ArtKit.lights_on = on
		for n in get_tree().get_nodes_in_group(&"night_only"):
			(n as Node3D).visible = on
		lights_toggled.emit(on)


## Real lights on the lamps nearest the player (biased ahead of the car).
func _update_pool() -> void:
	var strength := ArtKit.night_level
	if strength < 0.05 or world == null or player == null:
		for l in _pool:
			l.visible = false
		return
	var p := player.global_position
	var fwd := -player.global_transform.basis.z
	var lamps := world.lamp_positions_near(p, 70.0)
	var focus := p + fwd * 15.0
	var nearer := func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(focus) < b.distance_squared_to(focus)
	lamps.sort_custom(nearer)
	for i in _pool.size():
		var l := _pool[i]
		if i < lamps.size():
			l.global_position = lamps[i] + Vector3(0, -0.6, 0)
			l.light_energy = 2.2 * strength
			l.visible = true
		else:
			l.visible = false
