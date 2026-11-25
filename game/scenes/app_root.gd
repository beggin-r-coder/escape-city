extends Node
## AppRoot / Bootstrap: load settings, migrate save, resolve platform services (DashCore),
## open the menu, and route between screens. Gameplay lives in RunRoot.

var run_root: RunRoot
var ui: Control
var main_menu: MainMenu
var countdown: CountdownOverlay
var tutorial: TutorialOverlay
var pause_menu: PauseMenu
var revive_offer: ReviveOffer
var results: ResultsScreen
var settings: SettingsMenu
var garage: Garage
var toast: Label
var _settings_return: UiScreen
var _toast_t: float = 0.0


var flags: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	flags = DevFlags.parse(OS.get_cmdline_user_args())
	var save_path := ""
	if flags.has("fresh"):
		save_path = DevFlags.FRESH_SAVE
		DevFlags.delete_save(save_path)
	DashCore.boot(save_path)
	run_root = RunRoot.new()
	run_root.name = "RunRoot"
	run_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run_root)
	_build_ui()
	run_root.tutorial = tutorial
	run_root.crashed_ready.connect(_on_crashed_ready)
	run_root.hud.pause_pressed.connect(_pause)
	DashCore.ads.rewarded_earned.connect(_on_rewarded_earned)
	DashCore.ads.rewarded_closed.connect(_on_rewarded_closed)
	DashCore.ads.rewarded_failed.connect(_on_rewarded_failed)
	DashCore.save_recovered.connect(func(msg: String) -> void: show_toast(msg, 5.0))
	DashCore.entitlements_changed.connect(_on_entitlements_changed)
	if DashCore.save_store.last_load_status == "recovered_backup" or DashCore.save_store.last_load_status == "reset_corrupt":
		show_toast("Save data was damaged and has been recovered.", 5.0)
	_go_menu()
	if DevFlags.wants_harness(flags):
		var harness := DevHarness.new()
		harness.name = "DevHarness"
		add_child(harness)
		harness.start(self, flags)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiKit.make_theme(Color("e8463a"), Color(0.07, 0.09, 0.14, 0.92), Color("f6f3ec"))
	layer.add_child(ui)

	main_menu = MainMenu.new()
	ui.add_child(main_menu)
	main_menu.play_pressed.connect(_on_play)
	main_menu.garage_pressed.connect(func() -> void: _open_from(main_menu, garage))
	main_menu.settings_pressed.connect(func() -> void: _open_settings(main_menu))

	countdown = CountdownOverlay.new()
	ui.add_child(countdown)
	countdown.finished.connect(func() -> void: run_root.begin_driving())

	tutorial = TutorialOverlay.new()
	ui.add_child(tutorial)
	tutorial.step_changed.connect(_on_tutorial_step)
	tutorial.completed.connect(func() -> void: run_root.complete_tutorial())

	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
	pause_menu.resume_pressed.connect(_resume)
	pause_menu.retry_pressed.connect(_retry_from_pause)
	pause_menu.settings_pressed.connect(func() -> void: _open_settings(pause_menu))
	pause_menu.menu_pressed.connect(_menu_from_pause)

	revive_offer = ReviveOffer.new()
	ui.add_child(revive_offer)
	revive_offer.revive_pressed.connect(_on_revive_pressed)
	revive_offer.declined.connect(_show_results)

	results = ResultsScreen.new()
	ui.add_child(results)
	results.retry_pressed.connect(_retry_from_results)
	results.double_pressed.connect(_on_double_pressed)
	results.menu_pressed.connect(_menu_from_results)

	settings = SettingsMenu.new()
	ui.add_child(settings)
	settings.back_pressed.connect(_close_settings)
	settings.settings_changed.connect(func() -> void: run_root.apply_settings())

	garage = Garage.new()
	garage.catalog = run_root.catalog
	ui.add_child(garage)
	garage.back_pressed.connect(func() -> void: _open_from(garage, main_menu))
	garage.look_changed.connect(func() -> void: run_root.apply_equipped_look())

	toast = UiKit.label("", 24, Color("ffe9a8"))
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.offset_left = -500
	toast.offset_right = 500
	toast.offset_top = -90
	toast.offset_bottom = -40
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.visible = false
	ui.add_child(toast)


func show_toast(text: String, seconds: float = 2.5) -> void:
	toast.text = text
	toast.visible = true
	_toast_t = seconds


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.visible = false


func _hide_all() -> void:
	for s in [main_menu, countdown, tutorial, pause_menu, revive_offer, results, settings, garage]:
		(s as UiScreen).close_screen()


func _open_from(from: UiScreen, to: UiScreen) -> void:
	from.close_screen()
	to.open_screen()


func _open_settings(from: UiScreen) -> void:
	_settings_return = from
	from.close_screen()
	settings.open_screen()


func _close_settings() -> void:
	settings.close_screen()
	run_root.apply_settings()
	if _settings_return != null:
		_settings_return.open_screen()


# ---------------------------------------------------------------- flow

func _go_menu() -> void:
	get_tree().paused = false
	_hide_all()
	run_root.enter_preview()
	main_menu.open_screen()


func _on_play() -> void:
	_hide_all()
	_start_run()


func _start_run() -> void:
	get_tree().paused = false
	_hide_all()
	var first_run := not bool(DashCore.save_store.data.get("tutorial_done", false))
	if not run_root.start_run(first_run):
		push_warning("Could not start run from state %s" % RunSession.state_name(run_root.session.state))
		_go_menu()
		return
	if first_run:
		tutorial.start()
	else:
		countdown.start(3.0)


func _on_tutorial_step(step: int) -> void:
	DashCore.telemetry.log_event("tutorial_step", {"step": step})
	if step == 3:
		run_root.tutorial_spawn_police()


func _is_live_state() -> bool:
	var s := run_root.session.state
	return s == RunSession.State.RUNNING or s == RunSession.State.COUNTDOWN or s == RunSession.State.TUTORIAL


func _pause() -> void:
	if not _is_live_state():
		return
	if run_root.session.pause():
		get_tree().paused = true
		run_root.router.clear_all()
		pause_menu.open_screen()
		DashCore.save_store.save()


func _resume() -> void:
	if run_root.session.resume():
		pause_menu.close_screen()
		settings.close_screen()
		run_root.router.clear_all()  # held touches never carry over a pause
		get_tree().paused = false


func _retry_from_pause() -> void:
	pause_menu.close_screen()
	run_root.session.to_menu()
	DashCore.telemetry.log_event("retry", {"run_id": run_root.session.run_id})
	_start_run()


func _menu_from_pause() -> void:
	run_root.session.to_menu()
	_go_menu()


func _on_crashed_ready(reason: String) -> void:
	get_tree().paused = true
	var session := run_root.session
	var ads := DashCore.ads
	if DashCore.ad_policy.offers_enabled and session.can_offer_revive() and ads.is_rewarded_ready():
		session.offer_revive()
		revive_offer.open_with(reason)
		DashCore.telemetry.log_event("offer_seen", {"placement": "revive", "run_id": session.run_id})
	else:
		_show_results()


func _on_revive_pressed() -> void:
	var session := run_root.session
	DashCore.reward_gate.open_offer(session.run_id, "revive", "revive")
	if not DashCore.ads.show_rewarded("revive", session.run_id, "revive"):
		DashCore.reward_gate.close_offer(session.run_id, "revive")
		show_toast("No ad available right now.")
		_show_results()


func _on_double_pressed() -> void:
	var session := run_root.session
	DashCore.reward_gate.open_offer(session.run_id, "double", "double")
	DashCore.telemetry.log_event("offer_seen", {"placement": "double", "run_id": session.run_id})
	if not DashCore.ads.show_rewarded("double", session.run_id, "double"):
		DashCore.reward_gate.close_offer(session.run_id, "double")
		show_toast("No ad available right now.")
		results.reenable_double()


func _on_rewarded_earned(placement: String, run_id: String, offer_id: String) -> void:
	if not DashCore.reward_gate.try_claim(run_id, offer_id):
		return  # duplicate, stale or unknown callback
	DashCore.ad_policy.on_rewarded_shown()
	DashCore.telemetry.log_event("ad_reward", {"placement": placement, "run_id": run_id, "result": "earned"})
	if placement == "revive":
		if run_root.revive(run_id):
			revive_offer.close_screen()
			get_tree().paused = false
	elif placement == "double":
		var total := run_root.double_coins()
		if total > 0:
			results.mark_doubled(total)


func _on_rewarded_closed(placement: String, run_id: String, offer_id: String) -> void:
	if not DashCore.reward_gate.is_open(run_id, offer_id):
		return  # already claimed (normal close after reward) or unknown
	DashCore.reward_gate.close_offer(run_id, offer_id)  # dismissal earns nothing
	DashCore.telemetry.log_event("ad_reward", {"placement": placement, "run_id": run_id, "result": "dismissed"})
	if placement == "revive" and run_root.session.state == RunSession.State.REVIVE_PENDING:
		_show_results()
	elif placement == "double":
		results.reenable_double()


func _on_rewarded_failed(placement: String, run_id: String, offer_id: String, _reason: String) -> void:
	_on_rewarded_closed(placement, run_id, offer_id)


func _show_results() -> void:
	revive_offer.close_screen()
	var s := run_root.session.state
	if s != RunSession.State.CRASHED and s != RunSession.State.REVIVE_PENDING:
		return
	get_tree().paused = true
	var info := run_root.finish_run()
	var can_double := DashCore.ad_policy.offers_enabled and not run_root.session.rewarded_used \
		and DashCore.ads.is_rewarded_ready() and int(info["coins"]) > 0
	results.open_with(info, can_double)


## Interstitials only at results -> menu/retry boundaries, under AdPolicy limits.
func _through_boundary(next: Callable) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if DashCore.ad_policy.should_show_interstitial(now) and DashCore.ads.is_interstitial_ready():
		DashCore.ad_policy.on_interstitial_shown(now)
		if DashCore.ads.show_interstitial():
			await DashCore.ads.interstitial_closed
	next.call()


func _retry_from_results() -> void:
	results.close_screen()
	DashCore.telemetry.log_event("retry", {"run_id": run_root.session.run_id})
	_through_boundary(_start_run)


func _menu_from_results() -> void:
	results.close_screen()
	run_root.session.to_menu()
	_through_boundary(_go_menu)


func _on_entitlements_changed() -> void:
	if garage.visible:
		garage.open_screen()
	show_toast("Purchase restored/applied. Forced ads removed.")


# ---------------------------------------------------------------- platform lifecycle

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if run_root.session.state == RunSession.State.PAUSED:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Pause on focus loss; resuming never auto-resumes driving.
			if run_root != null:
				_pause()
				run_root.router.clear_all()
			if DashCore.save_store != null:
				DashCore.save_store.save()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if run_root == null:
				return
			if _is_live_state():
				_pause()
			elif run_root.session.state == RunSession.State.PAUSED:
				_resume()
			elif main_menu.visible:
				get_tree().quit()
