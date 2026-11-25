# Game design summary (from the Development Guide v1.0)

**Hook:** How long can you outrun the police?
**Scope:** an arcade chase through a connected district of reusable road blocks. It is not a
living open world: no pedestrians and no unrestricted simulation.

## Core loop
Begin with one pursuer → steer through traffic → drift around a junction → break line of
sight or create distance → collect a risky coin trail → survive escalating heat → get wrecked
or boxed in → bank rewards → equip a car look → retry.

## Controls & feel
* Left-thumb drag steering (floating origin, dead zone), with optional fixed left/right buttons.
* Auto-throttle. Hold the right brake button to slow down. Steering while braking adds a
  capped drift assist. There's no separate handbrake.
* High third-person chase camera with a stable horizon. It widens near intersections, and
  edge chevrons warn about off-screen police.
* CharacterBody3D arcade car (heading, longitudinal speed, lateral slip). Walls block movement;
  vehicle contacts apply scripted slowdown and damage.

## Session rules
* Portrait (720×1280 design resolution, one-handed friendly). The first run teaches one action at a time (steer → brake → drift → escape goal).
* The game pauses on focus loss, held touches are cleared on resume, and the UI consumes
  touches before gameplay does.
* Game over freezes rewards, shows a clear failure reason, and offers Retry before optional
  shop/ad actions. The retry target is under 2 s.

## Prototype vs Release 1
* **Prototype (this repo now):** generated district streaming, a player car, police (up to
  4), traffic (up to 8), breakable cones/crates, capture/wreck, restart. It also already has
  the release-architecture scaffolding (saves, wallet, ads/billing/consent interfaces with
  fakes, telemetry).
* **Release 1:** 12 district blocks, 3 player looks, 2 police skins, 4 traffic looks and one
  polished palette, plus onboarding, settings, save migration, lifecycle handling,
  consent-aware monetization, purchase recovery and store materials.
* **Excluded:** multiplayer, accounts, live events, global leaderboard, cloud saves, UGC and a
  gameplay backend.

## Monetization (small surface)
* Rewarded: either one revive after a crash or 2× base coins at results, never both in the
  same run.
* Interstitial: at most one per 3 completed runs and 180 s (whichever is stricter). None in
  the first 3 runs or after a rewarded ad, and only at results → menu/retry boundaries. No
  banners over play.
* Non-consumable "Remove Forced Ads" (rewarded ads stay optional). Cosmetics change looks only.
* The first earnable cosmetic costs about 10 normal runs (300 coins). Tune from observed earnings.
