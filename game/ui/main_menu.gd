class_name MainMenu
extends UiScreen

signal play_pressed
signal garage_pressed
signal settings_pressed


func open_screen() -> void:
	clear()
	var bg := UiKit.dim_background(self, 0.3)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var title := UiKit.label("ESCAPE", 112, Color("ffe066"))
	title.add_theme_constant_override("outline_size", 18)
	col.add_child(title)
	var title2 := UiKit.label("CITY", 112, Color("ff6b4a"))
	title2.add_theme_constant_override("outline_size", 18)
	col.add_child(title2)
	col.add_child(UiKit.label("How long can you outrun the police?", 28, Color(0.92, 0.94, 1.0)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)

	# Stats strip: best score and coins.
	var strip_center := CenterContainer.new()
	col.add_child(strip_center)
	var strip := PanelContainer.new()
	var ssb := UiKit.card_box(Color(0.05, 0.07, 0.12, 0.72))
	ssb.content_margin_top = 14
	ssb.content_margin_bottom = 14
	strip.add_theme_stylebox_override("panel", ssb)
	strip_center.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	strip.add_child(row)
	row.add_child(UiKit.label("BEST", 22, Color(1, 1, 1, 0.6)))
	row.add_child(UiKit.label(str(DashCore.save_store.get_int("best_score")), 30))
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.2)
	sep.custom_minimum_size = Vector2(2, 34)
	row.add_child(sep)
	row.add_child(UiKit.coin_icon(28))
	row.add_child(UiKit.label(str(DashCore.wallet.balance()), 30, Color("ffd23f")))

	var buttons := CenterContainer.new()
	col.add_child(buttons)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 16)
	buttons.add_child(bcol)
	var play := UiKit.button("PLAY", play_pressed.emit, Vector2(460, 124))
	play.add_theme_font_size_override("font_size", 48)
	bcol.add_child(play)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 16)
	brow.add_child(UiKit.secondary(UiKit.button("GARAGE", garage_pressed.emit, Vector2(222, 96))))
	brow.add_child(UiKit.secondary(UiKit.button("SETTINGS", settings_pressed.emit, Vector2(222, 96))))
	bcol.add_child(brow)
	if DashCore.consent.privacy_options_required():
		var privacy := UiKit.button("Privacy options", DashCore.consent.show_privacy_options, Vector2(260, 96))
		privacy.flat = true
		privacy.add_theme_font_size_override("font_size", 22)
		privacy.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		bcol.add_child(privacy)
	super.open_screen()
	UiKit.pulse(play)
