extends SceneTree
## Stage 35 focused contract tests. Run with:
## godot --headless --path . --script res://test_competition_contract.gd

const Contract = preload("res://scripts/competition/competition_contract.gd")
var checks := 0
var failures := 0

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("FAIL: " if not value else "PASS: ") + label)

func _initialize() -> void:
	var normalized := Contract.normalize_player_record({
		"player_id": "player-1", "display_name": "  فارس  ", "city_level": -2,
		"power": 9000, "qualifier_points": -5, "matches_played": 3
	})
	_check(not normalized.is_empty(), "valid player ID produces a record")
	_check(normalized["display_name"] == "فارس", "display name is trimmed")
	_check(int(normalized["city_level"]) == 0 and int(normalized["qualifier_points"]) == 0, "negative values are clamped")
	_check(Contract.normalize_player_record({"display_name": "no id"}).is_empty(), "record without identity is rejected")

	var rules := {"min_city_level": 10, "min_power": 50000, "min_qualifier_points": 100, "min_qualifier_matches": 3}
	var qualified := {"player_id": "q1", "city_level": 10, "power": 50000, "qualifier_points": 100, "matches_played": 3}
	_check(Contract.is_eligible_for_king_event(qualified, rules), "eligibility accepts a record meeting all configured thresholds")
	var weak := qualified.duplicate(true)
	weak["power"] = 49999
	_check(not Contract.is_eligible_for_king_event(weak, rules), "eligibility rejects a record below a threshold")
	_check(not Contract.is_eligible_for_king_event(qualified, {"min_power": 1}), "eligibility rejects incomplete rules")

	var records: Array = [
		{"player_id": "self", "power": 10000},
		{"player_id": "b", "power": 11000, "qualifier_points": 20},
		{"player_id": "a", "power": 9000, "qualifier_points": 40},
		{"player_id": "far", "power": 20000}
	]
	var candidates: Array = Contract.matchmaking_candidates(records, "self", 10000, 0.15)
	_check(candidates.size() == 2, "matchmaking filters out self and power outside the band")
	_check(candidates.size() == 2 and candidates[0]["player_id"] == "a", "closest power is ordered first with deterministic tie handling")

	var ranked := Contract.rank_qualifiers([
		{"player_id": "z", "qualifier_points": 100, "qualifier_wins": 2, "power": 800},
		{"player_id": "a", "qualifier_points": 100, "qualifier_wins": 2, "power": 800},
		{"player_id": "b", "qualifier_points": 120, "power": 1},
		{"player_id": "b", "qualifier_points": 110, "power": 1}
	], 2)
	_check(ranked.size() == 2, "leaderboard limit is respected")
	_check(ranked.size() == 2 and ranked[0]["player_id"] == "b", "highest qualifier points rank first and duplicate IDs collapse")
	_check(ranked.size() == 2 and ranked[1]["player_id"] == "a", "ties resolve deterministically by player ID")

	var preview := Contract.build_local_preview({"player_id": "p1", "display_name": "test"}, {"city_level": 4, "power": 123})
	_check(not preview.is_empty() and preview["authoritative"] == false, "local preview is explicitly non-authoritative")
	print("Stage 35 competition contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
