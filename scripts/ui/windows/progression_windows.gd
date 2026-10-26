extends RefCounted
## وحدة نوافذ التقدم: الجيش والأبطال والأبحاث والقرار + أدوات النوافذ المشتركة
## بلا حالة — المدينة تفوّض إليها

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const HeroesWindow := preload("res://scripts/ui/windows/heroes_window.gd")


static func window(city: Node, title: String, icon_name: String, builder: Callable) -> void:
	city._close_panel()
	close_window(city)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	city.modal_layer.add_child(dim)
	city.win_dim = dim
	var p := UI.panel(Color(0.05, 0.09, 0.16, 0.98), 22)
	dim.add_child(p)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 12
	p.offset_right = -12
	p.offset_top = 36
	p.offset_bottom = -36
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var close := UI.button("إغلاق", city._close_window, "dark", 46)
	close.custom_minimum_size = Vector2(100, 46)
	head.add_child(close)
	var tl := UI.label(title, 28, UI.GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(UI.icon_rect(icon_name, 44))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	city.win_scroll = sc
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	city.win_refresh = func():
		if not is_instance_valid(body):
			return
		var keep := sc.scroll_vertical
		city.win_tick.clear()
		for c in body.get_children():
			c.free()
		builder.call(body)
		await city.get_tree().process_frame
		if is_instance_valid(sc):
			sc.scroll_vertical = keep
	city.win_refresh.call()


static func close_window(city: Node) -> void:
	city.win_tick.clear()
	city.win_refresh = Callable()
	if is_instance_valid(city.win_dim):
		city.win_dim.queue_free()
	city.win_dim = null


static func refresh_window(city: Node) -> void:
	if city.win_refresh.is_valid():
		city.win_refresh.call_deferred()


static func card(bg: Color = Color(0.08, 0.13, 0.22, 0.95)) -> PanelContainer:
	return UI.panel(bg, 16)


static func cost_chips(cost: Dictionary, have_aurora: bool = true) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for r in cost:
		var c := UI.chip("aurora" if r == "aurora" else r, 22, 16)
		(c[1] as Label).text = Defs.fmt(float(cost[r]))
		var have: float = float(Game.aurora) if r == "aurora" else float(Game.res.get(r, 0.0))
		(c[1] as Label).add_theme_color_override("font_color", UI.RED if have < float(cost[r]) else Color.WHITE)
		h.add_child(c[0])
	return h


static func hrow(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func wrap_lbl(text: String, size: int = 17, color: Color = Color.WHITE) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- المعسكر (استعراض القوات)
static func show_army(city: Node) -> void:
	window(city, "المعسكر", "army", city._build_army)


static func _tier_stats(tp: String, tier: int) -> String:
	## القيم الفعلية بعد الأبحاث الحربية (هجوم ودفاع ومتانة)
	var st := Game.troop_stats(tp, tier)
	var text := "هجوم %d • دفاع %d • صحة %d" % [int(st["atk"]), int(st["def"]), int(st["hp"])]
	if float(st.get("damage", 0.0)) > 0:
		text += " • ضرر نهائي +%.1f%% (عدا الوحوش)" % (float(st["damage"]) * 100)
	return text


static func build_army(city: Node, body: VBoxContainer) -> void:
	# سعة المعسكر
	var cc := card()
	body.add_child(cc)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cc.add_child(cv)
	var cap_lbl := wrap_lbl("", 19, UI.GOLD)
	cv.add_child(cap_lbl)
	var cap_bar := UI.progress_bar(UI.GOLD)
	cv.add_child(cap_bar)
	var info := wrap_lbl("", 16, UI.TEXT_DIM)
	cv.add_child(info)
	var upd_info := func():
		var cap := Game.army_cap()
		cap_lbl.text = "المعسكر المستوى %d • الجيش %d من سعة %d" % [Game.camp_level(), Game.army_count(), cap]
		cap_bar.value = 100.0 * float(Game.army_count()) / maxf(float(cap), 1.0)
		info.text = "حاضرون %d • قيد التدريب %d • في مهمة %d • جرحى %d / %d • قوة المدينة %s • يأكل الجيش %s طعام في الساعة" % [
			Game.troop_total(), Game.training_total(), Game.army_away(), Game.wounded_total(), Game.wounded_cap(),
			Defs.fmt(Game.power()), Defs.fmt(Game.troop_total())]
	upd_info.call()
	city.win_tick.append(upd_info)
	if Game.camp_level() <= 0:
		var warn := card(Color(0.14, 0.07, 0.07, 0.9))
		body.add_child(warn)
		warn.add_child(wrap_lbl("ابنِ المعسكر أولًا (يفتح عند الفرن بالمستوى 3). هو مكان تجمع القوات وسعته تحدد حجم جيشك.", 19, UI.RED))
	# قائد الدفاع والغارة
	var dc := card()
	body.add_child(dc)
	var dh := hrow(12)
	dc.add_child(dh)
	dh.add_child(UI.button("اختيار القائد", city._show_heroes, "blue", 48))
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	var hn: String = Defs.HEROES[Game.defender]["name"] if Game.defender != "" else "بلا قائد"
	dv.add_child(wrap_lbl("قائد الدفاع: %s" % hn, 19, UI.GOLD))
	dv.add_child(wrap_lbl("دفاع المدينة يعتمد على جنودها الحاضرين فيها (من لم يخرج بمسيرة) وعلى أبحاثها الدفاعية وقائدها.", 15, UI.TEXT_DIM))
	var rl := wrap_lbl("", 16, UI.TEXT_DIM)
	dv.add_child(rl)
	var upd_raid := func():
		var st := Game.raid_strength()
		if Game.raid_next > 0.0:
			rl.text = "الغارة القادمة خلال %s • متوقع %d ذئبًا • الرمّاحون أقوى ضد الوحوش، والدروع تتحمل الصف الأول" % [Defs.fmt_time(Game.raid_next - Game.now()), int(st["n"])]
		else:
			rl.text = "تبدأ غارات الذئاب بعد بناء أول مبنى عسكري. الذئاب لا تهاجم وأنت غائب عن اللعبة."
	upd_raid.call()
	city.win_tick.append(upd_raid)
	dh.add_child(UI.icon_rect("wolf", 48))
	# استعراض القوات حسب النوع والرتبة
	for tp in Defs.TROOP_ORDER:
		var td: Dictionary = Defs.TROOPS[tp]
		var tcard := card()
		body.add_child(tcard)
		var h := hrow(12)
		tcard.add_child(h)
		var ttp: String = tp
		var bl := Game.barracks_level(tp)
		var bname: String = Defs.BUILDINGS[Defs.BARRACKS_TYPE[tp]]["name"]
		var open_btn := UI.button("فتح " + bname if bl > 0 else bname + " غير مبنية", func(): city._show_training(ttp), "gold" if bl > 0 else "dark", 54)
		open_btn.custom_minimum_size = Vector2(170, 54)
		open_btn.disabled = bl <= 0
		h.add_child(open_btn)
		var iv := VBoxContainer.new()
		iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		iv.add_theme_constant_override("separation", 3)
		h.add_child(iv)
		var total := 0
		var wnd := 0
		for t in range(1, 5):
			total += int(Game.troops["%s_%d" % [tp, t]])
			wnd += int(Game.wounded["%s_%d" % [tp, t]])
		iv.add_child(UI.label("%s — %d جندي" % [td["name"], total], 21, UI.GOLD))
		var any := false
		for t in range(4, 0, -1):
			var n := int(Game.troops["%s_%d" % [tp, t]])
			var w := int(Game.wounded["%s_%d" % [tp, t]])
			if n <= 0 and w <= 0:
				continue
			any = true
			var line := "• %s: %d" % [Defs.TIER_NAMES[t], n]
			if w > 0:
				line += " (+%d جريح)" % w
			iv.add_child(wrap_lbl(line + " — " + _tier_stats(tp, t), 16, Color.WHITE))
		if not any:
			iv.add_child(wrap_lbl("لا جنود من هذا النوع بعد.", 16, UI.TEXT_DIM))
		if Game.train.has(tp):
			var tr: Dictionary = Game.train[tp]
			var pr: PackedStringArray = String(tr["key"]).split("_")
			iv.add_child(wrap_lbl("قيد التدريب: %d %s • متبقٍ %s" % [int(tr["n"]), Defs.TIER_NAMES[int(pr[1])], Defs.fmt_time(float(tr["end"]) - Game.now())], 16, UI.GREEN))
		h.add_child(UI.icon_rect(tp, 64))
	if not Game.venture.is_empty():
		var vc := card(Color(0.16, 0.11, 0.05, 0.95))
		body.add_child(vc)
		var parts: Array[String] = []
		for k in Game.venture.get("units", {}):
			var pp: PackedStringArray = String(k).split("_")
			parts.append("%d %s" % [int(Game.venture["units"][k]), Defs.TROOPS[pp[0]]["plural"]])
		vc.add_child(wrap_lbl("في مسيرة عسكرية الآن: " + "، ".join(parts), 17, UI.GOLD))
	body.add_child(wrap_lbl("مثلث التفوق: الرمح يخترق الدرع • الدرع يصد السهام • السهم يصيب الرماح. وفي العاصفة تضعف السهام 20% وتقوى الدروع 10%.", 16, UI.TEXT_DIM))


# ---------------------------------------------------------------- الثكنة (التدريب)
static func show_training(city: Node, tp: String) -> void:
	var bname: String = Defs.BUILDINGS[Defs.BARRACKS_TYPE[tp]]["name"]
	city.train_tp = tp
	window(city, bname, tp, func(body): build_training(city, body, tp))


static func build_training(city: Node, body: VBoxContainer, tp: String) -> void:
	var td: Dictionary = Defs.TROOPS[tp]
	var bl := Game.barracks_level(tp)
	var bname: String = Defs.BUILDINGS[Defs.BARRACKS_TYPE[tp]]["name"]
	var cap := Game.train_batch_of(tp)
	var hc := card()
	body.add_child(hc)
	hc.add_child(wrap_lbl("%s • المستوى %d   •   سرعة التدريب ×%.2f   •   أكبر دفعة %d   •   أعلى رتبة: %s\nالجيش %d من سعة المعسكر %d" % [
		bname, bl, Defs.barracks_speed(bl) * (1.0 + Game.bonus("train_speed")), cap,
		Defs.TIER_NAMES[maxi(Game.max_tier_of(tp), 1)] if bl > 0 else "—", Game.army_count(), Game.army_cap()], 18, UI.GOLD))
	if bl <= 0 and not Game.dev_mode:
		var warn_card := card(Color(0.14, 0.07, 0.07, 0.9))
		body.add_child(warn_card)
		warn_card.add_child(wrap_lbl("ابنِ %s أولًا لتبدأ تدريب %s." % [bname, td["plural"]], 19, UI.RED))
		return
	# التدريب الجاري في هذه الثكنة
	if Game.train.has(tp):
		var tc := card(Color(0.07, 0.16, 0.24, 0.95))
		body.add_child(tc)
		var tv := VBoxContainer.new()
		tc.add_child(tv)
		var th := hrow()
		tv.add_child(th)
		var sp := UI.button("", func():
			Game.speedup_train(tp)
			refresh_window(city), "blue", 46)
		th.add_child(sp)
		th.add_child(UI.button("إلغاء", func():
			Game.cancel_train(tp)
			refresh_window(city), "red", 46))
		var tl := wrap_lbl("", 18)
		th.add_child(tl)
		var pb := UI.progress_bar(UI.GOLD)
		tv.add_child(pb)
		var was_key: String = Game.train[tp]["key"]
		var upd_train := func():
			if not Game.train.has(tp) or Game.train[tp]["key"] != was_key:
				refresh_window(city)
				return
			var tr: Dictionary = Game.train[tp]
			var parts: PackedStringArray = String(tr["key"]).split("_")
			var remain := float(tr["end"]) - Game.now()
			tl.text = "قيد التدريب: %d %s (%s) • متبقٍ %s" % [int(tr["n"]), td["plural"], Defs.TIER_NAMES[int(parts[1])], Defs.fmt_time(remain)]
			pb.value = 100.0 * (1.0 - remain / maxf(float(tr["end"]) - float(tr["start"]), 0.01))
			var g := Game.gems_for_time(remain)
			sp.text = "تسريع مجاني" if g == 0 else "تسريع • %d جوهرة" % g
		upd_train.call()
		city.win_tick.append(upd_train)
	# الرتبة والعدد
	city.army_n = clampi(city.army_n, 1, maxi(cap, 1))
	city.army_tier = clampi(city.army_tier, 1, maxi(Game.max_tier_of(tp), 1) if not Game.dev_mode else 4)
	var sel_row := hrow()
	body.add_child(sel_row)
	for t in [4, 3, 2, 1]:
		var tt: int = t
		var b := UI.button(Defs.TIER_NAMES[t], func():
			city.army_tier = tt
			refresh_window(city), "gold" if t == city.army_tier else "dark", 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not Game.dev_mode and t > Game.max_tier_of(tp)
		if b.disabled:
			b.text = "%s • ثكنة %d" % [Defs.TIER_NAMES[t], Defs.TIER_BARRACKS[t]]
		sel_row.add_child(b)
	sel_row.add_child(UI.label("الرتبة:", 18, UI.TEXT_DIM))
	var cnt_row := hrow()
	body.add_child(cnt_row)
	for it in [["الأقصى", cap], ["+10", city.army_n + 10], ["−10", city.army_n - 10], ["الربع", maxi(cap / 4, 1)]]:
		var val: int = it[1]
		var b := UI.button(it[0], func():
			city.army_n = clampi(val, 1, maxi(cap, 1))
			refresh_window(city), "dark", 46)
		b.custom_minimum_size = Vector2(96, 46)
		cnt_row.add_child(b)
	var nl := UI.label("العدد: %d من %d" % [city.army_n, cap], 20, Color.WHITE)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt_row.add_child(nl)
	# بطاقة الجنود
	var main_card := card()
	body.add_child(main_card)
	var h := hrow(12)
	main_card.add_child(h)
	var chk := Game.train_check(tp, city.army_tier, city.army_n)
	var b := UI.button("تدريب", func():
		if Game.start_train(tp, city.army_tier, city.army_n):
			city._toast("بدأ التدريب")
		refresh_window(city), "gold", 54)
	b.custom_minimum_size = Vector2(120, 54)
	b.disabled = not chk["ok"]
	h.add_child(b)
	var cv := VBoxContainer.new()
	h.add_child(cv)
	cv.add_child(cost_chips(chk["cost"]))
	var tch := UI.chip("time", 22, 16)
	(tch[1] as Label).text = Defs.fmt_time(chk["time"])
	cv.add_child(tch[0])
	var iv := VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(iv)
	var owned: Array[String] = []
	for t in range(1, 5):
		var n := int(Game.troops["%s_%d" % [tp, t]])
		if n > 0:
			owned.append("%s %d" % [Defs.TIER_NAMES[t], n])
	iv.add_child(UI.label("%s — %s" % [td["name"], Defs.TIER_NAMES[city.army_tier]], 21, UI.GOLD))
	iv.add_child(wrap_lbl(td["desc"], 15, UI.TEXT_DIM))
	iv.add_child(wrap_lbl("%s • يتفوق على: %s" % [_tier_stats(tp, city.army_tier), Defs.TROOPS[td["beats"]]["plural"]], 16))
	iv.add_child(wrap_lbl("لديك: " + ("، ".join(owned) if not owned.is_empty() else "لا أحد"), 16, UI.GREEN))
	var why: Array = chk["reasons"].duplicate()
	if not chk["missing"].is_empty() and why.is_empty():
		why.append("الموارد غير كافية")
	if not why.is_empty():
		iv.add_child(wrap_lbl(" • ".join(why), 15, UI.RED))
	h.add_child(UI.icon_rect(tp, 64))
	body.add_child(wrap_lbl("الرتبة الأعلى تكلّف أكثر وتحتاج وقتًا أطول. تطوير الثكنة يسرّع التدريب ويكبّر الدفعة ويفتح رتبًا أقوى، والأبحاث الحربية تسرّعه أكثر.", 15, UI.TEXT_DIM))


# ---------------------------------------------------------------- الأبطال


static func portrait(city: Node, id: String) -> Texture2D:
	return HeroesWindow.portrait(city, id)


static func show_heroes(city: Node) -> void:
	HeroesWindow.show(city)


static func build_heroes(city: Node, body: VBoxContainer) -> void:
	HeroesWindow.build(city, body)


# ---------------------------------------------------------------- الأبحاث
static func show_research(city: Node) -> void:
	window(city, "مختبر الجمر — الأبحاث", "research", city._build_research)


static func build_research(city: Node, body: VBoxContainer) -> void:
	var lab := Game.max_level_of("lab")
	if lab <= 0:
		body.add_child(wrap_lbl("ابنِ مختبر الجمر (يفتح عند الفرن بالمستوى 5) لتبدأ الأبحاث.", 19, UI.RED))
	if not Game.research.is_empty():
		var tc := card(Color(0.07, 0.16, 0.24, 0.95))
		body.add_child(tc)
		var tv := VBoxContainer.new()
		tc.add_child(tv)
		var th := hrow()
		tv.add_child(th)
		var sp := UI.button("", func():
			Game.speedup_research()
			refresh_window(city), "blue", 46)
		th.add_child(sp)
		var tl := wrap_lbl("", 18)
		th.add_child(tl)
		var pb := UI.progress_bar(Color("5fe3ff"))
		tv.add_child(pb)
		var rid: String = Game.research["id"]
		var upd := func():
			if Game.research.is_empty() or Game.research["id"] != rid:
				refresh_window(city)
				return
			var remain := float(Game.research["end"]) - Game.now()
			tl.text = "قيد البحث: %s — المستوى %d • متبقٍ %s" % [Defs.TECHS[rid]["name"], int(Game.research["lv"]), Defs.fmt_time(remain)]
			pb.value = 100.0 * (1.0 - remain / maxf(float(Game.research["end"]) - float(Game.research["start"]), 0.01))
			var g := Game.gems_for_time(remain)
			sp.text = "تسريع مجاني" if g == 0 else "تسريع • %d جوهرة" % g
		upd.call()
		city.win_tick.append(upd)
	var tabs := hrow()
	body.add_child(tabs)
	for i in [3, 2, 1, 0]:
		var bi: int = i
		var b := UI.button(Defs.BRANCHES[i], func():
			city.tech_branch = bi
			refresh_window(city), "gold" if i == city.tech_branch else "dark", 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	for id in Defs.TECHS:
		var td: Dictionary = Defs.TECHS[id]
		if int(td["branch"]) != city.tech_branch:
			continue
		var lv := int(Game.techs[id])
		var chk := Game.tech_check(id)
		var card := card()
		body.add_child(card)
		var h := hrow(12)
		card.add_child(h)
		var tid: String = id
		var b := UI.button("بحث" if lv < int(td["max"]) else "مكتمل", func():
			if Game.start_research(tid):
				city._toast("بدأ البحث")
			refresh_window(city), "gold", 54)
		b.custom_minimum_size = Vector2(110, 54)
		b.disabled = not chk["ok"]
		h.add_child(b)
		if lv < int(td["max"]):
			var cv := VBoxContainer.new()
			h.add_child(cv)
			cv.add_child(cost_chips(chk["cost"]))
			var tch := UI.chip("time", 22, 16)
			(tch[1] as Label).text = Defs.fmt_time(chk["time"])
			cv.add_child(tch[0])
		var iv := VBoxContainer.new()
		iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(iv)
		iv.add_child(UI.label("%s — %d / %d" % [td["name"], lv, int(td["max"])], 20, UI.GOLD if lv > 0 else Color.WHITE))
		var cur := Defs.eff_text(td["eff"], float(td["val"]) * lv)
		var nxt := Defs.eff_text(td["eff"], float(td["val"]) * (lv + 1))
		iv.add_child(wrap_lbl("%s: %s ← %s" % [Defs.EFF_NAMES[td["eff"]], cur, nxt] if lv < int(td["max"]) else "%s: %s" % [Defs.EFF_NAMES[td["eff"]], cur], 16))
		var why: Array = chk["reasons"].filter(func(x): return x != "المختبر مشغول ببحث آخر")
		if not why.is_empty() and lv < int(td["max"]):
			iv.add_child(wrap_lbl(" • ".join(why), 15, UI.RED))
		var pbar := UI.progress_bar(UI.GOLD)
		pbar.value = 100.0 * lv / float(td["max"])
		pbar.custom_minimum_size = Vector2(0, 6)
		iv.add_child(pbar)


# ---------------------------------------------------------------- دفتر القائد
static func show_decision(city: Node) -> void:
	if Game.pending_decision < 0:
		var wait := Game.decision_next - Game.now()
		city._modal("دفتر القائد", "لا توجد قرارات تنتظرك الآن.\nكل بضع دقائق يطرأ موقف جديد في المدينة، وقرارك يغيّر الموارد وثقة الناس.\n\nالموقف القادم خلال: %s\nثقة الناس الآن: %d%%" % [Defs.fmt_time(maxf(wait, 0.0)) if Game.furnace_level() >= 2 else "بعد تطوير الفرن إلى 2", int(Game.trust)],
				[["إغلاق", func(): pass, "dark"]], "decision")
		return
	var d: Dictionary = Defs.DECISIONS[Game.pending_decision]
	var a: Dictionary = d["a"]
	var b: Dictionary = d["b"]
	var body := "%s\n\n• %s: %s\n• %s: %s" % [d["text"], a["label"], Defs.decision_effect_text(a["eff"]), b["label"], Defs.decision_effect_text(b["eff"])]
	var btns: Array = []
	btns.append([b["label"], func(): decide(city, "b"), "blue"])
	btns.append([a["label"], func(): decide(city, "a"), "gold"])
	var v: Control = city._modal(d["title"], body, btns, "decision")
	# تعطيل الخيار غير الممكن
	var row: HBoxContainer = v.get_child(v.get_child_count() - 1)
	(row.get_child(0) as Button).disabled = not Game.decision_option_ok(b)
	(row.get_child(1) as Button).disabled = not Game.decision_option_ok(a)


static func decide(city: Node, which: String) -> void:
	Game.choose_decision(which)
	city._toast("تم القرار • ثقة الناس الآن %d%%" % int(Game.trust))
