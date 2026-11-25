extends Node

signal graphics_changed(settings: GraphicsSettings)

var graphics: GraphicsSettings = GraphicsSettings.create_preset(GraphicsSettings.QualityTier.HIGH_S25_ULTRA)

func _ready() -> void:
	# Apply baseline viewport scaling/MSAA settings at startup.
	apply_graphics_to_scene()

func set_quality_tier(tier: GraphicsSettings.QualityTier) -> void:
	graphics = GraphicsSettings.create_preset(tier)
	apply_graphics_to_scene()
	graphics_changed.emit(graphics)

func apply_graphics_to_scene(sun: DirectionalLight3D = null) -> void:
	var vp := get_viewport()
	if vp:
		graphics.apply_to_viewport(vp, sun)
