extends RefCounted
## وحدة نوافذ: الإعدادات + الصوت + الإحصائيات — بلا حالة، المدينة تفوّض إليها
## كل الدوال ساكنة وتستقبل المدينة (city) لتصل إلى عناصرها وأدواتها

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")


static func show_settings(city: Node) -> void:
	city._modal("الإعدادات", "جودة الرسوم الحالية: %s\nالحفظ تلقائي كل 15 ثانية وعند الخروج من اللعبة." % ("عالية" if Game.quality_high else "منخفضة (أسرع على الهواتف الضعيفة)"),
		[["الصوت", city._audio_window, "blue"],
		["الإحصائيات", city._stats_window, "blue"],
		["تبديل الجودة", func():
			Game.quality_high = not Game.quality_high
			city._apply_quality()
			Game.save_game(), "blue"],
		["نظام المطور", city._dev_window, "gold"],
		["بدء لعبة جديدة", city._confirm_reset, "red"],
		["إغلاق", func(): pass, "dark"]], "gear")


static func audio_window(city: Node) -> void:
	## نافذة الصوت: مستوى الموسيقى والمؤثرات — التغيير فوري ويُحفظ تلقائيًا
	city._close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	city.modal_layer.add_child(dim)
	var p := UI.panel(Color(0.06, 0.11, 0.19, 0.97), 22)
	p.custom_minimum_size = Vector2(480, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("الصوت", 26, UI.GOLD))
	v.add_child(UI.label("اسحب لتغيير المستوى — 0 يعني صمتًا. التغيير فوري ويُحفظ تلقائيًا.", 17))
	v.add_child(vol_slider(city, "الموسيقى", "music"))
	v.add_child(vol_slider(city, "المؤثرات والرياح", "sfx"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var close := UI.button("إغلاق", func(): dim.queue_free(), "blue", 54)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(close)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH


static func vol_slider(city: Node, title: String, which: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	box.add_child(head)
	var lbl := UI.label(title, 19)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var val_lbl := UI.label("", 19, UI.GOLD)
	head.add_child(val_lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 10.0
	s.step = 1.0
	s.custom_minimum_size = Vector2(420, 28)
	s.value = Sound.music_vol if which == "music" else Sound.sfx_vol
	val_lbl.text = vol_text(s.value)
	s.value_changed.connect(func(val: float) -> void:
		if which == "music":
			Sound.set_music_vol(val)
		else:
			Sound.set_sfx_vol(val)
		val_lbl.text = vol_text(val))
	box.add_child(s)
	return box


static func vol_text(v: float) -> String:
	if v <= 0.0:
		return "صامت"
	return "%d / 10" % int(v)


static func stats_window(city: Node) -> void:
	## نافذة الإحصائيات: لقطة حية للمدينة — تتحدث كل ثانية طالما النافذة مفتوحة
	city._close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	city.modal_layer.add_child(dim)
	var p := UI.panel(Color(0.06, 0.11, 0.19, 0.97), 22)
	p.custom_minimum_size = Vector2(520, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("الإحصائيات", 26, UI.GOLD))
	v.add_child(UI.label("لقطة حية لمدينتك — تتحدث كل ثانية.", 17))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vh: float = city.get_viewport().get_visible_rect().size.y
	scroll.custom_minimum_size = Vector2(0, clampf(vh * 0.62, 300.0, 560.0))
	v.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	scroll.add_child(content)
	var labels: Array = []
	var refresh := func() -> void:
		var rows: Array = stats_rows(Game.get_stats_snapshot())
		if labels.size() != rows.size():
			# أول مرة (أو تغيّر عدد الأسطر): ابنِ التسميات — بعدها يُحدَّث النص فقط
			for c in content.get_children():
				c.queue_free()
			labels.clear()
			for row in rows:
				var l: Label = UI.label(row[1], 19 if row[0] else 17, UI.GOLD if row[0] else Color.WHITE)
				content.add_child(l)
				labels.append(l)
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(0, 10)
			content.add_child(pad)
		else:
			for i in rows.size():
				(labels[i] as Label).text = rows[i][1]
	refresh.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: refresh.call())
	dim.add_child(timer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var close := UI.button("إغلاق", func(): dim.queue_free(), "blue", 54)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(close)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH


static func stats_rows(s: Dictionary) -> Array:
	## أسطر نافذة الإحصائيات من لقطة Game.get_stats_snapshot()
	## كل عنصر: [عنوان؟ (bool), النص (String)] — عدد الأسطر ثابت دائمًا
	var rows: Array = []
	rows.append([true, "المدينة"])
	rows.append([false, "مستوى الفرن: %d • مبانٍ مشيدة: %d/%d" % [int(s["furnace"]), int(s["built"]), int(s["plots_total"])]])
	rows.append([false, "السكان: %d/%d • الأصحاء: %d • المرضى: %d" % [int(s["pop_total"]), int(s["pop_cap"]), int(s["healthy"]), int(s["sick"])]])
	rows.append([false, "ثقة السكان: %d%%" % int(round(float(s["trust"])))])
	rows.append([true, "الاقتصاد الآن"])
	var res: Dictionary = s["res"]
	var net: Dictionary = s["net"]
	for r in ["food", "wood", "coal", "iron"]:
		if not res.has(r):
			continue
		var n: float = float(net[r])
		rows.append([false, "%s: %s (%s%.0f/س)" % [Defs.RES_NAMES[r], Defs.fmt(float(res[r])), "+" if n >= 0.0 else "-", absf(n)]])
	rows.append([true, "الجيش"])
	rows.append([false, "الجنود: %d • الجرحى: %d/%d" % [int(s["troops"]), int(s["wounded"]), int(s["wounded_cap"])]])
	rows.append([false, "المسيرات النشطة: %d/%d • مسيرة عسكرية: %s" % [int(s["marches"]), int(s["marches_max"]), "نشطة" if s["venture_active"] else "لا يوجد"]])
	rows.append([false, "القوة: %s" % Defs.fmt(float(s["power"]))])
	rows.append([true, "الخريطة والسيطرة"])
	rows.append([false, "معاقل: %d/4 • قلاع: %d/8" % [int(s["strongholds"]), int(s["fortresses"])]])
	rows.append([false, "استكشاف الخريطة: %.1f%%" % float(s["explored_pct"])])
	rows.append([false, "العاصفة: %s • الطقس: %s" % ["نشطة" if s["storm"] else "هادئة", cold_name(int(s["cold"]))]])
	rows.append([true, "الإنجاز التراكمي"])
	var lt: Dictionary = s["lifetime"]
	var col: Dictionary = lt["collected"]
	var col_parts: Array[String] = []
	for r in ["food", "wood", "coal", "iron"]:
		if col.has(r) and float(col[r]) > 0.0:
			col_parts.append("%s %s" % [Defs.fmt(float(col[r])), Defs.RES_NAMES[r]])
	rows.append([false, "جُمع منذ البداية: %s" % ("، ".join(col_parts) if not col_parts.is_empty() else "لا شيء بعد")])
	rows.append([false, "عمليات بناء وترقية اكتملت: %d • مسيرات أُرسلت: %d • جنود دُرّبوا: %d" % [int(lt["built"]), int(lt["marches"]), int(lt["trained"])]])
	rows.append([false, "أبحاث مكتملة: %d • بلورات شفق: %d • قرارات اتُّخذت: %d" % [int(lt["research"]), int(lt["aurora"]), int(lt["decisions"])]])
	return rows


static func cold_name(c: int) -> String:
	return ["دافئ", "بارد", "متجمد"][clampi(c, 0, 2)]


