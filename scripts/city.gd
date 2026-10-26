extends "res://scripts/city/city_events.gd"
## مشهد المدينة — الطبقة 6/6 (الأعلى): التهيئة وربط الإشارات وحلقة الإطار. بقية المنطق في scripts/city/ بسلسلة extends:
## city_core ← city_windows ← city_world ← city_panel ← city_events ← city.gd


func _ready() -> void:
	font = load(UI.FONT_PATH)
	_setup_env()
	var ground: Node3D = _inst("res://assets/city/ground.glb")
	add_child(ground)
	_apply_ground_snow_shader(ground)
	for id in Defs.PLOTS:
		_make_plot(id)
	_setup_fx()
	_setup_camera()
	_setup_ui()
	_setup_citizens()
	Game.changed.connect(_on_changed)
	Game.toast.connect(_toast)
	Game.building_done.connect(_on_building_done)
	Game.raid_happened.connect(_on_raid)
	Game.crystals_changed.connect(_sync_crystals)
	Game.decision_ready.connect(_on_changed)
	_setup_stage2_world()
	_on_changed()
	_apply_quality()
	call_deferred("_welcome")


func _welcome() -> void:
	if not Game.migration_note.is_empty():
		var mn: Dictionary = Game.migration_note
		Game.migration_note = {}
		var ml: Array[String] = ["تم تحديث نظام الجيش والمدينة:"]
		if mn.has("barracks_granted"):
			ml.append("• المعسكر صار مكان تجمع القوات، والتدريب انتقل إلى ثلاث ثكنات (دروع، رماح، رماة). منحناك كل ثكنة بمستوى معسكرك السابق (%d)." % int(mn["barracks_granted"]))
		if mn.has("shelters_removed"):
			ml.append("• المآوي صارت 4 فقط وسعتها أكبر. ألغينا %d مأوى زائدًا وأعدنا لك تكلفتها كاملة:" % int(mn["shelters_removed"]))
			var rp: Array[String] = []
			for r in mn.get("refund", {}):
				rp.append("%s %s" % [Defs.fmt(float(mn["refund"][r])), Defs.RES_NAMES[r]])
			ml.append("   " + "، ".join(rp))
		_modal("تحديث المدينة", "\n".join(ml), [["حسنًا", func(): pass, "gold"]], "army")
		return
	var rep: Dictionary = Game.offline_report
	if not rep.is_empty():
		var lines: Array[String] = ["غبت %s، وخلال غيابك:" % Defs.fmt_time(rep["elapsed"])]
		for r in rep["gained"]:
			if rep["gained"][r] >= 1:
				lines.append("• تجمّع %s %s في المباني" % [Defs.fmt(rep["gained"][r]), Defs.RES_NAMES[r]])
		if rep["built"] > 0:
			lines.append("• اكتمل %d من أعمال البناء" % rep["built"])
		if rep["pop"] > 0:
			lines.append("• وصل %d ناجين جدد" % rep["pop"])
		Game.offline_report = {}
		_modal("مرحبًا بعودتك أيها القائد", "\n".join(lines), [["جمع الكل", _collect_all, "gold"]], "gift")
	elif Game.daily_ready:
		_show_daily()
	elif Game.stats.get("built", 0) == 0 and Game.task_index == 0:
		_modal("مدينة الصقيع", "العالم تجمّد، ونجا معك قلة من الناس.\nأبقِ الفرن مشتعلًا، وابنِ المآوي، واجمع الموارد قبل العاصفة القادمة.\n\nاضغط على أي موقع بناء للبدء.",
				[["لنبدأ", func(): pass, "gold"]], "fire")
	elif Game.raid_unseen:
		_show_raid_report()


func _setup_camera() -> void:
	rig = StrategyCamera.new()
	rig.map_size = 120.0
	rig.edge_margin = 24.0
	rig.min_dist = 12.0
	rig.max_dist = 85.0
	rig.near_pitch_deg = 40.0
	rig.far_pitch_deg = 60.0
	rig.ground_y = 0.0
	add_child(rig)
	rig.ui_hit_test = _over_ui
	rig.tapped.connect(_on_tap)
	rig.set_view(Defs.CITY_CENTER + Vector3(0, 0, 6), 52.0)

	snow = CPUParticles3D.new()
	snow.amount = 700
	snow.lifetime = 5.0
	snow.preprocess = 5.0
	snow.local_coords = true
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(45, 1, 45)
	snow.position = Vector3(0, 26, 0)
	snow.direction = Vector3(0.3, -1, 0.1)
	snow.spread = 12.0
	snow.gravity = Vector3(0, -2.0, 0)
	snow.initial_velocity_min = 3.0
	snow.initial_velocity_max = 6.0
	snow.scale_amount_min = 0.7
	snow.scale_amount_max = 1.5
	snow.angular_velocity_min = -40.0
	snow.angular_velocity_max = 40.0
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = _flake_texture()
	m.albedo_color = Color(1, 1, 1, 1.0)
	q.material = m
	snow.mesh = q
	rig.add_child(snow)

## قوام رقاقة ثلج ناعم (تدرّج شعاعي) — يُبنى برمجيًا فلا ملفات صور إضافية
func _flake_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## المرحلة 32 — سطح الثلج السينمائي على أرضية المدينة (أسطح Snow فقط)
func _apply_ground_snow_shader(ground: Node3D) -> void:
	var snow_mat := ShaderMaterial.new()
	snow_mat.shader = load("res://shaders/ground_snow.gdshader")
	for mi in ground.find_children("*", "MeshInstance3D"):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var sm := mesh.surface_get_material(i) as StandardMaterial3D
			if sm != null and sm.resource_name == "Snow":
				(mi as MeshInstance3D).set_surface_override_material(i, snow_mat)


# ================================================================ الواجهة
func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UI.theme()
	layer.add_child(ui)

	frost_overlay = ColorRect.new()
	frost_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	frost_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.8)) * 1.55;
	float n = fract(sin(dot(floor(UV * 90.0), vec2(12.9898, 78.233))) * 43758.5453);
	float frost = smoothstep(0.5, 1.05, d + n * 0.08) * amount;
	// المرحلة 32: vignette سينمائي خفيف دائم يعطي عمقًا للتكوين
	float vig = smoothstep(0.55, 1.18, d) * 0.30;
	float a = clamp(vig + frost * (1.0 - vig), 0.0, 1.0);
	vec3 col = mix(vec3(0.01, 0.02, 0.05), vec3(0.82, 0.92, 1.0), frost / max(vig + frost, 1e-4));
	COLOR = vec4(col, a);
}"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	smat.set_shader_parameter("amount", 0.0)
	frost_overlay.material = smat
	ui.add_child(frost_overlay)

	# مؤقتات فوق المباني (تحت الواجهة الرئيسية في الترتيب)
	JobTimers.build(self, ui)
	# الواجهة الرئيسية بنمط ألعاب الاستراتيجية (scripts/ui/home_hud.gd)
	HomeHud.build(self)

	storm_label = UI.label("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	storm_label.add_theme_stylebox_override("normal", UI.style(Color(0.55, 0.15, 0.15, 0.85), 16))
	ui.add_child(storm_label)
	storm_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 320)
	storm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storm_label.custom_minimum_size = Vector2(340, 0)
	storm_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	storm_label.visible = false

	_build_building_panel()

	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 6)
	ui.add_child(toast_box)
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.anchor_top = 1.0
	toast_box.anchor_bottom = 1.0
	toast_box.offset_top = -270.0
	toast_box.offset_bottom = -270.0
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH

	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(modal_layer)


# ================================================================ كل إطار
func _process(delta: float) -> void:
	if dev_btn != null:
		dev_btn.visible = Game.dev_mode
	# الصقل البصري: لوحات المواقع تظهر فقط عند الاقتراب — تقليل التكدس فوق الواجهة
	var badges_near: bool = rig.dist < 42.0
	for id in plot_nodes:
		var pn: Dictionary = plot_nodes[id]
		var badge: Label3D = pn["badge"]
		var important: bool = Defs.PLOTS[id]["type"] == "furnace" or id == sel
		badge.visible = (badges_near or important) and not (id == sel and bp.visible)
	for id in plot_nodes:
		_update_plot_dynamic(id)
	JobTimers.update(self)
	_update_citizens(delta)
	# الفرن والجو
	var on: bool = Game.furnace_mode > 0 and Game.res["coal"] > 0
	var target := 0.0 if not on else (2.2 if Game.furnace_mode == 1 else 4.0)
	fire_light.light_energy = lerpf(fire_light.light_energy, target * (0.9 + 0.1 * sin(Time.get_ticks_msec() / 90.0)), delta * 4.0)
	smoke.emitting = on
	var tier := _tier("furnace", Game.furnace_level())
	smoke.position = Defs.CITY_CENTER + Vector3(0, 9.2 + tier * 2.6, 0)
	var storm := Game.storm_active()
	var cold := float(Game.cold_level) / 2.0
	var mat := frost_overlay.material as ShaderMaterial
	var cur := float(mat.get_shader_parameter("amount") if mat.get_shader_parameter("amount") != null else 0.0)
	mat.set_shader_parameter("amount", lerpf(cur, clampf(cold * 0.8 + (0.35 if storm else 0.0), 0.0, 1.0), delta * 1.5))
	env.fog_density = lerpf(env.fog_density, 0.02 if storm else 0.0058, delta * 0.8)
	env.fog_enabled = env.fog_density > 0.0005
	snow.speed_scale = 2.2 if storm else 1.0
	sun.light_energy = lerpf(sun.light_energy, 0.55 if storm else 1.0, delta)
	var d: float = rig.dist
	snow.emission_box_extents = Vector3(d * 0.8, 1, d * 0.8)
	snow.position = Vector3(0, clampf(d * 0.5, 12.0, 40.0), 0)
	_process_stage2(delta)
	if sel_ring.visible:
		var k := 1.0 + sin(Time.get_ticks_msec() / 180.0) * 0.04
		var r := (7.5 if sel == "furnace" else 2.6) * k
		sel_ring.scale = Vector3(r, 1, r)
