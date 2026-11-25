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
	var scale_ui := clampf(minf(sz.x / 1920.0, sz.y / 1080.0), 0.68, 1.25)
	var joystick_r := max_joystick_radius * scale_ui
	var inset_x := maxf(62.0 * scale_ui, sz.x * 0.08)
	var inset_y := maxf(96.0 * scale_ui, sz.y * 0.10)
	_default_center = Vector2(inset_x + joystick_r, sz.y - inset_y)
	if _joy_finger == -1 and not _mouse_joy_active:
		_joy_center = _default_center
		_joy_knob = _default_center

	# Right-thumb ergonomic button arc; all geometry is scaled and clamped to the safe area.
	var rx := sz.x - maxf(48.0 * scale_ui, sz.x * 0.035)
	var ry_bottom := sz.y - maxf(54.0 * scale_ui, sz.y * 0.055)
	var r_small := 44.0 * scale_ui
	var r_main := 54.0 * scale_ui
	_buttons = {
		"jump": {"pos": Vector2(rx - r_main, ry_bottom - r_main), "r": r_main, "label": "JUMP"},
		"crouch": {"pos": Vector2(rx - 205.0 * scale_ui, ry_bottom - 58.0 * scale_ui), "r": r_small, "label": "CUČANJE"},
		"run": {"pos": Vector2(rx - 178.0 * scale_ui, ry_bottom - 178.0 * scale_ui), "r": r_small, "label": "TRČANJE"},
		"sprint": {"pos": Vector2(rx - 82.0 * scale_ui, ry_bottom - 236.0 * scale_ui), "r": r_small, "label": "SPRINT"},
		"rifle": {"pos": Vector2(rx - 82.0 * scale_ui, ry_bottom - 350.0 * scale_ui), "r": r_small, "label": "ORUŽJE"},
		"aim": {"pos": Vector2(rx - 205.0 * scale_ui, ry_bottom - 310.0 * scale_ui), "r": r_small, "label": "CILJANJE"},
		"view": {"pos": Vector2(rx - 320.0 * scale_ui, ry_bottom - 330.0 * scale_ui), "r": r_small * 0.96, "label": "PREGLED"},
		"fire": {"pos": Vector2(rx - 320.0 * scale_ui, ry_bottom - 205.0 * scale_ui), "r": r_main, "label": "PALJBA"},
		"reload": {"pos": Vector2(rx - 318.0 * scale_ui, ry_bottom - 92.0 * scale_ui), "r": r_small * 0.92, "label": "PUNJENJE"},
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
	var base_col := Color(0.92, 0.92, 0.90, 0.22)
	var border_col := Color(0.95, 0.95, 0.92, 0.58)
	var knob_col := Color(0.96, 0.94, 0.88, 0.72) if (_joy_finger != -1 or _mouse_joy_active) else Color(0.92, 0.92, 0.90, 0.42)

	draw_circle(_joy_center, max_joystick_radius, base_col)
	draw_arc(_joy_center, max_joystick_radius, 0.0, TAU, 48, border_col, 2.5, true)
	draw_circle(_joy_knob, knob_radius, knob_col)
	draw_arc(_joy_knob, knob_radius, 0.0, TAU, 36, border_col, 2.0, true)

	if font:
		var stick_tag := "MOVE"
		var s_size := font.get_string_size(stick_tag, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, _joy_center + Vector2(-s_size.x * 0.5, max_joystick_radius + 20.0), stick_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.96, 0.95, 0.90, 0.82))

	for btn_id in ["crouch", "run", "sprint", "jump", "rifle", "aim", "view", "fire", "reload"]:
		if not _buttons.has(btn_id):
			continue
		var b: Dictionary = _buttons[btn_id]
		var center: Vector2 = b["pos"]
		var r: float = b["r"]
		var label: String = b["label"]
		var is_on := false
		var active_fill := Color(0.24, 0.34, 0.22, 0.65)
		var active_ring := Color(0.78, 0.88, 0.56, 0.95)
		var has_sub: bool = btn_id in ["crouch", "run", "sprint", "rifle", "aim", "view"]

		if btn_id == "run" and _run_active:
			is_on = true
			active_fill = Color(0.32, 0.46, 0.24, 0.72)
			active_ring = Color(0.76, 0.92, 0.48, 0.98)
		elif btn_id == "sprint" and _sprint_active:
			is_on = true
			active_fill = Color(0.56, 0.38, 0.16, 0.76)
			active_ring = Color(0.98, 0.78, 0.38, 0.98)
		elif btn_id == "crouch" and _crouch_active:
			is_on = true
			active_fill = Color(0.42, 0.44, 0.22, 0.74)
			active_ring = Color(0.92, 0.88, 0.48, 0.98)
		elif btn_id == "jump" and _jump_highlight:
			is_on = true
			active_fill = Color(0.45, 0.45, 0.40, 0.75)
			active_ring = Color(0.98, 0.96, 0.86, 0.98)
		elif btn_id == "rifle" and _rifle_equipped:
			is_on = true
			active_fill = Color(0.26, 0.42, 0.32, 0.76)
			active_ring = Color(0.72, 0.95, 0.62, 0.98)
		elif btn_id == "aim" and _aim_active:
			is_on = true
			active_fill = Color(0.58, 0.40, 0.16, 0.78)
			active_ring = Color(0.98, 0.82, 0.38, 0.98)
		elif btn_id == "fire":
			if _fire_flash_t > 0.0:
				is_on = true
				active_fill = Color(0.85, 0.28, 0.16, 0.88)
				active_ring = Color(1.0, 0.85, 0.42, 1.0)
			elif _rifle_equipped:
				is_on = true
				active_fill = Color(0.58, 0.20, 0.16, 0.70)
				active_ring = Color(0.96, 0.56, 0.38, 0.96)
		elif btn_id == "reload" and _reloading_active:
			is_on = true
			active_fill = Color(0.50, 0.42, 0.20, 0.76)
			active_ring = Color(0.98, 0.86, 0.48, 0.98)
		elif btn_id == "view":
			is_on = true
			if _first_person_active:
				active_fill = Color(0.20, 0.42, 0.56, 0.80)
				active_ring = Color(0.56, 0.88, 1.0, 0.98)
			else:
				active_fill = Color(0.22, 0.28, 0.30, 0.56)
				active_ring = Color(0.84, 0.90, 0.88, 0.80)

		var idle_alpha := 0.28 if (btn_id in ["fire", "reload"] and not _rifle_equipped) else 0.48
		var fill := active_fill if is_on else Color(0.14, 0.15, 0.14, idle_alpha)
		var ring := active_ring if is_on else Color(0.92, 0.92, 0.88, 0.38 if (btn_id in ["fire", "reload"] and not _rifle_equipped) else 0.62)
		var ring_w := 3.5 if is_on else 2.2

		draw_circle(center, r, fill)
		draw_arc(center, r, 0.0, TAU, 48, ring, ring_w, true)

		if font:
			var fsize := 17 if btn_id in ["jump", "fire"] else 15
			var tsz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			var text_pos := center + Vector2(-tsz.x * 0.5, tsz.y * 0.28)
			draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.75))
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.98, 0.97, 0.92, 0.96))
			if has_sub:
				var sub := ("FPS" if _first_person_active else "TPS") if btn_id == "view" else ("ON" if is_on else "OFF")
				var ssz := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
				draw_string(font, center + Vector2(-ssz.x * 0.5, r - 12.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ring)
