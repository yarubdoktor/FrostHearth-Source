extends "res://scripts/city/city_panel.gd"
## الطبقة 5/6 — ردود الأحداث: تغيّر حالة اللعبة والبناء المكتمل والطابور الجانبي والمهام وإدخال الشريحة والبنّائين.


func _chip_input(e: InputEvent, what: String) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	match what:
		"temp":
			var st: String = ["دافئة", "باردة — يمرض السكان ببطء", "متجمدة — يمرض السكان بسرعة والإنتاج نصفه"][Game.cold_level]
			_toast("الخارج %d° • الداخل %d° • المدينة %s" % [int(Game.outside_temp), int(Game.inside_temp), st])
		"pop":
			_toast("السكان %d من %d • الأصحاء %d • المرضى %d • يأكل كل ساكن 6 طعام في الساعة" % [Game.pop, Game.pop_capacity(), Game.healthy(), int(Game.sick)])
		"gems":
			_toast("الجواهر تُستخدم لتسريع البناء. تحصل عليها من المهام والمكافأة اليومية")
		"aurora":
			_toast("بلورات الشفق: تظهر في المدينة أثناء العواصف، المسها لجمعها. تستدعي بها الأبطال وتطوّر أبحاثًا خاصة")
		"trust":
			_toast("ثقة الناس %d%% • تغيّر الإنتاج بين −10%% و+10%% • تتأثر بقراراتك والبرد والجوع والغارات" % int(Game.trust))
		"power":
			_toast("قوة المدينة: الجنود والمباني والأبطال والأبحاث مجتمعة")
		_:
			var n := Game.net_rate(what)
			_toast("%s: %s • الصافي %s%s في الساعة" % [Defs.RES_NAMES[what], Defs.fmt(Game.res[what]), "+" if n >= 0 else "", Defs.fmt(n)])


func _builder_input(e: InputEvent, idx: int) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if idx < Game.queue.size():
		var id: String = Game.queue[idx]["plot"]
		_select(id)
	elif idx >= Game.builder_count():
		_toast("البنّاء %d يُفتح عند الفرن المستوى %d" % [idx + 1, Game.next_builder_unlock()])
	else:
		_toast("البنّاء متاح — اضغط على مبنى لتطويره")


# ---------------------------------------------------------------- الأحداث
func _on_building_done(id: String) -> void:
	if not plot_nodes.has(id):
		return
	_refresh_all()
	var p := Defs.plot_pos(id)
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 40
	burst.lifetime = 1.2
	burst.explosiveness = 0.9
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 8.0
	burst.gravity = Vector3(0, -6, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.18, 0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = UI.GOLD
	m.material = mat
	burst.mesh = m
	burst.position = p + Vector3(0, 2, 0)
	add_child(burst)
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


func _on_changed() -> void:
	for r in res_chips:
		(res_chips[r] as Label).text = Defs.fmt(Game.res[r])
		(res_chips[r] as Label).add_theme_color_override("font_color", UI.RED if Game.net_rate(r) < 0 and Game.res[r] < 200 else Color.WHITE)
	gem_label.text = Defs.fmt(Game.gems)
	aurora_label.text = Defs.fmt(Game.aurora)
	trust_label.text = "%d%%" % int(Game.trust)
	trust_label.add_theme_color_override("font_color", UI.GREEN if Game.trust >= 50 else (Color("ffd36b") if Game.trust >= 25 else UI.RED))
	power_label.text = Defs.fmt(Game.power())
	_update_side()
	HomeHud.refresh(self)
	temp_label.text = "%d°" % int(round(Game.inside_temp))
	var tcol: Color = [UI.GREEN, Color("ffd36b"), UI.RED][Game.cold_level]
	temp_label.add_theme_color_override("font_color", tcol)
	pop_label.text = "%d/%d" % [Game.pop, Game.pop_capacity()]
	sick_label.text = str(int(Game.sick))
	var open_builders := maxi(Game.builder_count(), Game.queue.size())   # المطور قد يتجاوز العدد
	var lock_at := Game.next_builder_unlock()
	for i in builder_rows.size():
		var row: Dictionary = builder_rows[i]
		var pnl: Control = row["panel"]
		# صف لكل بنّاء مفتوح + صف واحد مقفل يوضح متى يُفتح البنّاء التالي
		pnl.visible = i < open_builders or (i == open_builders and lock_at > 0)
		if i < Game.queue.size():
			var q: Dictionary = Game.queue[i]
			var tp: String = Defs.PLOTS[q["plot"]]["type"]
			var remain := float(q["end"]) - Game.now()
			(row["label"] as Label).text = "%s %d • %s" % [Defs.BUILDINGS[tp]["name"], int(q["level"]), Defs.fmt_time(remain)]
			(row["bar"] as ProgressBar).value = 100.0 * (1.0 - remain / maxf(float(q["end"]) - float(q["start"]), 0.01))
		elif i < open_builders:
			(row["label"] as Label).text = "البنّاء %d: متاح" % (i + 1)
			(row["bar"] as ProgressBar).value = 0
		else:
			(row["label"] as Label).text = "البنّاء %d: يفتح بالفرن %d" % [i + 1, lock_at]
			(row["bar"] as ProgressBar).value = 0
	# المهمة
	var tt := Game.tracked_task()
	if tt.is_empty():
		task_title.text = "أنهيت كل المهام الحالية"
		task_prog.text = "مهام جديدة في المرحلة القادمة"
		task_btn.visible = false
	else:
		var tk: Dictionary = tt["tk"]
		var pr := Game.task_progress(tk)
		task_title.text = ("الفصل الثاني • " if tt["ch"] == 2 else "") + str(tk["text"])
		var rws := Defs.reward_text(tk["reward"])
		var one: bool = tk["type"] in ["temp", "defender", "governor"]
		task_prog.text = "%s / %s   •   المكافأة: %s" % [Defs.fmt(minf(pr.x, pr.y)), Defs.fmt(pr.y), rws] if not one else "المكافأة: " + rws
		task_btn.visible = true
		var done := Game.task_done(tk)
		task_btn.text = "استلام" if done else "اذهب"
		task_btn.modulate = Color(1, 1, 1) if done else Color(0.75, 0.8, 0.9)
	# العاصفة
	var soon := Game.storm_soon()
	if Game.storm_active():
		storm_label.visible = true
		storm_label.text = "عاصفة ثلجية • -22° • تنتهي خلال %s" % Defs.fmt_time(Game.storm_end - Game.now())
	elif soon > 0:
		storm_label.visible = true
		storm_label.text = "تحذير: عاصفة ثلجية خلال %s — جهّز الفحم" % Defs.fmt_time(soon)
	elif Game.raid_soon() > 0:
		storm_label.visible = true
		storm_label.text = "غارة ذئاب خلال %s — جهّز جنودك وعيّن قائد الدفاع" % Defs.fmt_time(Game.raid_soon())
	else:
		storm_label.visible = false
	# إعادة بناء المواقع عند تغيّر المستويات أو الطابور
	var sig := str(Game.plots) + str(Game.queue.size()) + str(Game.furnace_level())
	if sig != _last_sig:
		_last_sig = sig
		_refresh_all()
	_update_panel()
	_sync_citizens()
	_sync_soldiers()
	for f in win_tick:
		(f as Callable).call()


func _task_action() -> void:
	var tt := Game.tracked_task()
	if tt.is_empty():
		return
	var tk: Dictionary = tt["tk"]
	if Game.task_done(tk):
		if tt["ch"] == 1:
			Game.claim_task()
		else:
			Game.claim_task2()
		Sound.play("collect")
		return
	match tk["type"]:
		"train", "raid_win", "power":
			_show_army()
			return
		"hero", "hero_lv", "defender", "governor":
			_show_heroes()
			return
		"research":
			_show_research()
			return
		"decision":
			_show_decision()
			return
		"aurora":
			_toast("تظهر بلورات الشفق في المدينة أثناء العواصف الثلجية، المسها لجمعها")
			return
	# الذهاب إلى المبنى المناسب
	var tp: String = tk.get("b", "")
	if tk["type"] == "collect":
		tp = {"food": "hunter", "wood": "sawmill", "coal": "coal_mine", "iron": "iron_mine"}[tk["r"]]
	elif tk["type"] == "pop":
		tp = "shelter"
	elif tk["type"] == "temp":
		tp = "furnace"
	elif tk["type"] == "march":
		_go_map()
		return
	var target := ""
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] != tp:
			continue
		if tk["type"] == "count" and Game.level(id) == 0 and Game.furnace_level() >= int(Defs.PLOTS[id]["unlock"]):
			target = id
			break
		if target == "" or Game.level(id) > Game.level(target):
			target = id
	if target != "":
		_select(target)


# ---------------------------------------------------------------- الأزرار الجانبية
func _update_side() -> void:
	if side_btns.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var dec: Button = side_btns["decision"]
	if Game.pending_decision >= 0:
		dec.modulate = Color(1.0, 0.9 + 0.1 * sin(t * 5.0), 0.6)
		dec.text = "قرار جديد"
	else:
		dec.modulate = Color.WHITE
		dec.text = "دفتر القائد"
	var army: Button = side_btns["army"]
	var tr_end := Game.train_next_end()
	army.text = "الجيش\n%s" % Defs.fmt_time(tr_end - Game.now()) if tr_end > 0.0 else "الجيش"
	if Game.raid_next > 0.0:
		raid_label.visible = true
		raid_label.text = "الغارة القادمة\n%s" % Defs.fmt_time(Game.raid_next - Game.now())
		var fc := Game.raid_forecast()
		if fc["active"]:
			raid_label.text += "\n%s" % _forecast_text(fc)
		raid_label.add_theme_color_override("font_color", UI.RED if Game.raid_soon() > 0 else Color.WHITE)
	else:
		raid_label.visible = false
