extends RefCounted
## Stage 35: isolated competition-domain contract.
## This module is deliberately not connected to Game/save/UI yet. Client values are previews only;
## a future authoritative service must recompute power, eligibility, rankings, and rewards server-side.

const SCHEMA_VERSION := 1
const DEFAULT_MATCH_POWER_BAND := 0.15
const DEFAULT_QUALIFIER_LIMIT := 100


static func normalize_player_record(raw: Dictionary) -> Dictionary:
	var player_id := str(raw.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"player_id": player_id,
		"display_name": _safe_name(raw.get("display_name", "")),
		"city_level": maxi(0, int(raw.get("city_level", 0))),
		"power": maxi(0, int(raw.get("power", 0))),
		"army_power": maxi(0, int(raw.get("army_power", 0))),
		"research_level": maxi(0, int(raw.get("research_level", 0))),
		"qualifier_points": maxi(0, int(raw.get("qualifier_points", 0))),
		"qualifier_wins": maxi(0, int(raw.get("qualifier_wins", 0))),
		"matches_played": maxi(0, int(raw.get("matches_played", 0))),
		"season_id": str(raw.get("season_id", "")).strip_edges(),
		"updated_at": maxi(0, int(raw.get("updated_at", 0)))
	}


static func build_local_preview(profile: Dictionary, city_state: Dictionary) -> Dictionary:
	## Data-transfer shape only. Never use this client-generated snapshot as proof of power or rewards.
	var normalized := normalize_player_record(profile)
	if normalized.is_empty():
		return {}
	var city := {
		"city_level": maxi(0, int(city_state.get("city_level", normalized["city_level"]))),
		"power": maxi(0, int(city_state.get("power", normalized["power"]))),
		"army_power": maxi(0, int(city_state.get("army_power", normalized["army_power"]))),
		"research_level": maxi(0, int(city_state.get("research_level", normalized["research_level"])))
	}
	return {
		"contract_version": SCHEMA_VERSION,
		"source": "local_preview",
		"authoritative": false,
		"player": normalized,
		"city": city
	}


static func is_eligible_for_king_event(record: Dictionary, rules: Dictionary) -> bool:
	## All thresholds are supplied by configuration; this file does not silently lock balance values.
	var player := normalize_player_record(record)
	if player.is_empty():
		return false
	if not rules.has("min_city_level") or not rules.has("min_power"):
		return false
	if not rules.has("min_qualifier_points") or not rules.has("min_qualifier_matches"):
		return false
	return (
		int(player["city_level"]) >= maxi(0, int(rules["min_city_level"]))
		and int(player["power"]) >= maxi(0, int(rules["min_power"]))
		and int(player["qualifier_points"]) >= maxi(0, int(rules["min_qualifier_points"]))
		and int(player["matches_played"]) >= maxi(0, int(rules["min_qualifier_matches"]))
	)


static func matchmaking_candidates(records: Array, player_id: String, player_power: int, power_band: float = DEFAULT_MATCH_POWER_BAND) -> Array:
	## Candidate discovery only. A backend must revalidate identities, season, availability, and current power.
	var target_id := player_id.strip_edges()
	var target_power := maxi(0, player_power)
	var band := clampf(power_band, 0.01, 1.0)
	var found: Array = []
	for raw in records:
		if not raw is Dictionary:
			continue
		var candidate: Dictionary = normalize_player_record(raw)
		if candidate.is_empty() or str(candidate["player_id"]) == target_id:
			continue
		var relative_gap := absf(float(candidate["power"]) - float(target_power)) / maxf(float(target_power), 1.0)
		if relative_gap <= band:
			candidate["match_power_gap"] = relative_gap
			found.append(candidate)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["match_power_gap"]), float(b["match_power_gap"])):
			return float(a["match_power_gap"]) < float(b["match_power_gap"])
		return str(a["player_id"]) < str(b["player_id"])
	)
	return found


static func rank_qualifiers(records: Array, limit: int = DEFAULT_QUALIFIER_LIMIT) -> Array:
	## Stable ordering: points, wins, power, then player ID. Duplicate IDs are collapsed.
	var unique: Dictionary = {}
	for raw in records:
		if not raw is Dictionary:
			continue
		var player: Dictionary = normalize_player_record(raw)
		if player.is_empty():
			continue
		var pid := str(player["player_id"])
		if not unique.has(pid) or _ranks_before(player, unique[pid]):
			unique[pid] = player
	var ranked: Array = unique.values()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _ranks_before(a, b)
	)
	return ranked.slice(0, mini(ranked.size(), maxi(0, limit)))


static func _ranks_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("qualifier_points", 0)) != int(b.get("qualifier_points", 0)):
		return int(a.get("qualifier_points", 0)) > int(b.get("qualifier_points", 0))
	if int(a.get("qualifier_wins", 0)) != int(b.get("qualifier_wins", 0)):
		return int(a.get("qualifier_wins", 0)) > int(b.get("qualifier_wins", 0))
	if int(a.get("power", 0)) != int(b.get("power", 0)):
		return int(a.get("power", 0)) > int(b.get("power", 0))
	return str(a.get("player_id", "")) < str(b.get("player_id", ""))


static func _safe_name(value: Variant) -> String:
	var result := str(value).strip_edges()
	if result.is_empty():
		return "قائد مجهول"
	return result.substr(0, 32)
