extends "res://scripts/map/map_core.gd"
## الطبقة 2/5 — مشهد الخريطة: البيئة والضباب ووضوح المدن وتوليد المجسمات ومعاينة التموضع وبقية المظهر وتحريك الفرق.


# ================================================================ البيئة
func _setup_env() -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.1
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.46
	env.glow_hdr_threshold = 1.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	_apply_daytime()


func _apply_daytime() -> void:
	if night:
		sky_mat.sky_top_color = Color("101826")
		sky_mat.sky_horizon_color = Color("2a3346")
		sky_mat.ground_horizon_color = Color("2a3346")
		sky_mat.ground_bottom_color = Color("101826")
		env.ambient_light_energy = 0.3
		env.fog_light_color = Color("222b3c")
		env.fog_density = 0.0022
		sun.light_color = Color("c4d0f0")
		sun.light_energy = 0.35
	else:
		sky_mat.sky_top_color = Color("6d95ba")
		sky_mat.sky_horizon_color = Color("e9e8da")
		sky_mat.ground_horizon_color = Color("dde2e9")
		sky_mat.ground_bottom_color = Color("a8b6c6")
		env.ambient_light_energy = 0.5
		env.fog_light_color = Color("d6e2f0")
		env.fog_density = 0.0016
		sun.light_color = Color("ffe4b8")
		sun.light_energy = 1.05
		if external_environment != null and external_environment.enabled:
			sky_mat.sky_horizon_color = Color("c4d1c3")
			sky_mat.ground_horizon_color = Color("c4d1c3")
			sky_mat.ground_bottom_color = Color("64734f")
			env.fog_light_color = Color("becbb8")
			sun.light_color = Color("fff1d8")


# ================================================================ ضباب الحرب
func _setup_fog() -> void:
	## طائرة معتمة فوق الخريطة تُختفي حيث كُشف — والكشف نفسه منطق في Game
	fog_img = _fog_image()
	fog_tex = ImageTexture.create_from_image(fog_img)
	var sh := Shader.new()
	sh.code = FOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("fog_tex", fog_tex)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(600, 4.5, 600)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _update_fog() -> void:
	## تُستدعى عند كشف مناطق جديدة: تحديث النسيج وإظهار لوحات المناطق المكشوفة
	if fog_img == null:
		return
	for fl in fog_labels:
		(fl["label"] as Label3D).visible = Game.is_explored(int(fl["x"]), int(fl["y"]))
	if vent_node != null:
		vent_node.visible = Game.is_explored(int(Game.vent["x"]), int(Game.vent["y"]))
	fog_img = _fog_image()
	fog_tex.update(fog_img)


func _fog_image() -> Image:
	## بايتات الحالة 0/1 تتحول إلى 0/255 في النسيج — وإلا بقيت الخريطة كلها مغطاة
	var bytes := PackedByteArray()
	bytes.resize(Game.explored.size())
	for i in range(Game.explored.size()):
		bytes[i] = 255 if Game.explored[i] > 0 else 0
	return Image.create_from_data(Defs.FOG_GRID, Defs.FOG_GRID, false, Image.FORMAT_R8, bytes)


# ================================================================ توزيع العناصر
func _setup_city_clearance(map_root: Node) -> void:
	# Forests are baked into the terrain mesh; a small presentation mask clears
	# them around larger cities without regenerating terrain or world data.
	var mask := Image.create(1200, 1200, false, Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for city in data["cities"]:
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				if dx * dx + dz * dz > 34:
					continue
				var x := int(city["x"]) + dx
				var z := int(city["y"]) + dz
				if x >= 0 and z >= 0 and x < 1200 and z < 1200:
					mask.set_pixel(x, z, Color.WHITE)
	city_clearance_material = ShaderMaterial.new()
	city_clearance_material.shader = preload("res://shaders/city_clearance.gdshader")
	city_clearance_material.set_shader_parameter("city_mask", ImageTexture.create_from_image(mask))
	city_clearance_material.set_shader_parameter("home_xz", Vector2(home_pos.x, home_pos.z))
	_apply_city_clearance(map_root)


func _apply_city_clearance(n: Node) -> void:
	if n is MeshInstance3D and str(n.name).begins_with("Chunk_"):
		for i in n.mesh.get_surface_count():
			var material: Material = n.mesh.surface_get_material(i)
			if material != null and material.resource_name == "Matte":
				n.set_surface_override_material(i, city_clearance_material)
	for child in n.get_children():
		_apply_city_clearance(child)


func _spawn_group(mesh: Mesh, items: Array, visual_scale := 1.0) -> void:
	var regions := {}
	for it in items:
		var key := Vector2i(int(it["x"]) / 300, int(it["y"]) / 300)
		if not regions.has(key):
			regions[key] = []
		regions[key].append(it)
	for key in regions:
		var arr: Array = regions[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			var it: Dictionary = arr[i]
			var ry: float = it.get("ry", fmod(it["x"] * 12.9898 + it["y"] * 78.233, TAU))
			var b := Basis(Vector3.UP, ry).scaled(Vector3.ONE * visual_scale)
			mm.set_instance_transform(i, Transform3D(b, Vector3(it["x"], it["h"], it["y"])))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _spawn_all() -> void:
	# الموارد
	for t in RES_NAMES:
		var items: Array = data["resources"].filter(func(r): return r["t"] == t)
		var source_path := "res://assets/res_%s.glb" % t
		var resource_mesh: Mesh = external_environment.prepare_resource(_mesh_from(source_path), source_path)
		_spawn_group(resource_mesh, items, MapVisuals.RESOURCE_SCALE)
		for r in items:
			_reg(int(r["x"]), int(r["y"]), 1, {"kind": "res", "t": t, "l": r["l"],
					"x": int(r["x"]), "y": int(r["y"]), "pos": Vector3(r["x"], r["h"], r["y"])})
	# الوحوش
	for t in BEAST_NAMES:
		var items: Array = data["beasts"].filter(func(b): return b["t"] == t)
		_spawn_group(_mesh_from("res://assets/beast_%s.glb" % t), items)
		for b in items:
			_reg(int(b["x"]), int(b["y"]), 1, {"kind": "beast", "t": t, "l": b["l"],
					"x": int(b["x"]), "y": int(b["y"]), "pos": Vector3(b["x"], b["h"], b["y"])})
	# المدن
	for team in ["ally", "enemy", "neutral"]:
		var items: Array = data["cities"].filter(func(c): return c["team"] == team)
		_spawn_group(_mesh_from(CitySkins.mesh_path(CitySkins.DEFAULT, team)), items, MapVisuals.CITY_SCALE)
		var col: Color = {"ally": Color("8fd0ff"), "enemy": Color("ff9a8a"), "neutral": Color("f2f2f2")}[team]
		for c in items:
			var p := Vector3(c["x"], c["h"], c["y"])
			var info := {"kind": "city", "n": c["n"], "team": team,
				"l": c["l"], "x": int(c["x"]), "y": int(c["y"]), "pos": p}
			_register_city(info)
			city_targets.append(info)
			var cl := _label3d("%s  %d" % [c["n"], c["l"]], p + Vector3(0, MapVisuals.CITY_LABEL_HEIGHT, 0), 26, col, 75.0)
			fog_labels.append({"label": cl, "x": int(c["x"]), "y": int(c["y"])})
	# مدينتك
	var h: Dictionary = data["home"]
	h["x"] = Game.home.x + 0.5
	h["y"] = Game.home.y + 0.5
	h["l"] = Game.furnace_level()
	h["n"] = "مدينتي"
	home_pos = Vector3(h["x"], h["h"], h["y"])
	home_node = MeshInstance3D.new()
	home_node.mesh = _mesh_from(CitySkins.mesh_path(Game.city_skin))
	home_node.scale = Vector3.ONE * MapVisuals.CITY_SCALE
	home_node.position = home_pos
	add_child(home_node)
	home_label = _label3d("%s  %d" % [h["n"], h["l"]], home_pos + Vector3(0, MapVisuals.CITY_LABEL_HEIGHT, 0), 32, Color("ffd36b"), 0)
	home_info = {"kind": "city", "n": h["n"], "team": "me", "l": h["l"], "x": Game.home.x, "y": Game.home.y, "pos": home_pos}
	city_targets.append(home_info)
	_register_city(home_info)
	# المعالم (مبنية داخل frost_map.glb) — نضيف الأسماء ومناطق الضغط
	for L in data["landmarks"]:
		var p := Vector3(L["x"], L["h"], L["y"])
		var r: int = L["r"]
		var info := {"kind": "lm", "n": L["name"], "type": L["type"], "id": L["id"],
			"x": int(L["x"]), "y": int(L["y"]), "pos": p, "r": r}
		_reg(int(L["x"]) - r, int(L["y"]) - r, r * 2 + 1, info)
		var big: bool = L["type"] == "sun_city"
		var lh: float = {"sun_city": 26.0, "stronghold": 14.0, "fortress": 12.0}.get(L["type"], 8.0)
		var ll := _label3d(L["name"], p + Vector3(0, lh, 0), 44 if big else 34,
				Color("ffd36b") if big else Color("ffffff"), 0.0 if big else 420.0)
		fog_labels.append({"label": ll, "x": int(L["x"]), "y": int(L["y"])})
	# المرحلة 3: المنفث الحراري الجوفي — ارتفاعه من التضاريس نفسها
	var vx := float(Game.vent["x"]) + 0.5
	var vz := float(Game.vent["y"]) + 0.5
	var vy := _terrain_height_at(vx, vz)
	var vp := Vector3(vx, vy + 0.3, vz)
	vent_node = MeshInstance3D.new()
	vent_node.mesh = _mesh_from("res://assets/city/crystal.glb")
	vent_node.position = vp
	vent_node.scale = Vector3.ONE * 1.8
	add_child(vent_node)
	vent_label = _label3d("المنفث الحراري", vp + Vector3(0, 4.4, 0), 30, Color("ffb066"), 0.0)
	fog_labels.append({"label": vent_label, "x": int(Game.vent["x"]), "y": int(Game.vent["y"])})
	_reg(int(Game.vent["x"]), int(Game.vent["y"]), 1, {"kind": "vent",
			"x": int(Game.vent["x"]), "y": int(Game.vent["y"]), "pos": vp})
	# حلقة التحديد
	sel_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 48
	sel_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("ffd36b")
	rm.emission_enabled = true
	rm.emission = Color("ffbf4f")
	rm.emission_energy_multiplier = 0.28
	rm.no_depth_test = true
	sel_ring.material_override = rm
	sel_ring.visible = false
	add_child(sel_ring)
	_setup_placement_preview()
	# القوات
	troop_mesh = _mesh_from("res://assets/troop.glb")
	march_mat = StandardMaterial3D.new()
	march_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	march_mat.albedo_color = Color("7fd3ff")
	march_mat.no_depth_test = true
	march_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func apply_city_skin(id: String) -> void:
	# Never replace the node, transform, selection record or mission target.
	home_node.mesh = _mesh_from(CitySkins.mesh_path(id))


func _toggle_external_preview() -> void:
	external_environment.set_enabled(not external_environment.enabled)
	_apply_daytime()
	_on_view(rig.focus, rig.dist)
	_toast("معاينة البيئة: خضراء" if external_environment.enabled else "معاينة البيئة: ثلجية")


func _toggle_night() -> void:
	night = not night
	_apply_daytime()
	_on_view(rig.focus, rig.dist)


func _setup_placement_preview() -> void:
	placement_preview = Node3D.new()
	add_child(placement_preview)
	placement_fill = StandardMaterial3D.new()
	placement_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placement_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	placement_fill.no_depth_test = true
	placement_outline = StandardMaterial3D.new()
	placement_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placement_outline.no_depth_test = true
	var tile := PlaneMesh.new()
	tile.size = Vector2(CityPlacement.PLOT_SIDE - 0.1, CityPlacement.PLOT_SIDE - 0.1)
	for x in [-2.5, 2.5]:
		for z in [-2.5, 2.5]:
			var cell := MeshInstance3D.new()
			cell.mesh = tile
			cell.material_override = placement_fill
			cell.position = Vector3(x, 0, z)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			placement_preview.add_child(cell)
	var line := BoxMesh.new()
	line.size = Vector3(CityPlacement.FOOTPRINT_SIDE, 0.04, 0.06)
	for offset in [-5.0, 0.0, 5.0]:
		for vertical in [false, true]:
			var bar := MeshInstance3D.new()
			bar.mesh = line
			bar.material_override = placement_outline
			bar.position = Vector3(offset, 0.02, 0) if vertical else Vector3(0, 0.02, offset)
			bar.rotation.y = PI * 0.5 if vertical else 0.0
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			placement_preview.add_child(bar)
	placement_preview.visible = false


func _sync_marches() -> void:
	var alive := {}
	for m in Game.marches:
		var key := str(m["start"])
		alive[key] = true
		if not march_vis.has(key):
			var troop := MeshInstance3D.new()
			troop.mesh = troop_mesh
			add_child(troop)
			var line := MeshInstance3D.new()
			var im := ImmediateMesh.new()
			line.mesh = im
			line.material_override = march_mat
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(line)
			march_vis[key] = {"troop": troop, "line": line, "im": im}
	# المرحلة 3: الفرقة العسكرية نحو المنفث (مفتاح ثابت ولون مميز)
	# يُسجل قبل حلقة التنظيف حتى لا يُهدم ويُعاد بناؤه كل إطار
	if not Game.venture.is_empty():
		alive["venture"] = true
		if not march_vis.has("venture"):
			var troop := MeshInstance3D.new()
			troop.mesh = troop_mesh
			add_child(troop)
			var line := MeshInstance3D.new()
			var im := ImmediateMesh.new()
			line.mesh = im
			var vm: StandardMaterial3D = march_mat.duplicate() as StandardMaterial3D
			vm.albedo_color = Color("ff9a4a")
			line.material_override = vm
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(line)
			march_vis["venture"] = {"troop": troop, "line": line, "im": im}
	for key in march_vis.keys():
		if not alive.has(key):
			(march_vis[key]["troop"] as Node).queue_free()
			(march_vis[key]["line"] as Node).queue_free()
			march_vis.erase(key)
