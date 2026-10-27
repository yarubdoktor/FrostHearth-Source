extends Node3D
## Shared 3D arena prototype. It reuses the same layout contract for both modes.
## No network, combat resolution, or reward mutation is performed here.
const Arena := preload("res://scripts/competition/competition_arena.gd")
const Simulation := preload("res://scripts/competition/competition_simulation.gd")
const Combat := preload("res://scripts/competition/competition_combat.gd")
const BG := Color("#07111f")
const GOLD := Color("#f3c86a")
const BLUE := Color("#5aa9d6")
const MAP_SCALE := 0.035
var mode := Arena.MODE_QUALIFIER
var layout: Dictionary = {}
var arena_root: Node3D
var camera: Camera3D
var ui: Control
var info_label: Label
var last_touch := Vector2.ZERO
var dragging := false
var yaw := 0.0
var pitch := -0.95
var distance := 32.0
var touch_points := {}
var last_pinch_distance := 0.0
var simulation_state: Dictionary = {}
var simulation_units: Dictionary = {}
var simulation_status: Label
var simulation_ui_timer := 0.0
var target_fortress: Node3D
var battle_result: Dictionary = {}
var battle_started := false
var battle_elapsed := 0.0
var battle_units: Array[Node3D] = []
var battle_arrows: Array[Dictionary] = []
var fire_nodes: Array[Node3D] = []
var battle_clock := 0.0

func _ready() -> void:
	_build_environment()
	_build_ui()
	_set_mode(Arena.MODE_QUALIFIER)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#102c48")
	sky_mat.sky_horizon_color = Color("#8ba7b7")
	sky_mat.ground_bottom_color = Color("#101b29")
	sky_mat.ground_horizon_color = Color("#607887")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9eb7cc")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	arena_root = Node3D.new()
	arena_root.name = "ArenaGenerated"
	add_child(arena_root)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 48
	add_child(camera)
	_update_camera()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 10
	header.offset_right = -10
	header.offset_top = 10
	header.offset_bottom = 88
	header.add_theme_stylebox_override("panel", _panel_style(Color("#0b1929"), GOLD))
	ui.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)
	var back := _button("رجوع", false)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://competition_hub.tscn"))
	row.add_child(back)
	var q := _button("التأهل · 4", true)
	q.pressed.connect(func(): _set_mode(Arena.MODE_QUALIFIER))
	row.add_child(q)
	var k := _button("مبنى الملك · 100", false)
	k.pressed.connect(func(): _set_mode(Arena.MODE_KING))
	row.add_child(k)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color("#f4f6f8"))
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info_label)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 10
	footer.offset_right = -10
	footer.offset_top = -150
	footer.offset_bottom = -10
	footer.add_theme_stylebox_override("panel", _panel_style(Color("#0b1929"), Color("#344a60")))
	ui.add_child(footer)
	var footer_content := VBoxContainer.new()
	footer_content.add_theme_constant_override("separation", 5)
	footer.add_child(footer_content)
	var note := Label.new()
	note.text = "معاينة محلية • اسحب لتدوير • إصبعان للتكبير • لا يوجد قتال أو خادم"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("#b8c8d8"))
	footer_content.add_child(note)
	simulation_status = Label.new()
	simulation_status.text = "المسيرات: جاهزة للمعاينة"
	simulation_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	simulation_status.add_theme_font_size_override("font_size", 12)
	simulation_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	simulation_status.add_theme_color_override("font_color", GOLD)
	footer_content.add_child(simulation_status)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	footer_content.add_child(action_row)
	var march_button := _button("إرسال فرقتي", true)
	march_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	march_button.pressed.connect(_send_preview_march)
	action_row.add_child(march_button)
	var all_button := _button("إرسال الفرق", true)
	all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_button.pressed.connect(_send_all_preview_marches)
	action_row.add_child(all_button)
	var reset_button := _button("إعادة التجربة", false)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_reset_preview_simulation)
	action_row.add_child(reset_button)

func _set_mode(next_mode: String) -> void:
	var next_layout: Dictionary = Arena.create_layout(next_mode)
	if not Arena.validate_layout(next_layout):
		return
	mode = next_mode
	layout = next_layout
	simulation_units.clear()
	simulation_state = {}
	target_fortress = null
	battle_result.clear()
	battle_started = false
	battle_elapsed = 0.0
	battle_units.clear()
	battle_arrows.clear()
	fire_nodes.clear()
	for child in arena_root.get_children():
		child.queue_free()
	_build_terrain()
	if mode == Arena.MODE_QUALIFIER:
		_build_qualifier()
	else:
		_build_king_map()
	_reset_preview_simulation()
	info_label.text = "%s | %d لاعب كحد تصميمي" % [str(layout.get("title", "")), int(layout.get("max_players", 0))]
	distance = 32.0 if mode == Arena.MODE_QUALIFIER else 72.0
	yaw = 0.0
	pitch = -0.95
	_update_camera()

func _reset_preview_simulation() -> void:
	var records: Array = [
		{"player_id": "preview_1", "units": 12, "speed": 42.0},
		{"player_id": "preview_2", "units": 10, "speed": 38.0},
		{"player_id": "preview_3", "units": 10, "speed": 38.0},
		{"player_id": "preview_4", "units": 10, "speed": 38.0}
	]
	simulation_state = Simulation.create(layout, records)
	for key in simulation_units.keys():
		var old_marker: Node3D = simulation_units[key]
		if is_instance_valid(old_marker):
			old_marker.queue_free()
	simulation_units.clear()
	if simulation_state.is_empty():
		if simulation_status != null:
			simulation_status.text = "تعذر بدء المعاينة المحلية"
		return
	for record in records:
		var pid := str(record.get("player_id", ""))
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.24
		mesh.bottom_radius = 0.34
		mesh.height = 0.75
		mesh.radial_segments = 8
		marker.mesh = mesh
		marker.material_override = _material(GOLD if pid == "preview_1" else BLUE, 0.18, 0.18)
		marker.name = "PreviewUnit_" + pid
		arena_root.add_child(marker)
		simulation_units[pid] = marker
	_update_simulation_visuals()
	_create_preview_squad()

func _create_preview_squad() -> void:
	for soldier in battle_units:
		if is_instance_valid(soldier):
			soldier.queue_free()
	battle_units.clear()
	var base := simulation_units.get("preview_1") as Node3D
	if base == null:
		return
	for i in range(7):
		var soldier := MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.14
		body.height = 0.52
		soldier.mesh = body
		soldier.material_override = _material(Color("#b8c6d4") if i % 2 == 0 else Color("#425d78"), 0.12, 0.2)
		soldier.name = "PreviewSoldier_%02d" % i
		arena_root.add_child(soldier)
		battle_units.append(soldier)
	var hero := MeshInstance3D.new()
	var hero_mesh := CapsuleMesh.new()
	hero_mesh.radius = 0.22
	hero_mesh.height = 0.9
	hero.mesh = hero_mesh
	hero.material_override = _material(GOLD, 0.25, 0.35)
	hero.name = "PreviewHero"
	arena_root.add_child(hero)
	battle_units.append(hero)

func _send_preview_march() -> void:
	if simulation_state.is_empty() or layout.get("objectives", []).is_empty():
		return
	var objective_id := str(layout.get("objectives", [])[0].get("id", ""))
	var next_state: Dictionary = Simulation.issue_march(simulation_state, "preview_1", objective_id)
	if not next_state.is_empty():
		simulation_state = next_state
	_update_simulation_visuals()

func _send_all_preview_marches() -> void:
	if simulation_state.is_empty() or layout.get("objectives", []).is_empty():
		return
	var objective_id := str(layout.get("objectives", [])[0].get("id", ""))
	for index in range(1, 5):
		var next_state: Dictionary = Simulation.issue_march(simulation_state, "preview_%d" % index, objective_id)
		if not next_state.is_empty():
			simulation_state = next_state
	_update_simulation_visuals()

func _process(delta: float) -> void:
	if simulation_state.is_empty():
		return
	simulation_state = Simulation.advance(simulation_state, delta)
	if simulation_state.is_empty():
		return
	_update_simulation_visuals()
	battle_clock += delta
	_update_battle_visuals(delta)
	var lead_player: Dictionary = Simulation.player_snapshot(simulation_state, "preview_1")
	if not battle_started and not lead_player.is_empty() and not bool(lead_player.get("marching", false)) and str(lead_player.get("target_objective", "")).length() > 0:
		var target: Vector2 = layout.get("objectives", [])[0].get("position", Vector2.ZERO)
		var lead_pos: Vector2 = lead_player.get("position", Vector2.ZERO)
		if lead_pos.distance_to(target) <= 18.0:
			_resolve_preview_battle()
	simulation_ui_timer += delta
	if simulation_ui_timer >= 0.2:
		simulation_ui_timer = 0.0
		var objective_id := str(layout.get("objectives", [])[0].get("id", ""))
		var objective: Dictionary = Simulation.objective_snapshot(simulation_state, objective_id)
		var owner_id := str(objective.get("owner_id", ""))
		var owner_text := "بلا مالك" if owner_id.is_empty() else "المالك: " + owner_id
		var progress := float(objective.get("progress", 0.0))
		var player: Dictionary = Simulation.player_snapshot(simulation_state, "preview_1")
		var march_text := "في الطريق" if bool(player.get("marching", false)) else "وصل/متوقف"
		var present_units := int(objective.get("present_units", 0))
		var contesting_players := int(objective.get("contesting_players", 0))
		var battle_text := ""
		if not battle_result.is_empty():
			battle_text = " • النتيجة: " + ("انتصار" if str(battle_result.get("outcome", "")) == "victory" else "هزيمة")
		simulation_status.text = "%s • السيطرة %.0f%% • قوات الهدف: %d • المتنافسون: %d • فرقتك: %s%s" % [owner_text, progress, present_units, contesting_players, march_text, battle_text]

func _resolve_preview_battle() -> void:
	if battle_started:
		return
	battle_started = true
	battle_elapsed = 0.0
	var attacker_units := int(Simulation.player_snapshot(simulation_state, "preview_1").get("units", 12))
	var defense_units := 12 if mode == Arena.MODE_QUALIFIER else 24
	var defense_fortification := 4.0 if mode == Arena.MODE_QUALIFIER else 16.0
	battle_result = Combat.resolve(
		{"units": attacker_units, "attack": 1.2, "hero_power": 8.0},
		{"units": defense_units, "attack": 1.0, "fortification": defense_fortification}
	)
	if battle_result.is_empty():
		simulation_status.text = "تعذر حساب نتيجة المعركة"
		return
	if str(battle_result.get("outcome", "")) == "victory":
		_start_target_fire()
	else:
		_clear_target_fire()
	_spawn_arrow_volley()

func _spawn_arrow_volley() -> void:
	var target := _to_world(layout.get("objectives", [])[0].get("position", Vector2.ZERO)) + Vector3(0.0, 1.0, 0.0)
	var origin := _to_world(Vector2(500, 500)) + Vector3(-4.5, 1.1, 0.0)
	for i in range(9):
		var arrow := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.025
		mesh.height = 0.72
		arrow.mesh = mesh
		arrow.material_override = _material(Color("#e9d5a1"), 0.18, 0.55)
		arrow.position = origin + Vector3(float(i % 3) * 0.32, float(i / 3) * 0.22, float(i % 2) * 0.28)
		var direction := (target - arrow.position).normalized()
		arrow.look_at(arrow.position + direction, Vector3.UP)
		arena_root.add_child(arrow)
		battle_arrows.append({"node": arrow, "target": target, "speed": 13.0 + float(i % 3), "life": 2.0})

func _update_battle_visuals(delta: float) -> void:
	if not battle_started:
		var base := simulation_units.get("preview_1") as Node3D
		if base != null:
			for i in range(battle_units.size()):
				var unit := battle_units[i]
				if not is_instance_valid(unit):
					continue
				var col := float(i % 4) - 1.5
				var row := float(i / 4)
				unit.position = base.position + Vector3(col * 0.42, 0.0, 0.6 + row * 0.48 + sin(battle_clock * 5.0 + float(i)) * 0.06)
				unit.rotation.y = sin(battle_clock * 2.5 + float(i)) * 0.08
	else:
		for i in range(battle_units.size()):
			var unit := battle_units[i]
			if not is_instance_valid(unit):
				continue
			var angle := TAU * float(i) / float(maxi(1, battle_units.size()))
			var spread := 3.0 + minf(battle_elapsed * 0.35, 2.5)
			var center := _to_world(layout.get("objectives", [])[0].get("position", Vector2.ZERO))
			unit.position = center + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread) + Vector3(0.0, absf(sin(battle_clock * 9.0 + float(i))) * 0.08, 0.0)
			unit.rotation.y = -angle + sin(battle_clock * 8.0 + float(i)) * 0.35
	for i in range(battle_arrows.size() - 1, -1, -1):
		var arrow_data: Dictionary = battle_arrows[i]
		var arrow := arrow_data.get("node") as Node3D
		if not is_instance_valid(arrow):
			battle_arrows.remove_at(i)
			continue
		var target: Vector3 = arrow_data.get("target", Vector3.ZERO)
		arrow.position = arrow.position.move_toward(target, float(arrow_data.get("speed", 13.0)) * delta)
		arrow_data["life"] = float(arrow_data.get("life", 0.0)) - delta
		if arrow.position.distance_to(target) < 0.3 or float(arrow_data["life"]) <= 0.0:
			arrow.queue_free()
			battle_arrows.remove_at(i)
		else:
			battle_arrows[i] = arrow_data
	for i in range(fire_nodes.size()):
		var flame := fire_nodes[i]
		if is_instance_valid(flame):
			var pulse := 0.85 + absf(sin(battle_clock * 7.0 + float(i))) * 0.45
			flame.scale = Vector3(pulse, pulse, pulse)

func _start_target_fire() -> void:
	if not fire_nodes.is_empty():
		return
	if target_fortress != null and is_instance_valid(target_fortress):
		target_fortress.modulate = Color("#ffb36a")
		for i in range(5):
			var flame := MeshInstance3D.new()
			var cone := ConeMesh.new()
			cone.bottom_radius = 0.24 if i % 2 == 0 else 0.16
			cone.height = 0.9 + float(i % 3) * 0.22
			flame.mesh = cone
			flame.material_override = _material(Color("#ff6a1a") if i % 2 == 0 else Color("#ffca55"), 0.0, 0.9)
			var offset := Vector3(cos(TAU * float(i) / 5.0) * 0.65, 1.1 + float(i % 2) * 0.35, sin(TAU * float(i) / 5.0) * 0.65)
			flame.position = target_fortress.position + offset
			arena_root.add_child(flame)
			fire_nodes.append(flame)
		var fire_light := OmniLight3D.new()
		fire_light.position = target_fortress.position + Vector3(0.0, 2.2, 0.0)
		fire_light.light_color = Color("#ff6a1a")
		fire_light.light_energy = 1.8
		fire_light.omni_range = 8.0
		arena_root.add_child(fire_light)
		fire_nodes.append(fire_light)

func _clear_target_fire() -> void:
	for node in fire_nodes:
		if is_instance_valid(node):
			node.queue_free()
	fire_nodes.clear()
	if target_fortress != null and is_instance_valid(target_fortress):
		target_fortress.modulate = Color.WHITE

func _update_simulation_visuals() -> void:
	for pid in simulation_units.keys():
		var marker: Node3D = simulation_units[pid]
		if not is_instance_valid(marker):
			continue
		var snapshot: Dictionary = Simulation.player_snapshot(simulation_state, str(pid))
		if snapshot.is_empty():
			continue
		var map_position: Vector2 = snapshot.get("position", Vector2.ZERO)
		marker.position = _to_world(map_position) + Vector3(0.0, 0.42, 0.0)

func _build_terrain() -> void:
	var width := float(layout.get("width", 1000)) * MAP_SCALE
	var depth := float(layout.get("height", 1000)) * MAP_SCALE
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, depth)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	ground.mesh = plane
	ground.material_override = _material(Color("#294653"), 0.0, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena_root.add_child(ground)
	var border := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width + 0.5, 0.5, depth + 0.5)
	border.mesh = box
	border.position.y = -0.35
	border.material_override = _material(Color("#182b39"), 0.2, 0.0)
	arena_root.add_child(border)
	var grid_count := 10 if mode == Arena.MODE_QUALIFIER else 5
	for i in range(1, grid_count):
		var f := float(i) / float(grid_count)
		_add_line(Vector3(-width * 0.5 + width * f, 0.035, -depth * 0.5), Vector3(-width * 0.5 + width * f, 0.035, depth * 0.5), Color("#67818a", 0.35), 0.025)
		_add_line(Vector3(-width * 0.5, 0.035, -depth * 0.5 + depth * f), Vector3(width * 0.5, 0.035, -depth * 0.5 + depth * f), Color("#67818a", 0.35), 0.025)
	_add_perimeter(width, depth)

func _build_qualifier() -> void:
	var city_models: Array[String] = [
		"res://assets/city_me.glb",
		"res://assets/city_enemy.glb",
		"res://assets/city_ally.glb",
		"res://assets/city_neutral.glb"
	]
	for i in range(layout.spawns.size()):
		var p: Vector2 = layout.spawns[i]
		var pos := _to_world(p)
		_add_spawn(pos, i + 1, i == 0)
		_add_glb_model(city_models[i % city_models.size()], pos, 0.42)
	_add_objective(_to_world(layout.objectives[0].position), 2.0, GOLD, "مركز السيطرة")
	target_fortress = _add_glb_model("res://assets/stronghold.glb", _to_world(layout.objectives[0].position), 0.9)
	# Low ruins and rocky cover are deliberately sparse so spawn points stay readable.
	for p in [Vector2(500, 250), Vector2(740, 500), Vector2(500, 750), Vector2(260, 500)]:
		_add_cover(_to_world(p), 0.55)

func _build_king_map() -> void:
	for sector in layout.get("sectors", []):
		var center: Vector2 = sector.get("center", Vector2.ZERO)
		var pos := _to_world(center)
		var is_king := str(sector.get("kind", "")) == "king_core"
		_add_sector(pos, is_king)
		if not is_king:
			_add_cover(pos + Vector3(0.2, 0.0, -0.18), 0.28)
	_add_objective(_to_world(layout.objectives[0].position), 3.2, GOLD, "مبنى الملك")
	target_fortress = _add_glb_model("res://assets/fortress.glb", _to_world(layout.objectives[0].position), 1.8)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var p := Vector3(cos(angle) * 27.0, 0.0, sin(angle) * 27.0)
		_add_cover(p, 0.65)

func _add_glb_model(path: String, pos: Vector3, scale_value: float) -> Node3D:
	# GLB assets are already part of the project; keep a procedural fallback if one fails to load.
	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		push_warning("Competition arena model unavailable: " + path)
		return null
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		push_warning("Competition arena model root is not Node3D: " + path)
		return null
	var model: Node3D = instance
	model.position = pos
	model.scale = Vector3.ONE * scale_value
	arena_root.add_child(model)
	return model

func _add_sector(pos: Vector3, king: bool) -> void:
	var tile := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(16.6, 0.16, 16.6)
	tile.mesh = mesh
	tile.position = pos + Vector3(0, 0.08, 0)
	tile.material_override = _material(Color("#4d3c24") if king else Color("#31515a"), 0.0, 0.0)
	arena_root.add_child(tile)
	var marker := MeshInstance3D.new()
	var outline := BoxMesh.new()
	outline.size = Vector3(16.7, 0.06, 16.7)
	marker.mesh = outline
	marker.position = pos + Vector3(0, 0.19, 0)
	marker.material_override = _material(GOLD if king else Color("#6b8a91"), 0.1, 0.2 if king else 0.0)
	arena_root.add_child(marker)

func _add_spawn(pos: Vector3, number: int, highlighted: bool) -> void:
	_add_ring(pos + Vector3(0, 0.12, 0), 2.1, GOLD if highlighted else BLUE)
	var keep := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 1.0
	mesh.height = 1.3
	mesh.radial_segments = 8
	keep.mesh = mesh
	keep.position = pos + Vector3(0, 0.75, 0)
	keep.material_override = _material(Color("#d2b071") if highlighted else Color("#7194a7"), 0.15, 0.0)
	arena_root.add_child(keep)
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.65
	tm.height = 1.1
	tm.radial_segments = 6
	tower.mesh = tm
	tower.position = pos + Vector3(0, 1.95, 0)
	tower.material_override = _material(GOLD if highlighted else Color("#7c9cac"), 0.2, 0.05)
	arena_root.add_child(tower)

func _add_objective(pos: Vector3, radius: float, color: Color, label: String) -> void:
	_add_ring(pos + Vector3(0, 0.15, 0), radius, color)
	var plinth := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = radius * 0.9
	base.bottom_radius = radius
	base.height = 0.6
	base.radial_segments = 24
	plinth.mesh = base
	plinth.position = pos + Vector3(0, 0.3, 0)
	plinth.material_override = _material(Color("#65502d"), 0.45, 0.05)
	arena_root.add_child(plinth)
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = radius * 0.42
	tm.height = radius * 1.6
	tm.radial_segments = 8
	tower.mesh = tm
	tower.position = pos + Vector3(0, radius * 1.1, 0)
	tower.material_override = _material(color, 0.25, 0.3)
	arena_root.add_child(tower)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, radius * 1.5, 0)
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = radius * 5.0
	arena_root.add_child(light)

func _add_cover(pos: Vector3, scale_value: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = scale_value
	mesh.height = scale_value * 1.7
	mesh.radial_segments = 7
	mesh.rings = 4
	rock.mesh = mesh
	rock.position = pos + Vector3(0, scale_value * 0.45, 0)
	rock.scale = Vector3(1.5, 0.9, 1.0)
	rock.material_override = _material(Color("#53666a"), 0.0, 0.0)
	arena_root.add_child(rock)

func _add_ring(pos: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.91
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position = pos
	ring.material_override = _material(color, 0.2, 0.45)
	arena_root.add_child(ring)

func _add_line(a: Vector3, b: Vector3, color: Color, thickness: float) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, 0.03, a.distance_to(b))
	line.mesh = mesh
	line.position = (a + b) * 0.5
	line.look_at_from_position(line.position, b, Vector3.UP)
	line.material_override = _material(color, 0.0, 0.0)
	arena_root.add_child(line)

func _add_perimeter(width: float, depth: float) -> void:
	var c := Color("#b18c4a")
	_add_line(Vector3(-width/2, 0.08, -depth/2), Vector3(width/2, 0.08, -depth/2), c, 0.12)
	_add_line(Vector3(width/2, 0.08, -depth/2), Vector3(width/2, 0.08, depth/2), c, 0.12)
	_add_line(Vector3(width/2, 0.08, depth/2), Vector3(-width/2, 0.08, depth/2), c, 0.12)
	_add_line(Vector3(-width/2, 0.08, depth/2), Vector3(-width/2, 0.08, -depth/2), c, 0.12)

func _to_world(point: Vector2) -> Vector3:
	return Vector3((point.x - float(layout.width) * 0.5) * MAP_SCALE, 0.0, (point.y - float(layout.height) * 0.5) * MAP_SCALE)

func _material(color: Color, metallic: float, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.48
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#18212b") if primary else Color("#edf3f8"))
	button.add_theme_stylebox_override("normal", _panel_style(GOLD if primary else Color("#13263a"), GOLD if primary else Color("#486175")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#ffe2a0") if primary else Color("#1b354b"), GOLD))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#b58d42") if primary else Color("#0b1929"), GOLD))
	return button

func _update_camera() -> void:
	if camera == null:
		return
	var target := Vector3.ZERO
	var horizontal := cos(pitch) * distance
	camera.position = target + Vector3(sin(yaw) * horizontal, -sin(pitch) * distance, cos(yaw) * horizontal)
	camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_touch = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(12.0, distance * 0.88)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(100.0, distance * 1.12)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var delta: Vector2 = event.position - last_touch
		yaw -= delta.x * 0.008
		pitch = clampf(pitch - delta.y * 0.004, -1.25, -0.48)
		last_touch = event.position
		_update_camera()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 1:
				last_touch = event.position
			elif touch_points.size() == 2:
				var points: Array = touch_points.values()
				last_pinch_distance = points[0].distance_to(points[1])
		else:
			touch_points.erase(event.index)
			if touch_points.size() < 2:
				last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		if not touch_points.has(event.index):
			return
		var old: Vector2 = touch_points[event.index]
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			var delta: Vector2 = event.position - old
			yaw -= delta.x * 0.008
			pitch = clampf(pitch - delta.y * 0.004, -1.25, -0.48)
			_update_camera()
		elif touch_points.size() == 2:
			var points: Array = touch_points.values()
			var pinch := points[0].distance_to(points[1])
			if last_pinch_distance > 1.0:
				distance = clampf(distance * last_pinch_distance / maxf(pinch, 1.0), 12.0, 100.0)
				_update_camera()
			last_pinch_distance = pinch
