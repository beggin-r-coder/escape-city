class_name PauseMenu
extends UiScreen

signal resume_pressed
signal retry_pressed
signal settings_pressed
signal menu_pressed


func open_screen() -> void:
	clear()
	UiKit.dim_background(self, 0.6)
	var col := UiKit.card_column(self, 16, 480.0)
	col.add_child(UiKit.label("PAUSED", 60))
	col.add_child(UiKit.button("RESUME", resume_pressed.emit))
	col.add_child(UiKit.secondary(UiKit.button("RETRY", retry_pressed.emit)))
	col.add_child(UiKit.secondary(UiKit.button("SETTINGS", settings_pressed.emit)))
	col.add_child(UiKit.secondary(UiKit.button("MENU", menu_pressed.emit)))
	super.open_screen()
