extends SceneTree
## Run: godot --headless --path . --script res://test_competition_match.gd
const MatchModel = preload("res://scripts/competition/competition_match.gd")
var checks := 0
var failures := 0

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("FAIL: " if not value else "PASS: ") + label)

func _initialize() -> void:
	var match_data := MatchModel.create_match("m-1", "season-1", 100)
	_check(not match_data.is_empty(), "match requires IDs and initializes")
	_check(MatchModel.create_match("", "season-1").is_empty(), "empty match ID rejected")
	for i in range(4):
		match_data = MatchModel.add_player(match_data, {"player_id": "p%d" % i, "power": 1000 + i})
		_check(not match_data.is_empty(), "unique player %d can join" % i)
	_check(match_data["status"] == MatchModel.STATUS_READY, "match becomes ready with four players")
	_check(MatchModel.add_player(match_data, {"player_id": "p4"}).is_empty(), "fifth player rejected")
	_check(MatchModel.add_player(match_data, {"player_id": "p0"}).is_empty(), "duplicate player rejected")
	_check(MatchModel.remove_player(match_data, "p0").size() > 0, "player can be removed before resolution")
	match_data = MatchModel.add_player(match_data, {"player_id": "p0"})
	_check(match_data["status"] == MatchModel.STATUS_READY, "match returns to ready after refilling")
	var invalid := MatchModel.record_local_result(match_data, [
		{"player_id":"p0","place":1},{"player_id":"p1","place":2},
		{"player_id":"p2","place":2},{"player_id":"p3","place":4}
	], 200)
	_check(invalid.is_empty(), "duplicate placements rejected")
	var result := MatchModel.record_local_result(match_data, [
		{"player_id":"p0","place":4},{"player_id":"p1","place":1},
		{"player_id":"p2","place":3},{"player_id":"p3","place":2}
	], 200)
	_check(not result.is_empty() and result["status"] == MatchModel.STATUS_RESOLVED, "valid placements resolve match preview")
	_check(result["result"]["verified"] == false, "local result is explicitly unverified")
	_check(MatchModel.add_player(result, {"player_id":"late"}).is_empty(), "resolved match cannot accept new players")
	var incomplete := MatchModel.create_match("m-2", "season-1")
	_check(MatchModel.record_local_result(incomplete, [], 200).is_empty(), "incomplete match cannot resolve")
	print("Stage 36 match model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
