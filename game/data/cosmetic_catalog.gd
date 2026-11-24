class_name CosmeticCatalog
extends Resource
## Launch cosmetic budget: 3 player looks, 2 police skins, 4 traffic looks.
## Cosmetics change looks only. First earnable look targets ~10 normal runs.

@export var player_ids: PackedStringArray = PackedStringArray(["car_default", "car_hatch", "car_muscle"])
@export var player_names: PackedStringArray = PackedStringArray(["Street Coupe", "Zip Hatch", "Night Muscle"])
@export var player_shapes: PackedInt32Array = PackedInt32Array([0, 1, 2])
@export var player_body: PackedColorArray = PackedColorArray([Color("e8463a"), Color("2fb5a3"), Color("1d1f26")])
@export var player_accent: PackedColorArray = PackedColorArray([Color("f3efe6"), Color("f6d743"), Color("f28c28")])
@export var player_prices: PackedInt32Array = PackedInt32Array([0, 300, 750])

@export var police_body: PackedColorArray = PackedColorArray([Color("f4f6fa"), Color("1b2a4a")])
@export var police_accent: PackedColorArray = PackedColorArray([Color("1b2a4a"), Color("f4f6fa")])

@export var traffic_body: PackedColorArray = PackedColorArray([Color("8aa1b8"), Color("e0b94a"), Color("6c7a5a"), Color("b8b3ab")])
@export var traffic_shapes: PackedInt32Array = PackedInt32Array([0, 3, 1, 3])


func player_index(item_id: String) -> int:
	var idx := player_ids.find(item_id)
	return maxi(idx, 0)
