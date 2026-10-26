extends Node
## Run: godot --headless --path . res://test_stage10.tscn
## Optional actual rendered preview: FROST_PREVIEW_PATH=/absolute/preview.png
const Sites := preload("res://scripts/resource_sites.gd")
const Visuals := preload("res://scripts/map_visuals.gd")
var failures := 0
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
	else:
		print("PASS: " + message)


func _ready() -> void:
	Game.save_path_override = "user://frost_stage10_test_only.json"
	Game.new_game()
	Game.set_process(false)
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var sites: Node = map.resource_sites
	check(sites != null, "resource presentation component loaded")
	check(sites.rows.size() == Game.MAX_MARCHES, "mission rows respect actual slot limit")
	check(sites.empty_hint.visible, "idle panel does not invent gathering troops")
	var sample := {"kind": "res", "t": "wood", "l": 5, "start": 100.0,
		"arrive": 110.0, "leave": 130.0, "back": 140.0}
	for pair in [[109.0, "outbound"], [110.0, "gather"], [129.0, "gather"], [130.0, "return"], [140.0, "done"]]:
		check(Sites.phase(sample, pair[0])["id"] == pair[1], "phase boundary %s -> %s" % pair)
	check(Sites.timer(3661.0) == "01:01:01", "hours minutes seconds timer")
	check(Sites.timer(-5.0) == "00:00:00", "timer never negative")
	var scout := sample.duplicate()
	scout["kind"] = "scout"
	scout["leave"] = 110.0
	check(Sites.phase(scout, 110)["id"] == "return", "zero-work scout returns immediately")
	check(Sites.phase(sample, 125)["progress"] == 0.75, "gather progress follows real work interval")
	for kind in ["wood", "coal", "iron", "food"]:
		var mesh: Mesh = map._mesh_from("res://assets/res_%s.glb" % kind)
		check(mesh.get_aabb().size.x > 5.0, "larger %s site geometry" % kind)
		var resource_width := mesh.get_aabb().size.x * Visuals.RESOURCE_SCALE
		var city_width: float = map.home_node.mesh.get_aabb().size.x * map.home_node.scale.x
		check(city_width >= resource_width * 2.0, "visible city is at least twice %s site width" % kind)
		var instances_scaled := false
		for child in map.get_children():
			if child is MultiMeshInstance3D and (child.multimesh.mesh == mesh or child.multimesh.mesh.get_meta("source_asset", "") == "res://assets/res_%s.glb" % kind):
				instances_scaled = is_equal_approx(child.multimesh.get_instance_transform(0).basis.get_scale().x, Visuals.RESOURCE_SCALE)
		if DisplayServer.get_name() == "headless":
			print("SKIP: actual %s MultiMesh transform readback requires rendered backend" % kind)
		else:
			check(instances_scaled, "actual %s MultiMesh transforms use smaller resource scale" % kind)
	check(is_equal_approx(map.home_node.scale.x, Visuals.CITY_SCALE), "home city uses enlarged presentation scale")
	check(map.city_targets.size() == map.data["cities"].size() + 1, "all city types use visual target records")
	check(map.city_clearance_material != null, "forest clearance around enlarged cities is configured")
	var under_fog := true
	for city in map.data["cities"]:
		if float(city["h"]) + map.home_node.mesh.get_aabb().end.y * Visuals.CITY_SCALE >= 4.5:
			under_fog = false
	check(under_fog, "enlarged default city tops remain below fog plane")
	var ground_edge: Vector3 = map.home_pos + Vector3(2.6, 0, 0)
	check(map._pick_city(ground_edge, Vector2.ZERO).get("team", "") == "me", "city can be selected at enlarged edge")
	map._on_tap(ground_edge, Vector2.ZERO)
	check(map.selected.get("team", "") == "me", "tap at enlarged city edge opens correct city")
	check(map._pick_city(Vector3(300.5, 0, 300.5), Vector2.ZERO).is_empty(), "larger city hit area respects unexplored land")
	map._close_panel()
	var target: Dictionary = {}
	for r in map.data["resources"]:
		if int(r["x"]) == 782 and int(r["y"]) == 850:
			target = r
			break
	check(not target.is_empty(), "unchanged resource coordinates from stage9")
	Game.reveal_at(target["x"], target["y"], 35)
	var pos := Vector3(target["x"], target["h"], target["y"])
	var picked: Dictionary = sites.pick(pos + Vector3(1.8, 0, 0), Vector2.ZERO)
	check(not picked.is_empty() and picked["t"] == "wood", "touch tolerance includes expanded site")
	check(sites.pick(Vector3(300.5, 0, 300.5), Vector2.ZERO).is_empty(), "unexplored site cannot be picked")
	var tx := int(target["x"])
	var ty := int(target["y"])
	check(Game.start_march({"kind": "res", "t": target["t"], "l": target["l"], "x": tx, "y": ty}),
		"existing gather mission starts without changing game logic")
	var m: Dictionary = Game.marches[0]
	var duration := float(m["leave"]) - float(m["arrive"])
	check(is_equal_approx(duration, 12.0 + 2.0 * float(target["l"])), "existing gathering duration preserved")
	var now := Game.now()
	m["start"] = now - 15
	m["arrive"] = now - 5
	m["leave"] = now + 17
	m["back"] = now + 27
	sites.refresh()
	check(sites.active_markers.size() == 1, "active site marker appears only during gathering")
	check(sites.rows[0]["button"].text.contains("جمع الموارد"), "mission panel shows real gathering state")
	check(not sites.rows[0]["time"].text.is_empty(), "remaining phase timer displayed")
	var same_mission := m.duplicate(true)
	sites.refresh()
	check(m == same_mission, "presentation does not mutate saved mission dictionary")
	Game.save_game()
	Game.marches = []
	check(Game.load_game(), "existing save format reloads successfully")
	m = Game.marches[0]
	sites.refresh()
	check(sites.active_markers.size() == 1, "gather indicator restored from saved mission times")
	var marker_id := (sites.active_markers.values()[0]["icon"] as Node).get_instance_id()
	sites.refresh()
	check((sites.active_markers.values()[0]["icon"] as Node).get_instance_id() == marker_id,
		"active icon reused instead of rebuilt per frame")
	var second := m.duplicate(true)
	second["start"] = now - 16
	Game.marches.append(second)
	sites.refresh()
	check(sites.active_markers.size() == 1, "two squads at one resource use one site marker")
	check(sites.active_markers.values()[0]["label"].text.contains("×2"), "same-site squad count visible")
	Game.marches.pop_back()
	m["leave"] = now - 1
	sites.refresh()
	check(sites.active_markers.is_empty(), "gather marker removed on departure")
	check(sites.rows[0]["button"].text.contains("عائدة"), "return phase distinguished from collection")
	m["arrive"] = now + 10
	m["leave"] = now + 32
	m["back"] = now + 42
	sites.refresh()
	check(sites.active_markers.is_empty(), "outbound squad never shows collecting icon")
	check(sites.rows[0]["button"].text.contains("في الطريق"), "outbound ETA distinguished from collection")
	m["arrive"] = now - 5
	m["leave"] = now + 17
	m["back"] = now + 27
	map.rig.set_view(Vector3(783.5, 0, 843.5), 43.0)
	await get_tree().process_frame
	sites.refresh()
	check(sites.markers.size() <= Sites.POOL_SIZE, "bounded nearby level marker pool")
	check(sites.markers.size() > 0, "nearby explored resources show level badges")
	map.rig.set_view(Vector3(783.5, 0, 843.5), 180.0)
	await get_tree().process_frame
	sites.refresh()
	var visible_levels := 0
	for marker in sites.markers:
		if marker["label"].visible:
			visible_levels += 1
	check(visible_levels == 0, "zoomed-out map hides level clutter")
	Game.marches = []
	sites.refresh()
	check(sites.active_markers.is_empty() and sites.empty_hint.visible, "completed missions leave no stale site or panel row")
	Game.marches = [m]
	# Rendered evidence is a separate non-persistent test arrangement.
	map.rig.set_view(Vector3(783.5, 0, 843.5), 43.0)
	map._close_panel()
	map.toast_time = 0
	map.toast.visible = false
	var preview_path := OS.get_environment("FROST_PREVIEW_PATH")
	if not preview_path.is_empty():
		m["leave"] = Game.now() + 16
		m["back"] = Game.now() + 26
		sites.refresh()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(preview_path)
		check(error == OK, "actual Godot viewport screenshot saved")
	var old_home: Vector3 = map.home_pos
	var new_x := Game.home.x
	var new_y := Game.home.y + 12
	Game.reveal_at(new_x, new_y, 10)
	map._move_home({"kind": "empty", "x": new_x, "y": new_y,
		"pos": Vector3(new_x + 0.5, old_home.y, new_y + 0.5)})
	check(map.city_clearance_material.get_shader_parameter("home_xz") == Vector2(map.home_pos.x, map.home_pos.z),
		"forest clearing follows relocated home")
	check(is_equal_approx(map.home_label.position.y, map.home_pos.y + Visuals.CITY_LABEL_HEIGHT),
		"city label retains correct height after relocation")
	check(map._pick_city(map.home_pos + Vector3(2.6, 0, 0), Vector2.ZERO).get("team", "") == "me",
		"enlarged city target follows relocation")
	print("STAGE10: %d checks, %d failures" % [checks, failures])
	map.queue_free()
	Game.marches = []
	# Stop test audio before tearing down the engine; do not alter production
	# sound behavior to address an unrelated pre-existing shutdown warning.
	for child in Sound.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
