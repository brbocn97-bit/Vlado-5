class_name RegionData
extends RefCounted
## Region catalogue (matches the Stage 4 master plan and the Stage 3.2 world grid).

const REGIONS := [
	{
		"id": "Krupa_Valley",
		"name": "Dolina Krupe",
		"subtitle": "Krupa Valley",
		"center": Vector2(0.0, 0.0),
		"bounds": Rect2(-160.0, -160.0, 320.0, 320.0),
	},
	{
		"id": "Crnca_Village",
		"name": "Selo Gornja Crnča",
		"subtitle": "Crnca Village",
		"center": Vector2(-340.0, 10.0),
		"bounds": Rect2(-640.0, -180.0, 480.0, 360.0),
	},
	{
		"id": "Security_Checkpoint",
		"name": "Sigurnosni punkt Raskršće",
		"subtitle": "Post-war Security Checkpoint",
		"center": Vector2(340.0, -90.0),
		"bounds": Rect2(160.0, -240.0, 500.0, 360.0),
	},
	{
		"id": "Durmitor_Forest_Hideout",
		"name": "Borova šuma i pećina",
		"subtitle": "Durmitor Forest Hideout",
		"center": Vector2(-250.0, -350.0),
		"bounds": Rect2(-640.0, -640.0, 760.0, 480.0),
	},
	{
		"id": "Krupa_Canyon_Crossings",
		"name": "Kanjon Krupe i vodenica",
		"subtitle": "Krupa Canyon Crossings",
		"center": Vector2(100.0, 340.0),
		"bounds": Rect2(-240.0, 160.0, 520.0, 480.0),
	},
	{
		"id": "Lovcen_High_Peaks",
		"name": "Crni vrh i katuni",
		"subtitle": "Lovćen High Peaks",
		"center": Vector2(360.0, 290.0),
		"bounds": Rect2(160.0, 120.0, 500.0, 520.0),
	},
]

## Stage 3.2 spawn point, reused so the player still starts on the village terrace.
const PLAYER_SPAWN_XZ := Vector2(-5.0, 9.5)


const REGION_IDS := [
	"Krupa_Valley",
	"Crnca_Village",
	"Security_Checkpoint",
	"Durmitor_Forest_Hideout",
	"Krupa_Canyon_Crossings",
	"Lovcen_High_Peaks",
]


static func get_region(id: String) -> Dictionary:
	for r in REGIONS:
		if r["id"] == id:
			return r
	return {}


static func distance_to_bounds(region: Dictionary, p: Vector2) -> float:
	var b: Rect2 = region["bounds"]
	var cx := clampf(p.x, b.position.x, b.position.x + b.size.x)
	var cz := clampf(p.y, b.position.y, b.position.y + b.size.y)
	return p.distance_to(Vector2(cx, cz))


static func region_at(p: Vector2) -> Dictionary:
	var best := {}
	var best_area := 1e12
	for r in REGIONS:
		var b: Rect2 = r["bounds"]
		if b.grow(0.001).has_point(p):
			var area := b.size.x * b.size.y
			if area < best_area:
				best = r
				best_area = area
	return best
