extends "res://scripts/city/city_world.gd"
## الطبقة 4/6 — لوحة المبنى والتفاعل: اللمس والاختيار والترقية والجمع وبناء اللوحة وتحديثها.


# ---------------------------------------------------------------- لوحة المبنى
func _build_building_panel() -> void:
	bp = UI.panel(Color(0.05, 0.1, 0.17, 0.94), 20)
	bp.custom_minimum_size = Vector2(690, 0)
	ui.add_child(bp)
	blockers.append(bp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bp.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var close := UI.button("إغلاق", _close_panel, "dark", 44)
	close.custom_minimum_size = Vector2(90, 44)
	head.add_child(close)
	bp_title = UI.label("", 26, UI.GOLD)
	bp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(bp_title)
	bp_desc = UI.label("", 16, UI.TEXT_DIM)
	bp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bp_desc)
	bp_stats = UI.label("", 18)
	bp_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bp_stats)
	bp_store_row = HBoxContainer.new()
	v.add_child(bp_store_row)
	bp_store_row.add_child(UI.button("جمع", func(): _collect(sel), "green", 44))
	bp_store = UI.label("", 18, Color.WHITE)
	bp_store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_store_row.add_child(bp_store)
	bp_mode_row = HBoxContainer.new()
	bp_mode_row.add_theme_constant_override("separation", 6)
	v.add_child(bp_mode_row)
	for m in [[2, "مضاعف"], [1, "عادي"], [0, "إطفاء"]]:
		var mode: int = m[0]
		var b := UI.button(m[1], func(): Game.set_furnace_mode(mode), "dark", 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		bp_mode_row.add_child(b)
		bp_mode_btns.append([mode, b])
	bp_progress = UI.progress_bar(Color("4fb4ff"))
	v.add_child(bp_progress)
	bp_cost_row = HBoxContainer.new()
	bp_cost_row.add_theme_constant_override("separation", 6)
	bp_cost_row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bp_cost_row)
	var tc := UI.chip("time", 24, 17)
	bp_time = tc[1]
	bp_cost_row.add_child(tc[0])
	for r in ["iron", "coal", "wood"]:
		var c := UI.chip(r, 24, 17)
		bp_cost_row.add_child(c[0])
		bp_cost_chips[r] = c
	bp_reasons = UI.label("", 16, UI.RED)
	bp_reasons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bp_reasons)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	bp_cancel = UI.button("إلغاء", func(): Game.cancel(sel); _refresh_all(), "red", 54)
	bp_speed = UI.button("", func(): Game.speedup(sel), "blue", 54)
	bp_instant = UI.button("", func(): _do_upgrade(true), "blue", 54)
	bp_main = UI.button("", func(): _do_upgrade(false), "gold", 54)
	bp_open = UI.button("", _open_from_panel, "green", 54)
	for b in [bp_open, bp_cancel, bp_speed, bp_instant, bp_main]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	bp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	bp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bp.offset_top -= 170.0   # فوق شريط المهمة وشريط التنقل
	bp.offset_bottom -= 170.0
	bp.visible = false


func _select(id: String) -> void:
	sel = id
	bp.visible = true
	var p := Defs.plot_pos(id)
	sel_ring.visible = true
	sel_ring.position = p + Vector3(0, 0.12, 0)
	var r := 7.5 if id == "furnace" else 2.6
	sel_ring.scale = Vector3(r, 1, r)
	_update_panel()
	# تحريك الكاميرا ليظهر المبنى فوق اللوحة
	rig.fly_to(p + Vector3(0, 0, 6), clampf(rig.dist, 26.0, 45.0), 0.5)


func _update_panel() -> void:
	if sel == "" or not bp.visible:
		return
	var id := sel
	var tp: String = Defs.PLOTS[id]["type"]
	var b: Dictionary = Defs.BUILDINGS[tp]
	var lv := Game.level(id)
	var q := Game.queue_entry(id)
	var chk := Game.check_upgrade(id)
	var nxt: int = chk["next"]
	bp_title.text = "%s — المستوى %d" % [b["name"], lv] if lv > 0 else "بناء: %s" % b["name"]
	bp_desc.text = b["desc"]
	var st: Array[String] = []
	match tp:
		"furnace":
			st.append("الحرارة: +%d° ← +%d°   •   الحرارة الآن داخل المدينة %d°" % [int(Defs.furnace_heat(lv)), int(Defs.furnace_heat(nxt)), int(Game.inside_temp)])
			st.append("استهلاك الفحم: %s في الساعة   •   المخزون %s" % [Defs.fmt(Game.coal_use()), Defs.fmt(Game.res["coal"])])
			if Game.res["coal"] > 0 and Game.coal_use() > 0:
				st.append("يكفي الفحم لمدة %s" % Defs.fmt_time(Game.res["coal"] / Game.coal_use() * 3600.0))
		"shelter":
			st.append("يؤوي: %d ← %d ساكن   •   السكان %d / %d" % [Defs.shelter_capacity(lv), Defs.shelter_capacity(nxt), Game.pop, Game.pop_capacity()])
		"storehouse":
			st.append("مدة تخزين مباني الإنتاج: %s ← %s ساعة" % [str(2.0 + 0.5 * lv), str(2.0 + 0.5 * nxt)])
		"barracks":
			st.append("سعة الجيش: %d ← %d جندي   •   الجيش الآن: %d" % [Defs.camp_capacity(lv), Defs.camp_capacity(nxt), Game.army_count()])
			st.append("الجنود: %d   •   الجرحى: %d" % [Game.troop_total(), Game.wounded_total()])
		"bk_shield", "bk_spear", "bk_bow":
			var ttp := ""
			for k in Defs.BARRACKS_TYPE:
				if Defs.BARRACKS_TYPE[k] == tp:
					ttp = k
			st.append("حجم الدفعة: %d ← %d جندي   •   سرعة التدريب: ×%.2f ← ×%.2f" % [Defs.train_batch(lv), Defs.train_batch(nxt), Defs.barracks_speed(lv), Defs.barracks_speed(nxt)])
			st.append("أعلى رتبة: %s   •   يدرّب: %s" % [Defs.TIER_NAMES[maxi(Game.max_tier_of(ttp), 1)] if lv > 0 else "—", Defs.TROOPS[ttp]["plural"]])
		"hero_hall":
			st.append("الحد الأعلى لمستوى الأبطال: %d ← %d   •   الأبطال: %d / 6" % [lv * 5, mini(nxt * 5, 50), Game.heroes_owned()])
		"lab":
			st.append("مستوى المختبر يفتح أبحاثًا أعمق ومستويات أعلى")
			if not Game.research.is_empty():
				st.append("قيد البحث: %s • متبقٍ %s" % [Defs.TECHS[Game.research["id"]]["name"], Defs.fmt_time(float(Game.research["end"]) - Game.now())])
		"market":
			st.append("رسوم التبادل: %d%% ← %d%%" % [roundi(Defs.market_fee(lv) * 100.0), roundi(Defs.market_fee(nxt) * 100.0)])
			st.append("حصة التبادل كل نصف ساعة: %d ← %d وحدة" % [Defs.market_quota(maxi(lv, 1)), Defs.market_quota(nxt)])
			if Game.storm_active():
				st.append("العاصفة ترفع سعر الفحم والطعام الآن")
		"war_depot":
			st.append("حجم المسيرة العسكرية: %d ← %d جندي" % [Defs.march_capacity(lv), Defs.march_capacity(nxt)])
			st.append("خصم مؤن الحملات: %d%% ← %d%%   •   المؤن: %s طعام لكل جندي" % [roundi(Defs.supply_discount(lv) * 100.0), roundi(Defs.supply_discount(nxt) * 100.0), str(snappedf(Defs.SUPPLY_FOOD_PER_TROOP * (1.0 - Defs.supply_discount(lv)), 0.01))])
			st.append("الحملة الحالية تحمل حتى %d جندي" % Game.march_capacity())
		"scout_tower":
			st.append("نصف قطر الكشف حول المدينة: %d ← %d" % [int(Defs.scout_vision(lv)), int(Defs.scout_vision(nxt))])
			st.append("مدة إنذار الغارة: %s ← %s" % [Defs.fmt_time(Defs.raid_warning_lead(lv)), Defs.fmt_time(Defs.raid_warning_lead(nxt))])
			if lv > 0:
				var fc0 := Game.raid_forecast()
				if fc0["active"]:
					st.append("الغارة القادمة: %s" % _forecast_text(fc0))
			st.append("دقة تقدير الذئاب: %s ← %s   •   من المستوى %d يُذكر الطقس" % [_forecast_acc(lv), _forecast_acc(nxt), Defs.FORECAST_STORM_LEVEL])
		"workshop":
			for gtp in Defs.TROOP_ORDER:
				var g0 := Defs.workshop_gear(gtp, lv)
				var g1 := Defs.workshop_gear(gtp, nxt)
				var gd: Dictionary = Defs.WORKSHOP_GEAR[gtp]
				var parts: Array[String] = []
				for stat in ["atk", "def", "hp"]:
					if gd.has(stat):
						parts.append("%s +%.1f%% ← +%.1f%%" % [{"atk": "هجوم", "def": "دفاع", "hp": "متانة"}[stat], g0[stat] * 100.0, g1[stat] * 100.0])
				st.append("%s: %s" % [gd["name"], "  •  ".join(parts)])
			st.append("أبحاث الحرب فوق المستوى 2 تتطلب ورشة أعلى (كل مستوى بحث = مستويان)")
		"wall":
			var wb0 := Defs.wall_bonuses(lv)
			var wb1 := Defs.wall_bonuses(nxt)
			var ws0 := Defs.wall_stage(lv)
			var ws1 := Defs.wall_stage(nxt)
			st.append("المرحلة: %s (%d/%d)%s" % [Defs.WALL_STAGES[ws0]["name"], ws0, Defs.WALL_STAGES.size() - 1,
				("  ←  %s" % Defs.WALL_STAGES[ws1]["name"]) if ws1 != ws0 else ""])
			st.append("دفاع الجنود: +%d%% ← +%d%%   •   هجوم الأبراج: +%d%% ← +%d%%" % [roundi(wb0["def"] * 100.0), roundi(wb1["def"] * 100.0), roundi(wb0["atk"] * 100.0), roundi(wb1["atk"] * 100.0)])
			st.append("قوة الدفاع الحالية: %d   •   لا يقاتل السور بلا جنود حاضرين" % int(Game.defense_profile()["power"]))
			if ws1 < Defs.WALL_STAGES.size() - 1 and ws1 == ws0:
				var nx: Dictionary = Defs.WALL_STAGES[ws0 + 1]
				st.append("المرحلة التالية «%s» عند المستوى %d وتتطلب الفرن %d" % [nx["name"], nx["from"], nx["furnace"]])
			if Game.bonus("wall_def") + Game.bonus("tower_atk") + Game.bonus("wall_hp") > 0.0:
				st.append("أبحاث الدفاع: دفاع +%d%%  •  هجوم الأبراج +%d%%  •  متانة +%d%%" % [roundi(Game.bonus("wall_def") * 100.0), roundi(Game.bonus("tower_atk") * 100.0), roundi(Game.bonus("wall_hp") * 100.0)])
			var fneed := 0
			for k in Defs.FURNACE_NEEDS_WALL:
				if Game.furnace_level() < int(k) and (fneed == 0 or int(k) < fneed):
					fneed = int(k)
			if fneed > 0:
				st.append("الفرن المستوى %d يتطلب السور بمرحلة «%s»" % [fneed, Defs.WALL_STAGES[Defs.furnace_wall_need(fneed)]["name"]])
		"infirmary":
			st.append("حصة القتلى من خسائر المعارك: %d%% ← %d%%" % [roundi(25.0 * Defs.death_mult(lv, 0.0)), roundi(25.0 * Defs.death_mult(nxt, 0.0))])
			st.append("العلاج: %.1f ← %.1f مريض في الدقيقة   •   المرضى %d" % [0.6 * lv, 0.6 * nxt, int(Game.sick)])
			st.append("الجرحى: %d / %d" % [Game.wounded_total(), Game.wounded_cap()])
			st.append("العمال: %d / %d" % [int(Game.workers.get(id, 0)), Defs.workers_needed(tp, lv)])
		_:
			if b.has("prod"):
				var r: String = b["prod"]
				st.append("الإنتاج: %s ← %s %s في الساعة" % [Defs.fmt(Defs.prod_rate(tp, lv)), Defs.fmt(Defs.prod_rate(tp, nxt)), Defs.RES_NAMES[r]])
				if lv > 0:
					st.append("العمال: %d / %d   •   الإنتاج الفعلي %s في الساعة" % [int(Game.workers.get(id, 0)), Defs.workers_needed(tp, lv), Defs.fmt(Game.current_rate(id))])
	bp_stats.text = "\n".join(st)
	var has_store := b.has("prod") and lv > 0
	bp_store_row.visible = has_store
	if has_store:
		bp_store.text = "جاهز للجمع: %s / %s" % [Defs.fmt(float(Game.stored.get(id, 0.0))), Defs.fmt(Game.storage_cap(id))]
	bp_mode_row.visible = tp == "furnace"
	for mb in bp_mode_btns:
		(mb[1] as Button).set_pressed_no_signal(Game.furnace_mode == mb[0])
		(mb[1] as Button).modulate = Color(1.25, 1.1, 0.7) if Game.furnace_mode == mb[0] else Color.WHITE
	var building := not q.is_empty()
	var opens := {"barracks": "فتح المعسكر", "bk_shield": "تدريب الدروع", "bk_spear": "تدريب الرماح", "bk_bow": "تدريب الرماة", "hero_hall": "الأبطال", "lab": "الأبحاث", "market": "فتح السوق", "workshop": "الورشة الحربية"}
	bp_open.visible = opens.has(tp) and lv > 0
	if bp_open.visible:
		bp_open.text = opens[tp]
	bp_progress.visible = building
	bp_cost_row.visible = not building and nxt <= int(b["max"])
	bp_speed.visible = building
	bp_cancel.visible = building
	bp_main.visible = not building
	bp_instant.visible = not building
	if building:
		var total := float(q["end"]) - float(q["start"])
		var remain := float(q["end"]) - Game.now()
		bp_progress.value = 100.0 * (1.0 - remain / maxf(total, 0.01))
		var g := Game.gems_for_time(remain)
		bp_speed.text = "تسريع مجاني" if g == 0 else "تسريع • %d جوهرة" % g
		bp_speed.disabled = not Game.dev_mode and Game.gems < g
		bp_reasons.text = "قيد البناء إلى المستوى %d • متبقٍ %s" % [int(q["level"]), Defs.fmt_time(remain)]
		bp_reasons.add_theme_color_override("font_color", Color("7fd3ff"))
		return
	bp_reasons.add_theme_color_override("font_color", UI.RED)
	var cost: Dictionary = chk["cost"]
	for r in bp_cost_chips:
		var c: Array = bp_cost_chips[r]
		(c[0] as Control).visible = cost.has(r)
		if cost.has(r):
			(c[1] as Label).text = Defs.fmt(cost[r])
			(c[1] as Label).add_theme_color_override("font_color", UI.RED if Game.res[r] < cost[r] else Color.WHITE)
	bp_time.text = Defs.fmt_time(chk["time"])
	var reasons: Array = chk["reasons"].duplicate()
	if not chk["missing"].is_empty():
		var miss: Array[String] = []
		for r in chk["missing"]:
			miss.append("%s %s" % [Defs.fmt(chk["missing"][r]), Defs.RES_NAMES[r]])
		reasons.append("ينقصك: " + "، ".join(miss))
	if not chk["builders_free"]:
		reasons.append("كل البنائين مشغولون (يمكنك البناء الفوري)")
	bp_reasons.text = "\n".join(reasons)
	bp_main.text = "تطوير" if lv > 0 else "بناء"
	bp_main.disabled = not chk["ok"]
	var gi := Game.gems_for_time(chk["time"])
	bp_instant.text = "فوري • %d جوهرة" % gi if gi > 0 else "فوري • مجاني"
	bp_instant.disabled = not chk["reasons"].is_empty() or not chk["missing"].is_empty() or (not Game.dev_mode and Game.gems < gi)


func _do_upgrade(instant: bool) -> void:
	if Game.start_upgrade(sel, instant):
		_refresh_plot(sel)
		if not instant:
			_toast("بدأ البناء")
	_update_panel()


func _collect(id: String) -> void:
	var tp: String = Defs.PLOTS[id]["type"]
	var v := Game.collect(id)
	if v > 0:
		Sound.play("collect")
		_float_text("+" + Defs.fmt(v), Defs.plot_pos(id) + Vector3(0, plot_nodes[id]["top"] + 1.0, 0), Defs.BUILDINGS[tp]["prod"])
	_update_panel()


func _collect_all() -> void:
	var got := {}
	for id in Defs.PLOTS:
		var tp: String = Defs.PLOTS[id]["type"]
		if not Defs.BUILDINGS[tp].has("prod"):
			continue
		var v := Game.collect(id)
		if v > 0:
			got[Defs.BUILDINGS[tp]["prod"]] = float(got.get(Defs.BUILDINGS[tp]["prod"], 0.0)) + v
			_float_text("+" + Defs.fmt(v), Defs.plot_pos(id) + Vector3(0, plot_nodes[id]["top"] + 1.0, 0), Defs.BUILDINGS[tp]["prod"])
	if got.is_empty():
		_toast("لا توجد موارد جاهزة للجمع الآن")
	else:
		var parts: Array[String] = []
		for r in got:
			parts.append("%s %s" % [Defs.fmt(got[r]), Defs.RES_NAMES[r]])
		_toast("تم جمع: " + "، ".join(parts))


# ---------------------------------------------------------------- النقر
func _on_tap(world: Vector3, sp: Vector2) -> void:
	# فقاعات الجمع أولًا (بالمسافة على الشاشة)
	var cam: Camera3D = rig.cam
	for i in crystal_nodes.size():
		var cn: Node3D = crystal_nodes[i]
		var cp := cn.global_position + Vector3(0, 0.6, 0)
		if not cam.is_position_behind(cp) and cam.unproject_position(cp).distance_to(sp) < 55.0:
			var v := Game.collect_crystal(i)
			if v > 0:
				_float_text("+%d" % v, cp + Vector3(0, 1.0, 0), "aurora")
			return
	for id in plot_nodes:
		var bub: Sprite3D = plot_nodes[id]["bubble"]
		if bub.visible and not cam.is_position_behind(bub.global_position):
			if cam.unproject_position(bub.global_position).distance_to(sp) < 46.0:
				_collect(id)
				return
	var best := ""
	var bd := 1e9
	for id in Defs.PLOTS:
		var p := Defs.plot_pos(id)
		var d := Vector2(world.x - p.x, world.z - p.z).length()
		var lim := 7.0 if id == "furnace" else 3.6
		if d < lim and d < bd:
			bd = d
			best = id
	if best == "" and Defs.on_wall_ring(world.x, world.z):
		best = Defs.WALL_PLOT   # لمس السور نفسه يفتح لوحته
	if best == "":
		_close_panel()
		return
	if Game.level(best) > 0 and float(Game.stored.get(best, 0.0)) >= 1.0:
		_collect(best)
	_select(best)


func _refresh_all() -> void:
	for id in plot_nodes:
		_refresh_plot(id)
	_update_panel()


func _open_from_panel() -> void:
	var tp: String = Defs.PLOTS[sel]["type"]
	match tp:
		"barracks":
			_show_army()
		"bk_shield":
			_show_training("shield")
		"bk_spear":
			_show_training("spear")
		"bk_bow":
			_show_training("bow")
		"hero_hall":
			_show_heroes()
		"lab":
			_show_research()
		"market":
			MarketWin.show(self)
		"workshop":
			_show_workshop()
