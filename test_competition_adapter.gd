extends SceneTree
## Run: godot --headless --path . --script res://test_competition_adapter.gd
const Adapter = preload("res://scripts/competition/competition_local_adapter.gd")
var checks := 0
var failures := 0

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("FAIL: " if not value else "PASS: ") + label)

func _initialize() -> void:
	var snapshot := Adapter.build_from_profile_card({
		"id": 42, "name": "قائد التجربة", "power": 98765, "furnace": 12,
		"troops": 500, "techs": 7
	}, "season-test")
	_check(not snapshot.is_empty(), "profile card produces a preview")
	_check(snapshot.get("authoritative", true) == false, "preview remains non-authoritative")
	_check(snapshot.get("source", "") == "local_preview", "source is marked as local preview")
	_check(snapshot.get("city", {}).get("city_level", 0) == 12, "furnace level maps to city level")
	_check(snapshot.get("city", {}).get("power", 0) == 98765, "profile power is copied for display")
	_check(snapshot.get("player", {}).get("season_id", "") == "season-test", "season label is propagated")
	_check(Adapter.build_from_profile_card({"id": 0, "name": "no-id"}).is_empty(), "empty local profile identity rejected")
	print("Stage 36 adapter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
