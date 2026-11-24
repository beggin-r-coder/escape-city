class_name Hud
extends CanvasLayer
## In-run HUD: score/distance, essential status, pause. Brake pad and steer buttons are
## visual zones registered with the InputRouter. Touch targets >= 96 px at 1280x720.

signal pause_pressed

var router: InputRouter
var score_label: Label
var distance_label: Label
var coins_label: Label
var health_bar: ProgressBar
var heat_pips: Array[ColorRect] = []
var wave_label: Label
var pause_button: Button
var brake_pad: Panel
var left_pad: Panel
var right_pad: Panel
var steer_hint: Label
var capture_box: VBoxContainer
var capture_bar: ProgressBar
var escape_box: VBoxContainer
var escape_bar: ProgressBar
var banner: Label
var arrows: PoliceArrows
var _root: Control
var _banner_t: float = 0.0


func build(input_router: InputRouter) -> void:
	router = input_router
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var m := UiKit.safe_margins(_root.get_viewport())
	var left := float(m["left"])
	var top := float(m["top"])
	var right := float(m["right"])
	var bottom := float(m["bottom"])

	arrows = PoliceArrows.new()
	_root.add_child(arrows)

	var stats := VBoxContainer.new()
	stats.custom_minimum_size = Vector2(240, 100)
	stats.position = Vector2(left + 8, top + 4)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stats)
	score_label = UiKit.label("0", 44)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats.add_child(score_label)
	distance_label = UiKit.label("0 m", 24, Color(0.85, 0.88, 0.95))
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats.add_child(distance_label)
	coins_label = UiKit.label("0 coins", 24, ArtKit.COIN)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats.add_child(coins_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(220, 16)
	health_bar.show_percentage = false
	health_bar.max_value = 1.0
	health_bar.step = 0.0
	health_bar.value = 1.0
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("54d16b")
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", bg)
	stats.add_child(health_bar)

	var heat := HBoxContainer.new()
	heat.custom_minimum_size = Vector2(300, 30)
	place(heat, Vector2(0.5, 0.0), Vector2(-150, top + 10))
	heat.alignment = BoxContainer.ALIGNMENT_CENTER
	heat.add_theme_constant_override("separation", 8)
	heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(heat)
	var heat_label := UiKit.label("HEAT", 22, Color("ff8a5c"))
	heat.add_child(heat_label)
	for i in 6:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 22)
		pip.color = Color(1, 1, 1, 0.2)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heat.add_child(pip)
		heat_pips.append(pip)
	wave_label = UiKit.label("", 20, Color(0.8, 0.85, 1.0))
	wave_label.custom_minimum_size = Vector2(300, 24)
	_root.add_child(wave_label)
	place(wave_label, Vector2(0.5, 0.0), Vector2(-150, top + 44))

	pause_button = UiKit.button("II", pause_pressed.emit, UiKit.TOUCH_MIN)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(pause_button)
	place(pause_button, Vector2(1.0, 0.0), Vector2(-right - UiKit.TOUCH_MIN.x, top))
	router.add_exclusion(pause_button)

	brake_pad = _pad("BRAKE", Vector2(220, 220), Color(0.9, 0.2, 0.2, 0.28))
	place(brake_pad, Vector2(1.0, 1.0), Vector2(-right - 230, -bottom - 230))
	router.set_zone(&"brake", brake_pad)

	left_pad = _pad("<", Vector2(180, 180), Color(1, 1, 1, 0.16))
	place(left_pad, Vector2(0.0, 1.0), Vector2(left + 10, -bottom - 190))
	right_pad = _pad(">", Vector2(180, 180), Color(1, 1, 1, 0.16))
	place(right_pad, Vector2(0.0, 1.0), Vector2(left + 210, -bottom - 190))
	router.set_zone(&"left", left_pad)
	router.set_zone(&"right", right_pad)

	steer_hint = UiKit.label("drag to steer", 22, Color(1, 1, 1, 0.35))
	steer_hint.custom_minimum_size = Vector2(260, 30)
	_root.add_child(steer_hint)
	place(steer_hint, Vector2(0.0, 1.0), Vector2(left + 40, -bottom - 60))

	capture_box = VBoxContainer.new()
	capture_box.custom_minimum_size = Vector2(400, 60)
	capture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(capture_box)
	place(capture_box, Vector2(0.5, 0.5), Vector2(-200, 40))
	capture_box.add_child(UiKit.label("SPEED UP! GETTING BUSTED", 30, Color("ff4d4d")))
	capture_bar = _bar(Color("ff4d4d"))
	capture_box.add_child(capture_bar)
	capture_box.visible = false

	escape_box = VBoxContainer.new()
	escape_box.custom_minimum_size = Vector2(320, 50)
	escape_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(escape_box)
	place(escape_box, Vector2(0.5, 0.0), Vector2(-160, top + 80))
	escape_box.add_child(UiKit.label("LOSING THEM...", 22, Color("7fe0ff")))
	escape_bar = _bar(Color("7fe0ff"))
	escape_box.add_child(escape_bar)
	escape_box.visible = false

	banner = UiKit.label("", 52, Color("ffe066"))
	banner.custom_minimum_size = Vector2(600, 60)
	banner.visible = false
	_root.add_child(banner)
	place(banner, Vector2(0.5, 0.5), Vector2(-300, -140))
	set_layout(InputRouter.Layout.DRAG)


## Anchor a control to a point of the screen and offset it from there.
static func place(c: Control, anchor: Vector2, offset: Vector2) -> void:
	var size := c.custom_minimum_size
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _pad(text: String, size: Vector2, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size.x * 0.5))
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var l := UiKit.label(text, 30, Color(1, 1, 1, 0.8))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	_root.add_child(p)
	return p


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 14)
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func set_layout(layout: int) -> void:
	var buttons := layout == InputRouter.Layout.BUTTONS
	left_pad.visible = buttons
	right_pad.visible = buttons
	steer_hint.visible = not buttons


func set_gameplay_visible(value: bool) -> void:
	_root.visible = value


func update_stats(score: int, distance: float, coins: int, health_ratio: float, band: int, pressure: bool) -> void:
	score_label.text = str(score)
	distance_label.text = "%d m" % int(distance)
	coins_label.text = "%d coins" % coins
	health_bar.value = health_ratio
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color("54d16b") if health_ratio > 0.5 else (Color("f2c230") if health_ratio > 0.25 else Color("ff4d4d"))
	for i in heat_pips.size():
		heat_pips[i].color = Color("ff5a3c") if i <= band else Color(1, 1, 1, 0.2)
	wave_label.text = "" if pressure else "COOL DOWN"


func update_threats(capture_ratio: float, escape_ratio: float) -> void:
	capture_box.visible = capture_ratio > 0.0
	capture_bar.value = capture_ratio
	escape_box.visible = escape_ratio > 0.0
	escape_bar.value = escape_ratio


func show_banner(text: String, seconds: float = 1.6) -> void:
	banner.text = text
	banner.visible = true
	_banner_t = seconds


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			banner.visible = false
