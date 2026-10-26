extends Node
const Exterior := preload("res://scripts/external_environment.gd")
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
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "actual viewport saved: " + path.get_file())


func _ready() -> void:
	Game.save_path_override = "user://frost_stage12_%s_test_only.json" % DisplayServer.get_name()
	Game.new_game()
	Game.set_process(false)
	Game.set_city_skin("forge")
	var balances: Dictionary = Game.res.duplicate(true)
	var gems := Game.gems
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var exterior: Node = map.external_environment
	check(exterior.enabled, "green sample enabled by default")
	check(exterior.green_at(Vector2(790, 842)), "fixed world sample center is green")
	check(exterior.green_at(Vector2(300, 300)), "Stage12.1 green now covers the whole exterior")
	check(exterior.terrain_surfaces == 144, "terrain chunk presentation overrides configured")
	check(exterior.lake_surfaces > 0, "lake presentation overrides configured")
	check(exterior.materials.size() <= 12, "shared materials reused across terrain chunks")
	check(exterior.resource_meshes.size() == 4, "all four resource types adapted")
	for kind in ["wood", "coal", "iron", "food"]:
		var path := "res://assets/res_%s.glb" % kind
		var source: Mesh = map._mesh_from(path)
		var painted: Mesh = exterior.resource_meshes[path]
		check(source != painted, kind + " imported mesh is isolated from presentation copy")
		var original_clean := true
		for i in source.get_surface_count():
			if source.surface_get_material(i) is ShaderMaterial:
				original_clean = false
		check(original_clean, kind + " source materials unchanged")
	check(Game.city_skin == "forge", "selected city skin not modified by biome")
	check(map.home_node.mesh == map._mesh_from("res://assets/city_skins/forge_me.glb"), "city skin asset untouched")
	map.rig.set_view(Vector3(783.5, 0, 843.5), 43.0)
	check(not map.snow.visible and not map.snow.emitting, "no snow particles over green sample")
	var camera_transform: Transform3D = map.rig.cam.global_transform
	map.biome_button.pressed.emit()
	check(not exterior.enabled, "actual comparison button returns winter view")
	check(map.snow.visible and map.snow.emitting, "winter particles restored in comparison mode")
	var all_off := true
	for material in exterior.materials:
		if material.get_shader_parameter("green_enabled"):
			all_off = false
	check(all_off, "comparison updates all local presentation materials")
	map.biome_button.pressed.emit()
	check(exterior.enabled and not map.snow.visible, "green comparison restored")
	check(map.rig.cam.global_transform == camera_transform, "comparison keeps exact camera transform")
	check(Game.res == balances and Game.gems == gems, "environment comparison changes no economy")
	map._on_tap(Vector3(300.5, 0, 300.5), Vector2.ZERO)
	check(map.selected.get("kind", "") == "unknown", "fog selection remains protected")
	map._close_panel()
	var initial_center: Vector2 = exterior.ground_material.get_shader_parameter("preview_center")
	var relocation := Vector2i(-1, -1)
	for dx in range(-25, 26):
		for dy in range(-25, 26):
			var candidate := Game.home + Vector2i(dx, dy)
			if Vector2(dx, dy).length() > 14 and map._home_placement_reason(candidate).is_empty():
				relocation = candidate
				break
		if relocation.x >= 0:
			break
	check(relocation.x >= 0, "valid relocation found under Stage12.1 footprint rules")
	if relocation.x >= 0:
		check(map._move_home({"kind": "empty", "x": relocation.x, "y": relocation.y,
			"pos": Vector3(relocation.x + 0.5, map.home_pos.y, relocation.y + 0.5)}),
			"city actually relocated before environment isolation assertion")
	check(exterior.ground_material.get_shader_parameter("preview_center") == initial_center,
		"biome location does not follow individual player's relocated city")
	map._move_home({"kind": "empty", "x": 790, "y": 842, "pos": Vector3(790.5, map.home_pos.y, 842.5)})
	map.toast_time = 0
	map.toast.visible = false
	# Local mission arrangement for rendered gathering evidence, never shipped
	# as the player's save and never a claim of multiplayer synchronization.
	Game.start_march({"kind": "res", "t": "wood", "l": 5, "x": 782, "y": 850})
	var march: Dictionary = Game.marches[0]
	march["start"] = Game.now() - 20
	march["arrive"] = Game.now() - 5
	march["leave"] = Game.now() + 90
	march["back"] = Game.now() + 110
	map.resource_sites.refresh()
	check(map.resource_sites.active_markers.size() == 1, "gather marker works in green biome")
	var folder := OS.get_environment("FROST12_PREVIEW_DIR")
	if not folder.is_empty():
		map.rig.set_view(Vector3(783.5, 0, 843.5), 43)
		map.toast.visible = false
		await capture(folder.path_join("Stage12_green.png"))
		map._toggle_external_preview()
		map.toast.visible = false
		await capture(folder.path_join("Stage12_winter_comparison.png"))
		map._toggle_external_preview()
		map.toast.visible = false
		Game.reveal_at(650, 805, 95)
		map.rig.set_view(Vector3(650, 0, 805), 110)
		await capture(folder.path_join("Stage12_lake.png"))
		map._toggle_night()
		map.rig.set_view(Vector3(783.5, 0, 843.5), 43)
		await capture(folder.path_join("Stage12_green_night.png"))
	Game.marches = []
	map.queue_free()
	await get_tree().process_frame
	var city: Node3D = load("res://city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	check(city.snow.visible and city.snow.emitting, "interior remains snowy")
	check(Game.city_skin == "forge", "exterior prototype does not reset equipped skin")
	if not folder.is_empty():
		# Clear only welcome overlays in the test capture; do not edit city code.
		for overlay in city.modal_layer.get_children():
			overlay.queue_free()
		await capture(folder.path_join("Stage12_interior_unchanged.png"))
	city.queue_free()
	await get_tree().process_frame
	print("STAGE12: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
