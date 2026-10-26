extends RefCounted
## مؤقتات الأعمال الجارية (Stage 16): بناء/ترقية، تدريب الجنود، أبحاث.
## 1) فوق كل مبنى يعمل: لوحة صغيرة بشريط تقدم ووقت متبقٍ (تتبع المبنى على الشاشة)
## 2) في طابور الشاشة الرئيسية: صفوف للتدريب (حتى 3 ثكنات) والبحث، والضغط عليها يفتح النافذة
## الحالة كلها من Game (queue / train / research / gear_queue)؛ المؤقت لا يملك حالة مستقلة.

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const CompletionFlashes := preload("res://scripts/ui/completion_flashes.gd")

const COL_BUILD := Color("8fe3a1")
const COL_TRAIN := Color("5aa7ff")
const COL_RESEARCH := Color("c9a0ff")
const TRAIN_OF := {"bk_shield": "shield", "bk_spear": "spear", "bk_bow": "bow"}
const TRAIN_ORDER := ["shield", "spear", "bow"]
const MAX_ROWS := 5          # ثلاث ثكنات + بحث + ملخص الورشة
const COMPACT_DIST := 110.0  # أبعد من هذا: شريط فقط بلا نص
const WIDGET_W := 190.0
const COMPACT_W := 70.0
const LIFT_PX := 20.0        # رفع اللوحة فوق نقطة المبنى


# ---------------------------------------------------------------- المصدر: ما الذي يعمل الآن؟
static func _train_job(tp: String) -> Dictionary:
	var tr: Dictionary = Game.train[tp]
	return {"kind": "train", "key": tp, "icon": "army", "color": COL_TRAIN,
		"name": "تدريب %s ×%d" % [Defs.TROOPS[tp]["name"], int(tr["n"])],
		"start": float(tr["start"]), "end": float(tr["end"])}


static func _research_job() -> Dictionary:
	var rid: String = Game.research["id"]
	return {"kind": "research", "key": rid, "icon": "research", "color": COL_RESEARCH,
		"name": "بحث %s %d" % [Defs.TECHS[rid]["name"], int(Game.research["lv"])],
		"start": float(Game.research["start"]), "end": float(Game.research["end"])}


static func _gear_job() -> Dictionary:
	var first: Dictionary = Game.gear_queue[0]
	for q in Game.gear_queue:
		if float(q["end"]) < float(first["end"]):
			first = q
	return {"kind": "gear", "key": "wk1", "icon": "hammer", "color": UI.GOLD,
		"name": "تصنيع تجهيزات ×%d" % Game.gear_queue.size(),
		"start": float(first["start"]), "end": float(first["end"])}


## أعمال مبنى واحد (بناء أولًا ثم تدريب أو بحث)
static func jobs_for(id: String) -> Array:
	var out: Array = []
	var q: Dictionary = Game.queue_entry(id)
	if not q.is_empty():
		var lv := int(q["level"])
		out.append({"kind": "build", "key": id, "icon": "hammer", "color": COL_BUILD,
			"name": "بناء" if lv <= 1 else "ترقية %d" % lv,
			"start": float(q["start"]), "end": float(q["end"])})
	var tp: String = Defs.PLOTS[id]["type"]
	if TRAIN_OF.has(tp) and Game.train.has(TRAIN_OF[tp]):
		out.append(_train_job(TRAIN_OF[tp]))
	if tp == "lab" and not Game.research.is_empty():
		out.append(_research_job())
	if tp == "workshop" and not Game.gear_queue.is_empty():
		out.append(_gear_job())
	return out


## أعمال المدينة غير المرتبطة بمبنى معيّن (للطابور الجانبي): تدريب كل ثكنة + البحث
static func city_jobs() -> Array:
	var out: Array = []
	for tp in TRAIN_ORDER:
		if Game.train.has(tp):
			out.append(_train_job(tp))
	if not Game.research.is_empty():
		out.append(_research_job())
	if not Game.gear_queue.is_empty():
		out.append(_gear_job())
	return out


static func progress(job: Dictionary, t: float) -> float:
	var s := float(job["start"])
	var e := float(job["end"])
	return 100.0 * clampf((t - s) / maxf(e - s, 0.01), 0.0, 1.0)


# ---------------------------------------------------------------- اللوحات فوق المباني
static func build(city: Node, ui: Control) -> void:
	var layer := Control.new()
	layer.name = "TimerLayer"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)
	city.timer_layer = layer
	var flashes := CompletionFlashes.new()
	flashes.city = city
	layer.add_child(flashes)


static func _set_bar_color(pb: ProgressBar, c: Color) -> void:
	var fg := pb.get_theme_stylebox("fill") as StyleBoxFlat
	if fg != null:
		fg.bg_color = c


static func _make_widget() -> Dictionary:
	var root := PanelContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.08, 0.14, 0.9), 10, Color(1, 1, 1, 0.2), 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var rows: Array = []
	for i in 2:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(head)
		var ic := UI.icon_rect("hammer", 16)
		head.add_child(ic)
		var nl := UI.label("", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(nl)
		var tl := UI.label("", 13, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(tl)
		var pb := UI.progress_bar(COL_BUILD)
		pb.custom_minimum_size = Vector2(0, 7)
		box.add_child(pb)
		rows.append({"box": box, "head": head, "icon": ic, "name": nl, "time": tl, "bar": pb, "kind": ""})
	root.visible = false
	return {"root": root, "rows": rows, "sig": ""}


static func update(city: Node) -> void:
	if city.timer_layer == null or city.rig == null:
		return
	var cam: Camera3D = city.rig.cam
	var compact: bool = city.rig.dist > COMPACT_DIST
	var vr: Rect2 = city.get_viewport().get_visible_rect().grow(80.0)
	var t := Game.now()
	var clock := Time.get_ticks_msec() / 1000.0
	for id in city.plot_nodes:
		var pn: Dictionary = city.plot_nodes[id]
		var jobs := jobs_for(id)
		# راية الثكنة تنبض أثناء التدريب
		var fm = pn.get("flag_mat")
		if fm != null:
			var training := false
			for j in jobs:
				if j["kind"] == "train":
					training = true
			(fm as StandardMaterial3D).emission_energy_multiplier = 0.6 + (0.9 * (0.5 + 0.5 * sin(clock * 4.0)) if training else 0.0)
		var w: Dictionary = city.timer_widgets.get(id, {})
		if jobs.is_empty():
			if not w.is_empty():
				(w["root"] as Control).visible = false
			continue
		if w.is_empty():
			w = _make_widget()
			city.timer_layer.add_child(w["root"])
			city.timer_widgets[id] = w
		var root: PanelContainer = w["root"]
		var p3: Vector3 = Defs.plot_pos(id) + Vector3(0, float(pn["top"]) + 0.6, 0)
		if cam.is_position_behind(p3):
			root.visible = false
			continue
		var sp: Vector2 = cam.unproject_position(p3)
		if not vr.has_point(sp):
			root.visible = false
			continue
		root.visible = true
		var rows: Array = w["rows"]
		for i in rows.size():
			var row: Dictionary = rows[i]
			var box: Control = row["box"]
			if i >= jobs.size():
				box.visible = false
				continue
			var j: Dictionary = jobs[i]
			box.visible = true
			(row["head"] as Control).visible = not compact
			if row["kind"] != j["kind"]:
				row["kind"] = j["kind"]
				(row["icon"] as TextureRect).texture = UI.icon(j["icon"])
				_set_bar_color(row["bar"], j["color"])
			(row["name"] as Label).text = j["name"]
			(row["time"] as Label).text = Defs.fmt_time_short(float(j["end"]) - t)
			(row["bar"] as ProgressBar).value = progress(j, t)
		var sig := "%s|%d" % [str(compact), jobs.size()]
		if sig != w["sig"]:
			w["sig"] = sig
			root.custom_minimum_size = Vector2(COMPACT_W if compact else WIDGET_W, 0)
			root.reset_size()
		root.position = sp - Vector2(root.size.x * 0.5, root.size.y + LIFT_PX)


# ---------------------------------------------------------------- صفوف الطابور الجانبي
static func make_row(city: Node, parent: Control, panel_w: float) -> void:
	var p := UI.panel(Color(0.04, 0.08, 0.14, 0.78), 14)
	p.custom_minimum_size = Vector2(panel_w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var ic := UI.icon_rect("army", 24)
	h.add_child(ic)
	var l := UI.label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	var tl := UI.label("", 14, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(tl)
	var pb := UI.progress_bar(COL_TRAIN)
	pb.custom_minimum_size = Vector2(0, 6)
	v.add_child(pb)
	p.visible = false
	var row := {"panel": p, "icon": ic, "name": l, "time": tl, "bar": pb, "item": {}, "kind": ""}
	p.gui_input.connect(func(e): row_input(city, e, row))
	parent.add_child(p)
	city.job_rows.append(row)


static func row_input(city: Node, e: InputEvent, row: Dictionary) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	var item: Dictionary = row["item"]
	if item.is_empty():
		return
	if item["kind"] == "train":
		city._show_training(item["key"])
	elif item["kind"] == "research":
		city._show_research()
	elif item["kind"] == "gear":
		city._show_workshop()


static func refresh_rows(city: Node) -> void:
	var items := city_jobs()
	var t := Game.now()
	for i in city.job_rows.size():
		var row: Dictionary = city.job_rows[i]
		var p: Control = row["panel"]
		if i >= items.size():
			p.visible = false
			row["item"] = {}
			continue
		var it: Dictionary = items[i]
		p.visible = true
		row["item"] = it
		if row["kind"] != it["kind"] + str(it["key"]):
			row["kind"] = it["kind"] + str(it["key"])
			(row["icon"] as TextureRect).texture = UI.icon(it["icon"])
			_set_bar_color(row["bar"], it["color"])
		(row["name"] as Label).text = it["name"]
		(row["time"] as Label).text = Defs.fmt_time_short(float(it["end"]) - t)
		(row["bar"] as ProgressBar).value = progress(it, t)
