# Device benchmark sheet

Reference matrix (freeze it after testing): one older 4 GB phone, one 6 GB midrange phone and
one modern 8 GB phone, covering at least two GPU families.

| Gate | Target |
|---|---|
| Low preset | 30 FPS: p95 frame time ≤ 33.3 ms in a 20-minute representative run |
| High preset | 60 FPS: p95 ≤ 16.7 ms on declared mid/high devices |
| Stutter / memory | No gameplay frame > 100 ms after warmup; PSS ≤ 450 MB; growth < 10% between minutes 5 and 20 |
| Startup / stability | Cold launch to menu ≤ 5 s on midrange; 50 run/retry cycles without crash, pool growth or stale input |
| Distribution | Initial download ≤ 150 MB (measure the packaged AAB) |

| Date | Build hash | Device | OS | Renderer | Preset | Seed | p95 ms | Long frames | PSS MB | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
