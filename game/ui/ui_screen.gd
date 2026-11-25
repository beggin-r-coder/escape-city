class_name UiScreen
extends Control
## Base for full-screen menus. Runs while the tree is paused and blocks touches
## from reaching gameplay.


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_screen() -> void:
	visible = true
	# Fade + slide in. Tweens bound to this node keep running while the tree is paused.
	modulate.a = 0.0
	position.y = 24.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_screen() -> void:
	visible = false


func clear() -> void:
	for c in get_children():
		c.queue_free()
