extends Node

const GraphicsSettingsScript = preload("res://resources/graphics_settings.gd")

signal graphics_changed(settings: Resource)

var graphics: Resource = GraphicsSettingsScript.create_preset(GraphicsSettingsScript.QualityTier.HIGH_S25_ULTRA)

func _ready() -> void:
	# Apply baseline viewport scaling/MSAA settings at startup.
	apply_graphics_to_scene()

func set_quality_tier(tier) -> void:
	graphics = GraphicsSettings.create_preset(tier)
	apply_graphics_to_scene()
	graphics_changed.emit(graphics)

func apply_graphics_to_scene(sun: DirectionalLight3D = null) -> void:
	var vp := get_viewport()
	if vp:
		graphics.apply_to_viewport(vp, sun)
