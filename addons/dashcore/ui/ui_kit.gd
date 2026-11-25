class_name UiKit
extends RefCounted
## Reusable UI builders. Games supply colors through `make_theme`.

const TOUCH_MIN := Vector2(96, 96)  # ~48dp at the 720x1280 design resolution on phones


static func make_theme(accent: Color, panel: Color, text: Color) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 28
	# Chunky "3D" buttons: a darker lip at the bottom that shrinks when pressed.
	theme.set_stylebox("normal", "Button", _button_box(accent, 7))
	theme.set_stylebox("hover", "Button", _button_box(accent.lightened(0.08), 7))
	theme.set_stylebox("focus", "Button", _button_box(accent.lightened(0.08), 7))
	theme.set_stylebox("pressed", "Button", _button_box(accent.darkened(0.12), 2))
	theme.set_stylebox("disabled", "Button", _button_box(Color(0.32, 0.33, 0.38, 0.9), 4))
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text.darkened(0.45))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.35))
	theme.set_constant("outline_size", "Button", 4)
	theme.set_stylebox("panel", "PanelContainer", card_box(panel))
	theme.set_color("font_color", "Label", text)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = accent
	grabber.set_corner_radius_all(10)
	theme.set_stylebox("slider", "HSlider", _flat(Color(1, 1, 1, 0.15), 6, 8))
	theme.set_stylebox("grabber_area", "HSlider", _flat(accent, 6, 8))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(accent.lightened(0.1), 6, 8))
	return theme


static func _button_box(color: Color, lip: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.border_width_bottom = lip
	sb.border_color = color.darkened(0.38)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14 + (7 - lip)
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _flat(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


## Dark translucent card with a soft shadow and hairline border.
static func card_box(color: Color = Color(0.06, 0.08, 0.13, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(28)
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	return sb


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


## Centered card containing a vertical column; returns the column.
static func card_column(parent: Control, separation: int = 16, min_width: float = 560.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", separation)
	card.add_child(col)
	return col


## Gold coin icon (no font glyph needed).
static func coin_icon(size: float = 26.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffd23f")
	sb.border_color = Color("c98a10")
	sb.set_border_width_all(maxi(2, int(size / 9.0)))
	sb.set_corner_radius_all(int(size * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	return p


## Label + value row for stat lists.
static func stat_row(title: String, value: String, value_color: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	var t := label(title, 24, Color(1, 1, 1, 0.65))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var v := label(value, 26, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row


## Soft looping "breathing" scale on a control (e.g. the PLAY button).
static func pulse(c: Control, amount: float = 0.04, seconds: float = 0.9) -> void:
	c.pivot_offset = c.custom_minimum_size * 0.5
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_SINE)


static func label(text: String, size: int = 28, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Word-wrap a label to a fixed width (narrow portrait screens).
static func wrapped(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = Vector2(360, 96)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_size.x, TOUCH_MIN.x), maxf(min_size.y, TOUCH_MIN.y))
	b.focus_mode = Control.FOCUS_NONE
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


## Lower-emphasis button (dark, outlined) for secondary choices like "No thanks".
static func secondary(b: Button) -> Button:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := _button_box(Color(0.2, 0.24, 0.33, 0.95) if st != "pressed" else Color(0.16, 0.19, 0.26, 1.0), 2 if st == "pressed" else 7)
		sb.border_color = Color(0.09, 0.11, 0.16, 1.0)
		b.add_theme_stylebox_override(st, sb)
	return b


static func centered_column(parent: Control, separation: int = 18) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", separation)
	center.add_child(col)
	return col


static func dim_background(parent: Control, alpha: float = 0.6) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(bg)
	return bg


static func slider_row(title: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := label(title, 26)
	l.custom_minimum_size = Vector2(210, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(340, 56)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


## Margins that keep UI out of notches / rounded corners, in viewport coordinates.
static func safe_margins(viewport: Viewport) -> Dictionary:
	var out := {"left": 16.0, "top": 16.0, "right": 16.0, "bottom": 16.0}
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return out
	var vp := viewport.get_visible_rect().size
	var sx := vp.x / float(screen.x)
	var sy := vp.y / float(screen.y)
	out["left"] = maxf(16.0, safe.position.x * sx)
	out["top"] = maxf(16.0, safe.position.y * sy)
	out["right"] = maxf(16.0, (screen.x - safe.end.x) * sx)
	out["bottom"] = maxf(16.0, (screen.y - safe.end.y) * sy)
	return out
