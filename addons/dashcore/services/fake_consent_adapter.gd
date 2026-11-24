class_name FakeConsentAdapter
extends ConsentAdapter
## Desktop/test consent: grants by default; toggle `granted` to test the denied flow.

var granted: bool = true
var options_required: bool = true


func request_consent_info() -> void:
	consent_updated.emit.call_deferred(granted)


func can_request_ads() -> bool:
	return granted


func privacy_options_required() -> bool:
	return options_required


func show_privacy_options() -> void:
	print("[FakeConsent] privacy options shown (granted=%s)" % granted)
