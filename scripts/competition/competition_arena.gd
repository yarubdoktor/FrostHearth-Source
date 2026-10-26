extends RefCounted
## Shared map contract for FrostHearth competition modes. Layout only; no combat/rewards.

const MODE_QUALIFIER := "qualifier"
const MODE_KING := "king"
const SCHEMA_VERSION := 1
const MAX_QUALIFIER_PLAYERS := 4
const MAX_KING_PLAYERS := 100

static func create_layout(mode: String) -> Dictionary:
	match mode:
		MODE_QUALIFIER:
			return _qualifier_layout()
		MODE_KING:
			return _king_layout()
		_:
			return {}

static func _qualifier_layout() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "mode": MODE_QUALIFIER,
		"title": "ميدان التأهل", "width": 1000, "height": 1000,
		"max_players": MAX_QUALIFIER_PLAYERS, "terrain_profile": "compact_arena",
		"legacy_assets_allowed": true,
		"spawns": [Vector2(180, 180), Vector2(820, 180), Vector2(820, 820), Vector2(180, 820)],
		"objectives": [{"id": "central_keep", "kind": "capture", "position": Vector2(500, 500), "radius": 90}],
		"sectors": []
	}

static func _king_layout() -> Dictionary:
	var sectors: Array[Dictionary] = []
	for row in range(5):
		for column in range(5):
			sectors.append({
				"id": "sector-%02d-%02d" % [row + 1, column + 1],
				"row": row, "column": column,
				"center": Vector2(240 + column * 480, 240 + row * 480),
				"kind": "king_core" if row == 2 and column == 2 else "control_sector"
			})
	return {
		"schema_version": SCHEMA_VERSION, "mode": MODE_KING,
		"title": "خريطة مبنى الملك", "width": 2400, "height": 2400,
		"max_players": MAX_KING_PLAYERS, "terrain_profile": "large_sector_map",
		"legacy_assets_allowed": true, "spawns": [],
		"objectives": [{"id": "king_building", "kind": "king_capture", "position": Vector2(1200, 1200), "radius": 150}],
		"sectors": sectors
	}

static func validate_layout(layout: Dictionary) -> bool:
	if int(layout.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	var mode := str(layout.get("mode", ""))
	if mode != MODE_QUALIFIER and mode != MODE_KING:
		return false
	if int(layout.get("width", 0)) <= 0 or int(layout.get("height", 0)) <= 0:
		return false
	var expected_players := MAX_QUALIFIER_PLAYERS if mode == MODE_QUALIFIER else MAX_KING_PLAYERS
	if int(layout.get("max_players", 0)) != expected_players or layout.get("objectives", []).is_empty():
		return false
	if mode == MODE_QUALIFIER and layout.get("spawns", []).size() != MAX_QUALIFIER_PLAYERS:
		return false
	if mode == MODE_KING and layout.get("sectors", []).size() != 25:
		return false
	return true
