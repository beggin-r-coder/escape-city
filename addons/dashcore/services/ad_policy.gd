class_name AdPolicy
extends RefCounted
## Interstitial frequency rules: at most one per 3 completed runs AND 180 s (whichever is
## stricter); none during the first 3 runs; none right after a rewarded ad; only at
## results-to-menu boundaries; never if the player owns Remove Forced Ads.

var min_runs_between: int = 3
var min_seconds_between: float = 180.0
var grace_runs: int = 3

var completed_runs: int = 0
var runs_since_interstitial: int = 0
var last_interstitial_time: float = -1.0e9
var rewarded_since_last_boundary: bool = false
var ads_removed: bool = false
var offers_enabled: bool = true  # remote/config kill switch for new ad offers


func on_run_completed() -> void:
	completed_runs += 1
	runs_since_interstitial += 1


func on_rewarded_shown() -> void:
	rewarded_since_last_boundary = true


## Call at the results -> menu (or retry) boundary. Consumes the "after rewarded" flag.
func should_show_interstitial(now_seconds: float) -> bool:
	var after_rewarded := rewarded_since_last_boundary
	rewarded_since_last_boundary = false
	if ads_removed or not offers_enabled or after_rewarded:
		return false
	if completed_runs <= grace_runs:
		return false
	if runs_since_interstitial < min_runs_between:
		return false
	if now_seconds - last_interstitial_time < min_seconds_between:
		return false
	return true


func on_interstitial_shown(now_seconds: float) -> void:
	runs_since_interstitial = 0
	last_interstitial_time = now_seconds
