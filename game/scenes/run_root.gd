class_name RunRoot
extends Node3D
## Owns one run: session state, controller, director, camera, scoring and local object
## pools. Run-scoped references live here and are reset (not leaked) between runs.

signal crashed_ready(reason: String)

const HANDLING_PATH := "res://game/data/handling_default.tres"
const DIFFICULTY_PATH := "res://game/data/difficulty_default.tres"
const COSMETICS_PATH := "res://game/data/cosmetics_default.tres"
const CHUNK_DIR := "res://game/data/chunks/"
const ORIGIN_SHIFT_DISTANCE := 1024.0
const CRASH_BEAT_SECONDS := 1.2

var session: RunSession
var seeds: SeedService
var graph: LaneGraph
var planner: ChunkPlanner
var pool: ChunkPool
var world: StreamingWorld
var player: PlayerCar
var camera: ChaseCamera
var director: PursuitDirector
var traffic: TrafficManager
var capture: CaptureResolver
var score: ScoreService
var router: InputRouter
var hud: Hud
var audio: SynthAudio
var tutorial: TutorialOverlay
var skid: SkidMarks
var _impact_debris_cd: float = 0.0
var handling: HandlingConfig
var difficulty: DifficultyProfile
var catalog: CosmeticCatalog
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var day_night: DayNight
## Dev harness override for time of day ("" = use the setting).
var forced_time: String = ""

## Dev harness hooks (see game/dev/dev_harness.gd).
var forced_seed: int = -1
var start_heat_band: int = 0
var god_mode: bool = false

var _crash_timer: float = -1.0
var _crash_reason: String = ""
var _last_capture_beep: float = 0.0
var _origin_shifts: int = 0


func _ready() -> void:
	handling = load(HANDLING_PATH) as HandlingConfig
	difficulty = load(DIFFICULTY_PATH) as DifficultyProfile
	catalog = load(COSMETICS_PATH) as CosmeticCatalog
	if handling == null:
		handling = HandlingConfig.new()
	if difficulty == null:
		difficulty = DifficultyProfile.new()
	if catalog == null:
		catalog = CosmeticCatalog.new()
	session = RunSession.new()
	seeds = SeedService.new(SeedService.new_run_seed())
	graph = LaneGraph.new(seeds)
	pool = ChunkPool.new()
	planner = ChunkPlanner.new(graph, seeds, _load_chunk_definitions(), _load_recovery())
	capture = CaptureResolver.new()
	capture.configure(handling.capture_speed_threshold, handling.capture_radius, handling.capture_seconds)
	capture.captured.connect(func() -> void: _on_crash("busted"))
	score = ScoreService.new()
	_build_environment()

	router = InputRouter.new()
	router.name = "InputRouter"
	add_child(router)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.current = true

	player = PlayerCar.new()
	player.name = "Player"
	add_child(player)
	player.setup(handling, router)
	player.wrecked.connect(func() -> void: _on_crash("wrecked"))
	player.impact.connect(_on_player_impact)
	camera.setup(player, graph)
	apply_equipped_look()

	world = StreamingWorld.new()
	world.name = "World"
	add_child(world)
	world.setup(graph, planner, pool, camera)
	world.prop_smashed.connect(_on_prop_smashed)
	world.coin_collected.connect(_on_coin)

	traffic = TrafficManager.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(graph, pool, camera, player, catalog, seeds.stream(SeedService.STREAM_AGENTS))

	var police_parent := Node3D.new()
	police_parent.name = "Police"
	add_child(police_parent)
	director = PursuitDirector.new()
	director.name = "PursuitDirector"
	add_child(director)
	director.setup(difficulty, graph, player, camera, pool, traffic, catalog, seeds.stream(SeedService.STREAM_AGENTS), police_parent)
	director.escape_verified.connect(_on_escape)
	director.band_changed.connect(_on_band_changed)
	traffic.police_provider = director.police_nodes

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.build(router)

	skid = SkidMarks.new()
	skid.name = "SkidMarks"
	add_child(skid)
	skid.add_to_group(&"origin_shift")

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(env, sun, sky_mat, world, player)

	audio = SynthAudio.new()
	audio.name = "Audio"
	add_child(audio)

	apply_settings()


func _load_chunk_definitions() -> Array[ChunkDefinition]:
	var out: Array[ChunkDefinition] = []
	for file in ["downtown", "residential", "park", "plaza", "construction", "parking"]:
		var d := load(CHUNK_DIR + file + ".tres") as ChunkDefinition
		if d != null:
			out.append(d)
	return out


func _load_recovery() -> ChunkDefinition:
	var d := load(CHUNK_DIR + "recovery.tres") as ChunkDefinition
	if d == null:
		d = ChunkDefinition.new()
		d.id = &"recovery"
		d.is_recovery = true
		d.max_lots = 1
	return d


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3a6ec8")
	sky_mat.sky_horizon_color = Color("a9c6e6")
	sky_mat.ground_horizon_color = Color("bcd3ea")
	sky_mat.ground_bottom_color = Color("5a6470")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa3c4")
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color("8fa8c6")
	env.fog_density = 0.0018
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.3
	env.fog_sky_affect = 0.25
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 0.92
	sun.shadow_opacity = 0.75
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func apply_settings() -> void:
	var store := DashCore.save_store
	var layout_name := str(store.get_setting("control_layout", "drag"))
	router.layout = InputRouter.Layout.BUTTONS if layout_name == "buttons" else InputRouter.Layout.DRAG
	hud.set_layout(router.layout)
	camera.reduced_motion = bool(store.get_setting("reduced_motion", false))
	player.grippy = str(store.get_setting("handling", "drifty")) == "grippy"
	QualityPresets.apply(str(store.get_setting("quality", "low")), get_viewport(), sun, env)
	var tod := forced_time if not forced_time.is_empty() else str(store.get_setting("time_of_day", "cycle"))
	if day_night != null and day_night.mode != tod:
		day_night.set_mode(tod)


func apply_equipped_look() -> void:
	var idx := catalog.player_index(DashCore.wallet.equipped())
	player.set_look(catalog.player_models[idx])


# ---------------------------------------------------------------- run lifecycle

func _spawn_pose() -> Array:
	var a := Vector2i(0, 1)
	var b := Vector2i(0, 0)
	return [graph.lane_point(a, b, graph.cell_size * 0.5), 0.0]


func _reset_world_state(seed_value: int) -> void:
	seeds.reset(seed_value)
	graph.origin_cell = Vector2i.ZERO
	planner.failures.clear()
	director.reset()
	traffic.reset_traffic()
	capture.reset()
	score.reset()
	_crash_timer = -1.0
	_origin_shifts = 0
	if skid != null:
		skid.clear_marks()
	var pose := _spawn_pose()
	var pos: Vector3 = pose[0]
	player.reset_at(pos, float(pose[1]), 0.0)
	player.cruise_speed = DifficultyProfile.pick_f(difficulty.player_cruise_speed, 0)
	world.band = 0
	world.hazard_density = DifficultyProfile.pick_f(difficulty.hazard_density, 0)
	world.reset_world(pos, 90.0)
	var errors := pool.validate()
	if not errors.is_empty():
		push_warning("Pool validation after reset: %s" % ", ".join(errors))


## Menu background: generated city, parked car, ambient traffic, orbiting camera.
func enter_preview() -> void:
	if session.state != RunSession.State.MENU:
		session.to_menu()
	_reset_world_state(forced_seed if forced_seed >= 0 else SeedService.new_run_seed())
	player.controls_enabled = false
	router.enabled = false
	camera.orbit = true
	camera.snap()
	hud.set_gameplay_visible(false)
	audio.engine_speed = 0.0
	audio.siren_level = 0.0
	audio.skid_level = 0.0
	audio.muted = true
	traffic.desired_count = 4


func start_run(tutorial_mode: bool) -> bool:
	if not session.begin_run(tutorial_mode):
		return false
	var seed_value := forced_seed if forced_seed >= 0 else SeedService.new_run_seed()
	_reset_world_state(seed_value)
	if start_heat_band > 0:
		var b := clampi(start_heat_band, 0, difficulty.band_count() - 1)
		director.heat_bonus = difficulty.band_start_times[b]
	camera.orbit = false
	camera.snap()
	day_night.restart()
	audio.muted = false
	hud.set_gameplay_visible(true)
	hud.update_threats(0.0, 0.0)
	player.controls_enabled = tutorial_mode
	player.damage_enabled = not tutorial_mode
	capture.enabled = not tutorial_mode
	router.enabled = tutorial_mode
	if tutorial_mode:
		player.speed = 6.0
	DashCore.telemetry.log_event("run_start", {
		"run_id": session.run_id, "seed": seed_value,
		"generator_version": LaneGraph.GENERATOR_VERSION, "tutorial": tutorial_mode})
	return true


## After the countdown.
func begin_driving() -> void:
	if session.start_running():
		player.controls_enabled = true
		router.enabled = true
		director.start()


func tutorial_spawn_police() -> void:
	director.start()


func complete_tutorial() -> void:
	DashCore.save_store.data["tutorial_done"] = true
	DashCore.save_store.save()
	if session.start_running():
		player.damage_enabled = true
		capture.enabled = true
		capture.reset()
		score.reset()
		player.distance_travelled = 0.0
		hud.show_banner("SURVIVE!", 1.4)


func _on_crash(reason: String) -> void:
	if not session.crash(reason):
		return  # duplicate crash callbacks are rejected
	_crash_reason = reason
	_crash_timer = CRASH_BEAT_SECONDS
	player.controls_enabled = false
	router.enabled = false
	director.stop()
	audio.play("crash")
	camera.add_shake(0.8)
	DashCore.haptic(120)
	DebrisPiece.burst(self, player.global_position, player.velocity, 5)
	hud.show_banner(ReviveOffer.reason_title(reason), CRASH_BEAT_SECONDS)


## Rewarded revive: verified empty road, distant police, partial health, protection.
func revive(callback_run_id: String) -> bool:
	if not session.apply_revive(callback_run_id):
		return false
	var pose := find_revive_pose()
	player.restore_for_revive(pose[0], float(pose[1]), 0.6, 3.0)
	player.controls_enabled = true
	router.enabled = true
	router.clear_all()
	capture.reset()
	director.protect(3.0)
	director.start()
	for t in traffic.agents():
		if (t as Node3D).global_position.distance_to(pose[0]) < 35.0:
			pool.release(t)
	camera.snap()
	hud.show_banner("REVIVED", 1.2)
	return true


func find_revive_pose() -> Array:
	var center := graph.world_to_node(player.global_position)
	var best: Array = []
	var best_d := INF
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var n := center + Vector2i(dx, dz)
			for nb in graph.neighbors(n):
				var pos := graph.lane_point(n, nb, graph.cell_size * 0.5)
				if not traffic.is_position_clear(pos, 25.0):
					continue
				var d := pos.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					best = [pos, LaneGraph.heading_of((graph.node_world(nb) - graph.node_world(n)).normalized())]
	if best.is_empty():
		return [player.global_position, player.heading]
	return best


## Freezes rewards, banks base coins once, records best score. Returns results info.
func finish_run() -> Dictionary:
	score.freeze()
	var final_score := score.score()
	var store := DashCore.save_store
	var best := store.get_int("best_score")
	var new_best := final_score > best
	if new_best:
		store.data["best_score"] = final_score
	store.data["runs_completed"] = store.get_int("runs_completed") + 1
	store.save()
	var coins := score.coin_payout()
	DashCore.wallet.credit("run:%s:base" % session.run_id, coins)
	DashCore.ad_policy.on_run_completed()
	DashCore.telemetry.log_event("run_end", {
		"run_id": session.run_id, "duration": snappedf(score.survival_seconds, 0.1),
		"failure_reason": session.failure_reason, "score": final_score, "escapes": score.escapes,
		"coins": coins, "revived": session.revive_used})
	session.finish(final_score)
	hud.set_gameplay_visible(false)
	return {
		"reason": session.failure_reason, "score": final_score, "best": maxi(best, final_score),
		"new_best": new_best, "seconds": score.survival_seconds, "escapes": score.escapes,
		"distance": score.distance, "coins": coins,
	}


## Rewarded 2x on the run's base coins. Keyed so a duplicate callback credits once.
func double_coins() -> int:
	var coins := score.coin_payout()
	if DashCore.wallet.credit("run:%s:double" % session.run_id, coins):
		session.mark_rewarded_used()
		return coins * 2
	return 0


# ---------------------------------------------------------------- per-frame

func _physics_process(delta: float) -> void:
	_impact_debris_cd -= delta
	skid.track(player.global_transform, player.drifting or (player.braking and player.speed > 9.0))
	match session.state:
		RunSession.State.RUNNING:
			_tick_running(delta)
		RunSession.State.TUTORIAL:
			_tick_ambient(delta)
			if director.running:
				director.update(delta, 0.0)
			if tutorial != null:
				tutorial.observe(player, delta)
			_update_hud()
		RunSession.State.CRASHED:
			_tick_ambient(delta)
			if _crash_timer > 0.0:
				_crash_timer -= delta
				if _crash_timer <= 0.0:
					crashed_ready.emit(_crash_reason)
		RunSession.State.MENU, RunSession.State.COUNTDOWN:
			_tick_ambient(delta)
	_update_audio()


func _tick_ambient(delta: float) -> void:
	traffic.update(delta)
	# Bias the streaming window ahead of the car so blocks are prepared before they are seen.
	var ahead := player.forward() * graph.cell_size * clampf(player.speed / 14.0, 0.0, 1.0)
	world.update(player.global_position + ahead, _vehicle_positions())
	_maybe_shift_origin()


func _tick_running(delta: float) -> void:
	if god_mode:
		player.health = handling.max_health
		capture.reset()
	var band := director.band
	player.cruise_speed = DifficultyProfile.pick_f(difficulty.player_cruise_speed, band)
	traffic.desired_count = DifficultyProfile.pick_i(difficulty.traffic_count, band)
	world.band = band
	world.hazard_density = DifficultyProfile.pick_f(difficulty.hazard_density, band)
	director.update(delta, score.survival_seconds)
	score.tick(delta, player.distance_travelled)
	var nearest := director.nearest_police_distance()
	var effective_speed := player.speed if player.invulnerable_timer <= 0.0 else 999.0
	var before := capture.ratio()
	capture.update(delta, effective_speed, nearest)
	if capture.ratio() > 0.0 and _last_capture_beep <= 0.0:
		audio.play("warning")
		_last_capture_beep = 0.9
	_last_capture_beep -= delta
	if before > 0.0 and capture.ratio() == 0.0:
		_last_capture_beep = 0.0
	_tick_ambient(delta)
	_update_hud()


func _update_hud() -> void:
	hud.update_stats(score.score(), score.distance, score.coins_collected,
		player.health / handling.max_health, director.band, director.pressure)
	hud.update_threats(capture.ratio(), director.escape_progress())
	hud.update_speed(player.speed)
	var dirs: Array[Vector2] = []
	var urg: Array[float] = []
	for p in director.police():
		var cop: PoliceAgent = p
		var d := cop.distance_to_player()
		if d > 110.0 or cop.mode == PoliceAgent.Mode.DISENGAGE:
			continue
		var dir := camera.offscreen_direction(cop.global_position)
		if dir != Vector2.ZERO:
			dirs.append(dir)
			urg.append(clampf(1.0 - d / 110.0, 0.0, 1.0))
	hud.arrows.set_markers(dirs, urg)


func _update_audio() -> void:
	audio.engine_speed = player.speed
	audio.skid_level = clampf(absf(player.lateral) / 6.0, 0.0, 1.0) if player.drifting else 0.0
	var nearest := director.nearest_police_distance()
	audio.siren_level = 0.0 if nearest == INF else clampf(1.0 - nearest / 130.0, 0.0, 1.0)


func _vehicle_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in director.police():
		out.append((p as Node3D).global_position)
	return out


func _maybe_shift_origin() -> void:
	var p := player.global_position
	if Vector2(p.x, p.z).length() < ORIGIN_SHIFT_DISTANCE:
		return
	var dc := Vector2i(roundi(p.x / graph.cell_size), roundi(p.z / graph.cell_size))
	var offset := Vector3(-float(dc.x) * graph.cell_size, 0.0, -float(dc.y) * graph.cell_size)
	graph.origin_cell += dc
	for n in get_tree().get_nodes_in_group(&"origin_shift"):
		if n.has_method(&"apply_origin_shift"):
			n.call(&"apply_origin_shift", offset)
	_origin_shifts += 1


# ---------------------------------------------------------------- events

func _on_player_impact(strength: float) -> void:
	camera.add_shake(clampf(strength / 20.0, 0.1, 0.6))
	if strength > 9.0 and _impact_debris_cd <= 0.0:
		_impact_debris_cd = 1.0
		DebrisPiece.burst(self, player.global_position, player.velocity, 2)
	if strength > 4.0:
		audio.play("crash")
		DashCore.haptic(40)


func _on_prop_smashed(_prop: BreakableProp, by: Node3D) -> void:
	if by == player:
		player.on_prop_smashed()
		score.props_smashed += 1
		director.add_heat(1.5)  # smashing street props draws more attention
		audio.play("smash")
		camera.add_shake(0.15)


func _on_band_changed(band: int) -> void:
	if band > 0 and session.state == RunSession.State.RUNNING:
		hud.show_banner("HEAT %d" % (band + 1), 1.2)


func _on_coin(_coin: CoinPickup) -> void:
	score.add_coin()
	audio.play("coin")


func _on_escape(_total: int) -> void:
	score.add_escape()
	audio.play("escape")
	hud.show_banner("ESCAPED  +%d" % ScoreService.ESCAPE_POINTS, 1.8)
	DashCore.haptic(60)
