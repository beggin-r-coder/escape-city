class_name FakeAdsAdapter
extends AdsAdapter
## Desktop/test ads. In "interactive" mode a TEST AD overlay lets the tester claim or
## dismiss. Scripted modes cover automated checks: earn, dismiss, no_fill, duplicate, timeout.

var mode: String = "interactive"
var _overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_rewarded_ready() -> bool:
	return can_request() and mode != "no_fill"


func is_interstitial_ready() -> bool:
	return can_request() and mode != "no_fill"


func show_rewarded(placement: String, run_id: String, offer_id: String) -> bool:
	if not is_rewarded_ready():
		rewarded_failed.emit(placement, run_id, offer_id, "no_fill")
		return false
	match mode:
		"earn":
			_emit_earned.call_deferred(placement, run_id, offer_id, 1)
		"duplicate":
			_emit_earned.call_deferred(placement, run_id, offer_id, 2)
		"dismiss":
			rewarded_closed.emit.call_deferred(placement, run_id, offer_id)
		"timeout":
			rewarded_failed.emit.call_deferred(placement, run_id, offer_id, "timeout")
		_:
			_show_overlay("TEST REWARDED AD\n(%s)" % placement, true, placement, run_id, offer_id)
	return true


func show_interstitial() -> bool:
	if not is_interstitial_ready():
		return false
	if mode == "interactive":
		_show_overlay("TEST INTERSTITIAL AD", false, "", "", "")
	else:
		interstitial_closed.emit.call_deferred()
	return true


func _emit_earned(placement: String, run_id: String, offer_id: String, times: int) -> void:
	for i in times:
		rewarded_earned.emit(placement, run_id, offer_id)
	rewarded_closed.emit(placement, run_id, offer_id)


func _show_overlay(title: String, rewarded: bool, placement: String, run_id: String, offer_id: String) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	bg.add_child(box)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	box.add_child(label)
	if rewarded:
		var claim := Button.new()
		claim.text = "Watch to end (earn reward)"
		claim.custom_minimum_size = Vector2(420, 96)
		claim.pressed.connect(_on_claim.bind(placement, run_id, offer_id))
		box.add_child(claim)
	var close := Button.new()
	close.text = "Close ad" if rewarded else "Close"
	close.custom_minimum_size = Vector2(420, 96)
	close.pressed.connect(_on_close.bind(rewarded, placement, run_id, offer_id))
	box.add_child(close)
	box.position -= Vector2(210, 160)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _on_claim(placement: String, run_id: String, offer_id: String) -> void:
	_close_overlay()
	_emit_earned(placement, run_id, offer_id, 1)


func _on_close(rewarded: bool, placement: String, run_id: String, offer_id: String) -> void:
	_close_overlay()
	if rewarded:
		rewarded_closed.emit(placement, run_id, offer_id)
	else:
		interstitial_closed.emit()
