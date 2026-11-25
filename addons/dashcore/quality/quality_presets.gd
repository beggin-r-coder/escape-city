class_name QualityPresets
extends RefCounted
## Low: 85% render scale, one cheap shadow map. High: full scale, MSAA 2x, 4-split shadows.
## Raise High only after thermal tests on reference devices.

const LOW := "low"
const HIGH := "high"


static func apply(preset: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> void:
	var high := preset == HIGH
	if viewport != null:
		viewport.scaling_3d_scale = 1.0 if high else 0.85
		viewport.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	if sun != null:
		# Low keeps one cheap orthogonal shadow map close to the car; High uses 4 splits.
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 110.0 if high else 60.0
		sun.shadow_blur = 1.5 if high else 1.0
	if env != null:
		env.glow_enabled = false
		env.ssao_enabled = false
		env.fog_enabled = true
