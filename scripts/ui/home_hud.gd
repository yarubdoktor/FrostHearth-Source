extends RefCounted
## الشاشة الرئيسية بنمط ألعاب الاستراتيجية الحديثة (المرحلة 2ب):
## شريط موارد علوي + ملف شخصي، صف الحالة (سكان • حرارة • قوة)، لوحة الطوابير (زحف/بناء) يمينًا،
## أزرار جانبية، شريط المهمة الحالية، وشريط تنقل سفلي بست أيقونات.
## كل المتغيرات التي يعتمد عليها بقية الكود (res_chips, temp_label, side_btns, dev_btn...) تُملأ هنا كما كانت.

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const JobTimers := preload("res://scripts/ui/job_timers.gd")
const AchievementsPanel := preload("res://scripts/ui/windows/achievements_panel.gd")

const NAV_H := 78.0
const QUEUE_TOP := 150.0
const QUEUE_W := 214.0   # عرض لوحة الطابور (عمودي 720)
const LEFT_W := 104.0    # عرض العمود الأيسر
const MARCH_NAMES := {"res": "جمع", "beast": "صيد وحش", "scout": "استطلاع", "city": "مدينة", "lm": "معلم", "hold": "احتلال", "vent": "المنفث"}


static func build(city: Node) -> void:
	var ui: Control = city.ui
	_top_area(city, ui)
	_queues(city, ui)
	_left_column(city, ui)
	_bottom_area(city, ui)


# ---------------------------------------------------------------- الأعلى: الموارد والملف الشخصي وصف الحالة
static func _top_area(city: Node, ui: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	city.blockers.append(box)

	# الصف الأول: الموارد + صورة الملف الشخصي
	var strip := UI.panel(Color(0.04, 0.08, 0.14, 0.9), 16)
	box.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	strip.add_child(row)
	for r in ["food", "wood", "coal", "iron", "aurora", "gems"]:
		var c := UI.chip("gem" if r == "gems" else r, 24, 16)
		var csb := (c[0] as Control).get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		csb.content_margin_left = 6.0
		csb.content_margin_right = 6.0
		(c[0] as Control).add_theme_stylebox_override("panel", csb)
		(c[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(c[0] as Control).custom_minimum_size = Vector2(0, 0)
		row.add_child(c[0])
		if r == "gems":
			city.gem_label = c[1]
		elif r == "aurora":
			city.aurora_label = c[1]
		else:
			city.res_chips[r] = c[1]
		var rr: String = r
		(c[0] as Control).gui_input.connect(func(e): city._chip_input(e, rr))
		(c[0] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	var av := UI.button("", city._show_profile, "gold", 64)
	av.custom_minimum_size = Vector2(64, 60)
	av.expand_icon = true
	av.add_theme_constant_override("icon_max_width", 52)
	av.icon = UI.icon("hero")
	row.add_child(av)
	city.avatar_btn = av

	# الصف الثاني: السكان والمرضى والثقة (يسارًا) • الحرارة (وسطًا) • القوة (يمينًا)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row2)
	var lg := HBoxContainer.new()
	lg.add_theme_constant_override("separation", 6)
	lg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(lg)
	var pc := UI.chip("pop", 28, 18)
	city.pop_label = pc[1]
	lg.add_child(pc[0])
	(pc[0] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(pc[0] as Control).gui_input.connect(func(e): city._chip_input(e, "pop"))
	var sc := UI.chip("sick", 24, 18)
	city.sick_label = sc[1]
	lg.add_child(sc[0])
	var trc := UI.chip("trust", 24, 18)
	city.trust_label = trc[1]
	lg.add_child(trc[0])
	(trc[0] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(trc[0] as Control).gui_input.connect(func(e): city._chip_input(e, "trust"))

	var tc := UI.chip("temp", 34, 24)
	city.temp_chip = tc[0]
	city.temp_label = tc[1]
	city.temp_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	city.temp_chip.gui_input.connect(func(e): city._chip_input(e, "temp"))
	row2.add_child(city.temp_chip)

	var rg := HBoxContainer.new()
	rg.alignment = BoxContainer.ALIGNMENT_END
	rg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(rg)
	var pwc := UI.power_bar(230.0)
	city.power_label = pwc[1]
	rg.add_child(pwc[0])
	(pwc[0] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(pwc[0] as Control).gui_input.connect(func(e): city._chip_input(e, "power"))


# ---------------------------------------------------------------- يمين: طابور الزحف + البنّاؤون
static func _queues(city: Node, ui: Control) -> void:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position.y = QUEUE_TOP
	city.blockers.append(right)

	# رأس «زحف n/m» قابل للطي
	var head := UI.panel(Color(0.04, 0.08, 0.14, 0.85), 12)
	head.custom_minimum_size = Vector2(QUEUE_W, 0)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	right.add_child(head)
	var hh := HBoxContainer.new()
	head.add_child(hh)
	hh.add_child(UI.icon_rect("army", 24))
	city.march_head = UI.label("", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	city.march_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(city.march_head)
	var arrow := UI.label("▼", 16, UI.TEXT_DIM)
	hh.add_child(arrow)
	city.march_box = VBoxContainer.new()
	city.march_box.add_theme_constant_override("separation", 6)
	right.add_child(city.march_box)
	head.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			city.hud_collapsed = not city.hud_collapsed
			arrow.text = "◀" if city.hud_collapsed else "▼"
			city.march_box.visible = not city.hud_collapsed)
	# خانات الفرق: كل فرق الخريطة + المسيرة العسكرية
	for i in 3:
		var p := UI.panel(Color(0.04, 0.08, 0.14, 0.78), 12)
		p.custom_minimum_size = Vector2(QUEUE_W, 0)
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		var ic := UI.icon_rect("food", 24)
		h.add_child(ic)
		var l := UI.label("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var pb := UI.progress_bar(UI.GREEN)
		pb.custom_minimum_size = Vector2(0, 6)
		v.add_child(pb)
		p.visible = false
		city.march_box.add_child(p)
		city.march_rows.append({"panel": p, "icon": ic, "label": l, "bar": pb})
	# البنّاؤون (كما كانوا)
	for i in Game.MAX_BUILDERS:   # Stage 17: 4 صفوف؛ يُخفى غير المفتوح (انظر city._update_builders)
		var bpnl := UI.panel(Color(0.04, 0.08, 0.14, 0.78), 14)
		bpnl.custom_minimum_size = Vector2(QUEUE_W, 0)
		var v2 := VBoxContainer.new()
		bpnl.add_child(v2)
		var h2 := HBoxContainer.new()
		v2.add_child(h2)
		h2.add_child(UI.icon_rect("hammer", 24))
		var l2 := UI.label("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(l2)
		var pb2 := UI.progress_bar(UI.GOLD)
		pb2.custom_minimum_size = Vector2(0, 6)
		v2.add_child(pb2)
		bpnl.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		bpnl.gui_input.connect(func(e): city._builder_input(e, idx))
		right.add_child(bpnl)
		city.builder_rows.append({"panel": bpnl, "label": l2, "bar": pb2})
	# التدريب (لكل ثكنة) والبحث: تظهر الصفوف فقط عند وجود عمل جارٍ، والضغط يفتح النافذة
	for i in JobTimers.MAX_ROWS:
		JobTimers.make_row(city, right, QUEUE_W)


# ---------------------------------------------------------------- يسار: الجمع وأدوات المطور وتنبيه الغارة
static func _left_column(city: Node, ui: Control) -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	left.position.y = QUEUE_TOP
	var collect: Button = city._icon_button("gift", "الجمع", city._collect_all)
	collect.custom_minimum_size = Vector2(LEFT_W, 62)
	left.add_child(collect)
	# Stage 38: competition is an additional destination; the original world map remains intact.
	var competition: Button = city._icon_button("crown", "المنافسة", func(): city.get_tree().change_scene_to_file("res://competition_hub.tscn"))
	competition.custom_minimum_size = Vector2(LEFT_W, 62)
	left.add_child(competition)
	city.dev_btn = city._icon_button("star", "أدوات المطور", city._dev_panel)
	city.dev_btn.custom_minimum_size = Vector2(LEFT_W, 62)
	city.dev_btn.visible = false
	left.add_child(city.dev_btn)
	city.raid_label = UI.label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	city.raid_label.add_theme_stylebox_override("normal", UI.style(Color(0.04, 0.08, 0.14, 0.82), 14, Color(1, 1, 1, 0.1), 8))
	city.raid_label.custom_minimum_size = Vector2(LEFT_W, 0)
	city.raid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city.raid_label.mouse_filter = Control.MOUSE_FILTER_STOP
	city.raid_label.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			if Game.last_raid.is_empty():
				city._show_army()
			else:
				city._show_raid_report())
	left.add_child(city.raid_label)
	city.blockers.append(left)


# ---------------------------------------------------------------- الأسفل: شريط المهمة + شريط التنقل
static func _bottom_area(city: Node, ui: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	city.blockers.append(box)

	# شريط المهمة الحالية (فوق شريط التنقل)
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 8)
	mg.add_theme_constant_override("margin_right", 8)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mg)
	var tp := UI.panel(Color(0.05, 0.1, 0.17, 0.9), 16)
	mg.add_child(tp)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tp.add_child(th)
	city.task_btn = UI.button("", city._task_action, "gold", 48)
	city.task_btn.custom_minimum_size = Vector2(96, 48)
	th.add_child(city.task_btn)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	th.add_child(tv)
	city.task_title = UI.label("", 18)
	city.task_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(city.task_title)
	city.task_prog = UI.label("", 15, UI.TEXT_DIM)
	tv.add_child(city.task_prog)
	th.add_child(UI.icon_rect("task", 40))

	# شريط التنقل: خمس أيقونات (من اليسار): الخريطة • الجيش • دفتر القائد • الأبطال • المهام (الأبحاث تُفتح من مختبر الجمر فقط — بند 2.36)
	var nav := UI.panel(Color(0.03, 0.06, 0.11, 0.96), 0)
	box.add_child(nav)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	nav.add_child(nh)
	var tabs := [["map", "الخريطة", city._go_map], ["army", "الجيش", city._show_army],
		["decision", "دفتر القائد", city._show_decision], ["hero", "الأبطال", city._show_heroes], ["task", "المهام", city._show_tasks]]
	for t in tabs:
		var b := UI.button(t[1], t[2], "dark", int(NAV_H))
		b.icon = UI.icon(t[0])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, NAV_H)
		nh.add_child(b)
		city.side_btns[t[0]] = b


# ---------------------------------------------------------------- التحديث الدوري (يُستدعى من _on_changed)
static func refresh(city: Node) -> void:
	if city.avatar_btn == null:
		return
	AchievementsPanel.refresh_hud(city.avatar_btn)
	# صورة الملف الشخصي: قائد الدفاع ثم الحاكم، وإلا الأيقونة الافتراضية
	var pid: String = Game.profile_avatar_id()
	if pid != "" and city.avatar_id != pid:
		city.avatar_id = pid
		city.avatar_btn.icon = city._portrait(pid)
	elif pid == "" and city.avatar_id != "":
		city.avatar_id = ""
		city.avatar_btn.icon = UI.icon("hero")
	# طابور الزحف
	var items: Array = []
	for m in Game.marches:
		items.append(m)
	if not Game.venture.is_empty():
		items.append(Game.venture)
	JobTimers.refresh_rows(city)
	city.march_head.text = "زحف %d/%d" % [items.size(), Game.MAX_MARCHES + 1]
	var t := Game.now()
	for i in city.march_rows.size():
		var row: Dictionary = city.march_rows[i]
		var p: PanelContainer = row["panel"]
		if i >= items.size():
			p.visible = false
			continue
		p.visible = true
		var m: Dictionary = items[i]
		var kind := str(m.get("kind", "vent")) if m.has("kind") else "hold"
		var nm: String = MARCH_NAMES.get(kind, "مسيرة")
		var icon_name := "army"
		if kind == "res" and Defs.RES.has(str(m.get("t", ""))):
			icon_name = str(m["t"])
			nm += " " + str(Defs.RES_NAMES[m["t"]])
		elif kind == "beast":
			icon_name = "wolf"
		(row["icon"] as TextureRect).texture = UI.icon(icon_name)
		var back := float(m.get("back", t))
		var start := float(m.get("start", back - 1.0))
		(row["label"] as Label).text = "%s • %s" % [nm, Defs.fmt_time(back - t)]
		(row["bar"] as ProgressBar).value = 100.0 * clampf((t - start) / maxf(back - start, 0.01), 0.0, 1.0)
