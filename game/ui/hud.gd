class_name Hud
extends CanvasLayer
## In-run HUD (portrait 720x1280): a top card with score, distance, coins, wanted stars and
## health; speed readout; brake pad and steer zones registered with the InputRouter; a red
## vignette when capture is building; pop-in banners. Touch targets >= 96 px.

signal pause_pressed

var router: InputRouter
var score_label: Label
var distance_label: Label
var coins_label: Label
var speed_label: Label
var health_bar: ProgressBar
var stars: HeatStars
var wave_label: Label
var pause_button: Button
var brake_pad: Panel
var left_pad: Panel
var right_pad: Panel
var steer_hint: Label
var steer_indicator: SteerIndicator
var capture_box: VBoxContainer
var capture_bar: ProgressBar
var escape_box: VBoxContainer
var escape_bar: ProgressBar
var banner: Label
var arrows: PoliceArrows
var vignette: TextureRect
var _root: Control
var _brake_style: StyleBoxFlat
var _banner_t: float = 0.0
var _health_fill: StyleBoxFlat
var _last_score: int = -1
var _t: float = 0.0


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

	vignette = TextureRect.new()
	vignette.texture = _vignette_texture()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate = Color(1, 1, 1, 0)
	_root.add_child(vignette)

	arrows = PoliceArrows.new()
	_root.add_child(arrows)
	steer_indicator = SteerIndicator.new()
	steer_indicator.router = router
	_root.add_child(steer_indicator)

	# --- top card
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := UiKit.card_box(Color(0.05, 0.07, 0.12, 0.62))
	csb.set_corner_radius_all(26)
	csb.shadow_size = 10
	card.add_theme_stylebox_override("panel", csb)
	card.custom_minimum_size = Vector2(720.0 - left - right - 120.0, 128)
	_root.add_child(card)
	place(card, Vector2(0, 0), Vector2(left, top))

	score_label = UiKit.label("0", 50)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.custom_minimum_size = Vector2(240, 56)
	card.add_child(score_label)
	score_label.position = Vector2(24, 8)
	distance_label = UiKit.label("0 m", 22, Color(0.82, 0.86, 0.95))
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	distance_label.custom_minimum_size = Vector2(200, 26)
	card.add_child(distance_label)
	distance_label.position = Vector2(26, 64)
	var coin := UiKit.coin_icon(24)
	card.add_child(coin)
	coin.position = Vector2(140, 66)
	coins_label = UiKit.label("0", 22, Color("ffd23f"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coins_label.custom_minimum_size = Vector2(80, 26)
	card.add_child(coins_label)
	coins_label.position = Vector2(172, 64)

	var wanted := UiKit.label("WANTED", 16, Color(1, 1, 1, 0.55))
	wanted.custom_minimum_size = Vector2(190, 18)
	card.add_child(wanted)
	wanted.position = Vector2(card.custom_minimum_size.x - 214, 12)
	stars = HeatStars.new()
	card.add_child(stars)
	stars.custom_minimum_size = Vector2(190, 30)
	stars.size = stars.custom_minimum_size
	stars.position = Vector2(card.custom_minimum_size.x - 214, 34)
	wave_label = UiKit.label("", 16, Color(0.75, 0.88, 1.0))
	wave_label.custom_minimum_size = Vector2(190, 20)
	card.add_child(wave_label)
	wave_label.position = Vector2(card.custom_minimum_size.x - 214, 66)

	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.max_value = 1.0
	health_bar.step = 0.0
	health_bar.value = 1.0
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_fill = StyleBoxFlat.new()
	_health_fill.bg_color = Color("54d16b")
	_health_fill.set_corner_radius_all(5)
	var hbg := StyleBoxFlat.new()
	hbg.bg_color = Color(1, 1, 1, 0.12)
	hbg.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("fill", _health_fill)
	health_bar.add_theme_stylebox_override("background", hbg)
	card.add_child(health_bar)
	health_bar.position = Vector2(24, 102)
	health_bar.size = Vector2(card.custom_minimum_size.x - 48, 10)

	pause_button = UiKit.button("II", pause_pressed.emit, UiKit.TOUCH_MIN)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.add_theme_font_size_override("font_size", 36)
	for st in ["normal", "hover", "pressed", "focus"]:
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.05, 0.07, 0.12, 0.62 if st != "pressed" else 0.85)
		psb.set_corner_radius_all(46)
		psb.corner_detail = 16
		psb.border_color = Color(1, 1, 1, 0.3)
		psb.set_border_width_all(3)
		pause_button.add_theme_stylebox_override(st, psb)
	_root.add_child(pause_button)
	place(pause_button, Vector2(1.0, 0.0), Vector2(-right - UiKit.TOUCH_MIN.x, top + 16))
	router.add_exclusion(pause_button)

	# --- bottom controls
	brake_pad = _pad("BRAKE", Vector2(220, 220), Color(0.9, 0.2, 0.2, 0.3))
	_brake_style = brake_pad.get_theme_stylebox("panel") as StyleBoxFlat
	place(brake_pad, Vector2(1.0, 1.0), Vector2(-right - 230, -bottom - 250))
	router.set_zone(&"brake", brake_pad)
	left_pad = _pad("<", Vector2(170, 170), Color(1, 1, 1, 0.16))
	place(left_pad, Vector2(0.0, 1.0), Vector2(left + 10, -bottom - 220))
	right_pad = _pad(">", Vector2(170, 170), Color(1, 1, 1, 0.16))
	place(right_pad, Vector2(0.0, 1.0), Vector2(left + 200, -bottom - 220))
	router.set_zone(&"left", left_pad)
	router.set_zone(&"right", right_pad)

	speed_label = UiKit.label("0 km/h", 30)
	speed_label.custom_minimum_size = Vector2(220, 36)
	_root.add_child(speed_label)
	place(speed_label, Vector2(1.0, 1.0), Vector2(-right - 230, -bottom - 290))

	steer_hint = UiKit.label("drag here to steer", 22, Color(1, 1, 1, 0.4))
	steer_hint.custom_minimum_size = Vector2(300, 30)
	_root.add_child(steer_hint)
	place(steer_hint, Vector2(0.0, 1.0), Vector2(left + 20, -bottom - 70))

	# --- threats and banners
	capture_box = VBoxContainer.new()
	capture_box.custom_minimum_size = Vector2(440, 70)
	capture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(capture_box)
	place(capture_box, Vector2(0.5, 0.5), Vector2(-220, 60))
	capture_box.add_child(UiKit.label("SPEED UP! GETTING BUSTED", 28, Color("ff4d4d")))
	capture_bar = _bar(Color("ff4d4d"))
	capture_box.add_child(capture_bar)
	capture_box.visible = false

	escape_box = VBoxContainer.new()
	escape_box.custom_minimum_size = Vector2(300, 50)
	escape_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(escape_box)
	place(escape_box, Vector2(0.5, 0.0), Vector2(-150, top + 160))
	escape_box.add_child(UiKit.label("LOSING THEM...", 22, Color("7fe0ff")))
	escape_bar = _bar(Color("7fe0ff"))
	escape_box.add_child(escape_bar)
	escape_box.visible = false

	banner = UiKit.label("", 56, Color("ffe066"))
	banner.custom_minimum_size = Vector2(640, 70)
	banner.visible = false
	_root.add_child(banner)
	place(banner, Vector2(0.5, 0.5), Vector2(-320, -200))
	banner.pivot_offset = banner.custom_minimum_size * 0.5
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


static func _vignette_texture() -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 128
	t.height = 228
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.1, 0.1, 0.0))
	g.set_color(1, Color(1, 0.1, 0.1, 0.75))
	g.add_point(0.6, Color(1, 0.1, 0.1, 0.0))
	t.gradient = g
	return t


func _pad(text: String, size: Vector2, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size.x * 0.5) - 2)
	sb.corner_detail = 16
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var l := UiKit.label(text, 30, Color(1, 1, 1, 0.85))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	_root.add_child(p)
	return p


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(260, 14)
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
	steer_indicator.visible = not buttons


func set_gameplay_visible(value: bool) -> void:
	_root.visible = value


func update_stats(score: int, distance: float, coins: int, health_ratio: float, band: int, pressure: bool) -> void:
	if score != _last_score:
		score_label.text = str(score)
		_last_score = score
	distance_label.text = "%d m" % int(distance)
	coins_label.text = str(coins)
	health_bar.value = health_ratio
	_health_fill.bg_color = Color("54d16b") if health_ratio > 0.5 else (Color("f2c230") if health_ratio > 0.25 else Color("ff4d4d"))
	stars.set_level(band + 1)
	wave_label.text = "" if pressure else "COOL DOWN"


func update_speed(mps: float) -> void:
	speed_label.text = "%d km/h" % int(round(mps * 3.6))


func update_threats(capture_ratio: float, escape_ratio: float) -> void:
	capture_box.visible = capture_ratio > 0.0
	capture_bar.value = capture_ratio
	escape_box.visible = escape_ratio > 0.0
	escape_bar.value = escape_ratio
	var pulse := 0.75 + 0.25 * sin(_t * 12.0)
	vignette.modulate.a = clampf(capture_ratio * 1.2, 0.0, 1.0) * pulse


func show_banner(text: String, seconds: float = 1.6) -> void:
	banner.text = text
	banner.visible = true
	_banner_t = seconds
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	var tw := banner.create_tween().set_parallel()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)


func _process(delta: float) -> void:
	_t += delta
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			banner.visible = false
	if _brake_style != null and router != null:
		var held := router.is_brake_held()
		_brake_style.bg_color = Color(1.0, 0.25, 0.2, 0.62) if held else Color(0.9, 0.2, 0.2, 0.3)
		_brake_style.border_color = Color(1, 1, 1, 0.85 if held else 0.4)
