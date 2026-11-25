extends SceneTree
## Headless automated checks (guide page 11). Run from the project root:
##   godot --headless --path . --import          (first time, builds the class cache)
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed.

const CHUNKS := ["downtown", "residential", "park", "plaza", "construction", "parking"]
const TEST_SAVE := "user://test_escape_city_save.json"

var _passes: int = 0
var _failures: int = 0
var _current: String = ""


func _initialize() -> void:
	var tests := [
		"test_graph_integrity",
		"test_graph_paths",
		"test_chunk_plans_certified",
		"test_seed_streams_independent",
		"test_pool_cycle",
		"test_reward_idempotent",
		"test_save_recovery",
		"test_reward_gate",
		"test_capture_resolver",
		"test_run_session",
		"test_spawn_fairness",
		"test_ad_policy",
		"test_telemetry_filter",
		"test_billing_entitlement",
		"test_score_contract",
		"test_input_dead_zone",
		"test_audio_offline",
	]
	var started := Time.get_ticks_msec()
	for t in tests:
		_current = t
		var before := _failures
		call(t)
		print("%s %s" % ["PASS" if _failures == before else "FAIL", t])
	print("\n%d checks passed, %d failed in %d ms" % [_passes, _failures, Time.get_ticks_msec() - started])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL [%s] %s" % [_current, msg])


# ------------------------------------------------------------------ world

## 1,000 districts: every lane socket connects, the window is connected, a loop exists.
func test_graph_integrity() -> void:
	var r := 6
	for seed_value in 1000:
		var g := LaneGraph.new(SeedService.new(seed_value))
		var nodes := {}
		var edges := 0
		var ok_sym := true
		var ok_degree := true
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				var n := Vector2i(x, z)
				nodes[n] = true
				var degree := 0
				for d in LaneGraph.DIRS:
					var nb: Vector2i = n + d
					var open := g.is_edge_open(n, nb)
					if open != g.is_edge_open(nb, n):
						ok_sym = false
					if open:
						degree += 1
						if absi(nb.x) <= r and absi(nb.y) <= r and (d == Vector2i(1, 0) or d == Vector2i(0, 1)):
							edges += 1
				if degree < 3:
					ok_degree = false
		# BFS restricted to the window.
		var seen := {Vector2i.ZERO: true}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			for nb in g.neighbors(cur):
				if absi(nb.x) <= r and absi(nb.y) <= r and not seen.has(nb):
					seen[nb] = true
					queue.append(nb)
		if not (ok_sym and ok_degree and seen.size() == nodes.size() and edges >= nodes.size()):
			check(false, "seed %d: sym=%s degree=%s reach=%d/%d edges=%d" % [seed_value, ok_sym, ok_degree, seen.size(), nodes.size(), edges])
			return
	check(true, "graph integrity")


func test_graph_paths() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 200:
		var g := LaneGraph.new(SeedService.new(k))
		var a := Vector2i(rng.randi_range(-5, 5), rng.randi_range(-5, 5))
		var b := Vector2i(rng.randi_range(-5, 5), rng.randi_range(-5, 5))
		var path := g.find_path(a, b)
		check(not path.is_empty() and path[0] == a and path[path.size() - 1] == b, "path %s -> %s found" % [a, b])
		for i in range(1, path.size()):
			if not g.is_edge_open(path[i - 1], path[i]):
				check(false, "path uses closed edge")
				return


func _definitions() -> Array[ChunkDefinition]:
	var defs: Array[ChunkDefinition] = []
	for c in CHUNKS:
		var d := load("res://game/data/chunks/%s.tres" % c) as ChunkDefinition
		check(d != null, "load chunk %s" % c)
		if d != null:
			defs.append(d)
	return defs


## 1,000 seeds per difficulty band: no static obstacle blocks a lane or junction, and
## hazards/coins sit in lanes but never inside the intersection box.
func test_chunk_plans_certified() -> void:
	var defs := _definitions()
	var recovery := load("res://game/data/chunks/recovery.tres") as ChunkDefinition
	check(recovery != null and recovery.is_recovery, "recovery chunk loads")
	var fallbacks := 0
	for band in 6:
		for seed_value in 1000:
			var seeds := SeedService.new(seed_value * 31 + band)
			var g := LaneGraph.new(seeds)
			var planner := ChunkPlanner.new(g, seeds, defs, recovery)
			var cell := Vector2i(seed_value % 7 - 3, (seed_value / 7) % 7 - 3)
			var plan := planner.plan_cell(cell, band, 1.0, true)
			if bool(plan["recovery"]):
				fallbacks += 1
			var errors := planner.validate_plan(plan)
			if not errors.is_empty():
				check(false, "seed %d band %d: %s" % [seed_value, band, errors[0]])
				return
			var hw := g.half_road()
			for h in plan["hazards"]:
				var p: Vector2 = h["pos"]
				if absf(p.x) < hw and absf(p.y) < hw:
					check(false, "hazard inside intersection")
					return
	check(fallbacks == 0, "no recovery fallbacks needed (%d)" % fallbacks)


## Changing the cosmetic stream must not alter gameplay layout.
func test_seed_streams_independent() -> void:
	var s := SeedService.new(1234)
	var a := s.cell_value(SeedService.STREAM_ROUTE, 3, -2)
	var b := s.cell_value(SeedService.STREAM_COSMETICS, 3, -2)
	check(a != b, "streams differ")
	check(is_equal_approx(a, SeedService.new(1234).cell_value(SeedService.STREAM_ROUTE, 3, -2)), "deterministic")
	check(not is_equal_approx(a, SeedService.new(1235).cell_value(SeedService.STREAM_ROUTE, 3, -2)), "seed sensitive")


## Acquire/reset/release 1,000 times with fixed capacity.
func test_pool_cycle() -> void:
	var pool := ChunkPool.new()
	var made := [0]
	var resets := [0]
	var factory := func() -> Object:
		made[0] += 1
		return RefCounted.new()
	var reset := func(_o: Object) -> void:
		resets[0] += 1
	pool.register_type(&"thing", factory, 8, reset)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var held: Array = []
	for i in 1000:
		var want := rng.randi_range(0, 12)
		for k in want:
			var o := pool.acquire(&"thing")
			if o != null:
				held.append(o)
		check(pool.active_count(&"thing") <= 8, "active within capacity")
		var release_n := rng.randi_range(0, held.size())
		for k in release_n:
			pool.release(held.pop_back())
		if i % 100 == 0:
			pool.release(null)  # tolerated
	for o in held:
		pool.release(o)
		pool.release(o)  # double release ignored
	check(pool.validate().is_empty(), "validate clean: %s" % ", ".join(pool.validate()))
	check(pool.active_count(&"thing") == 0, "all released")
	check(int(made[0]) <= 8, "never grew past capacity (%d made)" % int(made[0]))


# ------------------------------------------------------------------ saves & rewards

func _fresh_store() -> SaveStore:
	var store := SaveStore.new(TEST_SAVE)
	store.delete_all()
	return store


func test_reward_idempotent() -> void:
	var store := _fresh_store()
	var wallet := Wallet.new(store)
	check(wallet.credit("run:1:base", 25), "first credit")
	check(not wallet.credit("run:1:base", 25), "duplicate rejected")
	check(wallet.balance() == 25, "credited once")
	check(not wallet.credit("", 10) and not wallet.credit("x", 0), "invalid credits rejected")
	check(wallet.unlock("car_hatch", 20) and wallet.balance() == 5, "unlock spends")
	check(not wallet.unlock("car_hatch", 20), "no double unlock")
	store.delete_all()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_save_recovery() -> void:
	var store := _fresh_store()
	check(store.load_save() == "new", "fresh install is new")
	store.data["coins"] = 5
	check(store.save(), "save ok")
	var again := SaveStore.new(TEST_SAVE)
	check(again.load_save() == "ok" and again.get_int("coins") == 5, "current version loads")

	# Previous version migrates.
	_write(TEST_SAVE, SaveStore.make_envelope({"best": 99, "car": "car_hatch", "coins": 3}, 1))
	var migrated := SaveStore.new(TEST_SAVE)
	check(migrated.load_save() == "migrated", "v1 migrates")
	check(migrated.get_int("best_score") == 99 and str(migrated.data["equipped"]) == "car_hatch", "v1 fields mapped")
	check((migrated.data["unlocked"] as Array).has("car_hatch"), "v1 car unlocked")

	# Truncated primary recovers from last-good backup.
	var s2 := _fresh_store()
	s2.data["coins"] = 40
	s2.save()
	s2.data["coins"] = 41
	s2.save()  # backup now holds 40, primary 41
	var text := FileAccess.get_file_as_string(TEST_SAVE)
	_write(TEST_SAVE, text.substr(0, text.length() / 2))
	var recovered := SaveStore.new(TEST_SAVE)
	check(recovered.load_save() == "recovered_backup", "truncated -> backup")
	check(recovered.get_int("coins") == 40, "backup value restored")

	# Tampered checksum counts as corrupt; both files corrupt resets.
	_write(TEST_SAVE, "{\"schema_version\":2,\"payload\":\"{\\\"coins\\\":9999}\",\"checksum\":\"bad\"}")
	_write(TEST_SAVE + ".bak", "garbage")
	var reset := SaveStore.new(TEST_SAVE)
	check(reset.load_save() == "reset_corrupt", "corrupt both -> reset")
	check(reset.get_int("coins") == 0, "reset gives defaults")
	reset.delete_all()


func test_reward_gate() -> void:
	var gate := RewardGate.new()
	check(not gate.try_claim("r1", "revive"), "no claim without open offer")
	gate.open_offer("r1", "revive", "revive")
	check(gate.try_claim("r1", "revive"), "earned claims once")
	check(not gate.try_claim("r1", "revive"), "duplicate callback rejected")
	gate.open_offer("r1", "double", "double")
	gate.close_offer("r1", "double")  # dismissed
	check(not gate.try_claim("r1", "double"), "dismissal earns nothing")
	gate.open_offer("r2", "revive", "revive")
	check(not gate.try_claim("r1", "revive"), "stale run rejected")
	check(gate.try_claim("r2", "revive"), "new run claim ok")


# ------------------------------------------------------------------ pursuit

func test_capture_resolver() -> void:
	var c := CaptureResolver.new()
	c.configure(4.0, 9.0, 3.0)
	var fired := [0]
	c.captured.connect(func() -> void: fired[0] += 1)
	for i in 29:
		c.update(0.1, 2.0, 5.0)
	check(int(fired[0]) == 0, "not captured before 3 s")
	c.update(0.2, 2.0, 5.0)
	check(int(fired[0]) == 1, "captured at 3 s")
	c.update(0.5, 2.0, 5.0)
	check(int(fired[0]) == 1, "fires once")
	c.reset()
	for i in 20:
		c.update(0.1, 2.0, 5.0)
	c.update(0.1, 10.0, 5.0)
	check(c.progress == 0.0, "speeding up cancels")
	for i in 20:
		c.update(0.1, 2.0, 5.0)
	c.update(0.1, 2.0, 20.0)
	check(c.progress == 0.0, "distance cancels")
	# 30 scripted chase patterns: capture iff 3 continuous seconds of both conditions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for chase in 30:
		var r := CaptureResolver.new()
		r.configure(4.0, 9.0, 3.0)
		var got := [false]
		r.captured.connect(func() -> void: got[0] = true)
		var streak := 0.0
		var expected := false
		for step in 200:
			var slow := rng.randf() < 0.85
			var near := rng.randf() < 0.85
			r.update(0.05, 2.0 if slow else 12.0, 5.0 if near else 30.0)
			streak = streak + 0.05 if (slow and near) else 0.0
			if streak >= 3.0:
				expected = true
		check(bool(got[0]) == expected, "scripted chase %d" % chase)


func test_run_session() -> void:
	var s := RunSession.new()
	check(not s.crash("wrecked"), "no crash from MENU")
	check(s.begin_run(false) and s.state == RunSession.State.COUNTDOWN, "countdown")
	check(s.pause() and s.state == RunSession.State.PAUSED, "pause")
	check(s.resume() and s.state == RunSession.State.COUNTDOWN, "resume to previous")
	check(s.start_running(), "running")
	check(s.crash("busted"), "crash")
	check(not s.crash("busted"), "duplicate crash rejected")
	check(s.offer_revive(), "revive offered")
	check(not s.apply_revive("other-run"), "wrong run id rejected")
	check(s.apply_revive(s.run_id), "revive applied")
	check(not s.apply_revive(s.run_id), "revive once")
	check(s.crash("wrecked"), "crash again")
	check(not s.can_offer_revive(), "no second revive")
	check(s.finish(1234) and s.state == RunSession.State.RESULTS, "results")
	check(s.begin_run(false), "retry from results")


## 500 spawn evaluations: accepted spawns are never in view or within 3 s of travel.
func test_spawn_fairness() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var police_speed := 20.0
	var g := LaneGraph.new(SeedService.new(77))
	var player_node := Vector2i(0, 0)
	var player_pos := g.node_world(player_node)
	var accepted := 0
	for i in 500:
		var n := Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		var pos := g.node_world(n)
		var in_view := rng.randf() < 0.4
		var travel := g.travel_distance(n, player_node)
		var exclusions := [player_pos, pos + Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))]
		var fair := PursuitDirector.is_spawn_fair(pos, player_pos, Vector3.FORWARD, travel, police_speed, 3.0, in_view, exclusions, 12.0)
		if fair:
			accepted += 1
			if in_view or travel < police_speed * 3.0 or pos.distance_to(player_pos) < police_speed * 3.0:
				check(false, "unfair spawn accepted at %s" % n)
				return
			for e in exclusions:
				if pos.distance_to(e) < 12.0:
					check(false, "spawn overlaps exclusion zone")
					return
			var to := pos - player_pos
			if to.length() < 110.0 and to.normalized().dot(Vector3.FORWARD) > 0.5:
				check(false, "spawn directly ahead")
				return
	check(accepted > 0, "some spawns accepted (%d)" % accepted)


# ------------------------------------------------------------------ monetization & services

func test_ad_policy() -> void:
	var p := AdPolicy.new()
	for i in 3:
		p.on_run_completed()
		check(not p.should_show_interstitial(10000.0 + i), "grace runs")
	p.on_run_completed()
	check(p.should_show_interstitial(10000.0), "eligible after grace")
	p.on_interstitial_shown(10000.0)
	for i in 3:
		p.on_run_completed()
	check(not p.should_show_interstitial(10100.0), "180 s minimum")
	check(p.should_show_interstitial(10200.0), "eligible after 3 runs + 180 s")
	p.on_interstitial_shown(10200.0)
	for i in 3:
		p.on_run_completed()
	p.on_rewarded_shown()
	check(not p.should_show_interstitial(20000.0), "none right after rewarded")
	p.ads_removed = true
	check(not p.should_show_interstitial(30000.0), "remove ads respected")


func test_telemetry_filter() -> void:
	var t := Telemetry.new()
	t.sink = func(_e: Dictionary) -> void: pass
	check(t.log_event("run_end", {"run_id": "1700-1", "score": 420, "failure_reason": "busted"}), "valid event")
	check(not t.log_event("run_end", {"failure_reason": "I crashed into Bob's house!"}), "free text rejected")
	check(not t.log_event("run_end", {"email": "a@b.c"}), "unknown key rejected")
	check(not t.log_event("chat", {}), "unknown event rejected")
	check(not t.log_event("run_start", {"seed": {"nested": 1}}), "non-scalar rejected")


func test_billing_entitlement() -> void:
	var billing := FakeBillingAdapter.new()
	billing.next_result = "pending"
	billing.purchase(BillingAdapter.PRODUCT_REMOVE_ADS)
	check(not billing.owned.has(BillingAdapter.PRODUCT_REMOVE_ADS), "pending grants nothing")
	billing.next_result = "cancelled"
	billing.purchase(BillingAdapter.PRODUCT_REMOVE_ADS)
	check(not billing.owned.has(BillingAdapter.PRODUCT_REMOVE_ADS), "cancel grants nothing")
	billing.next_result = "purchased"
	billing.purchase(BillingAdapter.PRODUCT_REMOVE_ADS)
	var token := str(billing.owned.get(BillingAdapter.PRODUCT_REMOVE_ADS, ""))
	check(billing.verify(BillingAdapter.PRODUCT_REMOVE_ADS, token), "completed purchase verifies")
	check(not billing.verify(BillingAdapter.PRODUCT_REMOVE_ADS, "forged"), "forged token rejected")
	var store := _fresh_store()
	check(store.grant_entitlement(BillingAdapter.PRODUCT_REMOVE_ADS), "grant once")
	check(not store.grant_entitlement(BillingAdapter.PRODUCT_REMOVE_ADS), "no double grant")
	store.delete_all()
	billing.free()


func test_score_contract() -> void:
	var s := ScoreService.new()
	s.tick(12.5, 600.0)
	s.add_escape()
	s.add_escape()
	check(s.score() == 12 * 10 + 2 * 150, "score formula (%d)" % s.score())
	check(s.distance_coins() == 2, "distance payout")
	s.tick(0.0, 1.0e6)
	check(s.distance_coins() == ScoreService.MAX_DISTANCE_COINS, "distance payout bounded")
	s.freeze()
	s.add_escape()
	s.add_coin()
	check(s.escapes == 2 and s.coins_collected == 0, "frozen rewards")


func test_input_dead_zone() -> void:
	check(InputRouter.apply_dead_zone(0.05, 0.08) == 0.0, "inside dead zone")
	check(is_equal_approx(InputRouter.apply_dead_zone(1.0, 0.08), 1.0), "full deflection")
	check(InputRouter.apply_dead_zone(-0.5, 0.08) < 0.0, "sign preserved")


## Render the procedural audio offline: every sample finite, no clipping, audible when it
## should be, silent when muted. Prints peak/RMS per section (we can't listen in CI).
func test_audio_offline() -> void:
	var a := SynthAudio.new()
	var sections := [
		["idle", 0.0, 0.0, 0.0],
		["cruise_14", 14.0, 0.0, 0.0],
		["top_22", 22.0, 0.0, 0.0],
		["siren_close", 18.0, 1.0, 0.0],
		["drift_skid", 16.0, 0.4, 1.0],
	]
	for sec in sections:
		a.engine_speed = float(sec[1])
		a.siren_level = float(sec[2])
		a.skid_level = float(sec[3])
		var stats := _audio_stats(a.synth(int(SynthAudio.MIX_RATE), 1.0))
		print("    audio %-12s peak=%.3f rms=%.3f" % [sec[0], stats[0], stats[1]])
		check(stats[2], "%s samples finite" % sec[0])
		check(stats[0] < 0.99, "%s does not clip" % sec[0])
		check(stats[1] > 0.01, "%s audible" % sec[0])
	a.muted = true
	var muted := _audio_stats(a.synth(2048, 0.1))
	check(muted[0] < 0.0001, "muted is silent")
	a.build_one_shots()
	for id in ["crash", "smash", "coin", "warning", "escape"]:
		var wav := a.one_shot(id)
		check(wav != null and wav.data.size() > 0, "one-shot %s exists" % id)
		var peak := 0
		for i in range(0, wav.data.size(), 2):
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
		print("    audio %-12s len=%.2fs peak=%.3f" % [id, wav.data.size() / 2.0 / SynthAudio.MIX_RATE, peak / 32767.0])
		check(peak > 1000 and peak < 32767, "one-shot %s level sane" % id)
	a.free()


func _audio_stats(buf: PackedVector2Array) -> Array:
	var peak := 0.0
	var sum := 0.0
	var finite := true
	for v in buf:
		if is_nan(v.x) or is_inf(v.x):
			finite = false
		peak = maxf(peak, absf(v.x))
		sum += v.x * v.x
	return [peak, sqrt(sum / maxf(1.0, buf.size())), finite]
