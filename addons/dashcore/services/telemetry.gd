class_name Telemetry
extends RefCounted
## Event logging with an allowlist. Values must be numbers, bools or short id/enum strings;
## free text (and therefore personal data typed by players) is rejected.

const ALLOWED := {
	"run_start": ["run_id", "seed", "generator_version", "tutorial"],
	"run_end": ["run_id", "duration", "failure_reason", "score", "escapes", "coins", "revived"],
	"retry": ["run_id"],
	"offer_seen": ["placement", "run_id"],
	"ad_reward": ["placement", "run_id", "result"],
	"purchase_result": ["product_id", "result"],
	"tutorial_step": ["step"],
}

var enabled: bool = true
var buffer: Array[Dictionary] = []
var max_buffer: int = 500
var sink: Callable = Callable()
var _token := RegEx.new()


func _init() -> void:
	_token.compile("^[a-z0-9_:\\-\\.]{1,48}$")


func log_event(event_name: String, params: Dictionary = {}) -> bool:
	if not enabled or not ALLOWED.has(event_name):
		return false
	var allowed_keys: Array = ALLOWED[event_name]
	var clean := {}
	for k in params.keys():
		if not allowed_keys.has(k):
			return false
		var v: Variant = params[k]
		if v is String or v is StringName:
			if _token.search(str(v)) == null:
				return false
		elif not (v is int or v is float or v is bool):
			return false
		clean[k] = v
	var entry := {"event": event_name, "t": Time.get_unix_time_from_system(), "params": clean}
	buffer.append(entry)
	while buffer.size() > max_buffer:
		buffer.pop_front()
	if sink.is_valid():
		sink.call(entry)
	elif OS.is_debug_build():
		print("[telemetry] ", event_name, " ", clean)
	return true
