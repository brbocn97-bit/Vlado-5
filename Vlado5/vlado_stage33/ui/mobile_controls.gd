class_name MobileControls
extends Control

signal joystick_moved(move_vec: Vector2)
signal camera_dragged(delta_px: Vector2)
signal run_toggled()
signal sprint_toggled()
signal crouch_toggled()
signal jump_pressed()
signal equip_toggled()
signal aim_toggled()
signal fire_pressed()
signal reload_pressed()
signal view_toggled()

@export var max_joystick_radius: float = 88.0
@export var knob_radius: float = 34.0
@export var deadzone: float = 0.12
@export var left_zone_ratio: float = 0.44
@export var top_hud_safe_x: float = 660.0
@export var top_hud_safe_y: float = 235.0

var _default_center: Vector2 = Vector2(190.0, 880.0)
var _joy_center: Vector2 = Vector2(190.0, 880.0)
var _joy_knob: Vector2 = Vector2(190.0, 880.0)
var _joy_finger: int = -1
var _cam_finger: int = -1
var _btn_fingers: Dictionary = {}
var _mouse_joy_active: bool = false
var _move_vec: Vector2 = Vector2.ZERO

var _run_active: bool = false
var _sprint_active: bool = false
var _crouch_active: bool = false
var _jump_highlight: bool = false
var _rifle_equipped: bool = false
var _aim_active: bool = false
var _fire_flash_t: float = 0.0
var _reloading_active: bool = false
var _first_person_active: bool = false

var _buttons: Dictionary = {}
var _ui_scale: float = 1.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)

func _process(delta: float) -> void:
	if _fire_flash_t > 0.0:
		_fire_flash_t = maxf(0.0, _fire_flash_t - delta)
		if _fire_flash_t <= 0.0:
			queue_redraw()

func _update_layout() -> void:
	var sz := get_viewport_rect().size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(1920.0, 1080.0)
	_ui_scale = clampf(minf(sz.x / 1536.0, sz.y / 864.0), 0.72, 1.18)
	max_joystick_radius = 76.0 * _ui_scale
	knob_radius = 29.0 * _ui_scale
	_default_center = Vector2(maxf(112.0, sz.x * 0.125), sz.y - 138.0 * _ui_scale)
	if _joy_finger == -1 and not _mouse_joy_active:
		_joy_center = _default_center
		_joy_knob = _default_center

	# Ergonomic thumb layout, scaled to viewport. Combat controls sit above
	# movement controls and never overlap the map or top weapon panel.
	var s := _ui_scale
	_buttons = {
		"jump": {"pos": Vector2(sz.x - 104.0*s, sz.y - 108.0*s), "r": 43.0*s, "label": "SKOK"},
		"crouch": {"pos": Vector2(sz.x - 222.0*s, sz.y - 82.0*s), "r": 36.0*s, "label": "ČUČANJ"},
		"run": {"pos": Vector2(sz.x - 204.0*s, sz.y - 190.0*s), "r": 36.0*s, "label": "TRK"},
		"sprint": {"pos": Vector2(sz.x - 105.0*s, sz.y - 222.0*s), "r": 38.0*s, "label": "SPRINT"},
		"rifle": {"pos": Vector2(sz.x - 105.0*s, sz.y - 330.0*s), "r": 36.0*s, "label": "ORUŽJE"},
		"aim": {"pos": Vector2(sz.x - 205.0*s, sz.y - 308.0*s), "r": 38.0*s, "label": "NIŠAN"},
		"view": {"pos": Vector2(sz.x - 305.0*s, sz.y - 320.0*s), "r": 34.0*s, "label": "POGLED"},
		"fire": {"pos": Vector2(sz.x - 310.0*s, sz.y - 205.0*s), "r": 45.0*s, "label": "PALI"},
		"reload": {"pos": Vector2(sz.x - 320.0*s, sz.y - 88.0*s), "r": 33.0*s, "label": "PUNI"},
	}
	queue_redraw()

func set_mode_states(run_on: bool, sprint_on: bool, crouch_on: bool) -> void:
	if _run_active != run_on or _sprint_active != sprint_on or _crouch_active != crouch_on:
		_run_active = run_on
		_sprint_active = sprint_on
		_crouch_active = crouch_on
		queue_redraw()

func set_combat_states(equipped: bool, aiming: bool, reloading: bool) -> void:
	if _rifle_equipped != equipped or _aim_active != aiming or _reloading_active != reloading:
		_rifle_equipped = equipped
		_aim_active = aiming
		_reloading_active = reloading
		queue_redraw()

func set_view_mode(is_fp: bool) -> void:
	if _first_person_active != is_fp:
		_first_person_active = is_fp
		queue_redraw()

func set_weapon_button_label(lbl: String) -> void:
	if _buttons.has("rifle") and String(_buttons["rifle"]["label"]) != lbl:
		_buttons["rifle"]["label"] = lbl
		queue_redraw()

func get_button_center(btn_id: String) -> Vector2:
	if _buttons.has(btn_id):
		return _buttons[btn_id]["pos"]
	return Vector2.ZERO

func get_move_vector() -> Vector2:
	return _move_vec


func is_fire_held() -> bool:
	for k in _btn_fingers.keys():
		if _btn_fingers[k] == "fire":
			return true
	return false

func _hit_test_button(pos: Vector2) -> String:
	for btn_id in _buttons.keys():
		var b: Dictionary = _buttons[btn_id]
		if pos.distance_to(b["pos"]) <= float(b["r"]) + 10.0:
			return btn_id
	return ""

func _trigger_button(btn_id: String) -> void:
	match btn_id:
		"run":
			run_toggled.emit()
		"sprint":
			sprint_toggled.emit()
		"crouch":
			crouch_toggled.emit()
		"jump":
			_jump_highlight = true
			jump_pressed.emit()
		"rifle":
			equip_toggled.emit()
		"aim":
			aim_toggled.emit()
		"fire":
			_fire_flash_t = 0.16
			fire_pressed.emit()
		"reload":
			reload_pressed.emit()
		"view":
			view_toggled.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	var sz := get_viewport_rect().size
	var split_x := sz.x * left_zone_ratio

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if st.position.y < top_hud_safe_y and st.position.x < top_hud_safe_x:
				return
			var hit_btn := _hit_test_button(st.position)
			if hit_btn != "":
				_btn_fingers[st.index] = hit_btn
				_trigger_button(hit_btn)
				return
			if st.position.x <= split_x and _joy_finger == -1:
				_joy_finger = st.index
				_joy_center = st.position
				_joy_knob = st.position
				_update_joystick_value(st.position)
				queue_redraw()
			elif st.position.x > split_x and _cam_finger == -1:
				_cam_finger = st.index
		else:
			if _btn_fingers.has(st.index):
				if _btn_fingers[st.index] == "jump":
					_jump_highlight = false
					queue_redraw()
				_btn_fingers.erase(st.index)
			elif st.index == _joy_finger:
				_reset_joystick()
			elif st.index == _cam_finger:
				_cam_finger = -1

	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if _btn_fingers.has(sd.index):
			return
		if sd.index == _joy_finger:
			_update_joystick_value(sd.position)
			queue_redraw()
		elif sd.index == _cam_finger:
			camera_dragged.emit(sd.relative)

	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit_btn := _hit_test_button(mb.position)
				if hit_btn != "":
					_trigger_button(hit_btn)
					get_viewport().set_input_as_handled()
					return
				if mb.position.distance_to(_default_center) <= max_joystick_radius * 1.35:
					_mouse_joy_active = true
					_joy_center = _default_center
					_update_joystick_value(mb.position)
					queue_redraw()
					get_viewport().set_input_as_handled()
			else:
				if _jump_highlight:
					_jump_highlight = false
					queue_redraw()
				if _mouse_joy_active:
					_mouse_joy_active = false
					_reset_joystick()
	elif event is InputEventMouseMotion and _mouse_joy_active and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mm: InputEventMouseMotion = event
		_update_joystick_value(mm.position)
		queue_redraw()
		get_viewport().set_input_as_handled()

func _update_joystick_value(pos: Vector2) -> void:
	var offset := pos - _joy_center
	var dist := offset.length()
	if dist > max_joystick_radius:
		offset = offset.normalized() * max_joystick_radius
	_joy_knob = _joy_center + offset

	var norm := offset / maxf(max_joystick_radius, 1.0)
	if norm.length() < deadzone:
		_move_vec = Vector2.ZERO
	else:
		_move_vec = Vector2(norm.x, -norm.y)
	joystick_moved.emit(_move_vec)

func _reset_joystick() -> void:
	_joy_finger = -1
	_joy_center = _default_center
	_joy_knob = _default_center
	_move_vec = Vector2.ZERO
	joystick_moved.emit(_move_vec)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var s := _ui_scale
	var shadow := Color(0.0, 0.0, 0.0, 0.30)
	var base_col := Color(0.035, 0.055, 0.060, 0.62)
	var border_col := Color(0.82, 0.86, 0.80, 0.72)
	var knob_col := Color(0.82, 0.86, 0.80, 0.76) if (_joy_finger != -1 or _mouse_joy_active) else Color(0.62, 0.69, 0.65, 0.58)

	# Joystick: dark glass base, clear active thumb and subtle directional ticks.
	draw_circle(_joy_center + Vector2(0, 3*s), max_joystick_radius + 2*s, shadow)
	draw_circle(_joy_center, max_joystick_radius, base_col)
	draw_arc(_joy_center, max_joystick_radius, 0.0, TAU, 64, border_col, 2.0*s, true)
	for a in range(0, 360, 45):
		var rad := deg_to_rad(float(a))
		draw_line(_joy_center + Vector2(cos(rad), sin(rad)) * (max_joystick_radius - 9*s),
			_joy_center + Vector2(cos(rad), sin(rad)) * (max_joystick_radius - 3*s),
			Color(0.88, 0.90, 0.84, 0.42), 1.3*s)
	draw_circle(_joy_knob, knob_radius + 2*s, Color(0, 0, 0, 0.28))
	draw_circle(_joy_knob, knob_radius, knob_col)
	draw_arc(_joy_knob, knob_radius, 0.0, TAU, 48, Color(0.98, 0.98, 0.91, 0.86), 1.8*s, true)
	if font:
		var stick_tag := "KRETANJE"
		var fs := int(round(12*s))
		var ts := font.get_string_size(stick_tag, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, _joy_center + Vector2(-ts.x*0.5, max_joystick_radius + 18*s), stick_tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.94, 0.86, 0.88))

	for btn_id in ["view", "aim", "rifle", "sprint", "run", "fire", "reload", "crouch", "jump"]:
		if not _buttons.has(btn_id):
			continue
		var b: Dictionary = _buttons[btn_id]
		var center: Vector2 = b["pos"]
		var r: float = b["r"]
		var label: String = b["label"]
		var is_on := false
		var fill := Color(0.055, 0.075, 0.078, 0.72)
		var ring := Color(0.76, 0.82, 0.76, 0.72)
		if btn_id == "run": is_on = _run_active
		elif btn_id == "sprint": is_on = _sprint_active
		elif btn_id == "crouch": is_on = _crouch_active
		elif btn_id == "jump": is_on = _jump_highlight
		elif btn_id == "rifle": is_on = _rifle_equipped
		elif btn_id == "aim": is_on = _aim_active
		elif btn_id == "fire": is_on = _fire_flash_t > 0.0
		elif btn_id == "reload": is_on = _reloading_active
		elif btn_id == "view": is_on = true

		if is_on:
			if btn_id == "fire":
				fill = Color(0.48, 0.12, 0.08, 0.88); ring = Color(1.0, 0.52, 0.30, 1.0)
			elif btn_id == "aim" or btn_id == "sprint":
				fill = Color(0.40, 0.28, 0.10, 0.86); ring = Color(0.98, 0.78, 0.36, 1.0)
			elif btn_id == "view":
				fill = Color(0.10, 0.30, 0.36, 0.88); ring = Color(0.48, 0.82, 0.90, 1.0)
			else:
				fill = Color(0.16, 0.32, 0.22, 0.86); ring = Color(0.64, 0.88, 0.58, 1.0)
		elif btn_id == "fire":
			fill = Color(0.28, 0.085, 0.06, 0.78); ring = Color(0.90, 0.38, 0.24, 0.88)

		draw_circle(center + Vector2(0, 3*s), r + 2*s, shadow)
		draw_circle(center, r, fill)
		draw_arc(center, r, 0.0, TAU, 56, ring, 2.4*s if is_on else 1.7*s, true)
		draw_arc(center, r - 5*s, deg_to_rad(210), deg_to_rad(330), 24, Color(1,1,1,0.16), 1.0*s, true)
		if font:
			var fs := int(round((14 if btn_id in ["jump", "fire"] else 11)*s))
			var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			var text_pos := center + Vector2(-ts.x*0.5, ts.y*0.32)
			draw_string(font, text_pos + Vector2(1*s, 1*s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0,0,0,0.86))
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97,0.96,0.90,0.98))
			if btn_id in ["view", "aim", "run", "sprint", "crouch", "rifle"]:
				var sub := ("PRVO" if _first_person_active else "TREĆE") if btn_id == "view" else ("UKLJ." if is_on else "ISKLJ.")
				var sfs := int(round(8*s))
				var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs)
				draw_string(font, center + Vector2(-ss.x*0.5, r - 8*s), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, ring)
