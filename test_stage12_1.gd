extends Node
const Placement := preload("res://scripts/city_placement.gd")
const Defs := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func capture(path: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "actual Godot screenshot saved")


func _ready() -> void:
	Game.save_path_override = "user://frost_stage121_%s_test_only.json" % DisplayServer.get_name()
	Game.new_game()
	Game.set_process(false)
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Placement.PLOTS_PER_SIDE == 2 and Placement.PLOT_SIDE == 5.0, "four large building plots, not four tiny old tiles")
	check(Placement.FOOTPRINT_SIDE == 10.0 and Placement.MIN_CITY_SPACING == 12.0, "footprint and separation match rotated city models")
	check(map.external_environment.green_at(Vector2(300, 300)) and map.external_environment.green_at(Vector2(1100, 1100)),
		"green outside original sample, independent of player position")
	var uniforms_ok := true
	for material in map.external_environment.materials:
		if not material.get_shader_parameter("whole_exterior"):
			uniforms_ok = false
	check(uniforms_ok, "whole-world setting reaches every environment shader")
	check(map.data["cities"].size() == 420, "all 420 demo cities retained")
	var collisions := 0
	var invalid := 0
	var cities: Array = map.data["cities"]
	for i in cities.size():
		var a := Vector2(cities[i]["x"], cities[i]["y"])
		if not map.city_placement.reason(a, i).is_empty():
			invalid += 1
		for j in i:
			var b := Vector2(cities[j]["x"], cities[j]["y"])
			if Placement.overlaps(a, b):
				collisions += 1
	check(collisions == 0, "no overlapping city reservations among any pair")
	check(invalid == 0, "every city passes terrain, resource, beast, landmark and city clearance")
	check(map._home_placement_reason(Game.home).is_empty(), "default saved home remains valid")
	var city: Dictionary = cities[0]
	var city_tile := Vector2i(int(city["x"]), int(city["y"]))
	Game.reveal_at(city_tile.x, city_tile.y, 35)
	var previous_home: Vector2i = Game.home
	var previous_transform: Transform3D = map.home_node.transform
	var old_save := FileAccess.get_file_as_string(Game.save_path_override)
	check(not map._move_home({"kind": "empty", "x": city_tile.x + 3, "y": city_tile.y,
		"pos": Vector3(city_tile.x + 3.5, city["h"], city_tile.y + 0.5)}), "reject placement beside occupied city")
	check(Game.home == previous_home and map.home_node.transform == previous_transform, "rejection does not move city")
	check(FileAccess.get_file_as_string(Game.save_path_override) == old_save, "rejection does not rewrite save")
	check(not map._move_home({"kind": "empty", "x": 782, "y": 850, "pos": Vector3(782.5, 0.15, 850.5)}),
		"reject placing city on gathering site")
	check(not map._home_placement_reason(Vector2i(650, 802)).is_empty(), "reject lake")
	check(not map._home_placement_reason(Vector2i(0, 0)).is_empty(), "reject map edge")
	check(not map._home_placement_reason(Vector2i(300, 300)).is_empty(), "reject invalid or unexplored full footprint")
	var target := Vector2i(-1, -1)
	for dx in range(-30, 31):
		for dy in range(-30, 31):
			var tile := previous_home + Vector2i(dx, dy)
			if Vector2(dx, dy).length() >= 14.0 and map._home_placement_reason(tile).is_empty():
				target = tile
				break
		if target.x >= 0:
			break
	check(target.x >= 0, "valid nearby relocation space exists")
	if target.x >= 0:
		var preview_info := {"kind": "empty", "x": target.x, "y": target.y,
			"pos": Vector3(target.x + 0.5, 0.15, target.y + 0.5)}
		map._select(preview_info)
		check(map.placement_preview.visible and not map.p_action.disabled, "valid four-cell preview enables relocation")
		check(map.placement_preview.get_child_count() == 10, "four plot faces and six grid boundaries shown")
		map._select({"kind": "empty", "x": 782, "y": 850, "pos": Vector3(782.5, 0.15, 850.5)})
		check(map.placement_preview.visible and map.p_action.disabled, "invalid four-cell preview blocks relocation")
		map._close_panel()
		check(not map.placement_preview.visible, "closing selection hides footprint preview")
		var explored_backup: PackedByteArray = Game.explored.duplicate()
		Game.explored.fill(0)
		var fog_x := floori(float(target.x) / Defs.FOG_CELL)
		var fog_y := floori(float(target.y) / Defs.FOG_CELL)
		Game.explored[fog_y * Defs.FOG_GRID + fog_x] = 1
		check(Game.is_explored(target.x, target.y) and not map._home_placement_reason(target).is_empty(),
			"revealing centre alone does not allow hidden footprint")
		Game.explored = explored_backup
		check(map._move_home({"kind": "empty", "x": target.x, "y": target.y,
			"pos": Vector3(target.x + 0.5, 0.15, target.y + 0.5)}), "valid relocation accepted")
		var area: Rect2i = Placement.tiles(Vector2(target) + Vector2(0.5, 0.5))
		var registered := true
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				if map.lookup.get(Vector2i(x, y), {}).get("team", "") != "me":
					registered = false
		check(registered, "entire physical city footprint registered")
		var old_center: Dictionary = map.lookup.get(previous_home, {})
		check(old_center.get("team", "") != "me", "old city footprint released")
		check(Game.load_game() and Game.home == target, "new location persists")
		check(map._move_home({"kind": "empty", "x": previous_home.x, "y": previous_home.y,
			"pos": Vector3(previous_home.x + 0.5, 0.09, previous_home.y + 0.5)}), "return to original valid home accepted")
	var resources_intact := true
	for res in map.data["resources"]:
		var tile := Vector2i(floori(res["x"]), floori(res["y"]))
		if map.lookup.get(tile, {}).get("kind", "") != "res":
			resources_intact = false
	check(resources_intact, "all resource destinations intact after city placement and relocation")
	map.biome_button.pressed.emit()
	check(not map.external_environment.green_at(Vector2(1100, 1100)), "winter comparison remains available globally")
	map.biome_button.pressed.emit()
	check(map.external_environment.green_at(Vector2(1100, 1100)), "green comparison restored globally")
	var folder := OS.get_environment("FROST121_PREVIEW_DIR")
	if not folder.is_empty():
		Game.start_march({"kind": "res", "t": "wood", "l": 5, "x": 782, "y": 850})
		var march: Dictionary = Game.marches[0]
		march["start"] = Game.now() - 20
		march["arrive"] = Game.now() - 5
		march["leave"] = Game.now() + 90
		march["back"] = Game.now() + 110
		map.resource_sites.refresh()
		map.rig.set_view(Vector3(783.5, 0, 843.5), 43)
		map.toast.visible = false
		await capture(folder.path_join("Stage12_1_green.png"))
		# Previously overlapping pair: show actual corrected positions, not fake cities.
		var group := Vector3(0, 0, 0)
		var nearest := INF
		for i in cities.size():
			for j in i:
				var a := Vector2(cities[i]["x"], cities[i]["y"])
				var b := Vector2(cities[j]["x"], cities[j]["y"])
				var distance := a.distance_to(b)
				if distance < nearest:
					nearest = distance
					group = Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
		Game.reveal_at(group.x, group.z, 50)
		map.rig.set_view(group, 48)
		map.toast.visible = false
		await capture(folder.path_join("Stage12_1_city_spacing.png"))
		map.rig.set_view(Vector3(target.x + 0.5, 0, target.y + 0.5), 40)
		map._select({"kind": "empty", "x": target.x, "y": target.y,
			"pos": Vector3(target.x + 0.5, 0.15, target.y + 0.5)})
		await capture(folder.path_join("Stage12_1_footprint.png"))
		map._close_panel()
		map._toggle_external_preview()
		map.toast.visible = false
		await capture(folder.path_join("Stage12_1_winter_comparison.png"))
	map.queue_free()
	await get_tree().process_frame
	print("STAGE12.1: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
