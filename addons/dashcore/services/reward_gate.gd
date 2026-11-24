class_name RewardGate
extends RefCounted
## Guards rewarded-ad callbacks: a reward is claimable once per (run_id, offer_id),
## only for the currently offered offer, and never from a dismissal.

var _claimed: Dictionary = {}
var _open_offers: Dictionary = {}  # key -> placement


static func key(run_id: String, offer_id: String) -> String:
	return "%s|%s" % [run_id, offer_id]


func open_offer(run_id: String, offer_id: String, placement: String) -> void:
	_open_offers[key(run_id, offer_id)] = placement


func close_offer(run_id: String, offer_id: String) -> void:
	_open_offers.erase(key(run_id, offer_id))


func is_open(run_id: String, offer_id: String) -> bool:
	return _open_offers.has(key(run_id, offer_id))


## Returns true exactly once for an open offer on the earned-reward callback.
func try_claim(run_id: String, offer_id: String) -> bool:
	var k := key(run_id, offer_id)
	if _claimed.has(k) or not _open_offers.has(k):
		return false
	_claimed[k] = true
	_open_offers.erase(k)
	return true


func reset() -> void:
	_claimed.clear()
	_open_offers.clear()
