class_name QualityPresets
extends RefCounted
## Low: reduced render scale, no shadows/post effects. High: full scale + shadows.
## Raise High only after thermal tests on reference devices.

const LOW := "low"
const HIGH := "high"


static func apply(preset: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> void:
	var high := preset == HIGH
	if viewport != null:
		viewport.scaling_3d_scale = 1.0 if high else 0.75
		viewport.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	if sun != null:
		sun.shadow_enabled = high
	if env != null:
		env.glow_enabled = false
		env.ssao_enabled = false
		env.fog_enabled = true
