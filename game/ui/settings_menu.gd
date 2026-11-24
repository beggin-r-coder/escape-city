class_name SettingsMenu
extends UiScreen
## Independent music/effects sliders, control layout, reduced motion, haptics, quality.

signal back_pressed
signal settings_changed


func open_screen() -> void:
	clear()
	UiKit.dim_background(self, 0.8)
	var col := UiKit.centered_column(self, 14)
	col.add_child(UiKit.label("SETTINGS", 56))
	var store := DashCore.save_store
	col.add_child(UiKit.slider_row("Music", float(store.get_setting("music_volume", 0.7)), _on_music))
	col.add_child(UiKit.slider_row("Effects", float(store.get_setting("sfx_volume", 0.9)), _on_sfx))
	col.add_child(_toggle("Controls", "control_layout", ["drag", "buttons"], ["Drag steer", "Left/Right buttons"]))
	col.add_child(_toggle("Quality", "quality", ["low", "high"], ["Low", "High"]))
	col.add_child(_toggle("Reduced motion", "reduced_motion", [false, true], ["Off", "On"]))
	col.add_child(_toggle("Haptics", "haptics", [true, false], ["On", "Off"]))
	col.add_child(UiKit.button("BACK", back_pressed.emit))
	super.open_screen()


func _toggle(title: String, key: String, values: Array, labels: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UiKit.label(title, 26)
	l.custom_minimum_size = Vector2(260, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(360, 80)
	b.focus_mode = Control.FOCUS_NONE
	var store := DashCore.save_store
	var refresh := func() -> void:
		var idx := values.find(store.get_setting(key, values[0]))
		b.text = str(labels[maxi(idx, 0)])
	refresh.call()
	var cycle := func() -> void:
		var idx := values.find(store.get_setting(key, values[0]))
		var next: Variant = values[(maxi(idx, 0) + 1) % values.size()]
		store.set_setting(key, next)
		refresh.call()
		settings_changed.emit()
	b.pressed.connect(cycle)
	row.add_child(b)
	return row


func _on_music(v: float) -> void:
	DashCore.save_store.set_setting("music_volume", v)
	DashCore.apply_audio_settings()


func _on_sfx(v: float) -> void:
	DashCore.save_store.set_setting("sfx_volume", v)
	DashCore.apply_audio_settings()
