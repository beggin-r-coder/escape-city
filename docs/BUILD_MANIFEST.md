# Reproducible build manifest

Fill this in during the phase 0 smoke build and update it whenever a value changes.
Don't upgrade the engine during release hardening without rerunning every gate.

| Item | Value |
|---|---|
| Engine | Godot **4.3-stable** (standard, non-.NET). Pin the exact build hash once it's downloaded. |
| Export templates | 4.3-stable (must match the engine) |
| Renderer | GL Compatibility (baseline). Compare Mobile on a midrange Vulkan device before choosing the production renderer. |
| Language | Typed GDScript |
| Android package ID | `com.dashpanda.escapecity` (proposed; confirm before the first upload) |
| Target / min SDK | Target **API 36** (Play policy for new apps/updates from 31 Aug 2026). Set the min SDK from the tested engine/plugin combination. |
| Android SDK / build-tools | _record_ |
| NDK | _record_ |
| JDK | 17 (Godot 4.3 requirement); record the exact vendor/version |
| Godot Android plugins | none yet. Record name + version + commit for the ads/consent/billing bridge. |
| DashCore | 0.1.0 (vendored in `addons/dashcore`, see `addons/dashcore/VERSION`) |
| Generator version | `LaneGraph.GENERATOR_VERSION = 1` |
| Signing | Keystore stored **outside** the repo. Record the custodian and the recovery procedure (not the secrets). |
