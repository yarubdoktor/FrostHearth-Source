extends SceneTree
## Run with: godot --headless --path . -s res://tests/test_stage42_march_simulation.gd
const Arena = preload("res://scripts/competition/competition_arena.gd")
const Simulation = preload("res://scripts/competition/competition_simulation.gd")

func _initialize() -> void:
	var layout: Dictionary = Arena.create_layout(Arena.MODE_QUALIFIER)
	var players: Array = [
		{"player_id": "p1", "units": 10, "speed": 100.0},
		{"player_id": "p2", "units": 10, "speed": 100.0},
		{"player_id": "p3", "units": 10, "speed": 100.0},
		{"player_id": "p4", "units": 10, "speed": 100.0}
	]
	var sim: Dictionary = Simulation.create(layout, players)
	assert(not sim.is_empty())
	assert(Simulation.create(layout, [{"player_id": "p1"}, {"player_id": "p1"}]).is_empty())
	assert(Simulation.issue_march(sim, "missing", "central_keep").is_empty())
	assert(Simulation.issue_march(sim, "p1", "unknown").is_empty())
	sim = Simulation.issue_march(sim, "p1", "central_keep")
	assert(not sim.is_empty())
	var initial: Dictionary = Simulation.player_snapshot(sim, "p1")
	assert(bool(initial.get("marching", false)))
	for i in range(20):
		sim = Simulation.advance(sim, 1.0)
		assert(not sim.is_empty())
	var arrived: Dictionary = Simulation.player_snapshot(sim, "p1")
	assert(not bool(arrived.get("marching", true)))
	assert(arrived.get("position", Vector2.ZERO).distance_to(Vector2(500, 500)) < 0.01)
	var summary: Dictionary = Simulation.objective_snapshot(sim, "central_keep")
	assert(float(summary.get("progress", 0.0)) > 0.0)
	assert(not bool(summary.get("authoritative", true)))
	quit(0)
