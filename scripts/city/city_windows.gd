extends "res://scripts/city/city_core.gd"
## الطبقة 2/6 — النوافذ: غلاف نوافذ الجيش والأبطال والأبحاث والملف الشخصي والإعدادات والمطور، والنوافذ المنبثقة (_modal) والمهام وتقرير الغارة.


# ---------------------------------------------------------------- النوافذ
func _modal(title: String, body: String, buttons: Array, icon_name: String = "") -> Control:
	_close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var p := UI.panel(Color(0.06, 0.11, 0.19, 0.97), 22)
	p.custom_minimum_size = Vector2(620, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	h.add_child(UI.label(title, 26, UI.GOLD))
	if icon_name != "":
		h.add_child(UI.icon_rect(icon_name, 44))
	if body != "":
		var b := UI.label(body, 19)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(580, 0)
		v.add_child(b)
	# أكثر من زرين: عمود بعرض النافذة (الشاشة عمودية) • زرّان فقط: صف كما كان
	var stacked: bool = buttons.size() > 2
	var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for bt in buttons:
		if stacked and bt.size() > 2 and bt[2] == "red":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 14)   # مسافة تفصل الزر الخطر عن البقية
			row.add_child(gap)
		var cb: Callable = bt[1]
		var btn := UI.button(bt[0], func():
			dim.queue_free()
			cb.call(), bt[2] if bt.size() > 2 else "dark", 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return v


func _show_daily() -> void:
	var rw := Game.daily_reward()
	var parts: Array[String] = []
	for k in rw:
		parts.append("• %s: %s" % [Defs.RES_NAMES[k], Defs.fmt(rw[k])])
	_modal("المكافأة اليومية", "هدية اليوم لمدينتك:\n" + "\n".join(parts), [["استلام", func(): Game.claim_daily(), "gold"]], "gift")


func _show_tasks() -> void:
	var lines: Array[String] = []
	for i in Defs.TASKS.size():
		var tk: Dictionary = Defs.TASKS[i]
		var mark := "✓" if i < Game.task_index else ("◀" if i == Game.task_index else "•")
		lines.append("%s  %s" % [mark, tk["text"]])
		if i > Game.task_index + 3:
			lines.append("…")
			break
	if Game.chapter2_open():
		lines.append("")
		lines.append("الفصل الثاني (%d / %d):" % [mini(Game.task2_index, Defs.TASKS2.size()), Defs.TASKS2.size()])
		for i in range(Game.task2_index, mini(Game.task2_index + 4, Defs.TASKS2.size())):
			lines.append("%s  %s" % ["◀" if i == Game.task2_index else "•", Defs.TASKS2[i]["text"]])
	var title := "المهام • الفصل الأول (%d / %d)" % [mini(Game.task_index, Defs.TASKS.size()), Defs.TASKS.size()]
	var btns: Array = [["إغلاق", func(): pass, "dark"]]
	if Game.daily_ready:
		btns.append(["المكافأة اليومية", _show_daily, "gold"])
	_modal(title, "\n".join(lines), btns, "task")


func _show_profile() -> void:
	ProfileWin.show(self)


func _show_settings() -> void:
	WinAudioStats.show_settings(self)


func _audio_window() -> void:
	WinAudioStats.audio_window(self)


func _vol_slider(title: String, which: String) -> VBoxContainer:
	return WinAudioStats.vol_slider(self, title, which)


func _stats_window() -> void:
	WinAudioStats.stats_window(self)


func _stats_rows(s: Dictionary) -> Array:
	return WinAudioStats.stats_rows(s)


func _dev_window() -> void:
	WinDev.dev_window(self)


func _dev_panel() -> void:
	WinDev.dev_panel(self)


func _confirm_reset() -> void:
	WinDev.confirm_reset(self)


func _show_raid_report() -> void:
	var r: Dictionary = Game.last_raid
	if r.is_empty():
		return
	Game.raid_unseen = false
	var lines: Array[String] = []
	lines.append("هاجم %d ذئبًا البوابة الجنوبية%s." % [int(r["wolves"]), " وسط العاصفة" if r.get("storm", false) else ""])
	if str(r.get("hero", "")) != "":
		lines.append("قاد الدفاع: %s" % Defs.HEROES[r["hero"]]["name"])
	lines.append("قُتل من الذئاب: %d • جرحى جنودنا: %d • قتلانا: %d" % [int(r["killed"]), int(r["wounded"]), int(r["dead"])])
	if int(r.get("wall_level", 0)) > 0:
		lines.append("السور (مستوى %d): دفاع +%d%% • أبراج +%d%% • قوة الدفاع %d" % [int(r["wall_level"]), roundi(float(r["wall_bonus"]["def"]) * 100.0), roundi(float(r["wall_bonus"]["atk"]) * 100.0), int(r.get("defense_power", 0))])
	for l in r.get("log", []):
		lines.append("• " + str(l))
	if r["win"]:
		lines.append("الغنائم: " + Defs.reward_text(r["reward"]))
	else:
		var lp: Array[String] = []
		for k in r["loss"]:
			lp.append("%s %s" % [Defs.fmt(r["loss"][k]), Defs.RES_NAMES[k]])
		if not lp.is_empty():
			lines.append("نهبت الذئاب: " + "، ".join(lp))
		lines.append("نصيحة: درّب مزيدًا من الرمّاحين فهم الأقوى ضد الوحوش، وعيّن قائدًا للدفاع.")
	_modal("صمدت المدينة" if r["win"] else "اخترقت الذئاب الدفاع", "\n".join(lines),
			[["إغلاق", func(): pass, "dark"], ["الجيش", _show_army, "gold"]], "wolf")


func _window(title: String, icon_name: String, builder: Callable) -> void:
	WinProg.window(self, title, icon_name, builder)


func _close_window() -> void:
	WinProg.close_window(self)


func _refresh_window() -> void:
	WinProg.refresh_window(self)


func _card(bg: Color = Color(0.08, 0.13, 0.22, 0.95)) -> PanelContainer:
	return WinProg.card(bg)


func _cost_chips(cost: Dictionary, have_aurora: bool = true) -> HBoxContainer:
	return WinProg.cost_chips(cost, have_aurora)


func _hrow(sep: int = 8) -> HBoxContainer:
	return WinProg.hrow(sep)


func _wrap(text: String, size: int = 17, color: Color = Color.WHITE) -> Label:
	return WinProg.wrap_lbl(text, size, color)


func _show_army() -> void:
	WinProg.show_army(self)


func _build_army(body: VBoxContainer) -> void:
	WinProg.build_army(self, body)


func _show_training(tp: String) -> void:
	WinProg.show_training(self, tp)


func _portrait(id: String) -> Texture2D:
	return WinProg.portrait(self, id)


func _show_heroes() -> void:
	WinProg.show_heroes(self)


func _build_heroes(body: VBoxContainer) -> void:
	WinProg.build_heroes(self, body)


func _show_research() -> void:
	WinProg.show_research(self)


func _show_workshop() -> void:
	WorkshopWin.show(self)


func _build_research(body: VBoxContainer) -> void:
	WinProg.build_research(self, body)


func _show_decision() -> void:
	WinProg.show_decision(self)


func _decide(which: String) -> void:
	WinProg.decide(self, which)
