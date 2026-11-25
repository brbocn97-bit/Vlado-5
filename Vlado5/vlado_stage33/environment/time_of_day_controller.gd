class_name TimeOfDayController
extends Node

enum TimePreset {
	MORNING,
	NOON,
	DUSK,
	NIGHT,
}

@export var auto_cycle: bool = false
@export var day_duration_seconds: float = 240.0
@export_range(0.0, 24.0) var current_hour: float = 10.25

var sun_light: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var env_res: Environment
var night_lights: Array[Light3D] = []
var emissive_window_mats: Array[StandardMaterial3D] = []

func setup(
	p_sun: DirectionalLight3D,
	p_world_env: WorldEnvironment,
	p_night_lights: Array[Light3D],
	p_window_mats: Array[StandardMaterial3D]
) -> void:
	sun_light = p_sun
	world_env = p_world_env
	night_lights = p_night_lights
	emissive_window_mats = p_window_mats

	if world_env and world_env.environment:
		env_res = world_env.environment
		if env_res.sky and env_res.sky.sky_material is ProceduralSkyMaterial:
			sky_mat = env_res.sky.sky_material as ProceduralSkyMaterial

	apply_hour(current_hour)

func _process(delta: float) -> void:
	if auto_cycle:
		current_hour = fmod(current_hour + (24.0 / maxf(day_duration_seconds, 10.0)) * delta, 24.0)
		apply_hour(current_hour)

func set_preset(preset: TimePreset) -> void:
	match preset:
		TimePreset.MORNING:
			current_hour = 9.25
		TimePreset.NOON:
			current_hour = 13.0
		TimePreset.DUSK:
			current_hour = 18.25
		TimePreset.NIGHT:
			current_hour = 22.5
	apply_hour(current_hour)

func get_time_label() -> String:
	var h := int(floor(current_hour)) % 24
	var m := int(floor((current_hour - floor(current_hour)) * 60.0))
	var tag := "Day"
	if current_hour >= 17.5 and current_hour < 20.0:
		tag = "Dusk"
	elif current_hour >= 20.0 or current_hour < 5.5:
		tag = "Night"
	elif current_hour < 10.5:
		tag = "Morning"
	return "%02d:%02d (%s)" % [h, m, tag]

func apply_hour(hour: float) -> void:
	current_hour = fmod(maxf(hour, 0.0), 24.0)
	if not sun_light or not env_res or not sky_mat:
		return

	# Smooth daylight factor: 0.0 at night, 1.0 at midday
	var sun_elev_deg := -15.0
	if current_hour >= 5.5 and current_hour <= 19.2:
		var day_t := (current_hour - 5.5) / (19.2 - 5.5)
		sun_elev_deg = sin(day_t * PI) * 58.0 - 2.0
	var is_night := current_hour < 5.8 or current_hour > 19.0
	var dusk_weight := 0.0
	if current_hour >= 16.8 and current_hour <= 19.3:
		dusk_weight = sin(clampf((current_hour - 16.8) / 2.5, 0.0, 1.0) * PI)
	elif current_hour >= 5.4 and current_hour <= 7.8:
		dusk_weight = sin(clampf((current_hour - 5.4) / 2.4, 0.0, 1.0) * PI)

	if is_night:
		# Cool silver-blue Balkan moonlight
		sun_light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
		sun_light.light_color = Color(0.62, 0.72, 0.88)
		sun_light.light_energy = 0.44
	else:
		var azimuth := lerpf(-68.0, 68.0, clampf((current_hour - 6.0) / 13.0, 0.0, 1.0))
		sun_light.rotation_degrees = Vector3(-maxf(sun_elev_deg, 6.0), azimuth, 0.0)
		var noon_col := Color(0.98, 0.95, 0.89)
		var dusk_col := Color(0.95, 0.63, 0.38)
		sun_light.light_color = noon_col.lerp(dusk_col, dusk_weight)
		sun_light.light_energy = lerpf(1.38, 0.85, dusk_weight)

	# Sky & ambient palette (grounded, desaturated WWII Montenegro atmosphere)
	var day_top := Color(0.28, 0.42, 0.56)
	var day_horizon := Color(0.66, 0.72, 0.75)
	var dusk_top := Color(0.22, 0.26, 0.38)
	var dusk_horizon := Color(0.76, 0.54, 0.40)
	var night_top := Color(0.024, 0.035, 0.062)
	var night_horizon := Color(0.055, 0.080, 0.125)

	var sky_top := day_top.lerp(dusk_top, dusk_weight)
	var sky_hor := day_horizon.lerp(dusk_horizon, dusk_weight)
	if is_night:
		sky_top = night_top
		sky_hor = night_horizon

	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_hor
	sky_mat.ground_horizon_color = sky_hor * 0.72
	sky_mat.ground_bottom_color = Color(0.11, 0.12, 0.11) if not is_night else Color(0.02, 0.025, 0.03)
	sky_mat.sun_angle_max = 18.0 if not is_night else 6.0
	sky_mat.sun_curve = 0.14

	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_res.ambient_light_sky_contribution = 0.78
	env_res.ambient_light_energy = 0.38 if is_night else lerpf(0.68, 0.52, dusk_weight)

	# Atmospheric mountain fog
	env_res.fog_enabled = true
	env_res.fog_light_color = sky_hor * (0.65 if is_night else 0.92)
	env_res.fog_density = 0.0052 if is_night else lerpf(0.0038, 0.0048, dusk_weight)
	env_res.fog_sky_affect = 0.68
	env_res.fog_aerial_perspective = 0.62

	# Warm oil lanterns & cottage window glow at dusk/night
	var lantern_strength := 1.0 if is_night else dusk_weight * 0.75
	for l in night_lights:
		if is_instance_valid(l):
			l.visible = lantern_strength > 0.08
			l.light_energy = 1.65 * lantern_strength
	for wm in emissive_window_mats:
		if is_instance_valid(wm):
			wm.emission_enabled = lantern_strength > 0.08
			wm.emission_energy_multiplier = 1.45 * lantern_strength
