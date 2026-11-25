class_name SaveStore
extends RefCounted
## Versioned local save with atomic replacement and a last-good backup.
## File format: {"schema_version": N, "payload": "<json string>", "checksum": "<md5>"}.
## Local coin saves are NOT tamper-proof; never base competitive or paid claims on them.

const SCHEMA_VERSION := 2
const MAX_PROCESSED_REWARDS := 256

signal recovered(message: String)

var path: String = "user://escape_city_save.json"
var data: Dictionary = {}
var last_load_status: String = ""


func _init(save_path: String = "") -> void:
	if not save_path.is_empty():
		path = save_path
	data = default_data()


func backup_path() -> String:
	return path + ".bak"


func temp_path() -> String:
	return path + ".tmp"


static func default_data() -> Dictionary:
	return {
		"coins": 0,
		"best_score": 0,
		"runs_completed": 0,
		"tutorial_done": false,
		"unlocked": ["car_default"],
		"equipped": "car_default",
		"entitlements": [],
		"processed_rewards": [],
		"settings": {
			"music_volume": 0.7,
			"sfx_volume": 0.9,
			"control_layout": "drag",
			"reduced_motion": false,
			"haptics": true,
			"quality": "low",
			"time_of_day": "cycle",
			"handling": "drifty",
		},
	}


## Returns one of: new, ok, migrated, recovered_backup, reset_corrupt.
func load_save() -> String:
	var primary: Variant = _read_envelope(path)
	if primary is Dictionary:
		last_load_status = _adopt(primary)
		return last_load_status
	var had_primary := FileAccess.file_exists(path)
	var backup: Variant = _read_envelope(backup_path())
	if backup is Dictionary:
		_adopt(backup)
		last_load_status = "recovered_backup"
		recovered.emit("Your latest save was damaged. Progress was restored from a backup.")
		save()
		return last_load_status
	data = default_data()
	if had_primary or FileAccess.file_exists(backup_path()):
		last_load_status = "reset_corrupt"
		recovered.emit("Save data was damaged and could not be recovered. Progress has been reset.")
		save()
	else:
		last_load_status = "new"
	return last_load_status


func _adopt(envelope: Dictionary) -> String:
	var version := int(envelope["schema_version"])
	var payload: Dictionary = envelope["payload_dict"]
	var status := "ok"
	if version < SCHEMA_VERSION:
		payload = migrate(payload, version)
		status = "migrated"
	data = _merge_defaults(payload, default_data())
	if status == "migrated":
		save()
	return status


## Migration chain. Each step upgrades exactly one version.
static func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var p := payload.duplicate(true)
	var v := from_version
	if v == 1:
		# v1 stored "best" and "car"; v2 renames and adds reward tracking.
		p["best_score"] = int(p.get("best", 0))
		p.erase("best")
		var car := str(p.get("car", "car_default"))
		p.erase("car")
		p["equipped"] = car
		p["unlocked"] = ["car_default"] if car == "car_default" else ["car_default", car]
		p["processed_rewards"] = []
		v = 2
	return p


static func _merge_defaults(src: Dictionary, defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for key in src.keys():
		if out.has(key) and out[key] is Dictionary and src[key] is Dictionary:
			out[key] = _merge_defaults(src[key], out[key])
		else:
			out[key] = src[key]
	return out


## Reads and validates an envelope; returns Dictionary (with payload_dict) or null.
func _read_envelope(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return parse_envelope(text)


static func parse_envelope(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	var env: Dictionary = parsed
	if not (env.has("schema_version") and env.has("payload") and env.has("checksum")):
		return null
	var version := int(env["schema_version"])
	if version < 1 or version > SCHEMA_VERSION:
		return null
	var payload_text := str(env["payload"])
	if payload_text.md5_text() != str(env["checksum"]):
		return null
	var payload: Variant = JSON.parse_string(payload_text)
	if not (payload is Dictionary):
		return null
	env["payload_dict"] = payload
	return env


static func make_envelope(payload: Dictionary, version: int = SCHEMA_VERSION) -> String:
	var payload_text := JSON.stringify(payload)
	return JSON.stringify({
		"schema_version": version,
		"payload": payload_text,
		"checksum": payload_text.md5_text(),
	})


## Write temp -> validate -> keep last-good backup -> replace primary.
func save() -> bool:
	var text := make_envelope(data)
	var tmp := temp_path()
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveStore: cannot open temp file %s" % tmp)
		return false
	f.store_string(text)
	f.close()
	if not (_read_envelope(tmp) is Dictionary):
		push_warning("SaveStore: temp save failed validation")
		return false
	var g_primary := ProjectSettings.globalize_path(path)
	var g_backup := ProjectSettings.globalize_path(backup_path())
	var g_tmp := ProjectSettings.globalize_path(tmp)
	if _read_envelope(path) is Dictionary:
		DirAccess.copy_absolute(g_primary, g_backup)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(g_primary)
	var err := DirAccess.rename_absolute(g_tmp, g_primary)
	return err == OK


func delete_all() -> void:
	for p in [path, backup_path(), temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	data = default_data()


# -- typed accessors (JSON numbers come back as floats) --

func get_int(key: String, fallback: int = 0) -> int:
	return int(data.get(key, fallback))


func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	save()


func has_entitlement(product_id: String) -> bool:
	return (data.get("entitlements", []) as Array).has(product_id)


func grant_entitlement(product_id: String) -> bool:
	var list: Array = data.get("entitlements", [])
	if list.has(product_id):
		return false
	list.append(product_id)
	data["entitlements"] = list
	save()
	return true
