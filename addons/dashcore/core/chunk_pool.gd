class_name ChunkPool
extends RefCounted
## Bounded, typed object pool. Acquire returns null when a type reaches capacity,
## so callers must degrade gracefully instead of growing memory.

const META_TYPE := &"_pool_type"
const META_ACTIVE := &"_pool_active"

var _factories: Dictionary = {}  # type -> Callable() -> Object
var _resets: Dictionary = {}  # type -> Callable(obj) (called on release)
var _capacity: Dictionary = {}  # type -> int
var _free: Dictionary = {}  # type -> Array
var _active: Dictionary = {}  # type -> Array


func register_type(type: StringName, factory: Callable, capacity: int, reset: Callable = Callable()) -> void:
	_factories[type] = factory
	_resets[type] = reset
	_capacity[type] = capacity
	if not _free.has(type):
		_free[type] = []
		_active[type] = []


func has_type(type: StringName) -> bool:
	return _factories.has(type)


func acquire(type: StringName) -> Object:
	if not _factories.has(type):
		push_error("ChunkPool: unknown type %s" % type)
		return null
	var free_list: Array = _free[type]
	var active_list: Array = _active[type]
	var obj: Object = null
	while not free_list.is_empty() and obj == null:
		var candidate: Object = free_list.pop_back()
		if is_instance_valid(candidate):
			obj = candidate
	if obj == null:
		if active_list.size() + free_list.size() >= int(_capacity[type]):
			return null
		var factory: Callable = _factories[type]
		obj = factory.call()
		if obj == null:
			return null
		obj.set_meta(META_TYPE, type)
	obj.set_meta(META_ACTIVE, true)
	active_list.append(obj)
	return obj


func release(obj: Object) -> void:
	if obj == null or not is_instance_valid(obj) or not obj.has_meta(META_TYPE):
		return
	if not bool(obj.get_meta(META_ACTIVE, false)):
		return  # double release is ignored
	var type: StringName = obj.get_meta(META_TYPE)
	var active_list: Array = _active[type]
	active_list.erase(obj)
	obj.set_meta(META_ACTIVE, false)
	var reset: Callable = _resets[type]
	if reset.is_valid():
		reset.call(obj)
	(_free[type] as Array).append(obj)


func release_all(type: StringName = &"") -> void:
	var types: Array = [type] if type != &"" else _factories.keys()
	for t in types:
		var copy: Array = (_active[t] as Array).duplicate()
		for obj in copy:
			release(obj)


func active(type: StringName) -> Array:
	return (_active.get(type, []) as Array).duplicate()


func active_count(type: StringName) -> int:
	return (_active.get(type, []) as Array).size()


func free_count(type: StringName) -> int:
	return (_free.get(type, []) as Array).size()


func total_count(type: StringName) -> int:
	return active_count(type) + free_count(type)


func capacity(type: StringName) -> int:
	return int(_capacity.get(type, 0))


## Returns a list of problems; empty means healthy. Run after every reset.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for type in _factories.keys():
		var free_list: Array = _free[type]
		var active_list: Array = _active[type]
		if free_list.size() + active_list.size() > int(_capacity[type]):
			errors.append("%s exceeds capacity" % type)
		for obj in active_list:
			if not is_instance_valid(obj):
				errors.append("%s has freed active object" % type)
			elif free_list.has(obj):
				errors.append("%s object both active and free" % type)
			elif not bool(obj.get_meta(META_ACTIVE, false)):
				errors.append("%s active object flagged inactive" % type)
		for obj in free_list:
			if is_instance_valid(obj) and bool(obj.get_meta(META_ACTIVE, false)):
				errors.append("%s free object flagged active" % type)
	return errors


## Frees every pooled object. Call when the owner is torn down.
func dispose() -> void:
	for type in _factories.keys():
		for list_name in [_free, _active]:
			for obj in (list_name[type] as Array):
				if is_instance_valid(obj) and obj is Node:
					(obj as Node).queue_free()
			(list_name[type] as Array).clear()
