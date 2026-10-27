extends RefCounted
## Deterministic local capture-state model for competition previews.
## This is not authoritative, does not perform combat, and never writes save data.

const SCHEMA_VERSION := 1
const MAX_STEP_SECONDS := 5.0
const CAPTURE_RATE_PER_UNIT := 8.0
const MODE_QUALIFIER := "qualifier"
const MODE_KING := "king"

static func create_state(layout: Dictionary, player_ids: Array) -> Dictionary:
	if not _valid_layout(layout):
		return {}
	var ids: Array[String] = []
	var seen: Dictionary = {}
	for raw_id in player_ids:
		var player_id := str(raw_id).strip_edges()
		if player_id.is_empty() or seen.has(player_id):
			return {}
		seen[player_id] = true
		ids.append(player_id)
	var max_players := int(layout.get("max_players", 0))
	if ids.is_empty() or ids.size() > max_players:
		return {}
	var objectives: Array = []
	for raw_objective in layout.get("objectives", []):
		if not raw_objective is Dictionary:
			return {}
		var objective_id := str(raw_objective.get("id", "")).strip_edges()
		if objective_id.is_empty():
			return {}
		objectives.append({
			"objective_id": objective_id,
			"owner_id": "",
			"progress": 0.0,
			"presence": {}
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": str(layout.get("mode", "")),
		"player_ids": ids,
		"objectives": objectives,
		"source": "local_preview",
		"authoritative": false
	}

static func set_presence(state: Dictionary, player_id: String, objective_id: String, units: int) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated):
		return {}
	var pid := player_id.strip_edges()
	var oid := objective_id.strip_edges()
	if not updated.get("player_ids", []).has(pid) or units < 0:
		return {}
	var found := false
	var objectives: Array = updated.get("objectives", [])
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		if str(objective.get("objective_id", "")) != oid:
			continue
		var presence: Dictionary = objective.get("presence", {}).duplicate(true)
		presence[pid] = units
		objective["presence"] = presence
		objectives[i] = objective
		found = true
		break
	if not found:
		return {}
	updated["objectives"] = objectives
	return updated

static func set_owner(state: Dictionary, objective_id: String, owner_id: String, progress: float = 100.0) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated):
		return {}
	var oid := objective_id.strip_edges()
	var pid := owner_id.strip_edges()
	if not updated.get("player_ids", []).has(pid) or not is_finite(progress) or progress < 0.0 or progress > 100.0:
		return {}
	var objectives: Array = updated.get("objectives", [])
	var found := false
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		if str(objective.get("objective_id", "")) != oid:
			continue
		objective["owner_id"] = pid
		objective["progress"] = progress
		objectives[i] = objective
		found = true
		break
	if not found:
		return {}
	updated["objectives"] = objectives
	return updated

static func advance(state: Dictionary, delta_seconds: float) -> Dictionary:
	var updated := state.duplicate(true)
	if not _valid_state(updated) or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return {}
	var step := minf(delta_seconds, MAX_STEP_SECONDS)
	var objectives: Array = updated.get("objectives", [])
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		var presence: Dictionary = objective.get("presence", {})
		var owner_id := str(objective.get("owner_id", ""))
		var progress := clampf(float(objective.get("progress", 0.0)), 0.0, 100.0)
		var owner_units := int(presence.get(owner_id, 0)) if not owner_id.is_empty() else 0
		var strongest_id := ""
		var strongest_units := 0
		var second_units := 0
		for raw_id in updated.get("player_ids", []):
			var pid := str(raw_id)
			var units := int(presence.get(pid, 0))
			if pid == owner_id:
				continue
			if units > strongest_units:
				second_units = strongest_units
				strongest_units = units
				strongest_id = pid
			elif units > second_units:
				second_units = units
		if not owner_id.is_empty() and strongest_units > 0:
			if owner_units > 0 or second_units > 0:
				# Owner defending, or multiple challengers contesting: freeze capture.
				pass
			else:
				progress = maxf(0.0, progress - float(strongest_units) * CAPTURE_RATE_PER_UNIT * step)
				if progress <= 0.0:
					objective["owner_id"] = ""
		elif owner_id.is_empty():
			if strongest_units > 0 and strongest_units > second_units:
				progress = minf(100.0, progress + float(strongest_units - second_units) * CAPTURE_RATE_PER_UNIT * step)
				if progress >= 100.0:
					objective["owner_id"] = strongest_id
			# A tie between challengers stalls progress to avoid arbitrary winners.
		objective["progress"] = progress
		objectives[i] = objective
	updated["objectives"] = objectives
	return updated

static func objective_summary(state: Dictionary, objective_id: String) -> Dictionary:
	if not _valid_state(state):
		return {}
	for objective in state.get("objectives", []):
		if str(objective.get("objective_id", "")) == objective_id.strip_edges():
			var presence: Dictionary = objective.get("presence", {})
			var present_units := 0
			var contesting_players := 0
			for raw_id in state.get("player_ids", []):
				var pid := str(raw_id)
				var units := maxi(0, int(presence.get(pid, 0)))
				present_units += units
				if units > 0:
					contesting_players += 1
			return {
				"objective_id": str(objective.get("objective_id", "")),
				"owner_id": str(objective.get("owner_id", "")),
				"progress": float(objective.get("progress", 0.0)),
				"present_units": present_units,
				"contesting_players": contesting_players,
				"source": "local_preview",
				"authoritative": false
			}
	return {}

static func _valid_layout(layout: Dictionary) -> bool:
	var mode := str(layout.get("mode", ""))
	if mode != MODE_QUALIFIER and mode != MODE_KING:
		return false
	if int(layout.get("max_players", 0)) <= 0:
		return false
	if not layout.get("objectives", []) is Array or layout.get("objectives", []).is_empty():
		return false
	return true

static func _valid_state(state: Dictionary) -> bool:
	if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	if str(state.get("source", "")) != "local_preview" or bool(state.get("authoritative", true)):
		return false
	if not state.get("player_ids", []) is Array or state.get("player_ids", []).is_empty():
		return false
	if not state.get("objectives", []) is Array or state.get("objectives", []).is_empty():
		return false
	return true
