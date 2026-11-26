extends Node
## MissionSystem — autoload. Six-region campaign for Stage 4.
##
## Structure: 3 missions, each a chain of objectives that span the six regions.
## Objectives are driven by signals the rest of the game already emits:
##   · clue found          -> Stage4Ledger.add_clue
##   · soldier killed      -> Stage4Ledger.report_kill / GermanSoldier.died
##   · weapon recovered    -> WeaponArsenal.give_weapon
##   · region entered      -> WorldStreamer.active_region_changed
## so no other system has to know missions exist.

signal objective_completed(mission_id: String, objective_id: String)
signal objective_started(mission_id: String, objective_id: String)
signal mission_completed(mission_id: String)
signal mission_started(mission_id: String)
signal all_missions_completed()

const MISSIONS := [
	{
		"id": "m1_krupa",
		"title": "Dolina Krupe",
		"brief": "Nađi tragove o očevoj jedinici i saznaj šta čuvaju na punktu.",
		"objectives": [
			{"id": "clue_homestead", "text": "Pretraži kuću Šipčića", "type": "clue", "target": "clue_homestead_letter"},
			{"id": "clue_kafana", "text": "Pročitaj kafansku knjigu", "type": "clue", "target": "clue_kafana_ledger"},
			{"id": "talk_marko", "text": "Razgovaraj sa Markovom", "type": "talk", "target": "Marko"},
		],
	},
	{
		"id": "m2_crnca",
		"title": "Gornja Crnča",
		"brief": "Selo zna više nego što govori. Kapitulacija straže otvara drum.",
		"objectives": [
			{"id": "clue_elder", "text": "Uzmi starješinu kartu straža", "type": "clue", "target": "clue_elder_map"},
			{"id": "kill_checkpoint", "text": "Likvidiraj stražu na punktu (4)", "type": "kills", "target": 4},
			{"id": "clue_axis", "text": "Zaploti njemačku depešu", "type": "clue", "target": "clue_axis_dispatch"},
		],
	},
	{
		"id": "m3_durmitor",
		"title": "Durmitor",
		"brief": "Partizani čekaju u šumi. Donosi im dokaze i oružje.",
		"objectives": [
			{"id": "clue_orders", "text": "Nađi partizanske zapovijedi", "type": "clue", "target": "clue_partisan_orders"},
			{"id": "weapon_mp40", "text": "Zaploti MP40", "type": "weapon", "target": 1},
			{"id": "weapon_mg42", "text": "Zaploti MG42", "type": "weapon", "target": 2},
			{"id": "clue_cipher", "text": "Dešifruj knjigu veza", "type": "clue", "target": "clue_cipher_logbook"},
		],
	},
]

var missions: Array = []       # runtime copy with progress
var current_mission := 0
var kills_this_mission := 0
var started := false
var _hud: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_state()
	call_deferred("_connect_sources")


func _reset_state() -> void:
	missions = []
	for m in MISSIONS:
		var copy: Dictionary = m.duplicate(true)
		for o in copy["objectives"]:
			o["done"] = false
		copy["done"] = false
		missions.append(copy)
	current_mission = 0
	kills_this_mission = 0


func _connect_sources() -> void:
	var ledger := get_tree().root.get_node_or_null("Stage4Ledger")
	if ledger:
		if ledger.has_signal("clue_added"):
			ledger.clue_added.connect(_on_clue)
	# The ledger in this project prints but does not emit; poll it instead.
	started = true
	_announce_current()
	print("[Missions] %d misija, %d ciljeva" % [missions.size(), total_objectives()])


func bind_hud(hud: CanvasLayer) -> void:
	_hud = hud


# ------------------------------------------------------------------- queries
func total_objectives() -> int:
	var n := 0
	for m in missions:
		n += (m["objectives"] as Array).size()
	return n


func completed_objectives() -> int:
	var n := 0
	for m in missions:
		for o in m["objectives"]:
			if o["done"]:
				n += 1
	return n


func current() -> Dictionary:
	if current_mission >= missions.size():
		return {}
	return missions[current_mission]


func current_objective() -> Dictionary:
	var m := current()
	if m.is_empty():
		return {}
	for o in m["objectives"]:
		if not o["done"]:
			return o
	return {}


func status_line() -> String:
	if current_mission >= missions.size():
		return "SVE MISIJE ZAVRŠENE"
	var m := current()
	var o := current_objective()
	if o.is_empty():
		return "%s — završeno" % m["title"]
	return "%s: %s" % [m["title"], o["text"]]


# ------------------------------------------------------------------ progress
func _announce_current() -> void:
	if current_mission < missions.size():
		mission_started.emit(missions[current_mission]["id"])


func complete_objective(obj_id: String) -> void:
	for m in missions:
		for o in m["objectives"]:
			if o["id"] == obj_id and not o["done"]:
				o["done"] = true
				objective_completed.emit(m["id"], obj_id)
				_check_mission(m)
				return


func _check_mission(m: Dictionary) -> void:
	for o in m["objectives"]:
		if not o["done"]:
			return
	if m["done"]:
		return
	m["done"] = true
	mission_completed.emit(m["id"])
	print("[Missions] završena: %s" % m["title"])
	if current_mission == missions.find(m):
		current_mission += 1
		kills_this_mission = 0
		if current_mission < missions.size():
			_announce_current()
			print("[Missions] nova: %s" % missions[current_mission]["title"])
		else:
			print("[Missions] SVE MISIJE ZAVRŠENE")
			all_missions_completed.emit()


func _on_clue(clue_id: String) -> void:
	notify_clue(clue_id)


func notify_clue(clue_id: String) -> void:
	for m in missions:
		for o in m["objectives"]:
			if o["type"] == "clue" and o["target"] == clue_id and not o["done"]:
				complete_objective(o["id"])


func notify_kill() -> void:
	kills_this_mission += 1
	for m in missions:
		for o in m["objectives"]:
			if o["type"] == "kills" and not o["done"]:
				if kills_this_mission >= int(o["target"]):
					complete_objective(o["id"])


func notify_weapon(slot: int) -> void:
	for m in missions:
		for o in m["objectives"]:
			if o["type"] == "weapon" and not o["done"] and int(o["target"]) == slot:
				complete_objective(o["id"])


func notify_talk(speaker: String) -> void:
	for m in missions:
		for o in m["objectives"]:
			if o["type"] == "talk" and o["target"] == speaker and not o["done"]:
				complete_objective(o["id"])
