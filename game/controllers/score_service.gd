class_name ScoreService
extends RefCounted
## Scoring contract: score = survival_seconds x 10 + verified_escape_events x 150.
## Coins = authored pickups + bounded distance payout. Frozen at game over.

const SURVIVAL_POINTS := 10
const ESCAPE_POINTS := 150
const DISTANCE_PER_COIN := 250.0
const MAX_DISTANCE_COINS := 40

var survival_seconds: float = 0.0
var escapes: int = 0
var coins_collected: int = 0
var distance: float = 0.0
var props_smashed: int = 0
var frozen: bool = false


func reset() -> void:
	survival_seconds = 0.0
	escapes = 0
	coins_collected = 0
	distance = 0.0
	props_smashed = 0
	frozen = false


func tick(delta: float, route_distance: float) -> void:
	if frozen:
		return
	survival_seconds += delta
	distance = route_distance


func add_escape() -> void:
	if not frozen:
		escapes += 1


func add_coin() -> void:
	if not frozen:
		coins_collected += 1


func score() -> int:
	return int(survival_seconds) * SURVIVAL_POINTS + escapes * ESCAPE_POINTS


func distance_coins() -> int:
	return mini(int(distance / DISTANCE_PER_COIN), MAX_DISTANCE_COINS)


func coin_payout() -> int:
	return coins_collected + distance_coins()


func freeze() -> void:
	frozen = true
