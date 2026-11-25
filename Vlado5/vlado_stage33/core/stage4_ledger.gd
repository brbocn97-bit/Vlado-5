extends Node
## Stage4Ledger — autoload. Tracks clues, missions and session stats for the
## Stage 4 layer without touching the Stage 3.2 GameManager.

signal clue_added(clue_id: String)

const TOTAL := 7

var clues: Array[String] = []
var clues_available: Array[String] = [
	"clue_homestead_letter",
	"clue_kafana_ledger",
	"clue_elder_map",
	"clue_security_dispatch",
	"clue_partisan_orders",
	"clue_mill_ledger",
	"clue_cipher_logbook",
]
var missions: Array[String] = []
var shots_fired := 0
var shots_hit := 0
var kills := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_clue(id: String) -> bool:
	if id == "" or clues.has(id):
		return false
	clues.append(id)
	print("[Stage4Ledger] clue %s  (%d/%d)" % [id, mini(clues.size(), TOTAL), TOTAL])
	clue_added.emit(id)
	return true


func has_clue(id: String) -> bool:
	return clues.has(id)


func complete_mission(id: String) -> void:
	if not missions.has(id):
		missions.append(id)
		print("[Stage4Ledger] mission complete: ", id)


func report_shot(hit: bool) -> void:
	shots_fired += 1
	if hit:
		shots_hit += 1


func report_kill() -> void:
	kills += 1
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms and ms.has_method("notify_kill"):
		ms.notify_kill()


func accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return 100.0 * float(shots_hit) / float(shots_fired)


func summary() -> String:
	return "Pogoci %.0f%% · Ubijeno %d · Zabilješke %d/%d" % [
		accuracy(), kills, clues.size(), TOTAL]
