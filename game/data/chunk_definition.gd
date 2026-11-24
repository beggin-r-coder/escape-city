class_name ChunkDefinition
extends Resource
## A certified block module. The planner filters by difficulty band, then places
## buildings/props inside the block interior and hazards/pickups in reserved road slots.

enum Kind { DOWNTOWN, RESIDENTIAL, PARK, PLAZA, CONSTRUCTION, PARKING }

@export var id: StringName = &"block"
@export var kind: Kind = Kind.RESIDENTIAL
@export var weight: float = 1.0
@export var min_band: int = 0
@export var max_band: int = 99
@export var building_min_height: float = 8.0
@export var building_max_height: float = 20.0
@export var max_lots: int = 4
@export var tree_count: int = 0
@export var hazard_slots: int = 0
@export var parked_car_slots: int = 0
@export var coin_line_chance: float = 0.3
@export var is_recovery: bool = false


func allows_band(band: int) -> bool:
	return band >= min_band and band <= max_band
