# DashCore 0.1.0

Shared services for DashPanda titles, extracted with restraint. Each title vendors a
**pinned** copy: patch one game, run the common tests, then opt the other games into the
update. Never auto-update all published titles together.

| Component | Contract and boundary |
|---|---|
| `RunSession` | Owns run_id, state, final score and the one-revive allowance. No vehicle physics. |
| `InputRouter` | Maps drag/buttons/keyboard to normalized actions; dead zones, cancellation, UI exclusion. |
| `ChunkPool` / `SeedService` | Acquire/reset/release by type with bounded pools; deterministic seed streams. The game owns module legality. |
| `SaveStore` / `Wallet` | Versioned local save with temp-validate-replace and a last-good backup; unique reward IDs prevent duplicate credit. |
| `UiKit` / `AudioBuses` / `QualityPresets` | Reusable menus, sound buses and preset application. The game supplies theme and camera. |
| `AdsAdapter` / `BillingAdapter` / `ConsentAdapter` / `Telemetry` | Interfaces with fake adapters; consent, callback guards (`RewardGate`), frequency policy (`AdPolicy`), purchase recovery, event filtering. |

Game-specific systems such as the lane-graph pursuit AI stay in the game until another
title needs them.
