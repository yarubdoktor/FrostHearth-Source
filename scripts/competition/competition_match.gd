extends RefCounted
## Pure local model for a four-city qualifier match.
## It does not perform combat, persist rewards, or authenticate players.
## All match results remain untrusted until a future authoritative server verifies them.

const SCHEMA_VERSION := 1
const REQUIRED_CITIES := 4
const STATUS_WAITING := "waiting"
const STATUS_READY := "ready"
const STATUS_RESOLVED := "resolved"
const STATUS_CANCELLED := "cancelled"


static func create_match(match_id: String, season_id: String, created_at: int = 0) -> Dictionary:
	var safe_id := match_id.strip_edges()
	var safe_season := season_id.strip_edges()
	if safe_id.is_empty() or safe_season.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"match_id": safe_id,
		"season_id": safe_season,
		"status": STATUS_WAITING,
		"created_at": maxi(0, created_at),
		"players": [],
		"result": {},
		"source": "local_preview",
		"authoritative": false
	}


static func add_player(match_data: Dictionary, player_record: Dictionary) -> Dictionary:
	var updated := match_data.duplicate(true)
	if not _valid_open_match(updated):
		return {}
	var player := _normalize_player(player_record)
	if player.is_empty():
		return {}
	var players: Array = updated.get("players", [])
	if players.size() >= REQUIRED_CITIES:
		return {}
	for existing in players:
		if str(existing.get("player_id", "")) == str(player["player_id"]):
			return {}
	players.append(player)
	updated["players"] = players
	updated["status"] = STATUS_READY if players.size() == REQUIRED_CITIES else STATUS_WAITING
	return updated


static func remove_player(match_data: Dictionary, player_id: String) -> Dictionary:
	var updated := match_data.duplicate(true)
	if not _valid_open_match(updated):
		return {}
	var target := player_id.strip_edges()
	if target.is_empty():
		return {}
	var players: Array = updated.get("players", [])
	var kept: Array = []
	var removed := false
	for player in players:
		if str(player.get("player_id", "")) == target:
			removed = true
		else:
			kept.append(player)
	if not removed:
		return {}
	updated["players"] = kept
	updated["status"] = STATUS_WAITING
	return updated


static func record_local_result(match_data: Dictionary, placements: Array, resolved_at: int = 0) -> Dictionary:
	## This stores a preview only. It cannot award items or modify Game/save state.
	var updated := match_data.duplicate(true)
	if not _valid_open_match(updated) or str(updated.get("status", "")) != STATUS_READY:
		return {}
	if placements.size() != REQUIRED_CITIES:
		return {}
	var players: Array = updated.get("players", [])
	var expected_ids: Dictionary = {}
	for player in players:
		expected_ids[str(player.get("player_id", ""))] = true
	var seen: Dictionary = {}
	var normalized: Array = []
	for raw in placements:
		if not raw is Dictionary:
			return {}
		var pid := str(raw.get("player_id", "")).strip_edges()
		var place := int(raw.get("place", 0))
		if not expected_ids.has(pid) or seen.has(pid) or place < 1 or place > REQUIRED_CITIES:
			return {}
		seen[pid] = true
		normalized.append({"player_id": pid, "place": place})
	if seen.size() != REQUIRED_CITIES:
		return {}
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["place"]) != int(b["place"]):
			return int(a["place"]) < int(b["place"])
		return str(a["player_id"]) < str(b["player_id"])
	)
	for i in range(normalized.size()):
		if int(normalized[i]["place"]) != i + 1:
			return {}
	updated["result"] = {
		"placements": normalized,
		"resolved_at": maxi(0, resolved_at),
		"verified": false
	}
	updated["status"] = STATUS_RESOLVED
	return updated


static func cancel_match(match_data: Dictionary, reason: String = "") -> Dictionary:
	var updated := match_data.duplicate(true)
	if not _valid_open_match(updated):
		return {}
	updated["status"] = STATUS_CANCELLED
	updated["cancel_reason"] = reason.strip_edges().substr(0, 120)
	return updated


static func _valid_open_match(match_data: Dictionary) -> bool:
	if str(match_data.get("match_id", "")).strip_edges().is_empty():
		return false
	if str(match_data.get("season_id", "")).strip_edges().is_empty():
		return false
	if not match_data.get("players", []) is Array:
		return false
	var status := str(match_data.get("status", ""))
	return status == STATUS_WAITING or status == STATUS_READY


static func _normalize_player(raw: Dictionary) -> Dictionary:
	var pid := str(raw.get("player_id", "")).strip_edges()
	if pid.is_empty():
		return {}
	return {
		"player_id": pid,
		"display_name": str(raw.get("display_name", "قائد مجهول")).strip_edges().substr(0, 32),
		"power": maxi(0, int(raw.get("power", 0))),
		"city_level": maxi(0, int(raw.get("city_level", 0))),
		"qualifier_points": maxi(0, int(raw.get("qualifier_points", 0)))
	}
