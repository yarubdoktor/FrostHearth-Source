extends SceneTree
## Run with: godot --headless --path . -s res://tests/test_stage45_combat_resolution.gd
const Combat = preload("res://scripts/competition/competition_combat.gd")

func _initialize() -> void:
	var win: Dictionary = Combat.resolve(
		{"units": 20, "attack": 1.4, "hero_power": 12.0},
		{"units": 12, "attack": 1.0, "fortification": 4.0}
	)
	assert(not win.is_empty())
	assert(str(win.get("outcome", "")) == "victory")
	assert(bool(win.get("target_burns", false)))
	assert(int(win.get("attacker_losses", 0)) > 0)
	assert(int(win.get("defender_losses", 0)) > 0)
	assert(int(win.get("attacker_units_remaining", -1)) >= 0)
	assert(not bool(win.get("authoritative", true)))
	var loss: Dictionary = Combat.resolve(
		{"units": 8, "attack": 1.0, "hero_power": 0.0},
		{"units": 18, "attack": 1.1, "fortification": 8.0}
	)
	assert(str(loss.get("outcome", "")) == "defeat")
	assert(not bool(loss.get("target_burns", true)))
	assert(int(loss.get("defender_losses", 0)) < int(loss.get("attacker_losses", 0)))
	assert(Combat.resolve({"units": 0, "attack": 1.0}, {"units": 5, "attack": 1.0}).is_empty())
	assert(Combat.resolve({"units": 5, "attack": -1.0}, {"units": 5, "attack": 1.0}).is_empty())
	quit(0)
