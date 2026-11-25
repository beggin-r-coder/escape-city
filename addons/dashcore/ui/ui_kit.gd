class_name UiKit
extends RefCounted
## Reusable UI builders. Games supply colors through `make_theme`.

const TOUCH_MIN := Vector2(96, 96)  # ~48dp at the 720x1280 design resolution on phones


static func make_theme(accent: Color, panel: Color, text: Color) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 28
	var normal := _box(accent.darkened(0.15), 14)
	var hover := _box(accent, 14)
	var pressed := _box(accent.darkened(0.35), 14)
	var disabled := _box(Color(0.3, 0.3, 0.33, 0.8), 14)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = normal
		match state_name:
			"hover": sb = hover
			"pressed": sb = pressed
			"disabled": sb = disabled
			"focus": sb = hover
		theme.set_stylebox(state_name, "Button", sb)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text.darkened(0.4))
	theme.set_stylebox("panel", "PanelContainer", _box(panel, 20))
	theme.set_color("font_color", "Label", text)
	return theme


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


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
		var sb := _box(Color(0.1, 0.12, 0.18, 0.85) if st != "pressed" else Color(0.18, 0.2, 0.26, 0.95), 14)
		sb.border_color = Color(1, 1, 1, 0.3)
		sb.set_border_width_all(2)
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
	l.custom_minimum_size = Vector2(260, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(360, 56)
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
