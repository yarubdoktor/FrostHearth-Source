extends Node
const Catalog := preload("res://scripts/city_skins.gd")
const Visuals := preload("res://scripts/map_visuals.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(Game._save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _ready() -> void:
	Game.save_path_override = "user://frost_stage11_%s_test_only.json" % DisplayServer.get_name()
	Game.new_game()
	Game.set_process(false)
	check(Game.city_skin == Catalog.DEFAULT, "new game selects default skin")
	check(Catalog.valid_id("../../anything") == Catalog.DEFAULT, "invalid skin identifiers fall back safely")
	check(Catalog.mesh_path("missing", "unknown") == Catalog.mesh_path(Catalog.DEFAULT), "asset path is catalog controlled")
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var picker: PanelContainer = map.skin_picker
	check(not picker.visible, "picker starts hidden")
	check(picker.viewport.own_world_3d, "preview world is isolated from playable map")
	var reference_width := 0.0
	for id in Catalog.ORDER:
		for team in ["me", "ally", "enemy", "neutral"]:
			var mesh: Mesh = map._mesh_from(Catalog.mesh_path(id, team))
			var bounds := mesh.get_aabb()
			var width := bounds.size.x * Visuals.CITY_SCALE
			if reference_width == 0:
				reference_width = width
			check(is_equal_approx(width, reference_width) and width >= 6.38, "%s/%s retains city footprint" % [id, team])
			check(bounds.end.y * Visuals.CITY_SCALE + .43 < 4.5, "%s/%s fits below fog plane" % [id, team])
	var transform: Transform3D = map.home_node.transform
	var node_id: int = map.home_node.get_instance_id()
	var old_mesh_id: int = map.home_node.mesh.get_instance_id()
	var save_text := FileAccess.get_file_as_string(Game._save_path())
	var balances: Dictionary = Game.res.duplicate(true)
	var gems := Game.gems
	var troops: Dictionary = Game.troops.duplicate(true)
	var plots: Dictionary = Game.plots.duplicate(true)
	var location := Game.home
	var child_count := map.get_child_count()
	picker.show_picker()
	check(picker.visible, "picker opens")
	picker.options["forge"].pressed.emit()
	check(picker.preview_id == "forge", "actual preview button selects forge skin")
	check(Game.city_skin == Catalog.DEFAULT and map.home_node.mesh.get_instance_id() == old_mesh_id,
		"browsing does not equip or change playable city")
	check(FileAccess.get_file_as_string(Game._save_path()) == save_text, "preview does not write save")
	picker.close()
	check(not picker.visible and Game.city_skin == Catalog.DEFAULT, "cancel leaves equipped skin unchanged")
	picker.show_picker()
	picker.options["forge"].pressed.emit()
	picker.equip_button.pressed.emit()
	check(Game.city_skin == "forge", "actual equip button changes cosmetic state")
	check(map.home_node.mesh.get_instance_id() != old_mesh_id, "equip signal updates playable city mesh")
	check(map.home_node.get_instance_id() == node_id and map.home_node.transform == transform,
		"equip preserves node identity position rotation and scale")
	check(Game.res == balances and Game.gems == gems and Game.troops == troops and Game.plots == plots,
		"equip grants no bonuses and costs no resources or troops")
	check(Game.home == location, "equip does not change city coordinates")
	check(picker.equip_button.disabled, "equipped option cannot be accidentally re-equipped")
	check(Game.load_game() and Game.city_skin == "forge", "equipped skin survives save reload")
	check(not Game.set_city_skin("not_in_catalog") and Game.city_skin == "forge", "invalid equip rejected without mutation")
	for i in 15:
		Game.set_city_skin(Catalog.ORDER[i % Catalog.ORDER.size()])
	check(map.get_child_count() == child_count, "repeated switching does not accumulate map nodes")
	check(map._pick_city(map.home_pos + Vector3(2.6, 0, 0), Vector2.ZERO).get("team", "") == "me",
		"city edge remains selectable after switching")
	# Render real screenshots and separate real viewport images for the gallery.
	var preview_dir := OS.get_environment("FROST11_PREVIEW_DIR")
	if not preview_dir.is_empty():
		map.rig.set_view(Vector3(783.5, 0, 843.5), 43.0)
		map.toast_time = 0
		map.toast.visible = false
		for id in Catalog.ORDER:
			Game.set_city_skin(id)
			picker.show_picker()
			for frame in 8:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(preview_dir.path_join("Stage11_%s.png" % id))
			check(error == OK, "real map screenshot saved for " + id)
			error = picker.viewport.get_texture().get_image().save_png(preview_dir.path_join("Stage11_model_%s.png" % id))
			check(error == OK, "real isolated model viewport saved for " + id)
		picker.close()
		map._toggle_night()
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(preview_dir.path_join("Stage11_night.png")) == OK,
			"actual night view screenshot saved")
	picker.close()
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	save.erase("city_skin")
	write_save(save)
	check(Game.load_game() and Game.city_skin == Catalog.DEFAULT, "older saves without skin field load default")
	save["city_skin"] = "unknown_future_skin"
	write_save(save)
	check(Game.load_game() and Game.city_skin == Catalog.DEFAULT, "unknown saved skin safely falls back")
	Game.set_city_skin("aurora")
	map.queue_free()
	await get_tree().process_frame
	check(Game.load_game() and Game.city_skin == "aurora", "saved aurora survives map exit")
	var second_map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(second_map)
	await get_tree().process_frame
	check(second_map.home_node.mesh == second_map._mesh_from(Catalog.mesh_path("aurora")),
		"re-entered map restores equipped mesh")
	second_map.queue_free()
	await get_tree().process_frame
	print("STAGE11: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
