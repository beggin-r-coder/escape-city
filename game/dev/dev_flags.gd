class_name DevFlags
extends RefCounted
## Dev/test flags, passed after `--` on the Godot command line. See README "Test harness".

const FRESH_SAVE := "user://dev_fresh_save.json"
const HARNESS_KEYS := ["autotest", "shot", "shots", "screen", "demo"]


static func parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		if not a.begins_with("--"):
			continue
		var body := a.substr(2)
		var eq := body.find("=")
		if eq == -1:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


static func wants_harness(flags: Dictionary) -> bool:
	for k in HARNESS_KEYS:
		if flags.has(k):
			return true
	return false


static func delete_save(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
