extends Node
## DashCore autoload: exposes only platform/session services (save, wallet, ads,
## consent, billing, telemetry). Gameplay state lives in the game's RunRoot.
## Platform adapters are resolved here; desktop and automated tests use fakes.

const VERSION := "0.1.0"

signal save_recovered(message: String)
signal entitlements_changed

var save_store: SaveStore
var wallet: Wallet
var telemetry: Telemetry
var ad_policy: AdPolicy
var reward_gate: RewardGate
var consent: ConsentAdapter
var ads: AdsAdapter
var billing: BillingAdapter
var booted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Load settings, migrate save, resolve platform services. Called by the game's AppRoot.
func boot(save_path: String = "") -> void:
	if booted:
		return
	booted = true
	AudioBuses.ensure()
	save_store = SaveStore.new(save_path)
	save_store.recovered.connect(func(msg: String) -> void: save_recovered.emit(msg))
	save_store.load_save()
	wallet = Wallet.new(save_store)
	telemetry = Telemetry.new()
	ad_policy = AdPolicy.new()
	ad_policy.completed_runs = save_store.get_int("runs_completed")
	reward_gate = RewardGate.new()
	_resolve_platform_adapters()
	apply_audio_settings()


func _resolve_platform_adapters() -> void:
	# Android: replace these fakes with plugin-backed adapters once the native
	# bridge spike passes (see docs/ANDROID_EXPORT.md). Keep the same interfaces.
	consent = FakeConsentAdapter.new()
	consent.name = "Consent"
	add_child(consent)
	ads = FakeAdsAdapter.new()
	ads.name = "Ads"
	add_child(ads)
	ads.initialize(consent)
	billing = FakeBillingAdapter.new()
	billing.name = "Billing"
	add_child(billing)
	billing.purchase_updated.connect(_on_purchase_updated)
	consent.request_consent_info()
	billing.query_owned()
	ad_policy.ads_removed = save_store.has_entitlement(BillingAdapter.PRODUCT_REMOVE_ADS)


func _on_purchase_updated(product_id: String, status: String, token: String) -> void:
	telemetry.log_event("purchase_result", {"product_id": product_id, "result": status})
	if status != "purchased" and status != "restored":
		return  # pending/cancelled/failed grant nothing
	if not billing.verify(product_id, token):
		return
	if save_store.grant_entitlement(product_id) or status == "restored":
		billing.acknowledge(token)
	if product_id == BillingAdapter.PRODUCT_REMOVE_ADS:
		ad_policy.ads_removed = true
	entitlements_changed.emit()


func apply_audio_settings() -> void:
	AudioBuses.set_volume(AudioBuses.MUSIC, float(save_store.get_setting("music_volume", 0.7)))
	AudioBuses.set_volume(AudioBuses.SFX, float(save_store.get_setting("sfx_volume", 0.9)))


func haptic(duration_ms: int = 30) -> void:
	if bool(save_store.get_setting("haptics", true)):
		Input.vibrate_handheld(duration_ms)
