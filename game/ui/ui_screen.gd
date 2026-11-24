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


func close_screen() -> void:
	visible = false


func clear() -> void:
	for c in get_children():
		c.queue_free()
