class_name DevHarness
extends Node
## Headless/virtual-screen test harness driven by command-line flags (after `--`):
##   --fresh          use a throwaway save file (deleted at start and end)
##   --autotest       play the whole game flow automatically, one status line per stage
##   --until=N        stop the autotest once heat stage N is reached
##   --shot=PATH      capture one screenshot of --screen and quit
##   --shots=DIR      run the autotest and save screenshots at key moments into DIR
##   --screen=NAME    menu|garage|settings|tutorial|countdown|run|pause|revive|results
##   --wait=SEC       game seconds to wait before --shot (default depends on screen)
##   --seed=N         force the run seed (reproducible layouts)
##   --heat=N         start runs at heat stage N
##   --god            no damage/capture during play
##   --time=MODE      day|night|cycle (overrides the Time of day setting)
##   --near-police    (with --shot) wait until a police car is 10-28 m away
##   --touch          (with --shot) inject a real screen-touch drag (shows the steer ring)
##   --capture-warning (with --shot) show the capture warning state
##   --demo           start a run and let the autopilot drive (for Movie Maker capture)
##   --probe=SEC      with --demo: status every --every=SEC, police-proximity summary, quit
##   --trace          with --probe: position, capture progress, HP and each cop's AI state
##   --handling=MODE  drifty|grippy (overrides the Handling setting)
##   --empty          hide city blocks (open asphalt) for handling renders
##   --closeup        low chase camera (review body roll, tail swing, smoke)
##   --maneuver       scripted full-lock turns at speed; prints slide/drift numbers per move
##   --ad=MODE        fake ads: earn|dismiss|no_fill|interactive

const S := RunSession.State

var app: Node
var run: RunRoot
var flags: Dictionary
var autopilot: Autopilot
var shots_dir: String = ""
var failures: int = 0
var driving: bool = false
var _shot_index: int = 0
# Handling stats (probe): how slippery does the car actually drive?
var _drive_time: float = 0.0
var _drift_time: float = 0.0
var _drift_run: float = 0.0
var _longest_drift: float = 0.0
var _max_slip_deg: float = 0.0
var _spinouts: int = 0
var _spinning: bool = false
var _player_speed_sum: float = 0.0
var _police_speed_sum: float = 0.0
var _police_samples: int = 0
var _samples: int = 0


func start(app_root: Node, dev_flags: Dictionary) -> void:
	app = app_root
	run = app.get("run_root")
	flags = dev_flags
	process_mode = Node.PROCESS_MODE_ALWAYS
	if flags.has("seed"):
		run.forced_seed = int(flags["seed"])
	elif flags.has("autotest"):
		run.forced_seed = 20261125  # reproducible regression gate; pass --seed to vary
	if flags.has("heat"):
		run.start_heat_band = int(flags["heat"])
	if flags.has("god"):
		run.god_mode = true
	if flags.has("time"):
		run.forced_time = str(flags["time"])
		run.apply_settings()
	var fake := DashCore.ads as FakeAdsAdapter
	if fake != null:
		fake.mode = str(flags.get("ad", "earn"))
	autopilot = Autopilot.new(run, int(flags.get("seed", 7)))
	shots_dir = str(flags.get("shots", ""))
	if not shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_dir)
	if flags.has("closeup"):
		# Low chase camera for reviewing car body motion, smoke and tail swing.
		run.camera.distance = 6.5
		run.camera.height = 5.5
		run.camera.look_ahead = 3.0
		run.camera.base_fov = 70.0
		run.camera.wide_fov = 74.0
		run.camera.rigid = true
	if flags.has("empty"):
		run.world.debug_hide_blocks = true
		for cell in run.world.active.keys():
			((run.world.active[cell] as Dictionary)["node"] as Node3D).visible = false
	if flags.has("handling"):
		run.player.grippy = str(flags["handling"]) == "grippy"
	if flags.has("maneuver"):
		_maneuver.call_deferred()
	elif flags.has("demo"):
		_demo.call_deferred()
	elif flags.has("autotest") or not shots_dir.is_empty():
		_autotest.call_deferred()
	else:
		_single_shot.call_deferred()


func _physics_process(_delta: float) -> void:
	if not driving:
		return
	var st := run.session.state
	if st == S.RUNNING or st == S.TUTORIAL:
		autopilot.update(run.router)
		_track_handling(1.0 / Engine.physics_ticks_per_second)


func _track_handling(dt: float) -> void:
	var p := run.player
	_drive_time += dt
	_samples += 1
	_player_speed_sum += Vector2(p.velocity.x, p.velocity.z).length()
	for cop in run.director.police():
		var c := cop as PoliceAgent
		if c.mode != PoliceAgent.Mode.DISENGAGE and c.active:
			_police_speed_sum += Vector2(c.velocity.x, c.velocity.z).length()
			_police_samples += 1
	if p.drifting:
		_drift_time += dt
		_drift_run += dt
		_longest_drift = maxf(_longest_drift, _drift_run)
	else:
		_drift_run = 0.0
	if p.speed > 4.0 or absf(p.lateral) > 4.0:
		var slip := rad_to_deg(absf(atan2(p.lateral, maxf(p.speed, 0.01))))
		_max_slip_deg = maxf(_max_slip_deg, slip)
		var spun := slip > 100.0
		if spun and not _spinning:
			_spinouts += 1
		_spinning = spun


# ------------------------------------------------------------------ helpers

func log_line(msg: String) -> void:
	print("[autotest] ", msg)


func expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("[autotest] FAIL ", msg)


func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if bool(cond.call()):
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())


func state() -> int:
	return run.session.state


func state_name() -> String:
	return RunSession.state_name(run.session.state)


func shot(label: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	_shot_index += 1
	await save_viewport(shots_dir.path_join("%02d_%s.png" % [_shot_index, label]))


func save_viewport(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		log_line("screenshot unavailable (headless?)")
		return
	img.save_png(path)
	log_line("shot %s" % path)


func status(prefix: String) -> void:
	var near := run.director.nearest_police_distance()
	log_line("%s stage=%d t=%.0fs v=%d near=%s score=%d dist=%dm escapes=%d police=%d traffic=%d cells=%d health=%d coins=%d state=%s fps=%d" % [
		prefix, run.director.band, run.score.survival_seconds, int(run.player.speed), "-" if near == INF else "%dm" % int(near), run.score.score(), int(run.score.distance),
		run.score.escapes, run.director.police().size(), run.traffic.agents().size(),
		run.world.active_cell_count(), int(run.player.health), run.score.coins_collected,
		state_name(), Engine.get_frames_per_second()])


func finish() -> void:
	driving = false
	autopilot.release(run.router)
	log_line("done failures=%d" % failures)
	if flags.has("fresh"):
		DevFlags.delete_save(DevFlags.FRESH_SAVE)
	get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------ full autotest

func _autotest() -> void:
	await wait(1.0)
	expect(state() == S.MENU and (app.get("main_menu") as Control).visible, "menu shown at boot")
	await shot("menu")
	var menu: MainMenu = app.get("main_menu")
	menu.garage_pressed.emit()
	await wait(0.3)
	expect((app.get("garage") as Control).visible, "garage opens")
	await shot("garage")
	(app.get("garage") as Garage).back_pressed.emit()
	menu = app.get("main_menu")
	menu.settings_pressed.emit()
	await wait(0.3)
	expect((app.get("settings") as Control).visible, "settings opens")
	await shot("settings")
	(app.get("settings") as SettingsMenu).back_pressed.emit()
	await wait(0.2)

	# Run 1: tutorial on a fresh save, otherwise countdown.
	var tutorial_expected := not bool(DashCore.save_store.data.get("tutorial_done", false))
	(app.get("main_menu") as MainMenu).play_pressed.emit()
	await wait(0.1)
	if tutorial_expected:
		expect(state() == S.TUTORIAL, "first run starts tutorial")
		await _tutorial_script()
		expect(state() == S.RUNNING, "tutorial hands over to RUNNING (got %s)" % state_name())
		expect(bool(DashCore.save_store.data.get("tutorial_done", false)), "tutorial_done saved")
	else:
		expect(state() == S.COUNTDOWN, "run starts with countdown")
		await wait(0.5)
		await shot("countdown")
		expect(await wait_until(func() -> bool: return state() == S.RUNNING, 5.0), "countdown ends")
	autopilot.reset()
	driving = true

	# Stage sweep (god mode so every heat stage is reached).
	var last_stage := run.difficulty.band_count() - 1
	var until := int(flags.get("until", last_stage))
	var keep_god := flags.has("god")
	run.god_mode = true
	var seen := -1
	var entered_at := 0.0
	var limit := run.difficulty.band_start_times[mini(until, last_stage)] + 40.0
	while true:
		await get_tree().process_frame
		if state() != S.RUNNING:
			expect(false, "run ended during god-mode sweep: %s" % state_name())
			break
		if run.director.band != seen:
			seen = run.director.band
			entered_at = run.score.survival_seconds
			status("STAGE")
			await wait(1.0)
			await shot("stage_%d" % seen)
		if seen >= until and run.score.survival_seconds - entered_at > 10.0:
			break
		if run.score.survival_seconds > limit:
			expect(false, "stage %d not reached by %.0fs" % [until, limit])
			break
	status("SWEEP END")
	expect(run.score.distance > 100.0, "car actually travelled")
	expect(run.pool.validate().is_empty(), "pools valid mid-run")
	if flags.has("until"):
		finish()
		return

	# Pause / resume.
	app.call("_pause")
	expect(state() == S.PAUSED and get_tree().paused, "pause")
	await shot("pause")
	app.call("_resume")
	expect(state() == S.RUNNING and not get_tree().paused, "resume")

	# Natural crash, then rewarded revive.
	run.god_mode = keep_god
	var crashed := await wait_until(func() -> bool: return state() != S.RUNNING, 45.0)
	status("NATURAL" if crashed else "FORCED")
	if not crashed:
		run.player.take_damage(9999.0)
	expect(await wait_until(func() -> bool: return state() == S.REVIVE_PENDING, 4.0), "revive offered after crash (%s)" % state_name())
	log_line("crash reason=%s" % run.session.failure_reason)
	await shot("revive_offer")
	(app.get("revive_offer") as ReviveOffer).revive_pressed.emit()
	await wait(0.3)
	expect(state() == S.RUNNING and not get_tree().paused, "revived and driving")
	expect(run.session.revive_used, "revive marked used")
	await wait(4.0)
	status("AFTER REVIVE")
	run.player.take_damage(9999.0)
	expect(await wait_until(func() -> bool: return state() == S.RESULTS, 4.0), "second crash goes straight to results (%s)" % state_name())
	await wait(0.3)
	await shot("results")
	expect((app.get("results") as Control).visible, "results visible")
	log_line("results score=%d best=%d coins=%d" % [run.session.final_score, DashCore.save_store.get_int("best_score"), run.score.coin_payout()])

	# Run 2: retry, decline revive, then 2x coins.
	(app.get("results") as ResultsScreen).retry_pressed.emit()
	expect(await wait_until(func() -> bool: return state() == S.RUNNING, 8.0), "retry reaches RUNNING")
	autopilot.reset()
	await wait(25.0)
	status("RUN2")
	run.player.take_damage(9999.0)
	expect(await wait_until(func() -> bool: return state() == S.REVIVE_PENDING, 4.0), "run 2 revive offered")
	(app.get("revive_offer") as ReviveOffer).declined.emit()
	expect(await wait_until(func() -> bool: return state() == S.RESULTS, 2.0), "decline -> results")
	var payout := run.score.coin_payout()
	var before := DashCore.wallet.balance()
	(app.get("results") as ResultsScreen).double_pressed.emit()
	await wait(0.3)
	expect(payout > 0, "run 2 earned coins to double")
	if payout > 0:
		expect(DashCore.wallet.balance() == before + payout, "2x coins credited once (%d -> %d, payout %d)" % [before, DashCore.wallet.balance(), payout])
	DashCore.ads.rewarded_earned.emit("double", run.session.run_id, "double")
	expect(DashCore.wallet.balance() == before + payout, "duplicate reward callback ignored")
	await shot("results_doubled")

	(app.get("results") as ResultsScreen).menu_pressed.emit()
	expect(await wait_until(func() -> bool: return state() == S.MENU and (app.get("main_menu") as Control).visible, 5.0), "back to menu")

	# Save round-trip.
	var path := DevFlags.FRESH_SAVE if flags.has("fresh") else DashCore.save_store.path
	var reloaded := SaveStore.new(path)
	var st := reloaded.load_save()
	expect(st == "ok", "save reloads ok (%s)" % st)
	expect(reloaded.get_int("runs_completed") == DashCore.save_store.get_int("runs_completed"), "runs_completed persisted")
	expect(reloaded.get_int("coins") == DashCore.wallet.balance(), "coins persisted")
	expect(reloaded.get_int("best_score") > 0, "best score persisted")
	log_line("save runs=%d coins=%d best=%d tutorial_done=%s" % [reloaded.get_int("runs_completed"), reloaded.get_int("coins"), reloaded.get_int("best_score"), reloaded.data.get("tutorial_done")])
	finish()


func _tutorial_script() -> void:
	var tut: TutorialOverlay = app.get("tutorial")
	var r := run.router
	r.override_active = true
	await shot("tutorial")
	# Step 0: steer left then right.
	r.override_steer = -1.0
	await wait(0.6)
	r.override_steer = 1.0
	await wait(0.6)
	r.override_steer = 0.0
	expect(tut.step == 1, "tutorial step 0 (steer) completes")
	# Step 1: brake in a straight line.
	r.override_brake = true
	await wait(1.0)
	r.override_brake = false
	expect(tut.step == 2, "tutorial step 1 (brake) completes")
	status("TUT after brake")
	# Step 2: regain speed, then brake + steer to drift.
	await wait(2.5)
	for attempt in 3:
		status("TUT drift attempt %d" % attempt)
		r.override_brake = true
		r.override_steer = -1.0 if attempt % 2 == 0 else 1.0  # left first: toward open road
		await wait(1.4)
		log_line("  drift_time=%.2f drifting=%s" % [run.player.drift_time, run.player.drifting])
		r.override_brake = false
		r.override_steer = 0.0
		if tut.step >= 3:
			break
		await wait(2.0)
	expect(tut.step >= 3, "tutorial step 2 (drift) completes")
	# Step 3: police intro while the autopilot drives.
	autopilot.reset()
	driving = true
	await shot("tutorial_police")
	await wait_until(func() -> bool: return state() == S.RUNNING, 8.0)
	driving = false


# ------------------------------------------------------------------ single screenshot

func _single_shot() -> void:
	var screen := str(flags.get("screen", "menu"))
	var path := str(flags.get("shot", "user://shot.png"))
	if screen != "tutorial":
		DashCore.save_store.data["tutorial_done"] = true
	await wait(0.5)
	var default_wait := 1.0
	match screen:
		"garage":
			(app.get("main_menu") as MainMenu).garage_pressed.emit()
		"settings":
			(app.get("main_menu") as MainMenu).settings_pressed.emit()
		"tutorial":
			(app.get("main_menu") as MainMenu).play_pressed.emit()
			driving = true
			default_wait = 2.0
		"countdown":
			(app.get("main_menu") as MainMenu).play_pressed.emit()
			default_wait = 0.6
		"run", "pause", "revive", "results":
			(app.get("main_menu") as MainMenu).play_pressed.emit()
			await wait_until(func() -> bool: return state() == S.RUNNING, 6.0)
			autopilot.reset()
			driving = true
			default_wait = 10.0
	await wait(float(flags.get("wait", default_wait)))
	if flags.has("touch"):
		# Real touch events through the input pipeline: press, then drag right.
		driving = false
		autopilot.release(run.router)
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = Vector2(180, 980)
		down.pressed = true
		Input.parse_input_event(down)
		for k in 6:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = Vector2(180 + 12 * (k + 1), 980)
			Input.parse_input_event(drag)
			await get_tree().process_frame
		await wait(0.4)
	if flags.has("capture-warning"):
		run.capture.progress = run.capture.required_seconds * 0.6
		run.hud.update_threats(0.6, 0.0)
		run.god_mode = false
		await get_tree().process_frame
	if flags.has("near-police"):
		var near := func() -> bool:
			var d := run.director.nearest_police_distance()
			return d < 28.0 and d > 10.0
		await wait_until(near, 90.0)
	match screen:
		"pause":
			app.call("_pause")
			await wait(0.2)
		"revive", "results":
			run.player.take_damage(9999.0)
			await wait_until(func() -> bool: return state() == S.REVIVE_PENDING, 4.0)
			if screen == "results":
				(app.get("revive_offer") as ReviveOffer).declined.emit()
			await wait(0.3)
	status("SHOT %s" % screen)
	await save_viewport(path)
	finish()


# ------------------------------------------------------------------ demo (video capture)

func _demo() -> void:
	DashCore.save_store.data["tutorial_done"] = true
	await wait(float(flags.get("menu", 1.5)))
	(app.get("main_menu") as MainMenu).play_pressed.emit()
	await wait_until(func() -> bool: return state() == S.RUNNING, 6.0)
	autopilot.reset()
	driving = true
	if flags.has("probe"):
		var total := float(flags.get("probe", "120")) if str(flags["probe"]) != "true" else 120.0
		var samples: Array[float] = []
		var t := 0.0
		var every := float(flags.get("every", "5"))
		while t < total and state() == S.RUNNING:
			await wait(every)
			t += every
			status("PROBE")
			if flags.has("trace"):
				var modes := []
				for cop in run.director.police():
					modes.append("%s@%dm" % [PoliceAgent.Mode.keys()[(cop as PoliceAgent).mode], int((cop as PoliceAgent).distance_to_player())])
				var pp := run.player.global_position
				var cam := run.camera
				var cam_fwd := -cam.global_transform.basis.z
				log_line("  camdiff=%.2f carh=%.2f camh=%.2f" % [wrapf(LaneGraph.heading_of(Vector3(cam_fwd.x, 0, cam_fwd.z).normalized()) - run.player.heading, -PI, PI), run.player.heading, LaneGraph.heading_of(Vector3(cam_fwd.x, 0, cam_fwd.z).normalized())])
				log_line("  cap=%.2f spd=%.1f hp=%d pos=(%d,%d) node=%s heading=%.2f brake=%s steer=%.2f cops=%s" % [run.capture.progress, run.player.speed, int(run.player.health), pp.x, pp.z, run.graph.world_to_node(pp), run.player.heading, run.router.override_brake, run.router.override_steer, modes])
			var d := run.director.nearest_police_distance()
			samples.append(d if d != INF else 999.0)
		var close := 0
		for d in samples:
			if d < 60.0:
				close += 1
		log_line("streaming activations=%d max_cell_ms=%.2f" % [run.world.activations, run.world.max_activate_usec / 1000.0])
		log_line("speeds player_avg=%.1f m/s police_avg=%.1f m/s" % [_player_speed_sum / maxf(_samples, 1), _police_speed_sum / maxf(_police_samples, 1)])
		log_line("handling drift=%d%% longest_drift=%.1fs max_slip=%d deg spinouts=%d" % [int(100.0 * _drift_time / maxf(_drive_time, 0.01)), _longest_drift, int(_max_slip_deg), _spinouts])
		log_line("probe samples=%d within60m=%d%%" % [samples.size(), int(100.0 * close / maxf(1.0, samples.size()))])
		finish()


# ------------------------------------------------------------------ handling maneuver test

## Player-like inputs on a straight road: a hard flick, a sustained full lock, and a
## brake-turn. Prints peak sideways speed, peak slide angle and drift duration for each.
func _maneuver() -> void:
	DashCore.save_store.data["tutorial_done"] = true
	run.god_mode = true
	await wait(0.5)
	(app.get("main_menu") as MainMenu).play_pressed.emit()
	await wait_until(func() -> bool: return state() == S.RUNNING, 6.0)
	var r := run.router
	r.override_active = true
	# Pure handling: no walls/traffic in the way while measuring.
	var saved_mask := run.player.collision_mask
	run.player.collision_mask = 0
	var moves := [["flick 0.35s", 0.35, false], ["full lock 0.8s", 0.8, false], ["brake-turn 0.6s", 0.6, true]]
	for mv in moves:
		var pose := run.find_revive_pose()
		run.player.restore_for_revive(pose[0], float(pose[1]), 1.0, 0.0)
		run.player.speed = run.player.cruise_speed
		run.camera.snap()
		r.override_steer = 0.0
		r.override_brake = false
		await wait(float(flags.get("gap", "0.3")))
		var peak_lat := 0.0
		var peak_deg := 0.0
		var visual_checked := false
		var drift := 0.0
		var t := 0.0
		var hold := float(mv[1])
		while t < hold + 2.5:
			r.override_steer = 1.0 if t < hold else 0.0
			r.override_brake = bool(mv[2]) and t < hold
			await get_tree().physics_frame
			var dt := 1.0 / Engine.physics_ticks_per_second
			t += dt
			var p := run.player
			# Collisions are off for this test (no walls), which also removes the floor:
			# keep the car on the ground so renders show it.
			p.global_position.y = 0.0
			peak_lat = maxf(peak_lat, absf(p.lateral))
			peak_deg = maxf(peak_deg, rad_to_deg(absf(atan2(p.lateral, maxf(p.speed, 0.01)))))
			# Visual contract mid-slide (right turn, sliding left): the rendered body must
			# exaggerate the slide (tail swing same side as the slip) and lean outward (left).
			if not visual_checked and absf(p.lateral) > 4.0 and p.visual != null and t > 0.4:
				visual_checked = true
				var slip_sign := signf(p.lateral)  # negative = sliding left in a right turn
				var tail := p.visual.tail_swing()
				var roll := p.visual.body_roll()
				log_line("  visual: slip=%.1f tail=%.3f roll=%.3f" % [p.lateral, tail, roll])
				expect(signf(tail) == slip_sign and absf(tail) > 0.05, "tail swing exaggerates the slide (tail %.3f, slip %.1f)" % [tail, p.lateral])
				# Every maneuver turns right (steer +1), so the roof must lean left (outward).
				expect(roll > 0.02, "body leans out of the right turn (roll %.3f)" % roll)
			if p.drifting:
				drift += dt
			if flags.has("trace") and int(t * 60) % 6 == 0 and t < hold + 2.5:
				log_line("   t=%.2f v=%.1f lat=%.2f yaw=%.2f steer=%.2f drift=%s" % [t, p.speed, p.lateral, p.yaw_rate, p.steer, p.drifting])
		log_line("maneuver %-16s grippy=%s peak_sideways=%.1f m/s peak_slide=%d deg drift=%.2fs" % [mv[0], run.player.grippy, peak_lat, int(peak_deg), drift])
		# Handling contract: Drifty slides on hard inputs, Grippy stays planted, flicks stay controllable.
		var name_s := str(mv[0])
		if name_s.begins_with("flick"):
			expect(peak_lat < 3.0, "a quick flick stays controllable (%.1f m/s)" % peak_lat)
		elif run.player.grippy:
			expect(drift == 0.0, "grippy does not drift on %s" % name_s)
		else:
			expect(drift > 1.0 and peak_deg > 30.0, "drifty drifts on %s (%.2fs, %d deg)" % [name_s, drift, int(peak_deg)])
	run.player.collision_mask = saved_mask
	finish()
