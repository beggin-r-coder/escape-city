class_name PauseMenu
extends UiScreen

signal resume_pressed
signal retry_pressed
signal settings_pressed
signal menu_pressed


func open_screen() -> void:
	clear()
	UiKit.dim_background(self, 0.65)
	var col := UiKit.centered_column(self, 16)
	col.add_child(UiKit.label("PAUSED", 64))
	col.add_child(UiKit.button("RESUME", resume_pressed.emit))
	col.add_child(UiKit.button("RETRY", retry_pressed.emit))
	col.add_child(UiKit.button("SETTINGS", settings_pressed.emit))
	col.add_child(UiKit.button("MENU", menu_pressed.emit))
	super.open_screen()
