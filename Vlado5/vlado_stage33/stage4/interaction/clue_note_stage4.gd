class_name ClueNoteStage4
extends Stage4Interactable
## Readable intel found in the world: ledgers, dispatch orders, radio logs.
## Registers itself with the Stage 4 mission ledger so the HUD can show
## "zabilješke 3/6".

@export var clue_id := ""
@export var title := "Zabilješka"
@export_multiline var body := ""
@export var paper_angle := 0.0


func _ready() -> void:
	kind = Kind.CLUE_NOTE
	prompt = "Pročitaj: " + title
	super._ready()
	_build()


func _build() -> void:
	var paper := Stage4Props.box(Vector3(0.30, 0.012, 0.22), "cloth_white")
	paper.position = Vector3(0, 0.02, 0)
	paper.rotation.y = paper_angle
	add_child(paper)
	for i in 3:
		var ink := Stage4Props.box(Vector3(0.20 - i * 0.03, 0.004, 0.012), "iron")
		ink.position = Vector3(0.01 * i, 0.028, -0.05 + i * 0.04)
		ink.rotation.y = paper_angle
		add_child(ink)
	set_box(Vector3(0.75, 0.65, 0.75), Vector3(0, 0.22, 0))


func _do_interact(_by: Node3D) -> void:
	var ledger := get_tree().root.get_node_or_null("Stage4Ledger")
	if ledger and ledger.has_method("add_clue"):
		ledger.add_clue(clue_id)
	notify(title, body)
