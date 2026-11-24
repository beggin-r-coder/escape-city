class_name CountdownOverlay
extends UiScreen
## 3-2-1 before driving. Pauses with the game (not PROCESS_MODE_ALWAYS).

signal finished

var _t: float = 0.0
var _label: Label


func _init() -> void:
	super._init()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start(seconds: float = 3.0) -> void:
	clear()
	_label = UiKit.label("3", 140, Color("ffe066"))
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_t = seconds
	open_screen()


func _process(delta: float) -> void:
	if not visible or _label == null:
		return
	_t -= delta
	if _t <= 0.0:
		close_screen()
		finished.emit()
		return
	_label.text = str(int(ceil(_t)))
