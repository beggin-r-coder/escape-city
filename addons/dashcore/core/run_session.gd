class_name RunSession
extends RefCounted
## Owns run_id, run state, final score and the one-revive allowance. No vehicle physics.
## MENU -> TUTORIAL or COUNTDOWN -> RUNNING -> CRASHED -> REVIVE_PENDING or RESULTS -> MENU/RETRY.
## PAUSED remembers the previous state. Invalid/duplicate transitions are rejected.

enum State { MENU, TUTORIAL, COUNTDOWN, RUNNING, PAUSED, CRASHED, REVIVE_PENDING, RESULTS }

signal state_changed(previous: int, current: int)
signal run_started(run_id: String)
signal run_ended(run_id: String, reason: String)

const TRANSITIONS := {
	State.MENU: [State.TUTORIAL, State.COUNTDOWN],
	State.TUTORIAL: [State.RUNNING, State.PAUSED, State.MENU],
	State.COUNTDOWN: [State.RUNNING, State.PAUSED, State.MENU],
	State.RUNNING: [State.CRASHED, State.PAUSED],
	State.PAUSED: [State.MENU],
	State.CRASHED: [State.REVIVE_PENDING, State.RESULTS],
	State.REVIVE_PENDING: [State.RUNNING, State.RESULTS],
	State.RESULTS: [State.MENU, State.COUNTDOWN, State.TUTORIAL],
}

var state: int = State.MENU
var paused_from: int = State.MENU
var run_id: String = ""
var revive_used: bool = false
var rewarded_used: bool = false
var failure_reason: String = ""
var final_score: int = 0
var _counter: int = 0


static func state_name(s: int) -> String:
	return State.keys()[s]


func can_transition(target: int) -> bool:
	var allowed: Array = TRANSITIONS.get(state, [])
	return allowed.has(target)


func _set_state(target: int) -> void:
	var previous := state
	state = target
	state_changed.emit(previous, target)


func begin_run(tutorial: bool) -> bool:
	var target: int = State.TUTORIAL if tutorial else State.COUNTDOWN
	if not can_transition(target):
		return false
	_counter += 1
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), _counter]
	revive_used = false
	rewarded_used = false
	failure_reason = ""
	final_score = 0
	_set_state(target)
	run_started.emit(run_id)
	return true


func start_running() -> bool:
	if state != State.COUNTDOWN and state != State.TUTORIAL:
		return false
	_set_state(State.RUNNING)
	return true


func pause() -> bool:
	if not can_transition(State.PAUSED):
		return false
	paused_from = state
	_set_state(State.PAUSED)
	return true


func resume() -> bool:
	if state != State.PAUSED:
		return false
	_set_state(paused_from)
	return true


## Returns false for duplicate crash callbacks (state is no longer RUNNING).
func crash(reason: String) -> bool:
	if state != State.RUNNING:
		return false
	failure_reason = reason
	_set_state(State.CRASHED)
	return true


func can_offer_revive() -> bool:
	return state == State.CRASHED and not revive_used and not rewarded_used


func offer_revive() -> bool:
	if not can_offer_revive():
		return false
	_set_state(State.REVIVE_PENDING)
	return true


## Only the matching run may revive, and only once.
func apply_revive(callback_run_id: String) -> bool:
	if state != State.REVIVE_PENDING or callback_run_id != run_id or revive_used:
		return false
	revive_used = true
	rewarded_used = true
	failure_reason = ""
	_set_state(State.RUNNING)
	return true


func finish(score: int) -> bool:
	if not can_transition(State.RESULTS):
		return false
	final_score = score
	_set_state(State.RESULTS)
	run_ended.emit(run_id, failure_reason)
	return true


func to_menu() -> bool:
	if not can_transition(State.MENU):
		return false
	_set_state(State.MENU)
	return true


func mark_rewarded_used() -> void:
	rewarded_used = true
