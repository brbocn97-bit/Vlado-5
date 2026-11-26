class_name Stage4HUD
extends CanvasLayer
## Stage4HUD — additive UI for the Stage 4 layer. The Stage 3.2 DebugHUD keeps
## ownership of health, stamina, ammo, crosshair and the view-mode badge; this
## layer adds only what Stage 4 introduces:
##   · region banner + streaming state (ACTIVE / MID / FAR)
##   · interaction prompt
##   · dialogue / clue reader panel
##   · clue counter (0..6)
##   · teleport debug keys F5..F10

const COL_BG := Color(0.06, 0.07, 0.06, 0.74)
const COL_EDGE := Color(0.62, 0.55, 0.36, 0.85)
const COL_TEXT := Color(0.93, 0.90, 0.82)
const COL_ACCENT := Color(0.88, 0.72, 0.36)

var root: Control
var lbl_region: Label
var lbl_prompt: Label
var lbl_counter: Label
var lbl_mission: Label
var lbl_mission_flash := 0.0
var lbl_stream: Label
var panel_note: PanelContainer
var lbl_note_title: Label
var lbl_note_body: RichTextLabel
var _note_timer := 0.0
var _world: Stage4World
@export var show_development_ui := false


func _ready() -> void:
	add_to_group("stage4_hud")
	layer = 11
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_region_banner()
	_build_prompt()
	_build_note_panel()
	_build_counter()
	if show_development_ui and OS.has_feature("editor"):
		_build_stream_panel()
	call_deferred("_bind_missions")

	if show_development_ui and OS.has_feature("editor"):
		_add_rotate_button()

func bind_world(w: Stage4World) -> void:
	_world = w
	if w:
		var streamer := get_tree().root.get_node_or_null("WorldStreamer")
		if streamer and streamer.has_signal("active_region_changed"):
			streamer.active_region_changed.connect(_on_region_changed)


# ------------------------------------------------------------------- build
func _mk_panel(bg: Color = COL_BG) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func _mk_label(text: String, size: int, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_region_banner() -> void:
	lbl_region = _mk_label("Dolina Krupe", 22, COL_ACCENT)
	lbl_region.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_region.position = Vector2(-220, 210)
	lbl_region.custom_minimum_size = Vector2(440, 0)
	lbl_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_region.modulate.a = 0.0
	root.add_child(lbl_region)


func _build_prompt() -> void:
	lbl_prompt = _mk_label("", 17, COL_ACCENT)
	lbl_prompt.set_anchors_preset(Control.PRESET_CENTER)
	lbl_prompt.position = Vector2(-200, 52)
	lbl_prompt.custom_minimum_size = Vector2(400, 0)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.visible = false
	root.add_child(lbl_prompt)


func _build_note_panel() -> void:
	panel_note = _mk_panel(Color(0.83, 0.79, 0.69, 0.95))
	panel_note.set_anchors_preset(Control.PRESET_CENTER)
	panel_note.position = Vector2(-280, -170)
	panel_note.custom_minimum_size = Vector2(560, 0)
	panel_note.visible = false
	root.add_child(panel_note)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_note.add_child(v)
	lbl_note_title = _mk_label("", 19, Color(0.20, 0.15, 0.07))
	v.add_child(lbl_note_title)
	lbl_note_body = RichTextLabel.new()
	lbl_note_body.bbcode_enabled = true
	lbl_note_body.fit_content = true
	lbl_note_body.custom_minimum_size = Vector2(520, 0)
	lbl_note_body.add_theme_font_size_override("normal_font_size", 15)
	lbl_note_body.add_theme_color_override("default_color", Color(0.17, 0.13, 0.07))
	lbl_note_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl_note_body)
	var hint := _mk_label("[G] zatvori", 12, Color(0.36, 0.29, 0.16))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)


func _build_counter() -> void:
	lbl_mission = _mk_label("", 14, Color(0.95, 0.90, 0.72))
	lbl_mission.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_mission.position = Vector2(-320, 274)
	lbl_mission.custom_minimum_size = Vector2(640, 0)
	lbl_mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_mission)

	lbl_counter = _mk_label("Zabilješke 0/6", 13, COL_TEXT)
	lbl_counter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_counter.position = Vector2(-60, 244)
	root.add_child(lbl_counter)


func _build_stream_panel() -> void:
	var p := _mk_panel(Color(0.04, 0.05, 0.04, 0.62))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.position = Vector2(20, -320)
	p.custom_minimum_size = Vector2(268, 0)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(_mk_label("STAGE 4 · STREAMING", 11, COL_ACCENT))
	lbl_stream = _mk_label("", 11, Color(0.82, 0.86, 0.78))
	v.add_child(lbl_stream)


# ------------------------------------------------------------------ public
func set_stage4_prompt(text: String) -> void:
	if text == "":
		lbl_prompt.visible = false
		return
	lbl_prompt.text = "[G]  " + text
	lbl_prompt.visible = true


func show_stage4_note(title: String, body: String) -> void:
	lbl_note_title.text = title
	lbl_note_body.text = body
	panel_note.visible = true
	_note_timer = 12.0


func show_toast(text: String) -> void:
	var t := _mk_label(text, 17, COL_ACCENT)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-200, -90)
	t.custom_minimum_size = Vector2(400, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "position:y", -120, 0.7)
	tw.tween_interval(1.4)
	tw.tween_property(t, "modulate:a", 0.0, 0.5)
	tw.tween_callback(t.queue_free)


func _on_region_changed(region: Node) -> void:
	if region == null:
		return
	var data := RegionData.get_region(region.region_id)
	lbl_region.text = str(data.get("name", region.region_id))
	lbl_region.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(lbl_region, "modulate:a", 0.35, 0.8)


# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	if _note_timer > 0.0:
		_note_timer -= delta
		if _note_timer <= 0.0:
			panel_note.visible = false
	var ledger := get_tree().root.get_node_or_null("Stage4Ledger")
	if ledger:
		lbl_counter.text = "Zabilješke %d/%d" % [ledger.clues.size(), ledger.TOTAL]
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms and lbl_mission:
		if ms.current_mission >= ms.missions.size():
			lbl_mission.text = "★ SVE MISIJE ZAVRŠENE"
			lbl_mission.add_theme_color_override("font_color", Color(0.80, 0.95, 0.62))
		else:
			lbl_mission.text = "▸ " + ms.status_line()
	if lbl_mission_flash > 0.0:
		lbl_mission_flash -= delta
		lbl_mission.modulate.a = 1.0 if lbl_mission_flash > 0.0 else 0.85
	var streamer := get_tree().root.get_node_or_null("WorldStreamer")
	if streamer and lbl_stream:
		var lines := PackedStringArray()
		for l in streamer.status_lines():
			lines.append(str(l))
		lbl_stream.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G and panel_note.visible:
			panel_note.visible = false
			_note_timer = 0.0
			get_viewport().set_input_as_handled()
		if show_development_ui and OS.has_feature("editor") and _world and event.keycode >= KEY_F5 and event.keycode <= KEY_F10:
			var idx: int = event.keycode - KEY_F5
			var order := RegionData.REGION_IDS
			if idx < order.size():
				_world.teleport_to_region(order[idx])


# --- mobilno: dugme za kalibraciju FPS orijentacije oružja -----------------
var _btn_rot: Button = null
var _rot_step := 0
var _rot_angles := [Vector3.ZERO, Vector3(0,90,0), Vector3(90,0,0),
			Vector3(0,0,90), Vector3(180,0,0), Vector3(0,180,0)]


func _add_rotate_button() -> void:
	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		return
	_btn_rot = Button.new()
	_btn_rot.text = "ROT"
	_btn_rot.custom_minimum_size = Vector2(64, 48)
	_btn_rot.add_theme_font_size_override("font_size", 16)
	_btn_rot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_rot.anchor_left = 1.0
	_btn_rot.anchor_top = 0.0
	_btn_rot.anchor_right = 1.0
	_btn_rot.anchor_bottom = 0.0
	_btn_rot.offset_left = -114
	_btn_rot.offset_top = 128
	_btn_rot.offset_right = -18
	_btn_rot.offset_bottom = 176
	_btn_rot.pressed.connect(_on_rotate_pressed)
	root.add_child(_btn_rot)


func _on_rotate_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		show_toast("Nema player-a")
		return
	var fps = player.get_node_or_null("FirstPersonRig")
	if fps == null or not fps.has_method("fp_set_rot"):
		show_toast("Nema FPS rig-a")
		return
	_rot_step = (_rot_step + 1) % _rot_angles.size()
	fps.call("fp_set_rot", _rot_angles[_rot_step])
	show_toast("Rotacija %d/6  %s" % [_rot_step + 1, str(_rot_angles[_rot_step])])

func _bind_missions() -> void:
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms == null:
		return
	ms.bind_hud(self)
	ms.objective_completed.connect(_on_objective_done)
	ms.mission_completed.connect(_on_mission_done)


func _on_objective_done(_mid: String, oid: String) -> void:
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms == null:
		return
	show_toast("✔ Cilj ispunjen")
	lbl_mission_flash = 2.0


func _on_mission_done(mid: String) -> void:
	show_stage4_note("MISIJA ZAVRŠENA", "Sve stavke ove misije su ispunjene.\nNastavi prema sljedećoj regiji.")
