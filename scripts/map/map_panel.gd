extends "res://scripts/map/map_venture.gd"
## الطبقة 4/5 — لوحة الخريطة: اللمس واختيار المدينة أو المعلم وتنفيذ الإجراء ونقل المدينة.


func _on_tap(world: Vector3, _sp: Vector2) -> void:
	var tile := Vector2i(floori(world.x), floori(world.z))
	if tile.x < 0 or tile.y < 0 or tile.x >= 1200 or tile.y >= 1200:
		return
	var info: Dictionary = lookup.get(tile, {})
	# Physical city footprints are registered in lookup. Vacant tiles can
	# additionally use screen-space selection tolerance without overwriting targets.
	if info.is_empty():
		var city := _pick_city(world, _sp)
		if not city.is_empty():
			info = city
	# Enlarged sites retain their logical one-tile destination. Touch tolerance
	# does not expand lookup, change occupancy, or overwrite adjacent entities.
	if resource_sites != null and (info.is_empty() or info.get("kind", "") == "res"):
		var site: Dictionary = resource_sites.pick(world, _sp)
		if not site.is_empty():
			info = site
	if not Game.is_explored(tile.x, tile.y):
		# منطقة مجهولة: لا تسرّب أي تفاصيل عن الكيانات فوقها
		info = {"kind": "unknown", "x": tile.x, "y": tile.y, "pos": Vector3(tile.x + 0.5, world.y, tile.y + 0.5)}
	elif info.is_empty():
		info = {"kind": "empty", "x": tile.x, "y": tile.y, "pos": Vector3(tile.x + 0.5, world.y, tile.y + 0.5)}
	_select(info)


func _select(info: Dictionary) -> void:
	selected = info
	p_action.disabled = false
	placement_preview.visible = false
	var pos: Vector3 = info["pos"]
	var rr := 1.0
	match info["kind"]:
		"res":
			p_title.text = "%s  Lv.%d" % [RES_NAMES[info["t"]], info["l"]]
			p_sub.text = "مورد قابل للجمع"
			p_info.text = "الكمية المتوقعة: %s" % _fmt(RES_GAIN[info["t"]] * info["l"])
			p_action.text = "جمع"
			rr = MapVisuals.RESOURCE_RING_RADIUS
		"beast":
			p_title.text = "%s  Lv.%d" % [BEAST_NAMES[info["t"]], info["l"]]
			p_sub.text = "وحش بري"
			p_info.text = "القوة المقدّرة: %s" % _fmt(info["l"] * 3500)
			p_action.text = "هجوم"
			rr = 1.0
		"city":
			p_title.text = "%s  Lv.%d" % [info["n"], info["l"]]
			p_sub.text = TEAM_NAMES[info["team"]]
			p_info.text = "مساحة المدينة: ٢×٢ خانات بناء كبيرة + حرم فاصل"
			if info["team"] == "me" and not _home_placement_reason(Game.home).is_empty():
				p_info.text = "موقع قديم ضيق؛ انقل المدينة إلى مساحة أوسع"
			p_action.text = {"me": "دخول المدينة", "ally": "تعزيز", "enemy": "هجوم", "neutral": "استطلاع"}[info["team"]]
			rr = MapVisuals.CITY_RING_RADIUS
		"lm":
			p_title.text = info["n"]
			if info["type"] == "stronghold" or info["type"] == "fortress":
				var hd: Dictionary = Defs.HOLD_DEFS[info["type"]]
				if Game.holds.has(String(info["id"])):
					p_sub.text = "تحت سيطرتك"
					p_info.text = "المكافأة الدائمة سارية: %s" % hd["eff"]
					p_action.text = "تفاصيل"
				else:
					p_sub.text = "%s — يحرسه حرّاس" % hd["name"]
					p_info.text = "احتلاله يمنح مكافأة دائمة: %s" % hd["eff"]
					p_action.text = "أرسل فرقة عسكرية"
			else:
				p_sub.text = LM_TYPES[info["type"]]
				p_info.text = "منطقة قابلة للاحتلال في حرب التحالفات"
				p_action.text = "احتلال"
			rr = float(info["r"]) + 0.5
		"vent":
			if Game.vent.get("captured", false):
				p_title.text = "المنفث الحراري — تحت سيطرتك"
				p_sub.text = "منفث جوفي دافئ"
				p_info.text = "يمنح المدينة +%d° دفئًا دائمًا ويخفف أثر جبهات الصقيع" % int(Defs.VENT_HEAT)
				p_action.text = "تفاصيل"
			else:
				p_title.text = "المنفث الحراري"
				p_sub.text = "منفث جوفي دافئ — يحرسه وحوش"
				p_info.text = "احتلاله يمنح المدينة +%d° دفئًا دائمًا — أرسل فرقة عسكرية" % int(Defs.VENT_HEAT)
				p_action.text = "أرسل فرقة عسكرية"
			rr = 1.2
		"unknown":
			p_title.text = "منطقة غير مستكشفة"
			p_sub.text = "ضباب الحرب"
			p_info.text = "أرسل فرقة استطلاع لتكشف ما حول هذه المنطقة"
			p_action.text = "إرسال استطلاع"
			rr = 1.2
		_:
			p_title.text = "أرض خارجية"
			p_sub.text = "فحص مساحة ٢×٢ خانات بناء كبيرة"
			var placement_error := _home_placement_reason(Vector2i(info["x"], info["y"]))
			p_info.text = "المساحة مناسبة لنقل المدينة" if placement_error.is_empty() else placement_error
			p_action.text = "نقل المدينة"
			p_action.disabled = not placement_error.is_empty()
			var valid := placement_error.is_empty()
			placement_fill.albedo_color = Color(0.12, 0.85, 0.38, 0.22) if valid else Color(0.95, 0.12, 0.08, 0.22)
			placement_outline.albedo_color = Color("6dffaa") if valid else Color("ff6558")
			placement_preview.position = pos + Vector3(0, 0.18, 0)
			placement_preview.visible = true
			rr = 5.0
	p_sub.text += "   •   X: %d  Y: %d" % [info["x"], info["y"]]
	panel.visible = true
	if tools_sheet != null:
		tools_sheet.visible = false
	sel_ring.visible = true
	sel_ring.position = pos + Vector3(0, 0.15, 0)
	sel_rr = rr


func _on_action() -> void:
	if selected.is_empty():
		return
	var info := selected
	if info["kind"] == "unknown":
		_send_scout(info)
	elif info["kind"] == "empty":
		_move_home(info)
	elif info["kind"] == "city" and info["team"] == "me":
		_go_city()
	elif info["kind"] == "city" and info["team"] != "neutral" and info["team"] != "enemy":
		_toast("ميزة التعزيز ستتوفر مع نظام الجيش في المرحلة القادمة")
	elif info["kind"] == "lm" and (info["type"] == "stronghold" or info["type"] == "fortress"):
		if Game.holds.has(String(info["id"])):
			_toast("هذا الموقع تحت سيطرتك — المكافأة الدائمة سارية")
		elif not Game.venture.is_empty():
			_toast("الفرقة العسكرية في مهمة بالفعل")
		else:
			_open_venture_window({"kind": "hold", "id": String(info["id"]), "n": String(info["n"])})
	elif info["kind"] == "vent":
		if Game.vent.get("captured", false):
			_toast("المنفث يحرسه جيشك — الدفء مستمر ما دام بيدك")
		elif not Game.venture.is_empty():
			_toast("الفرقة العسكرية في طريقها إلى المنفث")
		else:
			_open_vent_window()
	elif Game.start_march(info):
		Sound.play("march")
		var m: Dictionary = Game.marches.back()
		_toast("انطلقت الفرقة — الوصول خلال %s" % Defs.fmt_time(float(m["arrive"]) - Game.now()))
	_close_panel()


func _move_home(info: Dictionary) -> bool:
	var error := _home_placement_reason(Vector2i(info["x"], info["y"]))
	if not error.is_empty():
		_toast(error)
		return false
	var old_pos: Vector3 = home_info["pos"]
	var old_area: Rect2i = CityPlacement.tiles(Vector2(old_pos.x, old_pos.z))
	for x in range(old_area.position.x, old_area.end.x):
		for y in range(old_area.position.y, old_area.end.y):
			var key := Vector2i(x, y)
			var occupant: Dictionary = lookup.get(key, {})
			if occupant.get("team", "") == "me":
				lookup.erase(key)
	var p: Vector3 = info["pos"]
	home_pos = Vector3(info["x"] + 0.5, p.y, info["y"] + 0.5)
	home_info["x"] = info["x"]
	home_info["y"] = info["y"]
	home_info["pos"] = home_pos
	_register_city(home_info)
	home_node.position = home_pos
	city_clearance_material.set_shader_parameter("home_xz", Vector2(home_pos.x, home_pos.z))
	home_label.position = home_pos + Vector3(0, MapVisuals.CITY_LABEL_HEIGHT, 0)
	Game.home = Vector2i(info["x"], info["y"])
	Game.save_game()
	_toast("تم نقل مدينتك إلى X: %d  Y: %d" % [info["x"], info["y"]])
	return true
