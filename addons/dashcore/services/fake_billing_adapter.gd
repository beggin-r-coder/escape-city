class_name FakeBillingAdapter
extends BillingAdapter
## In-memory billing for desktop and tests. `next_result` scripts the next purchase.

var next_result: String = "purchased"
var owned: Dictionary = {}  # product_id -> token
var acknowledged: Dictionary = {}
var _counter: int = 0


func is_available() -> bool:
	return true


func purchase(product_id: String) -> bool:
	_counter += 1
	var token := "fake-%s-%d" % [product_id, _counter]
	var result := next_result
	if result == "purchased":
		owned[product_id] = token
	purchase_updated.emit.call_deferred(product_id, result, token)
	return true


func complete_pending(product_id: String, token: String) -> void:
	owned[product_id] = token
	purchase_updated.emit(product_id, "purchased", token)


func query_owned() -> void:
	for product_id in owned.keys():
		purchase_updated.emit.call_deferred(product_id, "restored", str(owned[product_id]))


func acknowledge(token: String) -> void:
	acknowledged[token] = true


func verify(product_id: String, token: String) -> bool:
	return owned.get(product_id, "") == token
