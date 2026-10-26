extends RefCounted
## واجهة الخريطة الخارجية (المرحلة 25): نفس هيكل واجهة المدينة.
## الأعلى: شريط الموارد ثم صف (الموقع • عداد القوة) • تحته عمودان: بطاقة الحالة يسارًا ولوحة الفرق يمينًا
## الأسفل: شريط تنقل ثابت بخمسة أزرار متساوية العرض + صفيحة أدوات تُفتح من زر «أدوات».

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")

const NAV_H := 78.0
const COLUMN_TOP := 150.0
const STATUS_W := 214.0
const RES_ORDER := ["food", "wood", "coal", "iron"]


static func build(map: Node3D) -> void:
	_top(map)
	_status_card(map)
	_bottom(map)


static func _top(map: Node3D) -> void:
	var box := VBoxContainer.new()
	box.name = "MapTop"
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.ui.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	map.ui_blockers.append(box)

	# الصف الأول: الموارد (نفس شكل المدينة)
	var strip := UI.panel(Color(0.04, 0.08, 0.14, 0.9), 16)
	box.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	strip.add_child(row)
	for r in RES_ORDER + ["gems"]:
		var c := UI.chip("gem" if r == "gems" else r, 24, 16)
		var csb := (c[0] as Control).get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		csb.content_margin_left = 6.0
		csb.content_margin_right = 6.0
		(c[0] as Control).add_theme_stylebox_override("panel", csb)
		(c[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(c[0] as Control).custom_minimum_size = Vector2(0, 0)
		row.add_child(c[0])
		map.res_chips[r] = c[1]

	# الصف الثاني: الموقع يسارًا • عداد القوة يمينًا
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row2)
	var lg := HBoxContainer.new()
	lg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(lg)
	var loc := UI.chip("map", 28, 18)
	map.coord_label = loc[1]
	lg.add_child(loc[0])
	var rg := HBoxContainer.new()
	rg.alignment = BoxContainer.ALIGNMENT_END
	rg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(rg)
	var pw := UI.power_bar(230.0)
	map.power_label = pw[1]
	rg.add_child(pw[0])


static func _status_row(icon_name: String, color: Color, wrap := false) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UI.icon_rect(icon_name, 24))
	var l := UI.label("", 15, color, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(STATUS_W - 70.0, 0)
	h.add_child(l)
	return [h, l]


static func _status_card(map: Node3D) -> void:
	var card := UI.panel(Color(0.04, 0.08, 0.14, 0.85), 14)
	card.name = "MapStatusCard"
	card.custom_minimum_size = Vector2(STATUS_W, 0)
	map.ui.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	card.position.y = COLUMN_TOP
	map.ui_blockers.append(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(UI.label("الخارج الأخضر", 17, Color("ffd36b"), HORIZONTAL_ALIGNMENT_LEFT))
	var a := _status_row("army", Color("7fd3ff"))
	map.march_label = a[1]
	v.add_child(a[0])
	var b := _status_row("shield", Color("a9f0a0"))
	map.holds_label = b[1]
	v.add_child(b[0])
	var c := _status_row("time", Color("9fb8d0"), true)
	map.front_label = c[1]
	v.add_child(c[0])


static func _nav_button(text: String, icon_name: String, cb: Callable, kind: String) -> Button:
	var b := UI.button(text, cb, kind, int(NAV_H))
	b.icon = UI.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 36)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 15)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, NAV_H)
	return b


static func _bottom(map: Node3D) -> void:
	var box := VBoxContainer.new()
	box.name = "MapBottom"
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.ui.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map.ui_blockers.append(box)

	# صفيحة الأدوات (مخفية حتى يُضغط «أدوات»)
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 8)
	mg.add_theme_constant_override("margin_right", 8)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.visible = false
	box.add_child(mg)
	map.tools_sheet = mg
	var sheet := UI.panel(Color(0.05, 0.1, 0.17, 0.94), 16)
	mg.add_child(sheet)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	sheet.add_child(th)
	var hide_sheet := func() -> void: mg.visible = false
	var night := UI.button("الليل / النهار", func() -> void:
		hide_sheet.call()
		map._toggle_night(), "dark", 54)
	var sun := UI.button("مدينة الشمس", func() -> void:
		hide_sheet.call()
		map.rig.fly_to(Vector3(600, 0, 600), 95.0), "dark", 54)
	map.biome_button = UI.button("مقارنة البيئة", func() -> void:
		hide_sheet.call()
		map._toggle_external_preview(), "dark", 54)
	for bt in [night, sun, map.biome_button]:
		(bt as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(bt)

	# شريط التنقل الثابت: خمسة أزرار متساوية العرض
	var nav := UI.panel(Color(0.03, 0.06, 0.11, 0.96), 0)
	nav.name = "MapNav"
	box.add_child(nav)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	nav.add_child(nh)
	var tabs := [
		["tools", "أدوات", "gear", func() -> void:
			map._close_panel()
			mg.visible = not mg.visible, "dark"],
		["skin", "سكن المدينة", "hammer", func() -> void:
			mg.visible = false
			map.skin_picker.show_picker(), "dark"],
		["full", "الخريطة كاملة", "map", func() -> void: map.rig.fly_to(Vector3(600, 0, 600), 300.0, 1.0), "dark"],
		["home", "مدينتي", "pop", func() -> void: map.rig.fly_to(map.home_pos, 34.0), "dark"],
		["enter", "دخول المدينة", "fire", func() -> void: map._go_city(), "gold"],
	]
	for t in tabs:
		var b := _nav_button(t[1], t[2], t[3], t[4])
		nh.add_child(b)
		map.nav_btns[t[0]] = b


static func refresh(map: Node3D) -> void:
	for r in map.res_chips:
		var l: Label = map.res_chips[r]
		var v: float = Game.gems if r == "gems" else Game.res[r]
		l.text = Defs.fmt(v)
		l.add_theme_color_override("font_color", UI.RED if r != "gems" and Game.net_rate(r) < 0 and v < 200 else Color.WHITE)
	if map.power_label != null:
		map.power_label.text = Defs.fmt(Game.power())
