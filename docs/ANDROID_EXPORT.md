# Android export (phase 0 smoke build)

1. Install JDK 17 and the Android SDK (platform-tools, build-tools, platform API 36), then set
   both paths in **Editor Settings → Export → Android**.
2. **Project → Install Android Build Template** (gradle build is needed for plugins later).
3. **Project → Export → Add… → Android**:
   * Package: `com.dashpanda.escapecity`, target SDK 36, landscape (sensor).
   * Architectures: arm64-v8a (add armeabi-v7a only if a reference device needs it).
   * Debug keystore for smoke tests. Configure the release keystore locally only. Godot 4.3
     keeps credentials in `.godot/export_credentials.cfg` (git-ignored), so
     `export_presets.cfg` can be committed.
4. Smoke test on day one: install the debug build, suspend/resume it, check that touch steering
   works with two fingers (steer + brake), check that audio resumes, then capture baseline
   profiling. Record the results in `DEVICE_BENCHMARKS.md`.
5. Before the vertical slice, do the native integration spike: an AdMob **test** rewarded
   unit, the UMP consent flow and a Play Billing test purchase in an *exported* build, through
   a maintained Godot Android plugin. Implement `AdsAdapter`, `ConsentAdapter` and
   `BillingAdapter` subclasses, then swap them in `DashCore._resolve_platform_adapters()`.
6. Release builds ship as a signed **AAB** through a Play testing track, not as a local APK.
