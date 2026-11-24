extends SceneTree
## Loads every GDScript in the project and fails if any does not compile.
##   godot --headless --path . -s res://tests/compile_all.gd

var _failed: PackedStringArray = []
var _count: int = 0


func _initialize() -> void:
	for dir in ["res://addons", "res://game", "res://tests"]:
		_scan(dir)
	print("compiled %d scripts, %d failed" % [_count, _failed.size()])
	for f in _failed:
		printerr("  COMPILE FAIL ", f)
	quit(1 if not _failed.is_empty() else 0)


func _scan(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if d.current_is_dir():
			if not entry.begins_with("."):
				_scan(full)
		elif entry.ends_with(".gd"):
			_count += 1
			var script := load(full) as GDScript
			if script == null or not script.can_instantiate():
				_failed.append(full)
		entry = d.get_next()
