class_name ResultsScreen
extends UiScreen
## Frozen run rewards, a clear failure reason, and Retry before optional actions.

signal retry_pressed
signal double_pressed
signal menu_pressed

var _double_button: Button


func open_with(info: Dictionary, can_double: bool) -> void:
	clear()
	UiKit.dim_background(self, 0.6)
	var col := UiKit.card_column(self, 12, 600.0)
	var reason := str(info.get("reason", ""))
	col.add_child(UiKit.label(ReviveOffer.reason_title(reason), 60, Color("ff6b5a")))
	col.add_child(UiKit.wrapped(UiKit.label(ReviveOffer.reason_hint(reason), 22, Color(0.85, 0.87, 0.95)), 520))
	var score := int(info.get("score", 0))
	col.add_child(UiKit.label(str(score), 96, Color("ffe066")))
	if bool(info.get("new_best", false)):
		col.add_child(UiKit.label("NEW BEST!", 30, Color("7fe0ff")))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)
	col.add_child(UiKit.stat_row("Survived", "%d s" % int(info.get("seconds", 0))))
	col.add_child(UiKit.stat_row("Distance", "%d m" % int(info.get("distance", 0))))
	col.add_child(UiKit.stat_row("Escapes", str(int(info.get("escapes", 0)))))
	if not bool(info.get("new_best", false)):
		col.add_child(UiKit.stat_row("Best", str(int(info.get("best", 0)))))
	var earned := int(info.get("coins", 0))
	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 10)
	coins_row.add_child(UiKit.coin_icon(30))
	coins_row.add_child(UiKit.label("+%d coin%s" % [earned, "" if earned == 1 else "s"], 34, ArtKit.COIN))
	col.add_child(coins_row)
	var retry := UiKit.button("RETRY", retry_pressed.emit, Vector2(520, 116))
	retry.add_theme_font_size_override("font_size", 44)
	col.add_child(retry)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	if can_double:
		_double_button = UiKit.button("2x coins (ad)", _on_double, Vector2(252, 96))
		row.add_child(_double_button)
	row.add_child(UiKit.secondary(UiKit.button("MENU", menu_pressed.emit, Vector2(252, 96))))
	col.add_child(row)
	open_screen()


func mark_doubled(coins_total: int) -> void:
	if _double_button != null and is_instance_valid(_double_button):
		_double_button.text = "Doubled! (+%d)" % coins_total
		_double_button.disabled = true


func reenable_double() -> void:
	if _double_button != null and is_instance_valid(_double_button):
		_double_button.disabled = false


func _on_double() -> void:
	_double_button.disabled = true
	double_pressed.emit()
