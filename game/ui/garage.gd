class_name Garage
extends UiScreen
## Earnable car looks (cosmetic only) and the optional Remove Forced Ads purchase.
## Rewarded ads remain optional after Remove Forced Ads.

signal back_pressed
signal look_changed

var catalog: CosmeticCatalog


func open_screen() -> void:
	clear()
	UiKit.dim_background(self, 0.8)
	var col := UiKit.centered_column(self, 10)
	col.add_child(UiKit.label("GARAGE", 48))
	var wallet := DashCore.wallet
	col.add_child(UiKit.label("%d coins" % wallet.balance(), 30, ArtKit.COIN))
	for i in catalog.player_ids.size():
		var id := catalog.player_ids[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var icon := TextureRect.new()
		icon.texture = load(catalog.preview_path(i)) as Texture2D
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var name_label := UiKit.label(catalog.player_names[i], 28)
		name_label.custom_minimum_size = Vector2(220, 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		var b: Button
		if wallet.equipped() == id:
			b = UiKit.button("EQUIPPED", Callable(), Vector2(260, 84))
			b.disabled = true
		elif wallet.is_unlocked(id):
			b = UiKit.button("EQUIP", _equip.bind(id), Vector2(260, 84))
		else:
			var price := catalog.player_prices[i]
			b = UiKit.button("BUY %d" % price, _buy.bind(id, price), Vector2(260, 84))
			b.disabled = wallet.balance() < price
		row.add_child(b)
		col.add_child(row)
	if DashCore.billing.is_available():
		var owned := DashCore.save_store.has_entitlement(BillingAdapter.PRODUCT_REMOVE_ADS)
		var ads := UiKit.button("Forced ads removed" if owned else "Remove forced ads", _buy_remove_ads, Vector2(420, 76))
		ads.disabled = owned
		col.add_child(ads)
		col.add_child(UiKit.wrapped(UiKit.label("Optional rewarded ads (revive, 2x coins) stay available.", 20, Color(1, 1, 1, 0.6)), 560))
	col.add_child(UiKit.secondary(UiKit.button("BACK", back_pressed.emit, Vector2(300, 80))))
	super.open_screen()


func _equip(id: String) -> void:
	DashCore.wallet.equip(id)
	look_changed.emit()
	open_screen()


func _buy(id: String, price: int) -> void:
	if DashCore.wallet.unlock(id, price):
		DashCore.wallet.equip(id)
		look_changed.emit()
	open_screen()


func _buy_remove_ads() -> void:
	DashCore.billing.purchase(BillingAdapter.PRODUCT_REMOVE_ADS)
