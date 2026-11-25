class_name InventoryBag
extends CanvasLayer
## TORBA — inventar u donjem desnom uglu.
##
## Na telefonu nema tastature, pa se oruzja ne mogu birati brojevima.
## Ovo je dugme koje otvara listu svega sto igrac nosi.
## Svaki red se dodirne -> oruzje se prebaci u ruke.

const PANEL_W := 460
const PANEL_H := 460

var _arsenal: Node = null
var _bag_btn: Button = null
var _panel: Panel = null
var _list: VBoxContainer = null
var _open: bool = false


func _ready() -> void:
	layer = 21
	# sacekaj da se Stage33Bootstrap i arsenal izgrade (2 frejma)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_find_arsenal()
	_build_bag_button()
	_build_panel()


func _find_arsenal() -> void:
	# Arsenal je dijete Stage33Bootstrap cvorova; trazi po klasi
	for n in get_tree().get_nodes_in_group("stage33_arsenal"):
		_arsenal = n
		return
	for n in get_tree().get_nodes_in_group("arsenal"):
		_arsenal = n
		return
	# fallback: nadji po imenu skripte
	var root := get_tree().current_scene
	if root == null:
		return
	for n in root.find_children("*", "", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("weapon_arsenal.gd"):
			_arsenal = n
			return


## POPRAVKA v17 — GRUPA D: crta ikonu torbe (kožna vreća sa drškom
## i preklopcem) u Image, bez vanjskih fajlova.
func _make_bag_icon(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.62, 0.44, 0.22)
	var dark := Color(0.38, 0.26, 0.12)
	var strap := Color(0.30, 0.20, 0.09)
	var w := float(size)
	var x0 := int(w * 0.16)
	var x1 := int(w * 0.84)
	var y0 := int(w * 0.40)
	var y1 := int(w * 0.88)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var r := w * 0.12
			var cx := clampf(float(x), float(x0) + r, float(x1) - r)
			var cy := clampf(float(y), float(y0) + r, float(y1) - r)
			if Vector2(float(x) - cx, float(y) - cy).length() <= r + 0.5:
				img.set_pixel(x, y, body)
	var fy0 := int(w * 0.40)
	var fy1 := int(w * 0.52)
	for y in range(fy0, fy1):
		for x in range(x0, x1):
			var r2 := w * 0.12
			var cx2 := clampf(float(x), float(x0) + r2, float(x1) - r2)
			var cy2 := clampf(float(y), float(fy0) + r2, float(fy1) - r2)
			if Vector2(float(x) - cx2, float(y) - cy2).length() <= r2 + 0.5:
				img.set_pixel(x, y, dark)
	var cxb := w * 0.5
	var cyb := w * 0.40
	var rad := w * 0.20
	var thick := maxf(2.0, w * 0.045)
	for y in range(int(cyb - rad - thick) - 1, int(cyb)):
		for x in range(int(cxb - rad - thick) - 1, int(cxb + rad + thick) + 1):
			var d := Vector2(float(x) - cxb, float(y) - cyb).length()
			if absf(d - rad) <= thick:
				img.set_pixel(x, y, strap)
	var cs := int(w * 0.07)
	for y in range(int(w * 0.55), int(w * 0.55) + cs):
		for x in range(int(cxb) - cs / 2, int(cxb) + cs / 2):
			if x >= 0 and y >= 0 and x < size and y < size:
				img.set_pixel(x, y, Color(0.85, 0.72, 0.32))
	return ImageTexture.create_from_image(img)


## --- dugme TORBA u gornjem desnom uglu (slobodno od mobilnih dugmadi) ---
func _build_bag_button() -> void:
	_bag_btn = Button.new()
	_bag_btn.name = "BagButton"
	_bag_btn.text = ""
	_bag_btn.icon = _make_bag_icon(72)
	_bag_btn.expand_icon = false
	_bag_btn.tooltip_text = "TORBA"
	_bag_btn.focus_mode = Control.FOCUS_NONE
	_bag_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bag_btn.anchor_left = 1.0
	_bag_btn.anchor_top = 0.0
	_bag_btn.anchor_right = 1.0
	_bag_btn.anchor_bottom = 0.0
	_bag_btn.offset_left = -114
	_bag_btn.offset_top = 18
	_bag_btn.offset_right = -18
	_bag_btn.offset_bottom = 114
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.14, 0.11, 0.90)
	sb.border_color = Color(0.72, 0.58, 0.32, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	_bag_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.30, 0.25, 0.16, 1.0)
	_bag_btn.add_theme_stylebox_override("hover", sbh)
	_bag_btn.add_theme_stylebox_override("pressed", sbh)
	_bag_btn.pressed.connect(_toggle_panel)
	add_child(_bag_btn)


## --- panel sa listom oruzja ---
func _build_panel() -> void:
	_panel = Panel.new()
	_panel.name = "BagPanel"
	_panel.visible = false
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var panel_w := clampf(sz.x * 0.36, 360.0, 520.0)
	var panel_h := clampf(sz.y * 0.58, 380.0, 620.0)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -panel_w - 18
	_panel.offset_top = 124
	_panel.offset_right = -18
	_panel.offset_bottom = 124 + panel_h
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.10, 0.09, 0.96)
	psb.border_color = Color(0.72, 0.58, 0.32, 1.0)
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 12
	vb.offset_right = -16
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	var title := Label.new()
	title.text = "TORBA — ARSENAL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	hdr.add_child(title)

	var close_x := Button.new()
	close_x.text = "✕"
	close_x.custom_minimum_size = Vector2(44, 40)
	close_x.add_theme_font_size_override("font_size", 18)
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(_toggle_panel)
	hdr.add_child(close_x)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vb.add_child(footer)

	var unlock_btn := Button.new()
	unlock_btn.text = "OTKLJUČAJ SVIH 31 (TEST)"
	unlock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_btn.custom_minimum_size = Vector2(0, 46)
	unlock_btn.add_theme_font_size_override("font_size", 15)
	unlock_btn.focus_mode = Control.FOCUS_NONE
	unlock_btn.pressed.connect(_on_unlock_all)
	footer.add_child(unlock_btn)

	var close_btn := Button.new()
	close_btn.text = "ZATVORI"
	close_btn.custom_minimum_size = Vector2(115, 46)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_toggle_panel)
	footer.add_child(close_btn)


func _on_unlock_all() -> void:
	if _arsenal == null:
		_find_arsenal()
	if _arsenal and _arsenal.has_method("unlock_full_arsenal"):
		_arsenal.call("unlock_full_arsenal")
	_refresh()


func _toggle_panel() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		_refresh()


func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()

	if _arsenal == null:
		_find_arsenal()

	if _arsenal == null:
		var l := Label.new()
		l.text = "  (oružje nije nađeno)"
		l.add_theme_font_size_override("font_size", 18)
		_list.add_child(l)
		return

	var slots = _arsenal.get("weapons")
	var active_slot: int = int(_arsenal.get("active"))
	if slots == null:
		var l := Label.new()
		l.text = "  (torba je prazna)"
		l.add_theme_font_size_override("font_size", 18)
		_list.add_child(l)
		return

	var owned_items: Array = []
	var locked_items: Array = []
	for w in slots:
		if w == null:
			continue
		var s_id: int = int(w.slot)
		if bool(_arsenal.call("owns", s_id)):
			owned_items.append(w)
		else:
			locked_items.append(w)

	for group in [owned_items, locked_items]:
		for w in group:
			var s_id: int = int(w.slot)
			var is_active: bool = (s_id == active_slot)
			var is_owned: bool = bool(_arsenal.call("owns", s_id))
			var row := Button.new()
			var nm: String = str(w.display_name)
			var cat: String = str(w.get("category"))
			var ammo: Array = _arsenal.call("ammo_for", s_id)
			var mag: int = int(ammo[0]) if ammo.size() > 0 else 0
			var res: int = int(ammo[1]) if ammo.size() > 1 else 0
			if is_owned:
				row.text = ("▶ " if is_active else "   ") + nm + "  [%s]   %d/%d" % [cat, mag, res]
			else:
				row.text = "   " + nm + "  [%s] — zaključano" % cat
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.custom_minimum_size = Vector2(0, 48)
			row.add_theme_font_size_override("font_size", 16)
			row.focus_mode = Control.FOCUS_NONE
			if is_active:
				row.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
			elif not is_owned:
				row.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
			var rsb := StyleBoxFlat.new()
			rsb.bg_color = Color(0.22, 0.20, 0.16, 0.9) if not is_active else Color(0.32, 0.26, 0.12, 0.95)
			if not is_owned:
				rsb.bg_color = Color(0.14, 0.13, 0.12, 0.8)
			rsb.set_corner_radius_all(8)
			row.add_theme_stylebox_override("normal", rsb)
			row.add_theme_stylebox_override("hover", rsb)
			row.add_theme_stylebox_override("pressed", rsb)
			if is_owned:
				row.pressed.connect(func() -> void: _select_slot(s_id))
			else:
				row.disabled = true
			_list.add_child(row)


func _select_slot(slot_id: int) -> void:
	if _arsenal == null:
		return
	if _arsenal.has_method("switch_to"):
		_arsenal.call("switch_to", slot_id)
	_refresh()
