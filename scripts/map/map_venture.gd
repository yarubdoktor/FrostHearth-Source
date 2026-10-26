extends "res://scripts/map/map_scene.gd"
## الطبقة 3/5 — نافذة الحملة: اختيار الجنود والتشكيل وإرسال الحملة أو الاستطلاع.


# ================================================================ المرحلة 3: نافذة الفرقة العسكرية
func _open_vent_window() -> void:
	_open_venture_window({})


func _open_venture_window(target: Dictionary) -> void:
	## نافذة إرسال الفرقة العسكرية — تصلح للمنفث وللمعاقل والقلاع، والتشكيل يُختار هنا
	## Stage 33: أعداد المرسلين ونسب جاهزة وتوصية + معاينة فرصة النصر والخسائر والزمن والدفاع المتبقي
	venture_target = target
	venture_formation = "balanced"
	_close_vent_window()
	vent_win = _panel(Control.PRESET_CENTER)
	vent_win.custom_minimum_size = Vector2(440, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	vent_win.add_child(v)
	var title := Label.new()
	var tname := "المنفث الحراري"
	if not target.is_empty() and str(target.get("kind", "vent")) == "hold":
		tname = str(target.get("n", "الهدف"))
	title.text = "الفرقة العسكرية نحو " + tname
	title.add_theme_color_override("font_color", Color("ffd36b"))
	v.add_child(title)
	if not Game.venture.is_empty():
		var busy := Label.new()
		busy.text = "الفرقة العسكرية في مهمة — تعود بعد %s" % Defs.fmt_time(float(Game.venture.get("back", 0.0)) - Game.now())
		busy.add_theme_color_override("font_color", Color("ff9a8a"))
		busy.add_theme_font_size_override("font_size", 15)
		v.add_child(busy)
	var hint := Label.new()
	hint.text = "الجنود المرسلون يغادرون المدينة ولا يدافعون عنها حتى يعودوا. اختر العدد ثم راجع فرصة النصر والدفاع المتبقي."
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	# صفوف الجنود داخل حاوية تمرير محدودة الارتفاع — حتى لا تتجاوز النافذة شاشة الهاتف
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 88)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_FILL
	v.add_child(scroll)
	# صفّان جانبيان يقللان ارتفاع قائمة الجنود مع بقاء جميع الأنواع قابلة للتعديل.
	var list := GridContainer.new()
	list.columns = 3
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_FILL
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 4)
	scroll.add_child(list)
	vent_spins = {}
	var any_troops := false
	for k in Game.troops:
		var n := int(Game.troops[k])
		if n <= 0:
			continue
		any_troops = true
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(row)
		var parts: PackedStringArray = String(k).split("_")
		var nm := "%s • %s" % [Defs.TROOPS[parts[0]]["name"], Defs.TIER_NAMES[int(parts[1])]]
		var l := Label.new()
		l.text = "%s (%d)" % [nm, n]
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 12)
		l.custom_minimum_size.x = 54
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var sp := SpinBox.new()
		sp.custom_minimum_size = Vector2(60, 30)
		sp.add_theme_font_size_override("font_size", 12)
		sp.max_value = n
		sp.min_value = 0
		sp.step = 1
		sp.value = 0
		sp.value_changed.connect(func(_v): _update_vent_summary())
		row.add_child(sp)
		vent_spins[k] = sp
	if not any_troops:
		var empty := Label.new()
		empty.text = "لا يوجد جنود — درّب جيشًا من المعسكر أولًا"
		empty.add_theme_color_override("font_color", Color("ff9a8a"))
		v.add_child(empty)
	# نسب جاهزة + توصية
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 6)
	v.add_child(qh)
	for pr in [[0.25, "٢٥٪"], [0.5, "٥٠٪"], [0.75, "٧٥٪"], [1.0, "الأقصى"]]:
		var frac: float = pr[0]
		var qb := _button(str(pr[1]), func(): _fill_fraction(frac))
		qb.custom_minimum_size.y = 38
		qb.add_theme_font_size_override("font_size", 13)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qh.add_child(qb)
	var rec := _button("توصية", func(): _suggest_fill(), true)
	rec.custom_minimum_size.y = 38
	rec.add_theme_font_size_override("font_size", 13)
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.tooltip_text = "أقل قوة تحقق فرصة نصر جيدة ضمن حجم المسيرة المسموح"
	qh.add_child(rec)
	var zero_btn := _button("صفر", func(): _fill_fraction(0.0))
	zero_btn.custom_minimum_size.y = 38
	zero_btn.add_theme_font_size_override("font_size", 13)
	qh.add_child(zero_btn)
	vent_summary = Label.new()
	vent_summary.add_theme_font_size_override("font_size", 15)
	vent_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(vent_summary)
	vent_verdict = Label.new()
	vent_verdict.add_theme_font_size_override("font_size", 15)
	vent_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(vent_verdict)
	vent_home = Label.new()
	vent_home.add_theme_font_size_override("font_size", 14)
	vent_home.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(vent_home)
	# التشكيلات القتالية: ثلاثة أزرار تبادل
	var ftitle := Label.new()
	ftitle.text = "تشكيل القتال"
	ftitle.add_theme_color_override("font_color", Color("ffd36b"))
	v.add_child(ftitle)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	v.add_child(fh)
	_formation_btns = {}
	for fid in Defs.FORMATION_ORDER:
		var fd: Dictionary = Defs.FORMATIONS[fid]
		var fb := _button(fd["name"], func(): _pick_formation(String(fid)))
		fb.custom_minimum_size.y = 38
		fb.add_theme_font_size_override("font_size", 13)
		fb.toggle_mode = true
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.tooltip_text = str(fd["desc"])
		fh.add_child(fb)
		_formation_btns[fid] = fb
	var fdesc := Label.new()
	fdesc.add_theme_font_size_override("font_size", 14)
	fdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fdesc.add_theme_color_override("font_color", Color("b9cbe0"))
	v.add_child(fdesc)
	_formation_desc = fdesc
	_pick_formation("balanced")
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var send := _button("إرسال الفرقة", func(): _send_venture(), true)
	send.disabled = not any_troops
	vent_send_btn = send
	send.custom_minimum_size.y = 38
	send.add_theme_font_size_override("font_size", 13)
	hb.add_child(send)
	var cancel_btn := _button("إلغاء", _close_vent_window)
	cancel_btn.custom_minimum_size.y = 38
	cancel_btn.add_theme_font_size_override("font_size", 13)
	hb.add_child(cancel_btn)
	ui_blockers.append(vent_win)
	if any_troops:
		_suggest_fill()   # يبدأ باقتراح أقل قوة تحقق فرصة نصر جيدة؛ وللاعب تعديلها بحرية
	else:
		_update_vent_summary()
	_center_vent_win_soon()


func _center_vent_win_soon() -> void:
	## ينتظر استقرار التخطيط أولًا — القياس قبل التخطيط يعطي ارتفاعًا مؤقتًا ضخمًا للنص الملتف
	await get_tree().process_frame
	_center_vent_win()


func _center_vent_win() -> void:
	## توسيط فعلي بعد اكتمال المحتوى — النافذة تنمو للأسفل من نقطة الوسط فتغطي أزرار التنقل السفلية
	if vent_win == null or ui == null:
		return
	var h := minf(vent_win.size.y, minf(ui.size.y - 112.0, 600.0))
	# نافذة مثبتة بحجم صريح؛ وضع MINSIZE الافتراضي يعيد تمديدها إلى 711px رغم حد الارتفاع.
	vent_win.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	vent_win.clip_contents = true
	vent_win.size = Vector2(maxf(vent_win.size.x, 440.0), h)
	vent_win.position = (ui.size - vent_win.size) * 0.5


func _vent_units() -> Dictionary:
	var units := {}
	for k in vent_spins:
		var n := int(vent_spins[k].value)
		if n > 0:
			units[k] = n
	return units


func _vent_cap() -> int:
	return 999999 if Game.dev_mode else Game.march_capacity()


func _fill_fraction(frac: float) -> void:
	## تعبئة كل الصفوف بنسبة من المتاح ضمن سقف المسيرة (توزيع تناسبي على الأنواع)
	var avail := {}
	for k in vent_spins:
		avail[k] = int(vent_spins[k].max_value)
	var fill: Dictionary = Game.WarRules.quick_fill(avail, frac, _vent_cap())
	for k in vent_spins:
		vent_spins[k].set_value_no_signal(float(fill.get(k, 0)))
	_update_vent_summary()


func _suggest_fill() -> void:
	## أقل نسبة من الجيش تحقق فرصة نصر جيدة؛ وإن لم توجد فالأقصى المسموح مع تنبيه في الملخص
	var avail := {}
	for k in vent_spins:
		avail[k] = int(vent_spins[k].max_value)
	var chosen := 1.0
	for frac in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]:
		var fill: Dictionary = Game.WarRules.quick_fill(avail, frac, _vent_cap())
		if fill.is_empty():
			continue
		var pv := Game.venture_preview(fill, venture_formation, venture_target)
		chosen = frac
		if int(pv["win_lo"]) >= Game.WarRules.SEND_GOAL_PCT:
			break
	_fill_fraction(chosen)


func _update_vent_summary() -> void:
	## حجم المسيرة المسموح والمؤن + معاينة المعركة والدفاع المتبقي — يتحدث مع كل تغيير في الأعداد أو التشكيل
	if vent_summary == null or not is_instance_valid(vent_summary):
		return
	var units := _vent_units()
	var pv := Game.venture_preview(units, venture_formation, venture_target)
	var chk: Dictionary = pv["check"]
	var line := "حجم المسيرة: %d / %d   •   المؤن: %s طعام" % [chk["total"], chk["cap"], Defs.fmt(float(chk["cost"]))]
	if int(chk["total"]) > 0:
		line += "\nالقوة المرسلة ≈ %d   •   الذهاب %s   •   الرحلة كاملة %s" % [pv["power"], Defs.fmt_time(float(pv["travel"])), Defs.fmt_time(float(pv["round_trip"]))]
	if chk["reason"] != "" and chk["total"] > 0:
		line += "\n" + String(chk["reason"])
	vent_summary.text = line
	vent_summary.add_theme_color_override("font_color", Color("ff9a8a") if (chk["total"] > 0 and not chk["ok"]) else Color("b9cbe0"))
	if vent_verdict != null and is_instance_valid(vent_verdict):
		var enemy := "%d" % int(pv["enemy_n"])
		if float(pv["intel_err"]) > 0.0:
			enemy = "نحو %d–%d" % [pv["enemy_lo"], pv["enemy_hi"]]
		var vt := "%s: %s حارس" % [pv["enemy_name"], enemy]
		if float(pv["intel_err"]) > 0.0:
			vt += " (دقة ±%d٪ — يحسّنها برج الاستطلاع)" % int(round(float(pv["intel_err"]) * 100.0))
		if int(chk["total"]) > 0:
			var vd: Dictionary = Game.WarRules.verdict(int(pv["win_lo"]))
			var chance := "%d٪" % int(pv["win_lo"]) if int(pv["win_lo"]) == int(pv["win_hi"]) else "%d–%d٪" % [pv["win_lo"], pv["win_hi"]]
			vt += "\nفرصة النصر: %s — %s" % [chance, vd["text"]]
			vt += "\nخسائرك المتوقعة ≈ %d٪ • خسائر الحرّاس ≈ %d٪" % [pv["att_loss_pct"], pv["def_loss_pct"]]
			if int(pv["win_lo"]) < 50 and int(pv["retreat_pct"]) > 0:
				vt += "\nإن خسرت تتراجع الفرقة قبل الفناء وتعود بناجين"
			vent_verdict.add_theme_color_override("font_color", Color(String(vd["color"])))
		else:
			vent_verdict.add_theme_color_override("font_color", Color("b9cbe0"))
		vent_verdict.text = vt
	if vent_home != null and is_instance_valid(vent_home):
		if int(chk["total"]) <= 0:
			vent_home.text = ""
		else:
			var hold := int(pv["home_hold_pct"])
			var ht := "يبقى في المدينة %d جندي" % int(pv["remaining_total"])
			if int(pv["remaining_total"]) <= 0:
				ht = "ستبقى المدينة بلا جنود"
			ht += " • صمودها أمام الغارة القادمة (%d ذئب): %d٪" % [pv["raid_n"], hold]
			vent_home.text = ht
			vent_home.add_theme_color_override("font_color", Color("ff9a8a") if hold < 60 else (Color("ffd36b") if hold < 85 else Color("b9cbe0")))
	if vent_send_btn != null and is_instance_valid(vent_send_btn):
		vent_send_btn.disabled = not chk["ok"] or not Game.venture.is_empty()


func _pick_formation(fid: String) -> void:
	venture_formation = fid
	for k in _formation_btns:
		(_formation_btns[k] as Button).button_pressed = String(k) == fid
	if _formation_desc != null:
		_formation_desc.text = str(Defs.FORMATIONS[fid]["desc"])
	_update_vent_summary()


func _close_vent_window() -> void:
	if vent_win != null:
		ui_blockers.erase(vent_win)
		vent_win.queue_free()
		vent_win = null
	vent_spins = {}
	vent_summary = null
	vent_verdict = null
	vent_home = null
	vent_send_btn = null
	_formation_desc = null


func _send_venture() -> void:
	var units := {}
	for k in vent_spins:
		var n := int(vent_spins[k].value)
		if n > 0:
			units[k] = n
	var tgt := venture_target
	if Game.start_venture(units, venture_formation, tgt):
		Sound.play("march")
		_toast("انطلقت الفرقة العسكرية بتشكيل «%s»" % Defs.FORMATIONS[venture_formation]["name"])
		_close_vent_window()
		_close_panel()


func _send_scout(info: Dictionary) -> void:
	## فرقة استطلاع نحو منطقة مجهولة: تشغل خانة فرق، وتكشف عند الوصول ثم تعود
	if Game.marches.size() >= Game.MAX_MARCHES:
		_toast("كل الفرق في مهمة — انتظر عودة إحداها")
		return
	if Game.start_march({"kind": "scout", "x": int(info["x"]), "y": int(info["y"])}):
		Sound.play("march")
		var m: Dictionary = Game.marches.back()
		_toast("انطلقت فرقة الاستطلاع — الوصول خلال %s" % Defs.fmt_time(float(m["arrive"]) - Game.now()))
		_close_panel()
