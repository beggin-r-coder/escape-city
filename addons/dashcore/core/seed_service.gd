class_name SeedService
extends RefCounted
## Deterministic seed streams. Separate streams for route, hazards, cosmetics and
## pickups so that editing cosmetics never alters gameplay layout.

const STREAM_ROUTE := 1
const STREAM_HAZARDS := 2
const STREAM_COSMETICS := 3
const STREAM_PICKUPS := 4
const STREAM_AGENTS := 5

var run_seed: int = 0
var _streams: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	reset(seed_value)


func reset(seed_value: int) -> void:
	run_seed = seed_value & 0x7FFFFFFF
	# Re-seed existing stream objects in place: systems keep their references across runs.
	for stream_id in _streams.keys():
		(_streams[stream_id] as RandomNumberGenerator).seed = hash_ints(run_seed, stream_id, 0x5EED, 0)


## Sequential stream for run-level decisions (agent spawns, director choices).
func stream(stream_id: int) -> RandomNumberGenerator:
	if not _streams.has(stream_id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash_ints(run_seed, stream_id, 0x5EED, 0)
		_streams[stream_id] = rng
	return _streams[stream_id]


## Position-addressed generator: same seed + stream + cell always returns the same sequence.
func cell_rng(stream_id: int, i: int, j: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_ints(run_seed, stream_id, i, j)
	return rng


## Position-addressed value in [0, 1).
func cell_value(stream_id: int, i: int, j: int, salt: int = 0) -> float:
	var h := hash_ints(run_seed ^ (salt * 0x9E3779B1 & 0xFFFFFFFF), stream_id, i, j)
	return float(h) / 4294967296.0


static func mix32(x: int) -> int:
	var h: int = x & 0xFFFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xFFFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xFFFFFFFF
	h = (h >> 16) ^ h
	return h


static func hash_ints(a: int, b: int, c: int, d: int) -> int:
	var h := mix32(a)
	h = mix32(h ^ ((b * 0x27d4eb2d) & 0xFFFFFFFF))
	h = mix32(h ^ ((c * 0x165667b1) & 0xFFFFFFFF))
	h = mix32(h ^ ((d * 0x61c88647) & 0xFFFFFFFF))
	return h


static func new_run_seed() -> int:
	return randi() & 0x7FFFFFFF
