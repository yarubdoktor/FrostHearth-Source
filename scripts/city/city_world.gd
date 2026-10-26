extends "res://scripts/city/city_windows.gd"
## الطبقة 3/6 — عالم المدينة ثلاثي الأبعاد: البيئة والمؤثرات والقطع والمباني والمواطنون والجنود والبلورات وحركة الغارة.


# ================================================================ البيئة
func _setup_env() -> void:
	## المرحلة 32 — هوية بصرية سينمائية: شمس شتوية منخفضة دافئة، سماء أعمق، ACES، توهّج ناعم.
	## ملاحظة: SSAO والضباب الحجمي غير مدعومين في عارض Mobile فنُحقّق العمق بالضباب العمقي والتظليل المخبوز.
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5e86ad")
	sky_mat.sky_horizon_color = Color("f0e2c8")
	sky_mat.ground_horizon_color = Color("dde2e9")
	sky_mat.ground_bottom_color = Color("9fb0c2")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("c8d8ea")
	env.fog_density = 0.0058
	env.fog_sky_affect = 0.1
	env.fog_height = -6.0
	env.fog_height_density = 0.01
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.04
	env.adjustment_brightness = 0.99
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -25, 0)
	sun.light_energy = 1.0
	sun.light_color = Color("ffdfb0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_pancake_size = 20.0
	add_child(sun)


func _apply_quality() -> void:
	sun.shadow_enabled = Game.quality_high
	env.glow_enabled = Game.quality_high
	snow.amount = 700 if Game.quality_high else 250
	smoke.amount = 60 if Game.quality_high else 25


func _setup_fx() -> void:
	fire_light = OmniLight3D.new()
	fire_light.position = Defs.CITY_CENTER + Vector3(0, 7, 0)
	fire_light.light_color = Color("ff9a4a")
	fire_light.omni_range = 34.0
	fire_light.omni_attenuation = 1.2
	smoke = CPUParticles3D.new()
	smoke.amount = 50
	smoke.lifetime = 6.0
	smoke.preprocess = 5.0
	smoke.direction = Vector3(0.3, 1, 0.12)
	smoke.spread = 10.0
	smoke.gravity = Vector3(0.7, 0.8, 0)
	smoke.initial_velocity_min = 1.3
	smoke.initial_velocity_max = 2.2
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 1.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.6))
	smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.42, 0.44, 0.49, 0.55))
	grad.set_color(1, Color(0.86, 0.88, 0.92, 0.0))
	smoke.color_ramp = grad
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	sm.radial_segments = 10
	sm.rings = 5
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_color = Color(1, 1, 1, 0.85)
	sm.material = smat
	smoke.mesh = sm
	add_child(smoke)
	fire_light.shadow_enabled = false
	add_child(fire_light)

	sel_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	sel_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = UI.GOLD
	sel_ring.material_override = rm
	sel_ring.visible = false
	add_child(sel_ring)


func _make_plot(id: String) -> void:
	var root := Node3D.new()
	root.position = Defs.plot_pos(id)
	var dir := Defs.CITY_CENTER - root.position
	if dir.length() > 0.1:
		root.rotation.y = atan2(dir.x, dir.z)
	add_child(root)
	var tp: String = Defs.PLOTS[id]["type"]
	var top := 9.0 if tp == "furnace" else 3.6
	var badge := _label3d("", Vector3(0, top, 0), 30, Color.WHITE)
	root.add_child(badge)
	var timer := _label3d("", Vector3(0, top + 1.6, 0), 28, Color("7fd3ff"))
	root.add_child(timer)
	var bubble := Sprite3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.fixed_size = true
	bubble.pixel_size = 0.0006
	bubble.no_depth_test = true
	bubble.position = Vector3(0, top + 1.2, 0)
	bubble.visible = false
	if Defs.BUILDINGS[tp].has("prod"):
		bubble.texture = UI.icon(Defs.BUILDINGS[tp]["prod"])
	root.add_child(bubble)
	var flag_mat: StandardMaterial3D = null
	if tp.begins_with("bk_"):
		flag_mat = _add_banner(root, tp)
	plot_nodes[id] = {"root": root, "model": null, "key": "", "badge": badge, "timer": timer,
			"bubble": bubble, "scaffold": null, "top": top, "flag_mat": flag_mat}
	_refresh_plot(id)


func _add_banner(root: Node3D, tp: String) -> StandardMaterial3D:
	## راية ملونة تميّز كل ثكنة (دروع: أزرق • رماح: أخضر • رماة: برتقالي) — بلا نماذج جديدة
	var col := {"bk_shield": Color("5aa7ff"), "bk_spear": Color("7fdc7a"), "bk_bow": Color("ff9a4a")}[tp] as Color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.6
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.07
	pm.height = 4.2
	pole.mesh = pm
	pole.position = Vector3(2.6, 2.1, 2.2)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.3, 0.8, 0.06)
	flag.mesh = fm
	flag.material_override = mat
	flag.position = Vector3(2.6 + 0.7, 3.7, 2.2)
	root.add_child(flag)
	return mat


func _refresh_plot(id: String) -> void:
	var pn: Dictionary = plot_nodes[id]
	var tp: String = Defs.PLOTS[id]["type"]
	var lv := Game.level(id)
	var q := Game.queue_entry(id)
	var locked := Game.furnace_level() < int(Defs.PLOTS[id]["unlock"])
	var key := ""
	if tp == "wall":
		_sync_wall_ring(lv)   # السور حلقة واحدة حول المدينة، لا نموذج على الموقع
	elif lv > 0:
		var model_tp: String = "barracks" if tp.begins_with("bk_") else tp
		key = "res://assets/city/%s_t%d.glb" % [model_tp, _tier(id, lv)]
	elif q.is_empty():
		key = "res://assets/city/plot.glb"
	if key != pn["key"]:
		if pn["model"]:
			pn["model"].queue_free()
		pn["model"] = null
		if key != "":
			pn["model"] = _inst(key)
			pn["root"].add_child(pn["model"])
		pn["key"] = key
	var building: bool = not q.is_empty()
	if building and pn["scaffold"] == null:
		pn["scaffold"] = _inst("res://assets/city/scaffold.glb")
		if tp == "furnace":
			pn["scaffold"].scale = Vector3(2.4, 2.4, 2.4)
		pn["root"].add_child(pn["scaffold"])
	elif not building and pn["scaffold"] != null:
		pn["scaffold"].queue_free()
		pn["scaffold"] = null
	var badge: Label3D = pn["badge"]
	if lv > 0:
		var named: bool = tp == "furnace" or tp == "barracks" or tp.begins_with("bk_") or tp == "wall"
		badge.text = "%s  %d" % [Defs.BUILDINGS[tp]["name"], lv] if named else "Lv.%d" % lv
		if tp == "wall":
			badge.text = "%s  %d" % [Defs.WALL_STAGES[Defs.wall_stage(lv)]["name"], lv]
		badge.modulate = UI.GOLD if tp == "furnace" else Color.WHITE
		badge.font_size = 34 if tp == "furnace" else 26
	elif locked:
		badge.text = "مقفل • الفرن %d" % Defs.PLOTS[id]["unlock"]
		badge.modulate = Color(0.75, 0.78, 0.82)
		badge.font_size = 22
	elif not building:
		badge.text = "+ " + str(Defs.BUILDINGS[tp]["name"])
		badge.modulate = Color("9fe0ff")
		badge.font_size = 24
	else:
		badge.text = ""
	if pn["model"] and lv == 0:
		pn["model"].visible = true
		(pn["model"] as Node3D).scale = Vector3.ONE * (0.8 if locked else 1.0)


func _sync_wall_ring(lv: int) -> void:
	var key := "res://assets/city/city_wall_t%d.glb" % Defs.wall_stage(lv)
	if key == wall_ring_key:
		return
	if wall_ring != null:
		wall_ring.queue_free()
	wall_ring = _inst(key)
	wall_ring.name = "WallRing"
	add_child(wall_ring)
	wall_ring_key = key


func _update_plot_dynamic(id: String) -> void:
	var pn: Dictionary = plot_nodes[id]
	var q := Game.queue_entry(id)
	# المؤقت صار لوحة فوق المبنى (job_timers.gd) فنُفرغ النص القديم ثلاثي الأبعاد
	(pn["timer"] as Label3D).text = ""
	var bubble: Sprite3D = pn["bubble"]
	if bubble.texture:
		var s := float(Game.stored.get(id, 0.0))
		var cap := Game.storage_cap(id)
		bubble.visible = s >= 1.0 and s >= cap * 0.04 and q.is_empty()
		if bubble.visible:
			var t := Time.get_ticks_msec() / 1000.0
			bubble.position.y = pn["top"] + 1.4 + sin(t * 3.0 + id.hash() % 7) * 0.25
			bubble.modulate = Color(1, 0.85, 0.6) if s >= cap * 0.98 else Color.WHITE


# ================================================================ السكان
func _setup_citizens() -> void:
	citizen_meshes = [_inst("res://assets/city/citizen_a.glb"), _inst("res://assets/city/citizen_b.glb")]


func _sync_citizens() -> void:
	var want := mini(Game.healthy(), 36)
	while citizens.size() < want:
		var n: Node3D = (citizen_meshes[citizens.size() % 2] as Node3D).duplicate()
		n.scale = Vector3.ONE * 1.4
		add_child(n)
		var p := _random_spot()
		n.position = p
		citizens.append({"node": n, "to": _random_spot(), "wait": randf() * 2.0, "speed": randf_range(1.6, 2.4)})
	while citizens.size() > want:
		var c: Dictionary = citizens.pop_back()
		(c["node"] as Node).queue_free()


func _update_citizens(delta: float) -> void:
	for c in citizens:
		var n: Node3D = c["node"]
		if c["wait"] > 0:
			c["wait"] -= delta
			continue
		var to: Vector3 = c["to"]
		var d := to - n.position
		d.y = 0
		if d.length() < 0.3:
			c["to"] = _random_spot()
			c["wait"] = randf_range(0.5, 3.0)
			continue
		var step := d.normalized() * float(c["speed"]) * delta
		# الابتعاد عن الفرن
		var np := n.position + step
		var fc := np - Defs.CITY_CENTER
		fc.y = 0
		if fc.length() < 7.0:
			np = Defs.CITY_CENTER + fc.normalized() * 7.0
		n.position = np
		n.rotation.y = atan2(d.x, d.z)
		n.position.y = absf(sin(Time.get_ticks_msec() / 110.0 + float(c["speed"]) * 9.0)) * 0.08


func _float_text(t: String, pos: Vector3, r: String) -> void:
	var col := {"food": Color("ffd28a"), "wood": Color("e9b98a"), "coal": Color("d0d4dc"), "iron": Color("a9d8ff"), "aurora": Color("9ff3ff")}
	var l := _label3d(t, pos, 34, col.get(r, Color.WHITE))
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 3.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# ================================================================ المرحلة الثانية: العالم ثلاثي الأبعاد
func _setup_stage2_world() -> void:
	for k in Defs.TROOP_ORDER:
		soldier_meshes[k] = _inst("res://assets/city/soldier_%s.glb" % k)
	crystal_scene = _inst("res://assets/city/crystal.glb")
	wolf_scene = _inst("res://assets/city/wolf.glb")
	_sync_crystals()


func _sync_soldiers() -> void:
	var lv := Game.level("ba1")
	var counts := {}
	for tp in Defs.TROOP_ORDER:
		var n := 0
		for t in range(1, 5):
			n += int(Game.troops["%s_%d" % [tp, t]])
		counts[tp] = clampi(int(ceil(n / 15.0)), 0, 6)
	var sig := str(counts) + str(lv > 0)
	if sig == _soldier_sig:
		return
	_soldier_sig = sig
	for n in soldier_nodes:
		(n["node"] as Node).queue_free()
	soldier_nodes.clear()
	if lv <= 0 or not plot_nodes.has("ba1"):
		return
	var root: Node3D = plot_nodes["ba1"]["root"]
	var row := 0
	for tp in Defs.TROOP_ORDER:
		var c: int = counts[tp]
		for i in c:
			var n: Node3D = (soldier_meshes[tp] as Node3D).duplicate()
			n.scale = Vector3.ONE * 1.5
			n.position = Vector3((i - (c - 1) / 2.0) * 0.85, 0, 3.6 + row * 1.0)
			root.add_child(n)
			soldier_nodes.append({"node": n, "ph": randf() * TAU})
		row += 1


func _sync_crystals() -> void:
	for n in crystal_nodes:
		(n as Node).queue_free()
	crystal_nodes.clear()
	if crystal_scene == null:
		return
	for c in Game.crystals:
		var n: Node3D = crystal_scene.duplicate()
		n.position = Vector3(float(c["x"]), 0, float(c["z"]))
		n.scale = Vector3.ONE * 1.6
		add_child(n)
		crystal_nodes.append(n)


func _process_stage2(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in crystal_nodes.size():
		var n: Node3D = crystal_nodes[i]
		n.rotation.y += delta * 0.8
		n.position.y = 0.15 + sin(t * 2.2 + i) * 0.15
	for s in soldier_nodes:
		var n: Node3D = s["node"]
		n.position.y = absf(sin(t * 4.0 + float(s["ph"]))) * 0.06
	if raid_anim_t >= 0.0:
		_update_raid_anim(delta)


# ---------------------------------------------------------------- الغارة
func _on_raid(rep: Dictionary) -> void:
	if not is_inside_tree():
		return
	for a in raid_anim:
		(a["node"] as Node).queue_free()
	raid_anim.clear()
	raid_anim_win = rep["win"]
	var gate := Vector3(60, 0, 104)
	var nw := clampi(int(rep["wolves"]) / 3, 4, 16)
	for i in nw:
		var n: Node3D = wolf_scene.duplicate()
		n.scale = Vector3.ONE * 1.3
		var from := Vector3(60 + randf_range(-8, 8), 0, 122 + randf_range(0, 10))
		var to := gate + Vector3(randf_range(-4, 4), 0, randf_range(1.5, 4))
		n.position = from
		add_child(n)
		raid_anim.append({"node": n, "from": from, "to": to, "wolf": true})
	var ns := clampi(Game.troop_total() / 10, 0, 12)
	for i in ns:
		var tp: String = Defs.TROOP_ORDER[i % 3]
		var n: Node3D = (soldier_meshes[tp] as Node3D).duplicate()
		n.scale = Vector3.ONE * 1.6
		var from := Defs.plot_pos("ba1") + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var to := gate + Vector3(randf_range(-4, 4), 0, randf_range(-3.5, -1))
		n.position = from
		add_child(n)
		raid_anim.append({"node": n, "from": from, "to": to, "wolf": false})
	raid_anim_t = 0.0
	_close_panel()
	rig.fly_to(gate + Vector3(0, 0, -2), 38.0, 1.0)


func _update_raid_anim(delta: float) -> void:
	raid_anim_t += delta
	var t := raid_anim_t
	for a in raid_anim:
		var n: Node3D = a["node"]
		var from: Vector3 = a["from"]
		var to: Vector3 = a["to"]
		var p := n.position
		if t < 3.0:
			p = from.lerp(to, smoothstep(0.0, 3.0, t))
		elif t < 4.6:
			p = to + Vector3(sin(t * 20.0 + from.x) * 0.25, 0, cos(t * 17.0 + from.z) * 0.25)
		else:
			var k := clampf((t - 4.6) / 1.8, 0.0, 1.0)
			if a["wolf"]:
				var dest := to + (Vector3(0, 0, 26) if raid_anim_win else Vector3(randf_range(-2, 2), 0, -16))
				p = to.lerp(dest, k)
			else:
				p = to.lerp(to + (Vector3(0, 0, 2) if raid_anim_win else Vector3(0, 0, -6)), k)
		var d := p - n.position
		if d.length() > 0.01:
			n.rotation.y = atan2(d.x, d.z)
		n.position = Vector3(p.x, absf(sin(t * 12.0 + from.x)) * 0.12, p.z)
	if t > 6.6:
		for a in raid_anim:
			(a["node"] as Node).queue_free()
		raid_anim.clear()
		raid_anim_t = -1.0
		_show_raid_report()
