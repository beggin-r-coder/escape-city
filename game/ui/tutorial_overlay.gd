class_name TutorialOverlay
extends UiScreen
## Safe first-run sequence that teaches one action at a time:
## 1) steer both ways, 2) brake, 3) drift (brake + steer), 4) the pursuit goal.

signal step_changed(step: int)
signal completed

const STEPS := [
	"Drag your LEFT thumb left and right to steer",
	"Hold BRAKE (right side) to slow down",
	"Hold BRAKE and steer to DRIFT around a corner",
	"Police incoming! Break line of sight and get far away to ESCAPE",
]

var step: int = 0
var _label: Label
var _hold: float = 0.0


func _init() -> void:
	super._init()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start() -> void:
	clear()
	step = 0
	_hold = 0.0
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = 300
	panel.offset_bottom = 400
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.75)
	sb.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	_label = UiKit.label(STEPS[0], 28)
	_label.custom_minimum_size = Vector2(600, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_label)
	open_screen()
	step_changed.emit(step)


## Called every physics frame by RunRoot with the player's current state.
func observe(player: PlayerCar, delta: float) -> void:
	if not visible:
		return
	var done := false
	match step:
		0:
			done = player.steer_used.x > 0.0 and player.steer_used.y > 0.0
		1:
			if player.braking and not player.drifting:
				_hold += delta
			done = _hold > 0.6
		2:
			done = player.drift_time > 0.8
		3:
			_hold += delta
			done = _hold > 3.5
	if done:
		_advance()


func _advance() -> void:
	step += 1
	_hold = 0.0
	if step >= STEPS.size():
		close_screen()
		completed.emit()
		return
	_label.text = STEPS[step]
	step_changed.emit(step)
