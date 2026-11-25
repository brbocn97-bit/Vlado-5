class_name GraphicsSettings
extends Resource

enum QualityTier {
	LOW = 0,
	BALANCED = 1,
	HIGH_S25_ULTRA = 2,
}

@export var quality_tier: QualityTier = QualityTier.HIGH_S25_ULTRA
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_2X
@export var shadow_max_distance: float = 55.0
@export var directional_shadow_splits: int = 3
@export var lod_bias: float = 1.0

static func create_preset(tier: QualityTier) -> GraphicsSettings:
	var cfg := GraphicsSettings.new()
	cfg.quality_tier = tier
	match tier:
		QualityTier.LOW:
			cfg.render_scale = 0.75
			cfg.msaa_3d = Viewport.MSAA_DISABLED
			cfg.shadow_max_distance = 48.0
			cfg.directional_shadow_splits = 2
			cfg.lod_bias = 0.7
		QualityTier.BALANCED:
			cfg.render_scale = 0.90
			cfg.msaa_3d = Viewport.MSAA_DISABLED
			cfg.shadow_max_distance = 75.0
			cfg.directional_shadow_splits = 2
			cfg.lod_bias = 0.9
		QualityTier.HIGH_S25_ULTRA:
			cfg.render_scale = 1.0
			cfg.msaa_3d = Viewport.MSAA_2X
			cfg.shadow_max_distance = 105.0
			cfg.directional_shadow_splits = 3
			cfg.lod_bias = 1.0
	return cfg

func apply_to_viewport(vp: Viewport, sun: DirectionalLight3D = null) -> void:
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = render_scale
		vp.msaa_3d = msaa_3d
		vp.mesh_lod_threshold = lod_bias
	if sun:
		sun.directional_shadow_max_distance = shadow_max_distance
		sun.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			if directional_shadow_splits >= 3
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		)
