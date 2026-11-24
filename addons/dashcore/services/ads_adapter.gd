class_name AdsAdapter
extends Node
## Interface for an ads SDK bridge. Rewarded value must be granted ONLY on
## rewarded_earned; closing/dismissal alone earns nothing. Callbacks carry
## run_id + offer_id so the game can reject duplicates and stale runs.

signal rewarded_earned(placement: String, run_id: String, offer_id: String)
signal rewarded_closed(placement: String, run_id: String, offer_id: String)
signal rewarded_failed(placement: String, run_id: String, offer_id: String, reason: String)
signal interstitial_closed

var consent: ConsentAdapter


func initialize(consent_adapter: ConsentAdapter) -> void:
	consent = consent_adapter


func can_request() -> bool:
	return consent != null and consent.can_request_ads()


func is_rewarded_ready() -> bool:
	return false


func show_rewarded(_placement: String, _run_id: String, _offer_id: String) -> bool:
	return false


func is_interstitial_ready() -> bool:
	return false


func show_interstitial() -> bool:
	return false
