class_name ArsenalHUD
extends CanvasLayer
## ArsenalHUD — Stage 3.3 weapon readout.
##
## The Stage 3.2 DebugHUD already prints ammo for the M48 in its top-left block;
## this layer adds the parts the debug HUD has no concept of: which weapon is in
## hand, what the other owned weapons hold, and the pickup prompt.

const COL_BG := Color(0.025, 0.035, 0.034, 0.82)
const COL_EDGE := Color(0.68, 0.55, 0.31, 0.92)
const COL_TEXT := Color(0.94, 0.91, 0.84)
const COL_DIM := Color(0.62, 0.60, 0.54)
const COL_ACCENT := Color(0.92, 0.74, 0.34)

var root: Control
var lbl_weapon: Label
var lbl_ammo: Label
var lbl_slots: Label
var lbl_prompt: Label
var lbl_toast: Label
var arsenal: WeaponArsenal
var _toast_timer := 0.0
var _last_ammo_txt := ""
var _last_weapon_txt := ""


func _ready() -> void:
	layer = 12
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()


func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func _label(text: String, size: int, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	# weapon block, top-right to the left of BagButton so bottom mobile controls stay 100% clear
	var p := _panel()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.anchor_left = 1.0
	p.anchor_top = 0.0
	p.anchor_right = 1.0
	p.anchor_bottom = 0.0
	p.offset_left = -360
	p.offset_top = 18
	p.offset_right = -18
	p.custom_minimum_size = Vector2(342, 0)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	lbl_weapon = _label("M48", 20, COL_ACCENT)
	v.add_child(lbl_weapon)
	lbl_ammo = _label("5 / 30", 26, COL_TEXT)
	v.add_child(lbl_ammo)
	lbl_slots = _label("", 12, COL_DIM)
	v.add_child(lbl_slots)

	lbl_prompt = _label("", 17, COL_ACCENT)
	lbl_prompt.set_anchors_preset(Control.PRESET_CENTER)
	lbl_prompt.position = Vector2(-230, 96)
	lbl_prompt.custom_minimum_size = Vector2(460, 0)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.visible = false
	root.add_child(lbl_prompt)

	lbl_toast = _label("", 18, COL_ACCENT)
	lbl_toast.set_anchors_preset(Control.PRESET_CENTER)
	lbl_toast.position = Vector2(-230, -60)
	lbl_toast.custom_minimum_size = Vector2(460, 0)
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.modulate.a = 0.0
	root.add_child(lbl_toast)


func bind(a: WeaponArsenal) -> void:
	arsenal = a
	if a:
		a.weapon_changed.connect(_on_weapon_changed)
		_refresh()


func set_prompt(text: String) -> void:
	lbl_prompt.visible = text != ""
	lbl_prompt.text = text


func toast(text: String) -> void:
	lbl_toast.text = text
	lbl_toast.modulate.a = 1.0
	_toast_timer = 2.6


func _on_weapon_changed(d: WeaponDef) -> void:
	toast("Preuzeto: " + d.display_name if d else "")
	_refresh()


func _refresh() -> void:
	if arsenal == null:
		return
	var d := arsenal.active_def()
	if d == null:
		return
	lbl_weapon.text = d.display_name
	var a := arsenal.ammo_for(d.slot)
	lbl_ammo.text = "%d / %d" % [a[0], a[1]]
	var parts := PackedStringArray()
	for w in arsenal.weapons:
		if arsenal.owns(w.slot):
			var mark := "▸" if w.slot == arsenal.active else " "
			parts.append("%s %s" % [mark, w.display_name])
	lbl_slots.text = "   ".join(parts)


func _process(delta: float) -> void:
	if arsenal and arsenal.active_def():
		var d := arsenal.active_def()
		var a := arsenal.ammo_for(d.slot)
		var ammo_txt := "%d / %d" % [a[0], a[1]]
		if ammo_txt != _last_ammo_txt:
			_last_ammo_txt = ammo_txt
			lbl_ammo.text = ammo_txt
		var weapon_txt := "PUNJENJE…" if arsenal.is_reloading() else d.display_name
		if weapon_txt != _last_weapon_txt:
			_last_weapon_txt = weapon_txt
			lbl_weapon.text = weapon_txt
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(lbl_toast, "modulate:a", 0.0, 0.5)
