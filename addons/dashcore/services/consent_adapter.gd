class_name ConsentAdapter
extends Node
## Interface for the consent SDK (e.g. Google UMP). Ads may be requested only
## when can_request_ads() is true. Offline players must be able to play immediately.

signal consent_updated(can_request: bool)


func request_consent_info() -> void:
	consent_updated.emit(can_request_ads())


func can_request_ads() -> bool:
	return false


func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> void:
	pass
