extends CanvasLayer
## Reference-inspired WWII field HUD. Compact, readable and responsive.
const C_BG := Color(0.025, 0.035, 0.034, 0.78)
const C_PANEL := Color(0.055, 0.065, 0.057, 0.88)
const C_EDGE := Color(0.68, 0.55, 0.31, 0.88)
const C_GOLD := Color(0.91, 0.75, 0.42)
const C_TEXT := Color(0.93, 0.91, 0.83)
const C_MUTED := Color(0.67, 0.68, 0.62)
var root: Control
var _top: PanelContainer
var _mission: PanelContainer
var _bottom: PanelContainer
var _settings: PanelContainer
var _quality_label: Label
var _quality_buttons: Array[Button] = []

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	var qm := get_node_or_null("/root/QualityManager")
	if qm and qm.has_signal("quality_changed"):
		qm.quality_changed.connect(_on_quality_changed)
	_update_quality_text()
	get_viewport().size_changed.connect(_layout)

func _style(panel: PanelContainer, alpha: float = 0.82) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_BG.r,C_BG.g,C_BG.b,alpha)
	sb.border_color = C_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel",sb)

func _label(txt: String, size: int, col: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",col)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build() -> void:
	# Top status strip: historical field-instrument look, not a modern sci-fi HUD.
	_top = PanelContainer.new()
	_style(_top,0.72)
	root.add_child(_top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	_top.add_child(row)
	var emblem := _label("✚",25,C_GOLD)
	row.add_child(emblem)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation",0)
	row.add_child(info)
	info.add_child(_label("VLADO ŠIPČIĆ  •  CRNA GORA",15,C_GOLD))
	info.add_child(_label("DROBNJAK  /  RATNA ZONA",11,C_MUTED))
	var sep := VSeparator.new()
	row.add_child(sep)
	var state := VBoxContainer.new()
	state.add_theme_constant_override("separation",1)
	row.add_child(state)
	state.add_child(_label("STATUS",10,C_MUTED))
	state.add_child(_label("NA TERENU",14,C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var compass := _label("N  ▲",16,C_GOLD)
	row.add_child(compass)

	# Objective card sits below the mini-map on the left.
	_mission = PanelContainer.new()
	_style(_mission,0.80)
	root.add_child(_mission)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation",4)
	_mission.add_child(mv)
	mv.add_child(_label("DNEVNIK  /  ZADATAK",13,C_GOLD))
	mv.add_child(_label("DOLINA KRUPA",17,C_TEXT))
	mv.add_child(_label("Istraži okolinu i prati teren.",12,C_MUTED))
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0,1)
	rule.color = Color(C_EDGE.r,C_EDGE.g,C_EDGE.b,0.55)
	mv.add_child(rule)
	mv.add_child(_label("SEKTOR  •  PLANINSKI PRILAZ",10,C_MUTED))

	# Bottom equipment strip: compact slots, leaving the center gameplay view clear.
	_bottom = PanelContainer.new()
	_style(_bottom,0.72)
	root.add_child(_bottom)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation",8)
	_bottom.add_child(slots)
	for entry in ["✚  PRVA POMOĆ","▣  OPREMA","⌖  MAPA","⚙  PODEŠAVANJA"]:
		var b := Button.new()
		b.text = entry
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112,38)
		b.add_theme_font_size_override("font_size",11)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.10,0.12,0.10,0.68)
		normal.border_color = Color(C_EDGE.r,C_EDGE.g,C_EDGE.b,0.52)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(3)
		b.add_theme_stylebox_override("normal",normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.22,0.19,0.12,0.92)
		b.add_theme_stylebox_override("hover",hover)
		b.add_theme_stylebox_override("pressed",hover)
		if entry.find("MAPA") >= 0:
			b.pressed.connect(_open_map)
		elif entry.find("PODEŠAVANJA") >= 0:
			b.pressed.connect(_toggle_settings)
		else:
			b.disabled = true
			b.modulate = Color(0.78,0.78,0.72,0.78)
		slots.add_child(b)
	_build_settings()
	_layout()

func _build_settings() -> void:
	_settings = PanelContainer.new()
	_settings.name = "GraphicsSettings"
	_style(_settings, 0.96)
	_settings.visible = false
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_settings)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 10)
	_settings.add_child(box)
	box.add_child(_label("GRAFIČKA PODEŠAVANJA", 20, C_GOLD))
	box.add_child(_label("Izaberi kvalitet prema snazi telefona", 13, C_MUTED))
	_quality_label = _label("", 14, C_TEXT)
	_quality_label.custom_minimum_size = Vector2(390, 38)
	_quality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_quality_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for item in [["LOW",0],["MEDIUM",1],["HIGH",2]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(112, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_quality.bind(int(item[1])))
		row.add_child(b)
		_quality_buttons.append(b)
	var hint := _label("LOW: slabiji telefoni  •  MEDIUM: balans  •  HIGH: jači telefoni", 11, C_MUTED)
	hint.custom_minimum_size = Vector2(390, 30)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var close := Button.new()
	close.text = "ZATVORI"
	close.custom_minimum_size = Vector2(0, 42)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_toggle_settings)
	box.add_child(close)

func _toggle_settings() -> void:
	if _settings:
		_settings.visible = not _settings.visible
		_update_quality_text()

func _select_quality(selected: int) -> void:
	var qm := get_node_or_null("/root/QualityManager")
	if qm and qm.has_method("set_tier"):
		qm.call("set_tier", selected, true)
	_update_quality_text()

func _on_quality_changed(_tier: int, _name: String) -> void:
	_update_quality_text()

func _update_quality_text() -> void:
	if not _quality_label:
		return
	var qm := get_node_or_null("/root/QualityManager")
	if qm == null:
		_quality_label.text = "Kvalitet nije dostupan"
		return
	var active := int(qm.get("tier"))
	var summary := str(qm.call("get_profile_summary")) if qm.has_method("get_profile_summary") else ""
	_quality_label.text = "AKTIVNO: %s\n%s" % [str(qm.get("tier_name")), summary]
	for i in range(_quality_buttons.size()):
		_quality_buttons[i].disabled = (i == active)

func _open_map() -> void:
	for n in get_tree().get_nodes_in_group("world_map_ui"):
		if n.has_method("open_map"):
			n.call("open_map")
			return

func _layout() -> void:
	if not is_instance_valid(root):
		return
	var s := get_viewport().get_visible_rect().size
	var scale := clampf(minf(s.x/1536.0,s.y/864.0),0.72,1.15)
	_top.position = Vector2(s.x*0.30,14*scale)
	_top.size = Vector2(s.x*0.40,62*scale)
	_mission.position = Vector2(18*scale,218*scale)
	_mission.size = Vector2(270*scale,136*scale)
	_bottom.position = Vector2((s.x-500*scale)*0.5,s.y-58*scale)
	_bottom.size = Vector2(500*scale,48*scale)
	if _settings:
		var panel_size := Vector2(430, 255) * scale
		_settings.position = (s - panel_size) * 0.5
		_settings.size = panel_size
