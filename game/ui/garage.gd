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
	var col := UiKit.centered_column(self, 14)
	col.add_child(UiKit.label("GARAGE", 56))
	var wallet := DashCore.wallet
	col.add_child(UiKit.label("%d coins" % wallet.balance(), 30, ArtKit.COIN))
	for i in catalog.player_ids.size():
		var id := catalog.player_ids[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var swatch := ColorRect.new()
		swatch.color = catalog.player_body[i]
		swatch.custom_minimum_size = Vector2(60, 60)
		row.add_child(swatch)
		var name_label := UiKit.label(catalog.player_names[i], 28)
		name_label.custom_minimum_size = Vector2(260, 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		var b: Button
		if wallet.equipped() == id:
			b = UiKit.button("EQUIPPED", Callable(), Vector2(280, 84))
			b.disabled = true
		elif wallet.is_unlocked(id):
			b = UiKit.button("EQUIP", _equip.bind(id), Vector2(280, 84))
		else:
			var price := catalog.player_prices[i]
			b = UiKit.button("BUY %d" % price, _buy.bind(id, price), Vector2(280, 84))
			b.disabled = wallet.balance() < price
		row.add_child(b)
		col.add_child(row)
	if DashCore.billing.is_available():
		var owned := DashCore.save_store.has_entitlement(BillingAdapter.PRODUCT_REMOVE_ADS)
		var ads := UiKit.button("Forced ads removed" if owned else "Remove forced ads", _buy_remove_ads, Vector2(420, 84))
		ads.disabled = owned
		col.add_child(ads)
		col.add_child(UiKit.label("Optional rewarded ads (revive, 2x coins) stay available.", 20, Color(1, 1, 1, 0.6)))
	col.add_child(UiKit.button("BACK", back_pressed.emit))
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
