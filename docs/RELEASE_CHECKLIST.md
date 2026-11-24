# Acceptance and release checklist (guide page 11)

Attach the build hash, device, seed and evidence to every result.

## Automated (`tests/run_tests.gd`, run in CI by `.github/workflows/godot-tests.yml`)
These are implemented; tick each one off once CI has passed on the build.
- [ ] Graph integrity: 1,000 districts are connected, lane sockets are symmetric, degree ≥ 3, a loop exists
- [ ] Chunk certification: 1,000 seeds × 6 bands with no static obstacle in a lane or intersection
- [ ] Pool cycle: acquire/reset/release 1,000× at fixed capacity, with validation clean
- [ ] Reward idempotency, save current/previous/truncated/corrupt recovery
- [ ] Rewarded callbacks: earned / dismissed / duplicate / stale run
- [ ] Billing: pending/cancelled grant nothing; purchased verifies and grants once
- [ ] Capture: 30 scripted chase patterns; cancels when either condition clears
- [ ] Spawn fairness rule: 500 evaluations
- [ ] In-engine spawn fairness: 500 live police spawns, none in the frustum or within 3 s of travel (needs a scene test on a device/desktop)
- [ ] Pursue/recover transitions complete in 30 live scripted chases

## Physical devices (all reference phones)
- [ ] Onboarding, 50 retries, one 20-minute worst-case run, five background/resume cycles
- [ ] Repeat with airplane mode, low battery and interrupted audio
- [ ] No stuck input, repeated rewards or auto-resumed driving
- [ ] Ad no-fill and purchase reconnection with test accounts
- [ ] Performance budgets (DEVICE_BENCHMARKS.md); failures block release or narrow the supported devices

## Release candidate
- [ ] Zero known crash, purchase-loss or unavoidable-layout defects
- [ ] Signed AAB tested through a Play testing track
- [ ] Icons/screenshots/video match gameplay; content rating, privacy policy, Data safety, audience, ad declarations, product descriptions, support contact
- [ ] Current target API (36), native-library 16 KB page-size compatibility, plugin/billing library deadlines
- [ ] Signing recovery secured; version code incremented

## Go / hold / rollback
- Start with a limited rollout. Hold expansion if crash-free users drop below 99.5% or any
  reward/purchase anomaly appears.
- To stop new ad offers, set `DashCore.ad_policy.offers_enabled = false` (wire this to remote
  config before launch).
- Hotfixes go out as a higher version code built from the previous known-good source.
