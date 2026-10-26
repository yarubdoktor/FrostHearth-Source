extends "res://scripts/map/map_panel.gd"
## مشهد خريطة العالم — الطبقة 5/5 (الأعلى): التهيئة وربط الكاميرا والواجهة وحلقة الإطار. بقية المنطق في scripts/map/ بسلسلة extends:
## map_core ← map_scene ← map_venture ← map_panel ← world_map.gd


func _ready() -> void:
	font = load(FONT_PATH)
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	city_placement = CityPlacement.new(data)
	external_environment = ExternalEnvironment.new()
	add_child(external_environment)
	_setup_env()
	var map: Node = load(MAP_PATH).instantiate()
	_fix_materials(map)
	add_child(map)
	_spawn_all()
	_setup_city_clearance(map)
	external_environment.setup(map, city_clearance_material)
	_setup_fog()
	_setup_camera()
	_setup_ui()
	skin_picker = CitySkinPicker.new()
	ui.add_child(skin_picker)
	skin_picker.setup(self)
	ui_blockers.append(skin_picker)
	Game.city_skin_changed.connect(apply_city_skin)
	resource_sites = ResourceSites.new()
	add_child(resource_sites)
	resource_sites.setup(self)
	_toast("اسحب للتحرك • إصبعان للتكبير • اضغط على أي خانة")
	Game.changed.connect(_refresh_stock)
	Game.toast.connect(_toast)
	Game.fog_changed.connect(_update_fog)
	_update_fog()
	if not city_placement.reason(Vector2(Game.home) + Vector2(0.5, 0.5)).is_empty():
		_toast("موقع المدينة في الحفظ القديم ضيق؛ اختر مساحة أوسع لنقلها دون خسارة تقدمك")


# ================================================================ الكاميرا والثلج
func _setup_camera() -> void:
	rig = StrategyCamera.new()
	rig.map_size = float(data["size"])
	add_child(rig)
	rig.ui_hit_test = _over_ui
	rig.tapped.connect(_on_tap)
	rig.view_changed.connect(_on_view)
	rig.set_view(home_pos, 34.0)

	snow = CPUParticles3D.new()
	snow.amount = 900
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.local_coords = true
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(60, 1, 60)
	snow.direction = Vector3(0.3, -1, 0.1)
	snow.spread = 12.0
	snow.gravity = Vector3(0, -2.0, 0)
	snow.initial_velocity_min = 3.0
	snow.initial_velocity_max = 6.0
	var q := SphereMesh.new()
	q.radius = 0.07
	q.height = 0.14
	q.radial_segments = 6
	q.rings = 3
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.85)
	q.material = sm
	snow.mesh = q
	rig.add_child(snow)
	_on_view(rig.focus, rig.dist)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	ui.theme = th
	layer.add_child(ui)

	MapHud.build(self)
	var march_timers := MarchTimers.new()
	march_timers.world = self
	ui.add_child(march_timers)
	_refresh_stock()

	# لوحة المعلومات (أسفل اليسار)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.1, 0.17, 0.9), 18))
	panel.custom_minimum_size = Vector2(0, 0)
	ui.add_child(panel)
	ui_blockers.append(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	panel.add_child(pv)
	p_title = Label.new()
	p_title.add_theme_font_size_override("font_size", 24)
	p_title.add_theme_color_override("font_color", Color("ffd36b"))
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(p_title)
	p_sub = Label.new()
	p_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p_sub.add_theme_color_override("font_color", Color("b9cbe0"))
	pv.add_child(p_sub)
	p_info = Label.new()
	p_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_info.add_theme_font_size_override("font_size", 17)
	pv.add_child(p_info)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	pv.add_child(ph)
	var close := _button("إغلاق", _close_panel)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(close)
	p_action = _button("إرسال قوات", _on_action, true)
	p_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(p_action)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# عمودي: اللوحة بعرض الشاشة وفوق صف الأزرار السفلي بدل أن تتراكب معه
	panel.anchor_right = 1.0
	panel.offset_right = -14.0
	panel.offset_top -= 84.0
	panel.offset_bottom -= 84.0
	panel.visible = false

	# رسالة عائمة
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", _style(Color(0.04, 0.08, 0.14, 0.85), 20))
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 100)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_on_view(rig.focus, rig.dist)


func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		toast.modulate.a = clampf(toast_time / 0.6, 0.0, 1.0)
		if toast_time <= 0:
			toast.visible = false
	if sel_ring.visible:
		var k := (1.0 + sin(Time.get_ticks_msec() / 180.0) * 0.06) * sel_rr
		sel_ring.scale = Vector3(k, 1, k)
	# المرحلة 3: مؤشر جبهة الصقيع وأثرها البصري
	if Game.front_active() != _front_on:
		_front_on = Game.front_active()
		_apply_daytime()
		if _front_on:
			env.fog_density += 0.0016
			sun.light_energy *= 0.7
	if front_label != null:
		if _front_on:
			front_label.text = "جبهة صقيع نشطة: الحرارة الخارجية ناقص %d° إضافية" % int(Defs.FRONT_DROP)
			front_label.add_theme_color_override("font_color", Color("ff9a8a"))
		else:
			front_label.text = "الجبهة القادمة بعد %s" % Defs.fmt_time(Game.front_eta())
			front_label.add_theme_color_override("font_color", Color("9fb8d0"))
	if vent_label != null:
		vent_label.modulate = Color("a9f0a0") if Game.vent.get("captured", false) else Color("ffb066")
	_sync_marches()
	var t := Game.now()
	var t_now := Time.get_ticks_msec() / 1000.0
	for m in Game.marches:
		var key := str(m["start"])
		if not march_vis.has(key):
			continue
		var v: Dictionary = march_vis[key]
		var pr := _march_pos(m, t)
		var p: Vector3 = pr[0]
		var to: Vector3 = pr[1]
		var troop: MeshInstance3D = v["troop"]
		troop.position = Vector3(p.x, 0.35, p.z)
		# During collection the squad stands beside the enlarged work site,
		# rather than disappearing inside its hut / mine geometry.
		if m.get("kind", "") == "res" and t >= float(m["arrive"]) and t < float(m["leave"]):
			troop.position += MapVisuals.RESOURCE_SQUAD_OFFSET
		var dir := to - p
		if dir.length() > 0.05:
			troop.rotation.y = atan2(-dir.z, dir.x)
		_draw_dashes(v["im"], p, to, -t_now * 2.0)
	# المرحلة 3: رسم الفرقة العسكرية نحو المنفث
	if not Game.venture.is_empty() and march_vis.has("venture"):
		var vv: Dictionary = march_vis["venture"]
		var pr2 := _march_pos(Game.venture, t)
		var p2: Vector3 = pr2[0]
		var to2: Vector3 = pr2[1]
		var troop2: MeshInstance3D = vv["troop"]
		troop2.position = Vector3(p2.x, 0.35, p2.z)
		var dir2 := to2 - p2
		if dir2.length() > 0.05:
			troop2.rotation.y = atan2(-dir2.z, dir2.x)
		_draw_dashes(vv["im"], p2, to2, -t_now * 2.0)
