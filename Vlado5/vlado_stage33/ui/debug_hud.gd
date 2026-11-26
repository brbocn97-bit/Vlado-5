class_name DebugHUD
extends CanvasLayer

@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var animator_path: NodePath
@export var mobile_controls_path: NodePath
@export var time_controller_path: NodePath
@export var vegetation_path: NodePath

var _player: PlayerController
var _camera_rig: PlayerCamera
var _animator: PlayerAnimator
var _mobile_controls: MobileControls
var _time_ctrl: TimeOfDayController
var _vegetation: MontenegroVegetation
var _weapon: WeaponController
var _arsenal: WeaponArsenal
var _fp_rig: FirstPersonRig

var _crosshair: _CrosshairOverlay
var _combat_label: Label
var _hp_fill: ColorRect
var _stam_fill: ColorRect

@onready var _telemetry_label: Label = $Panel/Margin/VBox/TelemetryLabel
@onready var _quality_btn: Button = $Panel/Margin/VBox/ControlsRow/QualityButton
@onready var _time_btn: Button = $Panel/Margin/VBox/ControlsRow/TimeButton
@onready var _cam_in_btn: Button = $Panel/Margin/VBox/ControlsRow/CamInButton
@onready var _cam_out_btn: Button = $Panel/Margin/VBox/ControlsRow/CamOutButton
@onready var _shoulder_btn: Button = $Panel/Margin/VBox/ControlsRow/ShoulderButton

var _tier_names := ["Low", "Balanced", "S25 Ultra High"]
var _current_tier: int = 2
var _time_mode_idx: int = 0
var _time_labels := ["Morning", "Noon", "Dusk", "Night", "Auto"]
var _hit_notice_timer: float = 0.0
var _last_hit_text: String = ""

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_animator = get_node_or_null(animator_path)
	_mobile_controls = get_node_or_null(mobile_controls_path)
	_time_ctrl = get_node_or_null(time_controller_path)
	_vegetation = get_node_or_null(vegetation_path)
	if _player:
		_weapon = _player.find_child("WeaponController", true, false) as WeaponController
		_arsenal = _player.find_child("WeaponArsenal", true, false) as WeaponArsenal
		_fp_rig = _player.find_child("FirstPersonRig", true, false) as FirstPersonRig

	_build_combat_hud_widgets()
	# Production phone HUD: keep health/stamina/ammo, but remove development
	# telemetry and editor-only buttons from the gameplay screen.
	_telemetry_label.visible = false
	$Panel/Margin/VBox/ControlsRow.visible = false
	var status_panel := $Panel as PanelContainer
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.offset_left = -670.0
	status_panel.offset_top = 92.0
	status_panel.offset_right = -18.0
	status_panel.offset_bottom = 164.0

	if _mobile_controls and _player:
		_mobile_controls.joystick_moved.connect(_player.set_touch_move_vector)
		_mobile_controls.run_toggled.connect(_player.toggle_run)
		_mobile_controls.sprint_toggled.connect(_player.toggle_sprint)
		_mobile_controls.crouch_toggled.connect(_player.toggle_crouch)
		_mobile_controls.jump_pressed.connect(_player.request_jump)
		_mobile_controls.view_toggled.connect(_player.toggle_view_mode)
	if _mobile_controls and _weapon:
		_mobile_controls.equip_toggled.connect(_weapon.toggle_equip)
		_mobile_controls.aim_toggled.connect(_weapon.toggle_aim)
		_mobile_controls.fire_pressed.connect(_on_mobile_fire)
		_mobile_controls.reload_pressed.connect(_on_mobile_reload)
	if _weapon:
		_weapon.shot_fired.connect(_on_shot_fired)
		_weapon.target_hit.connect(_on_target_hit)
	if _mobile_controls and _camera_rig:
		_mobile_controls.camera_dragged.connect(_camera_rig.add_touch_look_delta)

	if _quality_btn:
		_quality_btn.pressed.connect(_on_cycle_quality)
		_quality_btn.text = "Quality: " + _tier_names[_current_tier]
	if _time_btn:
		_time_btn.visible = (_time_ctrl != null)
		_time_btn.pressed.connect(_on_cycle_time)
		_time_btn.text = "Time: " + _time_labels[_time_mode_idx]
	if _cam_in_btn:
		_cam_in_btn.pressed.connect(_on_cam_zoom_in)
	if _cam_out_btn:
		_cam_out_btn.pressed.connect(_on_cam_zoom_out)
	if _shoulder_btn:
		_shoulder_btn.pressed.connect(_on_cycle_shoulder)
		_update_shoulder_text()

func _build_combat_hud_widgets() -> void:
	_crosshair = _CrosshairOverlay.new()
	add_child(_crosshair)
	move_child(_crosshair, 0)

	var vbox := $Panel/Margin/VBox as VBoxContainer
	if not vbox:
		return

	var bars_row := HBoxContainer.new()
	bars_row.add_theme_constant_override("separation", 12)
	vbox.add_child(bars_row)

	# Health bar
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.12, 0.12, 0.12, 0.85)
	hp_bg.custom_minimum_size = Vector2(150, 10)
	bars_row.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.76, 0.24, 0.22, 0.95)
	_hp_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hp_fill.size = Vector2(150, 10)
	hp_bg.add_child(_hp_fill)

	# Stamina bar
	var st_bg := ColorRect.new()
	st_bg.color = Color(0.12, 0.12, 0.12, 0.85)
	st_bg.custom_minimum_size = Vector2(150, 10)
	bars_row.add_child(st_bg)
	_stam_fill = ColorRect.new()
	_stam_fill.color = Color(0.78, 0.72, 0.28, 0.95)
	_stam_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stam_fill.size = Vector2(150, 10)
	st_bg.add_child(_stam_fill)

	_combat_label = Label.new()
	_combat_label.add_theme_font_size_override("font_size", 14)
	_combat_label.text = "M48: 5 / 30 [Holstered]  |  Targets: 0/6"
	bars_row.add_child(_combat_label)

func _on_shot_fired() -> void:
	if _crosshair:
		_crosshair.kick_bloom()

func _on_target_hit(is_target: bool, distance_m: float, _total_hits: int) -> void:
	if is_target:
		_hit_notice_timer = 1.6
		_last_hit_text = "HIT %.0fm!" % distance_m
		if _crosshair:
			_crosshair.trigger_hitmarker(true)
	elif _crosshair:
		_crosshair.trigger_hitmarker(false)

var _arsenal_bound := false

func _arsenal_ref() -> WeaponArsenal:
	if _arsenal == null or not is_instance_valid(_arsenal):
		if _player:
			_arsenal = _player.find_child("WeaponArsenal", true, false) as WeaponArsenal
			_arsenal_bound = false
	if _arsenal and not _arsenal_bound:
		_arsenal_bound = true
		if not _arsenal.shot_fired.is_connected(_on_shot_fired):
			_arsenal.shot_fired.connect(_on_shot_fired)
		if not _arsenal.target_hit.is_connected(_on_target_hit):
			_arsenal.target_hit.connect(_on_target_hit)
	return _arsenal


func _on_mobile_fire() -> void:
	var a := _arsenal_ref()
	if a and a.active != WeaponArsenal.SLOT_M48:
		a.try_fire(true)
	elif _weapon:
		_weapon.try_fire()


func _on_mobile_reload() -> void:
	var a := _arsenal_ref()
	if a and a.active != WeaponArsenal.SLOT_M48:
		a.reload()
	elif _weapon:
		_weapon.try_reload()


func _on_cycle_quality() -> void:
	var qm := get_node_or_null("/root/QualityManager")
	if qm and qm.has_method("cycle_tier"):
		qm.cycle_tier()
		_current_tier = int(qm.get("tier"))
		if _vegetation:
			_vegetation.apply_quality_scale(mini(_current_tier, 2))
		_quality_btn.text = "Quality: " + str(qm.get("tier_name"))
		return
	_current_tier = (_current_tier + 1) % 3
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.set_quality_tier(_current_tier as GraphicsSettings.QualityTier)
	if _vegetation:
		_vegetation.apply_quality_scale(_current_tier)
	_quality_btn.text = "Quality: " + _tier_names[_current_tier]

func _on_cycle_time() -> void:
	if not _time_ctrl:
		return
	_time_mode_idx = (_time_mode_idx + 1) % _time_labels.size()
	match _time_mode_idx:
		0:
			_time_ctrl.auto_cycle = false
			_time_ctrl.set_preset(TimeOfDayController.TimePreset.MORNING)
		1:
			_time_ctrl.auto_cycle = false
			_time_ctrl.set_preset(TimeOfDayController.TimePreset.NOON)
		2:
			_time_ctrl.auto_cycle = false
			_time_ctrl.set_preset(TimeOfDayController.TimePreset.DUSK)
		3:
			_time_ctrl.auto_cycle = false
			_time_ctrl.set_preset(TimeOfDayController.TimePreset.NIGHT)
		4:
			_time_ctrl.auto_cycle = true
	_time_btn.text = "Time: " + _time_labels[_time_mode_idx]

func _on_cam_zoom_in() -> void:
	if _camera_rig:
		_camera_rig.adjust_distance(-0.35)

func _on_cam_zoom_out() -> void:
	if _camera_rig:
		_camera_rig.adjust_distance(0.35)

func _on_cycle_shoulder() -> void:
	if _camera_rig:
		_camera_rig.cycle_shoulder_offset()
		_update_shoulder_text()

func _update_shoulder_text() -> void:
	if not _shoulder_btn or not _camera_rig:
		return
	if _camera_rig.shoulder_offset_x > 0.1:
		_shoulder_btn.text = "Shldr: R"
	elif _camera_rig.shoulder_offset_x < -0.1:
		_shoulder_btn.text = "Shldr: L"
	else:
		_shoulder_btn.text = "Shldr: C"

func _process(delta: float) -> void:
	if _hit_notice_timer > 0.0:
		_hit_notice_timer = maxf(0.0, _hit_notice_timer - delta)

	if _mobile_controls and _player:
		_mobile_controls.set_mode_states(
			_player.is_run_active(),
			_player.is_sprint_active(),
			_player.is_crouch_active()
		)
		_mobile_controls.set_view_mode(_player.is_first_person())
	var a := _arsenal_ref()
	var d: WeaponDef = a.active_def() if a else null
	if _mobile_controls and _weapon:
		var is_rld: bool = a.is_reloading() if (a and a.active != WeaponArsenal.SLOT_M48) else (_weapon.current_state == WeaponController.State.RELOADING)
		_mobile_controls.set_combat_states(
			_weapon.is_equipped(),
			_weapon.is_aiming(),
			is_rld
		)
		if d != null:
			var btn_lbl := "ORUŽJE"
			if d.hold_style == "pistol":
				btn_lbl = "PIŠTOLJ"
			elif d.is_explosive:
				btn_lbl = "BOMBA"
			elif d.is_melee:
				btn_lbl = "NOŽ"
			elif d.slot == WeaponArsenal.SLOT_M48 or d.category == "Puške repetirke":
				btn_lbl = "PUŠKA"
			_mobile_controls.set_weapon_button_label(btn_lbl)

	if _time_btn and _time_ctrl:
		var lbl := "Auto" if _time_ctrl.auto_cycle else _time_ctrl.get_time_label()
		_time_btn.text = "Time: " + lbl

	if _hp_fill and _player:
		_hp_fill.size.x = 150.0 * clampf(_player.health / maxf(_player.max_health, 1.0), 0.0, 1.0)
	if _stam_fill and _player:
		_stam_fill.size.x = 150.0 * clampf(_player.stamina / maxf(_player.max_stamina, 1.0), 0.0, 1.0)

	var view_lbl := _player.get_view_mode_label() if _player else "THIRD PERSON"

	if _combat_label and _weapon:
		var hit_suffix := ("  |  " + _last_hit_text) if _hit_notice_timer > 0.0 else ""
		if a and d and a.active != WeaponArsenal.SLOT_M48:
			var ammo_arr: Array = a.ammo_for(d.slot)
			var st_lbl: String = "Reloading" if a.is_reloading() else _weapon.get_state_label()
			_combat_label.text = "[%s]  %s: %d / %d [%s]  |  Targets: %d/6%s" % [
				view_lbl,
				d.display_name,
				int(ammo_arr[0]),
				int(ammo_arr[1]),
				st_lbl,
				_weapon.targets_hit_set.size(),
				hit_suffix,
			]
		else:
			_combat_label.text = "[%s]  M48: %d / %d [%s]  |  Targets: %d/6%s" % [
				view_lbl,
				_weapon.mag_ammo,
				_weapon.reserve_ammo,
				_weapon.get_state_label(),
				_weapon.targets_hit_set.size(),
				hit_suffix,
			]

	if _crosshair and _weapon and _player:
		var move_spread := clampf(_player.current_horizontal_speed * 2.4, 0.0, 14.0)
		_crosshair.update_state(_weapon.is_equipped(), _weapon.is_aiming(), move_spread, _player.is_first_person())

	if not _telemetry_label:
		return
	var fps := Engine.get_frames_per_second()
	var state := _player.current_locomotion_state if _player else "-"
	var gait := _player.get_gait_label() if _player else "-"
	var speed := _player.current_horizontal_speed if _player else 0.0
	var slope := _player.current_slope_deg if _player else 0.0
	var anim := _animator.get_active_animation() if _animator else "-"
	if _player and _player.is_first_person() and _fp_rig and _fp_rig.is_fp_visible() and _player.weapon_equipped:
		anim = _fp_rig.get_active_animation()
	var pos := _player.global_position if _player else Vector3.ZERO
	# POPRAVKA v17 - GRUPA E: visina IZNAD TLA, ne sirova svjetska Y.
	var above_ground := pos.y
	var _td = _terrain_data_ref()
	if _td != null and _td.has_method("get_height"):
		above_ground = pos.y - _td.get_height(pos.x, pos.z)
	var dist := _camera_rig.get_effective_distance() if _camera_rig else 0.0
	var fov := _camera_rig.get_effective_fov() if _camera_rig else 0.0
	var stage_txt := "Stage 3.2 | " + _time_ctrl.get_time_label() if _time_ctrl else "Stage 1"

	_telemetry_label.text = (
		"Vlado Sipcic | %s | FPS: %d | %s | Mode: %s\n" +
		"State: %s  |  Anim: %s  |  Speed: %.2f m/s\n" +
		"Slope: %.1f deg  |  Cam: %.2fm/%.0f deg  |  Pos: (%.1f, %.1f)  tlo+%.2f"
	) % [stage_txt, fps, view_lbl, gait, state, anim, speed, slope, dist, fov, pos.x, pos.z, above_ground]


## POPRAVKA v17 - GRUPA E: terrain_data iz glavne scene.
var _td_cached = null

func _terrain_data_ref():
	if _td_cached != null and is_instance_valid(_td_cached):
		return _td_cached
	var sc := get_tree().current_scene
	if sc != null:
		_td_cached = sc.get("terrain_data")
	return _td_cached


class _CrosshairOverlay extends Control:
	var _equipped := false
	var _aiming := false
	var _first_person := false
	var _spread := 0.0
	var _bloom := 0.0
	var _hit_t := 0.0
	var _hit_target := false

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func kick_bloom() -> void:
		_bloom = 14.0
		queue_redraw()

	func trigger_hitmarker(is_tgt: bool) -> void:
		_hit_t = 0.28
		_hit_target = is_tgt
		queue_redraw()

	func update_state(eq: bool, aim: bool, move_spread: float, is_fp: bool = false) -> void:
		if _equipped != eq or _aiming != aim or _first_person != is_fp or absf(_spread - move_spread) > 0.4:
			_equipped = eq
			_aiming = aim
			_first_person = is_fp
			_spread = move_spread
			queue_redraw()

	func _process(delta: float) -> void:
		var dirty := false
		if _bloom > 0.05:
			_bloom = lerpf(_bloom, 0.0, 1.0 - exp(-10.0 * delta))
			dirty = true
		if _hit_t > 0.0:
			_hit_t = maxf(0.0, _hit_t - delta)
			dirty = true
		if dirty:
			queue_redraw()

	func _draw() -> void:
		if not _equipped and _hit_t <= 0.0:
			return
		var c := get_viewport_rect().size * 0.5
		if _equipped:
			if _first_person and _aiming:
				# Crisp subtle iron-sight alignment dot + wide outer ticks that do not obstruct M48 front/rear sights
				var pip_col := Color(1.0, 0.94, 0.68, 0.72)
				draw_circle(c, 1.8, pip_col)
				var ogap := 18.0 + _bloom * 0.65
				var ocol := Color(0.98, 0.95, 0.85, 0.42)
				draw_line(c + Vector2(-ogap - 6.0, 0), c + Vector2(-ogap, 0), ocol, 1.5, true)
				draw_line(c + Vector2(ogap, 0), c + Vector2(ogap + 6.0, 0), ocol, 1.5, true)
			else:
				var gap := (6.0 if _aiming else 14.0) + _spread * (0.45 if _aiming else 1.0) + _bloom
				var ln := 10.0 if _aiming else 8.0
				var col := Color(0.98, 0.95, 0.85, 0.92 if _aiming else 0.72)
				draw_circle(c, 2.0, col)
				draw_line(c + Vector2(-gap - ln, 0), c + Vector2(-gap, 0), col, 2.0, true)
				draw_line(c + Vector2(gap, 0), c + Vector2(gap + ln, 0), col, 2.0, true)
				draw_line(c + Vector2(0, -gap - ln), c + Vector2(0, -gap), col, 2.0, true)
				draw_line(c + Vector2(0, gap), c + Vector2(0, gap + ln), col, 2.0, true)

		if _hit_t > 0.0:
			var hc := Color(1.0, 0.30, 0.22, minf(_hit_t * 4.5, 1.0)) if _hit_target else Color(0.95, 0.88, 0.55, minf(_hit_t * 4.0, 1.0))
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(c + d * 6.0, c + d * 15.0, hc, 2.5, true)
