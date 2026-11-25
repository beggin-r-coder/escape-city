class_name CosmeticCatalog
extends Resource
## Launch cosmetic budget: 3 player looks, police, and varied traffic (Kenney Car Kit, CC0).
## Cosmetics change looks only. First earnable look targets ~10 normal runs.

@export var player_ids: PackedStringArray = PackedStringArray(["car_default", "car_hatch", "car_racer"])
@export var player_names: PackedStringArray = PackedStringArray(["Street Coupe", "Hot Hatch", "Track Racer"])
@export var player_models: PackedStringArray = PackedStringArray(["sedan-sports", "hatchback-sports", "race"])
@export var player_prices: PackedInt32Array = PackedInt32Array([0, 300, 750])

@export var police_models: PackedStringArray = PackedStringArray(["police", "police"])

@export var traffic_models: PackedStringArray = PackedStringArray(["sedan", "taxi", "suv", "van", "truck", "delivery"])


func player_index(item_id: String) -> int:
	var idx := player_ids.find(item_id)
	return maxi(idx, 0)


func preview_path(index: int) -> String:
	return "res://game/art/kenney/cars/previews/%s.png" % player_models[clampi(index, 0, player_models.size() - 1)]
