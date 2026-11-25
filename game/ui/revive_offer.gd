class_name ReviveOffer
extends UiScreen
## One optional revive per run, via rewarded ad. Auto-declines after a short timer.

signal revive_pressed
signal declined

const TIMEOUT := 7.0

var _t: float = 0.0
var _timer_label: Label
var _busy: bool = false


func open_with(reason: String) -> void:
	clear()
	_busy = false
	UiKit.dim_background(self, 0.6)
	var col := UiKit.centered_column(self, 16)
	col.add_child(UiKit.label(reason_title(reason), 72, Color("ff6b5a")))
	col.add_child(UiKit.label(reason_hint(reason), 26, Color(0.9, 0.9, 0.95)))
	col.add_child(UiKit.button("REVIVE  (watch ad)", _on_revive, Vector2(460, 104)))
	col.add_child(UiKit.secondary(UiKit.button("No thanks", declined.emit, Vector2(300, 96))))
	_timer_label = UiKit.label("", 24, Color(1, 1, 1, 0.6))
	col.add_child(_timer_label)
	_t = TIMEOUT
	open_screen()


func _process(delta: float) -> void:
	if not visible or _busy:
		return
	_t -= delta
	_timer_label.text = "%d" % int(ceil(maxf(_t, 0.0)))
	if _t <= 0.0:
		declined.emit()


static func reason_title(reason: String) -> String:
	match reason:
		"busted":
			return "BUSTED!"
		"wrecked":
			return "WRECKED!"
	return "GAME OVER"


static func reason_hint(reason: String) -> String:
	match reason:
		"busted":
			return "You slowed down next to the police for 3 seconds."
		"wrecked":
			return "Your car took too much damage from walls and rams."
	return ""


func _on_revive() -> void:
	_busy = true
	revive_pressed.emit()
