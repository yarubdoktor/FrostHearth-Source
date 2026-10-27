extends RefCounted
## Local, deterministic troop-march simulation for arena previews only.
## No combat, persistence, rewards, or trusted multiplayer behavior is implemented.
const Arena = preload("res://scripts/competition/competition_arena.gd")
const Capture = preload("res://scripts/competition/competition_capture.gd")
const SCHEMA_VERSION := 1
const DEFAULT_SPEED := 42.0
const OBJECTIVE_ARRIVAL_DISTANCE := 18.0

static func create(layout: Dictionary, player_records: Array) -> Dictionary:
	if not Arena.validate_layout(layout) or player_records.is_empty():
		return {}
	var max_players := int(layout.get("max_players", 0))
	if player_records.size() > max_players:
		return {}
	var players: Array[Dictionary] = []
	var ids: Array[String] = []
	var seen: Dictionary = {}
	var spawns: Array = layout.get("spawns", [])
	for i in range(player_records.size()):
		var raw: Variant = player_records[i]
		if not raw is Dictionary:
			return {}
		var pid := str(raw.get("player_id", "")).strip_edges()
		if pid.is_empty() or seen.has(pid):
			return {}
		seen[pid] = true
		var position := Vector2.ZERO
		if raw.get("position", null) is Vector2:
			position = raw.get("position", Vector2.ZERO)
		elif spawns.size() > i:
			position = spawns[i]
		else:
			var angle := TAU * float(i) / float(maxi(1, player_records.size()))
			var radius := minf(float(layout.get("width", 1000)), float(layout.get("height", 1000))) * 0.38
			position = Vector2(float(layout.get("width", 1000)) * 0.5, float(layout.get("height", 1000)) * 0.5) + Vector2(cos(angle), sin(angle)) * radius
		var units := maxi(0, int(raw.get("units", 10)))
		players.append({
			"player_id": pid,
			"position": position,
			"target_objective": "",
			"target_position": position,
			"units": units,
			"speed": clampf(float(raw.get("speed", DEFAULT_SPEED)), 1.0, 250.0),
			"marching": false
		})
		ids.append(pid)
	var capture_state: Dictionary = Capture.create_state(layout, ids)
	if capture_state.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": str(layout.get("mode", "")),
		"layout": layout.duplicate(true),
		"players": players,
		"capture": capture_state,
		"source": "local_preview",
		"authoritative": false
	}

static func issue_march(state: Dictionary, player_id: String, objective_id: String) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated):
		return {}
	var pid := player_id.strip_edges()
	var oid := objective_id.strip_edges()
	var target_position := Vector2.ZERO
	var target_found := false
	for objective in updated["layout"].get("objectives", []):
		if str(objective.get("id", "")) == oid:
			target_position = objective.get("position", Vector2.ZERO)
			target_found = true
			break
	if not target_found:
		return {}
	var players: Array = updated.get("players", [])
	var player_found := false
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if str(player.get("player_id", "")) != pid:
			continue
		player["target_objective"] = oid
		player["target_position"] = target_position
		player["marching"] = player.get("position", Vector2.ZERO).distance_to(target_position) > OBJECTIVE_ARRIVAL_DISTANCE
		players[i] = player
		player_found = true
		break
	if not player_found:
		return {}
	updated["players"] = players
	return updated

static func advance(state: Dictionary, delta_seconds: float) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated) or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return {}
	var step := minf(delta_seconds, 5.0)
	var players: Array = updated.get("players", [])
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if bool(player.get("marching", false)):
			var current: Vector2 = player.get("position", Vector2.ZERO)
			var target: Vector2 = player.get("target_position", current)
			var next_position := current.move_toward(target, float(player.get("speed", DEFAULT_SPEED)) * step)
			player["position"] = next_position
			if next_position.distance_to(target) <= OBJECTIVE_ARRIVAL_DISTANCE:
				player["position"] = target
				player["marching"] = false
		players[i] = player
	updated["players"] = players
	var capture_state: Dictionary = updated.get("capture", {}).duplicate(true)
	for objective in updated["layout"].get("objectives", []):
		var oid := str(objective.get("id", ""))
		for player in players:
			var player_position: Vector2 = player.get("position", Vector2.ZERO)
			var target_oid := str(player.get("target_objective", ""))
			var at_target := target_oid == oid and player_position.distance_to(objective.get("position", Vector2.ZERO)) <= OBJECTIVE_ARRIVAL_DISTANCE
			var units := int(player.get("units", 0)) if at_target else 0
			capture_state = Capture.set_presence(capture_state, str(player.get("player_id", "")), oid, units)
			if capture_state.is_empty():
				return {}
	capture_state = Capture.advance(capture_state, step)
	if capture_state.is_empty():
		return {}
	updated["capture"] = capture_state
	return updated

static func apply_combat_result(state: Dictionary, player_id: String, objective_id: String, result: Dictionary) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated) or str(result.get("source", "")) != "local_preview" or bool(result.get("authoritative", true)):
		return {}
	var outcome := str(result.get("outcome", ""))
	if outcome != "victory" and outcome != "defeat":
		return {}
	if bool(result.get("target_burns", false)) != (outcome == "victory"):
		return {}
	var pid := player_id.strip_edges()
	var oid := objective_id.strip_edges()
	var objective_found := false
	for objective in updated.get("layout", {}).get("objectives", []):
		if str(objective.get("id", "")) == oid:
			objective_found = true
			break
	if not objective_found:
		return {}
	var players: Array = updated.get("players", [])
	var found := false
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if str(player.get("player_id", "")) != pid:
			continue
		if int(result.get("attacker_units_start", -1)) != int(player.get("units", -2)):
			return {}
		var remaining := maxi(0, int(result.get("attacker_units_remaining", 0)))
		if remaining > int(player.get("units", 0)):
			return {}
		player["units"] = remaining
		if outcome == "defeat":
			player["target_objective"] = ""
			player["target_position"] = player.get("position", Vector2.ZERO)
			player["marching"] = false
		players[i] = player
		found = true
		break
	if not found:
		return {}
	updated["players"] = players
	if outcome == "victory":
		var capture_state: Dictionary = Capture.set_owner(updated.get("capture", {}), oid, pid, 100.0)
		if capture_state.is_empty():
			return {}
		updated["capture"] = capture_state
	return updated

static func player_snapshot(state: Dictionary, player_id: String) -> Dictionary:
	if not _valid_state(state):
		return {}
	for player in state.get("players", []):
		if str(player.get("player_id", "")) == player_id.strip_edges():
			return {
				"player_id": str(player.get("player_id", "")),
				"position": player.get("position", Vector2.ZERO),
				"target_objective": str(player.get("target_objective", "")),
				"units": int(player.get("units", 0)),
				"marching": bool(player.get("marching", false)),
				"source": "local_preview",
				"authoritative": false
			}
	return {}

static func objective_snapshot(state: Dictionary, objective_id: String) -> Dictionary:
	if not _valid_state(state):
		return {}
	return Capture.objective_summary(state.get("capture", {}), objective_id)

static func _valid_state(state: Dictionary) -> bool:
	if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	if str(state.get("source", "")) != "local_preview" or bool(state.get("authoritative", true)):
		return false
	if not state.get("layout", {}) is Dictionary or not Arena.validate_layout(state.get("layout", {})):
		return false
	if not state.get("players", []) is Array or state.get("players", []).is_empty():
		return false
	if not state.get("capture", {}) is Dictionary:
		return false
	return true
