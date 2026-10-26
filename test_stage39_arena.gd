extends SceneTree
const Arena := preload("res://scripts/competition/competition_arena.gd")
func _initialize() -> void:
	var q := Arena.create_layout(Arena.MODE_QUALIFIER)
	assert(Arena.validate_layout(q))
	assert(q.get("spawns", []).size() == 4)
	assert(q.get("objectives", [])[0].get("id") == "central_keep")
	var k := Arena.create_layout(Arena.MODE_KING)
	assert(Arena.validate_layout(k))
	assert(k.get("sectors", []).size() == 25)
	assert(k.get("max_players") == 100)
	print("Stage 39 shared 3D arena data tests passed")
	quit()
