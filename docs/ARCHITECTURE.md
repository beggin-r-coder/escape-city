# Architecture

One gameplay project per title, plus a versioned common package (`addons/dashcore`).

## Layers

| Layer | Where | Responsibility |
|---|---|---|
| AppRoot / Bootstrap | `game/scenes/app_root.gd` | `DashCore.boot()` (load settings, migrate save, resolve platform adapters), open the menu, route screens, platform lifecycle. |
| RunRoot | `game/scenes/run_root.gd` | Owns RunSession, the player controller, director, camera, scoring and the local object pools. Resets in place for a fast retry. |
| Game-specific nodes | `game/controllers`, `game/generation` | LaneGraph serves traffic and pursuit; PursuitDirector caps pressure and spawn fairness; PoliceAgent is a state machine; TrafficAgent reserves intersections; CaptureResolver checks proximity plus low speed. The graph AI stays out of DashCore. |
| Resources | `game/data` | HandlingConfig, DifficultyProfile, ChunkDefinition and CosmeticCatalog are typed `.tres`. |
| Platform adapters | `addons/dashcore/services` | Ads, consent and billing sit behind interfaces. Desktop and tests use fakes. |

The only autoload is `DashCore`, which holds platform/session services. There's no global
gameplay singleton.

## Run state flow

```
MENU -> TUTORIAL (first run) or COUNTDOWN -> RUNNING -> CRASHED -> REVIVE_PENDING or RESULTS -> MENU / RETRY
PAUSED remembers the state it interrupted.
```

`RunSession` rejects invalid transitions, so a duplicate crash callback or a stale or
duplicate ad callback has no effect. `ScoreService` consumes gameplay events, and only
`Wallet.credit(reward_id, amount)` changes the coin balance. Reward IDs
(`run:<run_id>:base`, `run:<run_id>:double`) make a repeated credit a no-op.

## Procedural world

* **Grid**: intersections sit at grid points 64 m apart and roads are 16 m wide (one lane
  each way at ±3 m, parking strips at ±6.5 m).
* **Connectivity by construction**: every z-direction road is open, and x-direction roads on
  rows where `j % 3 == 0` are always open. Other x-direction roads can close, at most one per
  node side. So the city is always connected, every node has degree ≥ 3, loops always exist,
  and the only escape route can never be removed.
* **Pipeline per cell** (`ChunkPlanner`): pick a definition that fits the band → lay out
  static obstacles → validate that the lanes and intersection are clear → reserve hazard
  slots → reserve pickup lines → decoration. If validation fails, a known-safe recovery chunk
  is used and the failure is logged (`planner.failures`).
* **Separate RNG streams** for route, hazards, cosmetics, pickups and agents, so a cosmetic
  edit never changes gameplay. Each cell's generators are seeded from
  `(run_seed, stream, i, j)`. Record seed + `LaneGraph.GENERATOR_VERSION` to reproduce a layout.
* **Streaming** (`StreamingWorld`): keeps a 5×5 window that leans ahead of the car, plus the
  neighbourhoods of active police. It activates at most 2 cells per frame and recycles cells
  only when they're off camera. Hazards never spawn in visible cells or the spawn safe zone.
* **Origin shifting**: past 1,024 m, every node in the `origin_shift` group shifts by a whole
  number of cells, and `LaneGraph.origin_cell` absorbs the offset. Distance scoring uses the
  accumulated route distance.

## Pursuit

* `PoliceAgent` has four states: PURSUE, INTERCEPT, RECOVER and DISENGAGE. It makes
  decisions at 8 Hz (staggered) and moves at the physics rate, uses A* over the lane graph
  (bounded), raycasts for line of sight, leads the player by at most 0.8 s, and has
  rubber-banding capped at +4 m/s.
* `PursuitDirector` takes the police count, speed and aggression from the band, runs
  pressure/recovery waves, assigns intercept roles and despawns far officers. It spawns only
  at graph nodes that are out of view, at least 3 s of travel away, not ahead of the player
  and clear of player/traffic exclusion zones (`is_spawn_fair`, which is unit-tested).
* `TrafficManager`/`TrafficAgent` drive right-hand lanes. They stop at the stop line until
  they hold the intersection slot. Slots expire after 4 s and long waits force a grant, so
  the system can't deadlock. Agents keep a following gap.

## Rendering and smoothness

* Vehicles simulate at the 60 Hz physics rate. Each has a `CarVisual` (`game/art/car_visual.gd`)
  that interpolates between physics ticks every rendered frame, so motion stays smooth on
  90/120 Hz screens. It also spins and steers the Kenney wheel nodes and adds body roll/pitch.
* `ChaseCamera` runs per rendered frame on the interpolated transform, with frame-rate
  independent exponential smoothing. It locks the horizontal FOV (`KEEP_WIDTH`) so the road
  width stays constant in portrait.
* World streaming activates at most one block per frame (about 2–4 ms per block on desktop),
  which avoids hitches; `--probe` reports the worst block time.
* Skid marks use one MultiMesh ring buffer (a single draw call). Crash debris uses Kenney
  car-kit parts.

## Night lighting (`game/art/day_night.gd`)

* One darkness value drives sun/moon, ambient light, sky, fog and colour grading.
* Shared night materials in `ArtKit` (window emission masks per building kit, lamp heads,
  additive light pools, car lights) all scale from that value, so a full dusk-to-night change
  is a loop over a handful of materials.
* Night-only nodes (light pools, spotlights, beacons) sit in the `night_only` group and are
  toggled once when the lights switch on.
* Only a few real lights exist: 6 pooled OmniLights follow the lamps nearest the car, plus 2
  player headlight SpotLights and one beacon per police car (at most 4). Everything else is
  emissive or a fake light pool.
* Zoning: 3×3-cell districts are commercial (towers, plazas, parking, construction) or
  suburban (houses on lawns, parks), so neighbourhoods feel coherent.
* With no reverse gear, a car nosed into static geometry at low speed pivots along the surface
  to slide free. Police are not static, so being boxed in by them still ends in capture.

## Scene and folder contract

`res://game/{scenes,controllers,generation,data,art,audio,ui}` hold this title.
`res://addons/dashcore` holds the common code and UI builders. RunRoot owns and frees all
run-scoped references. Pools are validated after every reset.
