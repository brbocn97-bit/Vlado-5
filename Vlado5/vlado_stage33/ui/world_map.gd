extends Control
## Tactical topographic map. Tap the inset to expand; tap outside or CLOSE to return.
const WORLD_HALF := 700.0
const REGION_DATA := [
	{"name":"KRUPA", "p":Vector2(0.0,0.0), "c":Color(0.72,0.66,0.43)},
	{"name":"CRNČA", "p":Vector2(-340.0,10.0), "c":Color(0.72,0.48,0.30)},
	{"name":"STRAŽARNICA", "p":Vector2(340.0,-90.0), "c":Color(0.70,0.34,0.27)},
	{"name":"DURMITOR", "p":Vector2(-250.0,-350.0), "c":Color(0.45,0.62,0.48)},
	{"name":"KANJON", "p":Vector2(100.0,340.0), "c":Color(0.36,0.61,0.68)},
	{"name":"LOVĆEN", "p":Vector2(360.0,290.0), "c":Color(0.72,0.72,0.62)}
]
const ROUTES := [[0,1],[0,2],[1,3],[0,4],[4,5]]
var _expanded := false
var _player: Node3D
var _terrain_data: MontenegroTerrainData
var _height_cells: Array = []
var _map_rect := Rect2(18, 18, 184, 184)
var _last_player_pos := Vector3.ZERO

func _ready() -> void:
	add_to_group("world_map_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	_player = get_tree().current_scene.get_node_or_null("VladoPlayer")
	_terrain_data = MontenegroTerrainData.new()
	_build_height_cache()
	set_process(true)
	set_process_input(true)
	queue_redraw()

func _build_height_cache() -> void:
	# 28x28 low-cost static elevation preview, cached once at startup.
	var n := 28
	for z in range(n):
		var row := []
		for x in range(n):
			var wx := -WORLD_HALF + (float(x)+0.5) * (WORLD_HALF*2.0/n)
			var wz := -WORLD_HALF + (float(z)+0.5) * (WORLD_HALF*2.0/n)
			row.append(_terrain_data.get_height(wx,wz))
		_height_cells.append(row)

func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_last_player_pos = _player.global_position
	queue_redraw()

func open_map() -> void:
	_expanded = true
	queue_redraw()

func close_map() -> void:
	_expanded = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position; pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position; pressed = true
	if not pressed:
		return
	var vp := get_viewport_rect().size
	var rect := _get_map_rect(vp)
	if _expanded:
		var close_rect := Rect2(vp.x-142, 22, 120, 48)
		if close_rect.has_point(pos) or not rect.has_point(pos):
			_expanded = false
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif rect.has_point(pos):
		_expanded = true
		queue_redraw()
		get_viewport().set_input_as_handled()

func _get_map_rect(vp: Vector2) -> Rect2:
	if _expanded:
		var side := minf(vp.x-36.0, vp.y-100.0)
		side = minf(side, 820.0)
		return Rect2((vp.x-side)*0.5, (vp.y-side)*0.5, side, side)
	return Rect2(18, 18, 184, 184)

func _map_point(world_xz: Vector2, rect: Rect2) -> Vector2:
	return Vector2(rect.position.x + (world_xz.x + WORLD_HALF)/(WORLD_HALF*2.0)*rect.size.x,
		rect.position.y + (world_xz.y + WORLD_HALF)/(WORLD_HALF*2.0)*rect.size.y)

func _draw() -> void:
	var vp := get_viewport_rect().size
	var rect := _get_map_rect(vp)
	if _expanded:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.015,0.025,0.025,0.82))
	_draw_map(rect, _expanded)
	if _expanded:
		var close := Rect2(vp.x-142,22,120,48)
		draw_rect(close, Color(0.16,0.22,0.20,0.96), true)
		draw_rect(close, Color(0.78,0.84,0.72,0.95), false, 2.0)
		_draw_text("ZATVORI", close.position+Vector2(22,30), 17, Color(0.96,0.95,0.86))
	else:
		_draw_text("MAPA  •  DODIRNI", rect.position+Vector2(8,17), 10, Color(0.98,0.96,0.84))

func _draw_map(rect: Rect2, large: bool) -> void:
	draw_rect(rect.grow(5), Color(0,0,0,0.55), true)
	draw_rect(rect, Color(0.10,0.15,0.13,0.98), true)
	var n := _height_cells.size()
	var cell := rect.size.x/float(n)
	for z in range(n):
		for x in range(n):
			var h: float = _height_cells[z][x]
			var col := Color(0.25,0.34,0.24)
			if h < 8: col = Color(0.38,0.43,0.30)
			elif h < 28: col = Color(0.43,0.43,0.30)
			elif h < 50: col = Color(0.40,0.39,0.30)
			elif h < 80: col = Color(0.43,0.42,0.37)
			else: col = Color(0.53,0.52,0.47)
			var p := rect.position + Vector2(x*cell,z*cell)
			draw_rect(Rect2(p,Vector2(cell+0.8,cell+0.8)),col,true)
	# contour/grid lines and route network
	for k in range(1,7):
		var q := float(k)/7.0
		draw_line(rect.position+Vector2(rect.size.x*q,0),rect.position+Vector2(rect.size.x*q,rect.size.y),Color(0.9,0.9,0.8,0.08),1.0)
		draw_line(rect.position+Vector2(0,rect.size.y*q),rect.position+Vector2(rect.size.x,rect.size.y*q),Color(0.9,0.9,0.8,0.08),1.0)
	for route in ROUTES:
		var a: Vector2 = REGION_DATA[route[0]]["p"]
		var b: Vector2 = REGION_DATA[route[1]]["p"]
		draw_line(_map_point(a,rect),_map_point(b,rect),Color(0.72,0.62,0.40,0.78),maxf(1.5,rect.size.x/250.0),true)
	for region in REGION_DATA:
		var pt := _map_point(region["p"],rect)
		draw_circle(pt, maxf(3.0,rect.size.x/58.0), Color(0.06,0.08,0.07,0.95))
		draw_circle(pt, maxf(2.0,rect.size.x/75.0), region["c"])
		if large:
			_draw_text(region["name"],pt+Vector2(7,-5),12,Color(0.98,0.96,0.84))
	var player_pt := _map_point(Vector2(_last_player_pos.x,_last_player_pos.z),rect)
	draw_circle(player_pt,maxf(5.0,rect.size.x/36.0),Color(0.95,0.83,0.36,0.35))
	draw_circle(player_pt,maxf(2.8,rect.size.x/55.0),Color(1.0,0.88,0.30))
	if large:
		_draw_text("SJEVER  ↑",rect.position+Vector2(12,rect.size.y-12),12,Color(0.98,0.96,0.84))
		_draw_text("KRUPA VALLEY  •  1.4 × 1.4 km",rect.position+Vector2(12,30),14,Color(0.98,0.96,0.84))
	draw_rect(rect,Color(0.80,0.84,0.73,0.95),false,2.0)

func _draw_text(value: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
