class_name Wallet
extends RefCounted
## Soft-currency wallet. Every credit carries a unique reward_id so the same reward
## event applied twice credits once. Only the wallet changes the coin balance.

signal balance_changed(coins: int)

var _store: SaveStore


func _init(store: SaveStore) -> void:
	_store = store


func balance() -> int:
	return _store.get_int("coins")


func credit(reward_id: String, amount: int) -> bool:
	if amount <= 0 or reward_id.is_empty():
		return false
	var processed: Array = _store.data.get("processed_rewards", [])
	if processed.has(reward_id):
		return false
	processed.append(reward_id)
	while processed.size() > SaveStore.MAX_PROCESSED_REWARDS:
		processed.pop_front()
	_store.data["processed_rewards"] = processed
	_store.data["coins"] = balance() + amount
	_store.save()
	balance_changed.emit(balance())
	return true


func spend(amount: int) -> bool:
	if amount < 0 or balance() < amount:
		return false
	_store.data["coins"] = balance() - amount
	_store.save()
	balance_changed.emit(balance())
	return true


func is_unlocked(item_id: String) -> bool:
	return (_store.data.get("unlocked", []) as Array).has(item_id)


func unlock(item_id: String, cost: int) -> bool:
	if is_unlocked(item_id):
		return false
	if not spend(cost):
		return false
	var unlocked: Array = _store.data.get("unlocked", [])
	unlocked.append(item_id)
	_store.data["unlocked"] = unlocked
	_store.save()
	return true


func equip(item_id: String) -> bool:
	if not is_unlocked(item_id):
		return false
	_store.data["equipped"] = item_id
	_store.save()
	return true


func equipped() -> String:
	return str(_store.data.get("equipped", "car_default"))
