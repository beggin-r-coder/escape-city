extends SceneTree
## Boots the real game, starts a run and plays it with scripted input for ~40 s of game
## time (fixed 60 FPS), cycling steering and braking. Prints a summary; CI fails the job if
## any SCRIPT ERROR appears in the output.
##   godot --headless --fixed-fps 60 --path . -s res://tests/smoke_run.gd

const TOTAL_FRAMES := 2400

var _frame: int = 0
var _app: Node


func _initialize() -> void:
	if root.get_node_or_null("DashCore") == null:
		var dc: Node = load("res://addons/dashcore/dashcore.gd").new()
		dc.name = "DashCore"
		root.add_child(dc)
	var scene := load("res://game/scenes/main.tscn") as PackedScene
	_app = scene.instantiate()
	root.add_child(_app)


func _process(_delta: float) -> bool:
	_frame += 1
	var dash = root.get_node("DashCore")
	if _frame == 20:
		dash.save_store.data["tutorial_done"] = true
		_app.call("_on_play")
	if _frame > 220:
		# Weave: steer left/right in alternating 1.5 s blocks, brake-drift every 6 s.
		var phase := (_frame / 90) % 2
		Input.action_release(&"steer_left")
		Input.action_release(&"steer_right")
		Input.action_press(&"steer_left" if phase == 0 else &"steer_right")
		if _frame % 360 < 40:
			Input.action_press(&"brake")
		else:
			Input.action_release(&"brake")
	if _frame % 600 == 0 or _frame == TOTAL_FRAMES:
		var run: Node = _app.get("run_root")
		var session: RunSession = run.get("session")
		var score: ScoreService = run.get("score")
		var world: StreamingWorld = run.get("world")
		var director: PursuitDirector = run.get("director")
		print("frame %d state=%s score=%d dist=%.0f cells=%d police=%d traffic=%d pools_ok=%s" % [
			_frame, RunSession.state_name(session.state), score.score(), score.distance,
			world.active_cell_count(), director.police().size(),
			(run.get("traffic") as TrafficManager).agents().size(),
			(run.get("pool") as ChunkPool).validate().is_empty()])
		var state := session.state
		if state == RunSession.State.CRASHED or state == RunSession.State.REVIVE_PENDING or state == RunSession.State.RESULTS:
			print("run ended: ", session.failure_reason)
	if _frame >= TOTAL_FRAMES:
		print("SMOKE DONE")
		return true
	return false
