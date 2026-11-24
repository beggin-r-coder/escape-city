class_name MainMenu
extends UiScreen

signal play_pressed
signal garage_pressed
signal settings_pressed


func open_screen() -> void:
	clear()
	var bg := UiKit.dim_background(self, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UiKit.centered_column(self, 16)
	col.add_child(UiKit.label("ESCAPE CITY", 88, Color("ffe066")))
	col.add_child(UiKit.label("How long can you outrun the police?", 30, Color(0.9, 0.92, 1.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)
	var store := DashCore.save_store
	col.add_child(UiKit.label("Best %d    |    %d coins" % [store.get_int("best_score"), DashCore.wallet.balance()], 28))
	var play := UiKit.button("PLAY", play_pressed.emit, Vector2(420, 110))
	play.add_theme_font_size_override("font_size", 40)
	col.add_child(play)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiKit.button("GARAGE", garage_pressed.emit, Vector2(200, 96)))
	row.add_child(UiKit.button("SETTINGS", settings_pressed.emit, Vector2(200, 96)))
	col.add_child(row)
	if DashCore.consent.privacy_options_required():
		var privacy := UiKit.button("Privacy options", DashCore.consent.show_privacy_options, Vector2(300, 96))
		privacy.add_theme_font_size_override("font_size", 22)
		col.add_child(privacy)
	super.open_screen()
