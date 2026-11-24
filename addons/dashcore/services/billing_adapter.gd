class_name BillingAdapter
extends Node
## Interface for Play Billing. Status values: pending, purchased, cancelled, failed, restored.
## Pending purchases grant nothing. Completed purchases are verified, granted once,
## then acknowledged. Owned items are reconciled on reconnect/reinstall via query_owned().

signal purchase_updated(product_id: String, status: String, token: String)

const PRODUCT_REMOVE_ADS := "remove_forced_ads"


func is_available() -> bool:
	return false


func purchase(_product_id: String) -> bool:
	return false


func query_owned() -> void:
	pass


func acknowledge(_token: String) -> void:
	pass


## Real builds must verify on a trusted server or vetted service. Fake returns true.
func verify(_product_id: String, _token: String) -> bool:
	return false
