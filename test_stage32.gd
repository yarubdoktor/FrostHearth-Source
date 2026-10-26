extends Node
## Stage 32 / P1: الهوية البصرية — إضاءة ACES، شيدر الثلج، الثلج المتساقط، vignette، قوابع الثلج وظلال التلامس في المجسمات.
const Defs := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame


func fresh() -> void:
	Game.save_path_override = "user://stage32_visual.json"
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.offline_report = {}
	Game.raid_unseen = false
	Game.migration_note = {}
	Game.stats["built"] = 2


func find_node(node: Node, target: String) -> Node:
	if str(node.name) == target:
		return node
	for child in node.get_children():
		var found := find_node(child, target)
		if found != null:
			return found
	return null


func test_shader_and_env() -> void:
	var shader: Shader = load("res://shaders/ground_snow.gdshader")
	check(shader != null, "ground snow shader resource loads")
	fresh()
	var packed: PackedScene = load("res://city.tscn")
	var city: Node = packed.instantiate()
	get_tree().get_root().add_child.call_deferred(city)
	await city.ready
	await frames()
	check(city.env.tonemap_mode == Environment.TONE_MAPPER_ACES, "city uses ACES tonemapping")
	check(city.env.fog_enabled and city.env.fog_density > 0.004, "permanent depth fog is on outside storms")
	check(city.env.glow_blend_mode == Environment.GLOW_BLEND_MODE_SOFTLIGHT, "glow uses softlight blend")
	check(absf(city.sun.light_energy - 1.0) < 0.01, "sun energy targets the cinematic value")
	check(city.snow.mesh is QuadMesh, "snowfall uses soft quad flakes")
	var qm: QuadMesh = city.snow.mesh
	var mat: StandardMaterial3D = qm.material
	check(mat != null and mat.albedo_texture != null, "snowflake texture is generated")
	check(mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "flakes billboard toward the camera")
	# شيدر الأرض: السطح الأول لـ ground صار ShaderMaterial
	var applied := false
	for mi in city.find_children("*", "MeshInstance3D", true, false):
		if str((mi as Node).name) != "ground":
			continue
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			if (mi as MeshInstance3D).get_surface_override_material(i) is ShaderMaterial:
				applied = true
	check(applied, "ground snow shader overrides the terrain surface")
	# vignette دائم في غطاء الصقيع
	var fo: ShaderMaterial = city.frost_overlay.material
	check(fo != null and fo.get_shader_parameter("amount") != null, "frost overlay keeps its storm parameter")
	var frost_code: String = city.frost_overlay.material.shader.code
	check(frost_code.contains("vig"), "frost overlay includes the permanent vignette")
	# بانر العاصفة تحت اللوحات لا فوقها
	check(city.storm_label.offset_top >= 300.0, "storm banner sits below the top HUD panels")
	check(city.storm_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "storm banner wraps long warnings")
	city.queue_free()
	await frames()


func test_map_env() -> void:
	fresh()
	var packed: PackedScene = load("res://world_map.tscn")
	var map: Node = packed.instantiate()
	get_tree().get_root().add_child.call_deferred(map)
	await map.ready
	await frames()
	check(map.env.tonemap_mode == Environment.TONE_MAPPER_ACES, "world map matches the ACES grade")
	check(map.env.glow_intensity > 0.3, "map glow stays subtle but present")
	map.queue_free()
	await frames()


func test_assets_upgraded() -> void:
	# المجسمات المجدّدة تحمل مادة الظل الجديدة وظلال التلامس
	var plot_scene: PackedScene = load("res://assets/city/plot.glb")
	var plot: Node3D = plot_scene.instantiate()
	var has_shadow_mat := false
	for mi in plot.find_children("*", "MeshInstance3D"):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m = mesh.surface_get_material(i)
			if m != null and m.resource_name == "Shadow":
				has_shadow_mat = true
	check(has_shadow_mat, "plot GLB carries the baked contact shadow disc")
	plot.free()
	# أسطح Snow موجودة كي يظهر ثلج الأسقف
	var shelter_scene: PackedScene = load("res://assets/city/shelter_t1.glb")
	var shelter: Node3D = shelter_scene.instantiate()
	var snow_parts := 0
	for mi in shelter.find_children("*", "MeshInstance3D"):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m = mesh.surface_get_material(i)
			if m != null and m.resource_name == "Snow":
				snow_parts += 1
	check(snow_parts > 0, "shelter GLB has roof snow surfaces")
	shelter.free()


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await test_shader_and_env()
	await test_map_env()
	test_assets_upgraded()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
