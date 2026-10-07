extends RefCounted
## Graphics presets (Low / Medium / High), picked in the [I] menu and saved to user://settings.cfg.
## High is the look the scenes are authored with; Medium and Low scale things down from there. player.gd calls apply()
## when each scene starts, so the preset survives scene changes. The scene's own values (SSR on/off, fog volume, light
## shadow fade, sun cascades) are remembered in metadata the first time, so going back to High restores them.
##   Low     no MSAA, FSR 1 at 77%, no SSR/SSAO, coarse fog volume, hard shadows, nearby light shadows only
##   Medium  no MSAA, no SSR, half-size SSAO, smaller fog volume, soft-low shadows
##   High    MSAA 2x + FXAA, SSR where the scene has it, full fog volume, soft-high shadows

const PATH := "user://settings.cfg"
const NAMES := ["Low", "Medium", "High"]
const LOW := 0
const MEDIUM := 1
const HIGH := 2

const P := {
	LOW: {"msaa": Viewport.MSAA_DISABLED, "scale": 0.77, "ssr": false, "ssao": false, "ssao_half": true,
		"fog_size": 48, "fog_depth": 48, "fog_filter": false, "shadow_q": RenderingServer.SHADOW_QUALITY_HARD,
		"dir_atlas": 2048, "pos_atlas": 2048, "light_fade": 0.5, "sun_splits": 2},
	MEDIUM: {"msaa": Viewport.MSAA_DISABLED, "scale": 1.0, "ssr": false, "ssao": true, "ssao_half": true,
		"fog_size": 64, "fog_depth": 64, "fog_filter": true, "shadow_q": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"dir_atlas": 4096, "pos_atlas": 4096, "light_fade": 0.75, "sun_splits": 4},
	HIGH: {"msaa": Viewport.MSAA_2X, "scale": 1.0, "ssr": true, "ssao": true, "ssao_half": false,
		"fog_size": 80, "fog_depth": 80, "fog_filter": true, "shadow_q": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"dir_atlas": 4096, "pos_atlas": 4096, "light_fade": 1.0, "sun_splits": 4},
}

static func get_preset() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return clampi(int(cfg.get_value("graphics", "preset", HIGH)), LOW, HIGH)

static func set_preset(preset: int, node: Node) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "preset", preset)
	cfg.save(PATH)
	apply(node)

## Apply the saved preset to the viewport, environment and lights of the scene `node` is in.
static func apply(node: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Dictionary = P[get_preset()]
	var vp := node.get_viewport()
	vp.msaa_3d = p["msaa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if p["scale"] >= 1.0 else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = p["scale"]
	vp.positional_shadow_atlas_size = p["pos_atlas"]

	RenderingServer.directional_shadow_atlas_set_size(p["dir_atlas"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["shadow_q"])
	RenderingServer.positional_soft_shadow_filter_set_quality(p["shadow_q"])
	RenderingServer.environment_set_volumetric_fog_volume_size(p["fog_size"], p["fog_depth"])
	RenderingServer.environment_set_volumetric_fog_filter_active(p["fog_filter"])
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, p["ssao_half"], 0.5, 2, 50.0, 300.0)

	var scene := node.get_tree().current_scene
	if scene == null:
		return
	for we in scene.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		if env == null:
			continue
		var orig: Dictionary = _orig(env, {"ssr": env.ssr_enabled, "ssao": env.ssao_enabled})
		env.ssr_enabled = orig["ssr"] and p["ssr"]
		env.ssao_enabled = orig["ssao"] and p["ssao"]
	for l in scene.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			var sun := l as DirectionalLight3D
			# keep the shadow distance: in the caverns the rock overhead is what keeps the sun out
			var o: Dictionary = _orig(sun, {"mode": sun.directional_shadow_mode})
			sun.directional_shadow_mode = o["mode"] if p["sun_splits"] == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		elif (l as Light3D).shadow_enabled and (l as Light3D).distance_fade_enabled:
			# shadowed lamps fade their shadow out at ~28 m (build_*.gd shadow_fade()); pull that in to draw fewer maps
			var lo: Dictionary = _orig(l, {"fade": (l as Light3D).distance_fade_shadow})
			(l as Light3D).distance_fade_shadow = lo["fade"] * p["light_fade"]

static func _orig(o: Object, now: Dictionary) -> Dictionary:
	if not o.has_meta("gfx_orig"):
		o.set_meta("gfx_orig", now)
	return o.get_meta("gfx_orig")
