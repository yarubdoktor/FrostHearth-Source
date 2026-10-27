extends SceneTree
## Run with: godot --headless --path . -s res://tests/test_stage45_combat_resolution.gd
const Combat = preload("res://scripts/competition/competition_combat.gd")
const Arena = preload("res://scripts/competition/competition_arena.gd")
const Simulation = preload("res://scripts/competition/competition_simulation.gd")

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
	var layout: Dictionary = Arena.create_layout(Arena.MODE_QUALIFIER)
	var initial: Dictionary = Simulation.create(layout, [
		{"player_id": "p1", "units": 20},
		{"player_id": "p2", "units": 12},
		{"player_id": "p3", "units": 10},
		{"player_id": "p4", "units": 10}
	])
	var captured: Dictionary = Simulation.apply_combat_result(initial, "p1", "central_keep", win)
	assert(not captured.is_empty())
	assert(str(Simulation.objective_snapshot(captured, "central_keep").get("owner_id", "")) == "p1")
	assert(int(Simulation.player_snapshot(captured, "p1").get("units", 0)) == int(win.get("attacker_units_remaining", 0)))
	assert(Simulation.apply_combat_result(initial, "p1", "unknown_keep", win).is_empty())
	var losing_army: Dictionary = Simulation.create(layout, [
		{"player_id": "p1", "units": 8},
		{"player_id": "p2", "units": 12},
		{"player_id": "p3", "units": 10},
		{"player_id": "p4", "units": 10}
	])
	var held: Dictionary = Simulation.apply_combat_result(losing_army, "p1", "central_keep", loss)
	assert(not held.is_empty())
	assert(str(Simulation.objective_snapshot(held, "central_keep").get("owner_id", "")) == "")
	assert(str(Simulation.player_snapshot(held, "p1").get("target_objective", "")) == "")
	quit(0)
