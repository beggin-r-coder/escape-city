# Tuning log

One row per change to `handling_default.tres` / `difficulty_default.tres`. Include the build
hash, device and seed so results can be reproduced.

| Date | Build | Device | Seed | Change | Why | Observed result |
|---|---|---|---|---|---|---|
| 2026-11-24 | initial | desktop | — | Baseline values from the guide: player 10–22 m/s, ≤4 police, ≤8 traffic, 3 s capture, escape 5 s / 20 s cooldown | Starting point | Not yet playtested |
| 2026-11-25 | dev harness | desktop (Xvfb) | 42 | Chase camera height 17→25 m, distance 15→12 m, look-ahead 11→7 m, FOV 58→55 | Screenshots: towers covered ~40% of the screen at heat 4; police right behind the car were off-frame | Roads and junctions readable; tail-gating police now in frame |
| 2026-11-25 | dev harness | desktop (Xvfb) | 42 | Downtown towers 18–42 m → 14–28 m; construction max 26→18 m | Same occlusion problem | Fewer walls over the action |
| 2026-11-25 | dev harness | desktop (Xvfb) | 42 | Fog 0.007→0.0028, cool fog colour, new sky, more saturated building palette, darker asphalt | Everything read beige/low-contrast, even the car | Clear contrast between road, blocks and cars |
| 2026-11-25 | dev harness | headless probe | 2–6 | Player speed now clamped to measured forward velocity after collisions | Bug: a car pinned nose-to-nose by police read 5–9 m/s, so "boxed in → busted" could never fire | Pinned car reads 0 m/s; capture rule works as designed |
| 2026-11-25 | dev harness | headless probe | 2–6 | Police ram recoil: after a hit, that cop drops to 85% of player speed for 2.5 s | At heat 5 one cop could ram ~1×/s from 4 m with no window (100→0 HP in ~8 s) | Autopilot at max heat: wrecks within 120 s went 3/5 → 2/5 seeds. Needs human playtest |
