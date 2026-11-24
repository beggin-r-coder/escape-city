# Escape City

**Endless police pursuit. How long can you outrun the police?**

An arcade car chase through a city built from reusable, certified road blocks. Traffic,
police pressure that ramps up but stays capped, and breakable street props make for
dramatic escapes. Built for Android with **Godot 4.3 (GDScript, GL Compatibility renderer)**,
following the DashPanda *Escape City Development Guide v1.0*.

> Status: **Phase 1 prototype + release scaffolding.** It's playable on desktop with fake
> ad/billing/consent adapters. It has not been run on a physical Android device yet; see
> [What still needs a human](#what-still-needs-a-human).

## Run it

1. Install **Godot 4.3-stable** (standard build, not .NET).
2. Open `project.godot` in the editor (the first import builds `.godot/`), then press **F5**.

Headless automated checks (guide page 11):

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

The exit code is 0 when every check passes.

## Controls

| Action | Touch | Keyboard |
|---|---|---|
| Steer | Drag with your left thumb anywhere on the left half (floating stick), **or** the optional left/right buttons (Settings → Controls) | A / D or ← / → |
| Brake | Hold the **BRAKE** pad, bottom right | Space / S / ↓ |
| Drift | Hold brake **and** steer above 8 m/s (capped drift assist) | brake + steer |
| Pause | **II** button, top right | Esc / P |

The car accelerates by itself (auto-throttle). On desktop the mouse acts as a touch, so you
can try drag steering with it.

## How a run plays

* You start with **one pursuer** spawning behind you, out of view.
* **Score** = `survival_seconds × 10 + verified_escapes × 150`.
* **Escape**: no officer has line of sight and all are more than 75 m away for 5 s. There's
  a 20 s cooldown, it pays at most once per disengagement, and it earns you a recovery wave.
* **Busted**: you stay below 4 m/s within 9 m of police for 3 continuous seconds. **Wrecked**:
  your health hits 0 from walls and rams.
* **Heat** rises over time (and a little when you smash props): faster cruising speed, then
  more police and intercept roles, then denser hazards. 40 s pressure waves alternate with
  16 s cool-downs.
* **Coins** come from authored pickup lines plus a capped distance payout (1 per 250 m, max
  40). They're banked once per run and spent in the **Garage** on looks (cosmetic only).
* After a crash you get one optional **rewarded revive** per run, *or* **2× coins** on the
  results screen, never both. Retry always comes before any ad action.

## Project layout

```
addons/dashcore/          shared, versioned package (no game-specific AI)
  core/                   RunSession (state machine), SeedService, ChunkPool
  input/                  InputRouter (drag / buttons / keyboard, UI exclusions)
  save/                   SaveStore (versioned, atomic, backup), Wallet (idempotent credits)
  services/               Ads / Billing / Consent interfaces + fakes, AdPolicy, RewardGate, Telemetry
  audio/ quality/ ui/     bus setup, quality presets, UI builders
  dashcore.gd             autoload: platform/session services only
game/
  scenes/                 main.tscn, AppRoot (bootstrap + screen flow), RunRoot (one run)
  controllers/            PlayerCar, PoliceAgent, TrafficAgent/Manager, PursuitDirector,
                          CaptureResolver, ScoreService, ChaseCamera, BreakableProp, CoinPickup
  generation/             LaneGraph, ChunkPlanner (pure data), ChunkBuilder, StreamingWorld
  data/                   typed resources (.tres): handling, difficulty, chunks, cosmetics
  art/ audio/ ui/         placeholder primitive art, procedural audio, HUD + menus
tests/run_tests.gd        headless acceptance checks
docs/                     design, architecture, build manifest, logs and gate sheets
```

Tune the game feel in `game/data/handling_default.tres` and the pacing in
`game/data/difficulty_default.tres`, and log every change in `docs/TUNING_LOG.md`.

## What still needs a human

* **Physical-device work**: the phase 0 Android smoke build, the device matrix, the
  performance budgets (page 8) and the lifecycle tests on real phones.
* The **10-player prototype gate** (`docs/PLAYTEST_GATE.md`). Don't expand content until it passes.
* **Native adapters**: AdMob + UMP consent + Play Billing through a Godot Android plugin,
  plus server-side purchase verification. The interfaces and fakes are in place.
* **Real art and audio** to replace the primitives and synth, recorded in `docs/ASSET_REGISTER.md`.
* Store listing, privacy policy, Data safety form and content rating (`docs/RELEASE_CHECKLIST.md`).
