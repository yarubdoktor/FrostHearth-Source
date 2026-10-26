extends RefCounted
## Stage 29.1: portrait hero gallery and a dedicated details view.
## Presentation only: all game actions continue to use the existing Game API.
const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")


static func portrait(city: Node, id: String) -> Texture2D:
	if not city._portraits.has(id):
		city._portraits[id] = load("res://assets/heroes/%s.jpg" % id)
	return city._portraits[id]


static func show(city: Node) -> void:
	city.hero_detail = false
	city._window("قاعة الأبطال", "hero", city._build_heroes)


static func _signature(city: Node) -> String:
	return str(Game.heroes) + str(Game.aurora) + str(Game.defender) + str(Game.governor) \
		+ str(Game.hero_cap()) + str(Game.dev_mode) + str(Game.hero_level_check(city.hero_sel)["ok"])


static func build(city: Node, outer: VBoxContainer) -> void:
	if not Defs.HEROES.has(city.hero_sel):
		city.hero_sel = Defs.HERO_ORDER[0]
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_left", 4)
	outer.add_child(inset)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	inset.add_child(body)
	body.add_child(_text("الأبطال: %d من %d  |  بلورات الشفق: %d" % [
		Game.heroes_owned(), Defs.HERO_ORDER.size(), Game.aurora], 20, UI.GOLD))
	if city.hero_detail:
		_details(city, body)
	else:
		_gallery(city, body)
	var last := [_signature(city)]
	city.win_tick.append(func():
		if is_instance_valid(body) and last[0] != _signature(city):
			last[0] = _signature(city)
			city._refresh_window())


static func _text(value: String, size: int = 17, color: Color = Color.WHITE) -> Label:
	var label := UI.label(value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func _box(parent: Control, name: String = "") -> VBoxContainer:
	var panel := UI.panel(Color("101e32"), 16)
	panel.name = name if name != "" else "HeroSection"
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


static func _image(city: Node, id: String, height: float) -> TextureRect:
	var image := TextureRect.new()
	image.texture = portrait(city, id)
	image.custom_minimum_size = Vector2(0, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.clip_contents = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


static func _stars(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(5 - stars)


static func _role(id: String) -> String:
	if Game.defender == id:
		return "قائد الدفاع"
	if Game.governor == id:
		return "حاكم المدينة"
	return ""


static func _gallery(city: Node, body: VBoxContainer) -> void:
	body.name = "HeroesGallery"
	body.add_child(_text("اختر بطاقة بطل لعرض مهاراته وترقياته وتعيين دوره.", 17, UI.TEXT_DIM))
	var role_box := _box(body, "HeroRoles")
	var defender := "غير معيّن" if Game.defender == "" else str(Defs.HEROES[Game.defender]["name"])
	var governor := "غير معيّن" if Game.governor == "" else str(Defs.HEROES[Game.governor]["name"])
	role_box.add_child(_text("قائد الدفاع: %s   |   حاكم المدينة: %s" % [defender, governor], 17, Color("a9e6ff")))
	var grid := GridContainer.new()
	grid.name = "HeroesGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for id in Defs.HERO_ORDER:
		_hero_card(city, grid, id)
	if Game.max_level_of("hero_hall") <= 0:
		body.add_child(_text("قاعة الأبطال تُفتح عند الفرن 4. يمكنك جمع الشظايا الآن؛ ضم الأبطال يحتاج بناء القاعة.", 17, UI.GOLD))
	body.add_child(_text("بلا صناديق حظ: تختار البطل، وكل استدعاء يمنح 10 شظايا مقابل %d بلورة شفق." % Defs.SUMMON_COST, 16, UI.TEXT_DIM))


static func _hero_card(city: Node, grid: GridContainer, id: String) -> void:
	var hd: Dictionary = Defs.HEROES[id]
	var h: Dictionary = Game.heroes[id]
	var accent := Color(hd["color"])
	var button := Button.new()
	button.name = "HeroCard_" + id
	button.custom_minimum_size = Vector2(190, 300)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(hd["name"]) + " | " + str(hd["title"])
	var border := UI.GOLD if _role(id) != "" else accent.darkened(0.35)
	button.add_theme_stylebox_override("normal", UI.style(Color("101c2e"), 16, border, 0))
	button.add_theme_stylebox_override("hover", UI.style(Color("1d3047"), 16, accent, 0))
	button.add_theme_stylebox_override("pressed", UI.style(Color("273d55"), 16, UI.GOLD, 0))
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + edge, 8)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	inset.add_child(column)
	var image := _image(city, id, 143)
	if not h["owned"]:
		image.modulate = Color(0.65, 0.69, 0.77)
	column.add_child(image)
	column.add_child(_text(str(hd["name"]), 23, accent))
	column.add_child(_text("%s | %s" % [Defs.TROOPS[hd["troop"]]["plural"], hd["elem"]], 14, UI.TEXT_DIM))
	if h["owned"]:
		column.add_child(_text("%s | مستوى %d" % [_stars(int(h["stars"])), int(h["lv"])], 14, UI.GOLD))
		column.add_child(_text(_role(id) if _role(id) != "" else "مملوك", 14, Color("8fe3a1")))
	else:
		column.add_child(_text("الشظايا: %d من %d" % [int(h["shards"]), Defs.STAR_SHARDS[0]], 14, UI.GOLD))
		column.add_child(_text("جاهز للضم" if int(h["shards"]) >= Defs.STAR_SHARDS[0] else "غير مملوك", 14, UI.TEXT_DIM))
		var bar := UI.progress_bar(accent)
		bar.custom_minimum_size = Vector2(0, 5)
		bar.value = minf(100, 100.0 * int(h["shards"]) / Defs.STAR_SHARDS[0])
		column.add_child(bar)
	_ignore_mouse(column)
	button.pressed.connect(func(): _navigate(city, id, true))
	button.pressed.connect(func(): Sound.ui_click())
	grid.add_child(button)


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


static func _navigate(city: Node, id: String, details: bool) -> void:
	city.hero_sel = id
	city.hero_detail = details
	city.win_scroll.scroll_vertical = 0
	city._refresh_window()


static func _details(city: Node, body: VBoxContainer) -> void:
	body.name = "HeroDetails"
	var id: String = city.hero_sel
	var hd: Dictionary = Defs.HEROES[id]
	var h: Dictionary = Game.heroes[id]
	var back := UI.button("العودة إلى جميع الأبطال", func(): _navigate(city, id, false), "dark", 50)
	back.name = "HeroBack"
	body.add_child(back)
	var hero := _box(body, "SelectedHero")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	hero.add_child(heading)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(info)
	info.add_child(_text(str(hd["name"]), 32, Color(hd["color"])))
	info.add_child(_text(str(hd["title"]), 20, UI.GOLD))
	info.add_child(_text("%s | %s" % [hd["elem"], Defs.TROOPS[hd["troop"]]["plural"]], 17, UI.TEXT_DIM))
	info.add_child(_text(_stars(int(h["stars"])), 25, UI.GOLD))
	info.add_child(_text("المستوى %d | الحد %d" % [int(h["lv"]), Game.hero_cap()], 17))
	info.add_child(_text(_role(id) if _role(id) != "" else ("مملوك" if h["owned"] else "غير مملوك"), 17, UI.GREEN))
	var image := _image(city, id, 190)
	image.custom_minimum_size.x = 190
	image.name = "SelectedHeroPortrait"
	heading.add_child(image)
	if not h["owned"]:
		image.modulate = Color(0.7, 0.74, 0.82)
	var need: int = Defs.STAR_SHARDS[0] if not h["owned"] else (Defs.STAR_SHARDS[int(h["stars"]) + 1] if int(h["stars"]) < 5 else 0)
	hero.add_child(_text("الشظايا: %d من %d" % [int(h["shards"]), need] if need > 0 else "النجوم مكتملة | الشظايا: %d" % int(h["shards"]), 18, UI.GOLD))
	if need > 0:
		var bar := UI.progress_bar(Color(hd["color"]))
		bar.custom_minimum_size = Vector2(0, 9)
		bar.value = minf(100, 100.0 * int(h["shards"]) / need)
		hero.add_child(bar)
	_actions(city, body, id, h, need)
	var skills := _box(body, "HeroSkills")
	skills.add_child(_text("مهارات البطل", 21, UI.GOLD))
	var bonus := Defs.hero_bonus(int(h["lv"]), int(h["stars"]))
	skills.add_child(_text("تعزيز القائد: هجوم ودفاع وصحة %s +%.1f%%" % [Defs.TROOPS[hd["troop"]]["plural"], bonus * 100], 17))
	skills.add_child(_text("%s: %s" % [hd["skill"], hd["skill_desc"]], 17, Color("ffd9a0")))
	skills.add_child(_text("%s: %s" % [hd["city"], hd["city_desc"]], 17, Color("a9e6ff")))
	skills.add_child(_text("مكافأة حاكم المدينة تقوى 15% مع كل نجمة.", 15, UI.TEXT_DIM))
	var story := _box(body, "HeroStory")
	story.add_child(_text("قصة البطل", 20, UI.GOLD))
	story.add_child(_text(str(hd["story"]), 16, UI.TEXT_DIM))


static func _actions(city: Node, body: VBoxContainer, id: String, h: Dictionary, need: int) -> void:
	var box := _box(body, "HeroActions")
	if not h["owned"]:
		var unlock := UI.button("ضم البطل", func(): Game.hero_unlock(id), "gold", 54)
		unlock.name = "HeroUnlock"
		unlock.disabled = not Game.dev_mode and (int(h["shards"]) < Defs.STAR_SHARDS[0] or Game.max_level_of("hero_hall") <= 0)
		box.add_child(unlock)
		if Game.max_level_of("hero_hall") <= 0 and not Game.dev_mode:
			box.add_child(_text("ابنِ قاعة الأبطال أولًا لتتمكن من ضم البطل.", 16, UI.GOLD))
	else:
		var check := Game.hero_level_check(id)
		var cost: Array[String] = []
		for r in check["cost"]:
			cost.append("%s %s" % [Defs.fmt(float(check["cost"][r])), Defs.RES_NAMES[r]])
		box.add_child(_text("تكلفة المستوى التالي: " + " | ".join(cost), 16, UI.TEXT_DIM))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var level := UI.button("ترقية المستوى", func(): Game.hero_level_up(id), "gold", 54)
		level.name = "HeroLevelUp"
		level.disabled = not check["ok"]
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(level)
		var star := UI.button("رفع نجمة", func(): Game.hero_star_up(id), "blue", 54)
		star.name = "HeroStarUp"
		star.disabled = int(h["stars"]) >= 5 or (not Game.dev_mode and int(h["shards"]) < need)
		star.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(star)
		if not check["reasons"].is_empty():
			box.add_child(_text(" | ".join(check["reasons"]), 15, UI.GOLD))
		elif not check["missing"].is_empty():
			box.add_child(_text("الموارد غير كافية لترقية المستوى.", 15, UI.GOLD))
	var summon := UI.button("استدعاء • %d بلورة" % Defs.SUMMON_COST, func(): Game.hero_summon(id), "blue", 54)
	summon.name = "HeroSummon"
	summon.disabled = not Game.dev_mode and Game.aurora < Defs.SUMMON_COST
	box.add_child(summon)
	box.add_child(_text("الاستدعاء يمنح 10 شظايا لهذا البطل، بلا اختيار عشوائي.", 15, UI.TEXT_DIM))
	if h["owned"]:
		var roles := HBoxContainer.new()
		roles.add_theme_constant_override("separation", 10)
		box.add_child(roles)
		var defend := UI.button("إلغاء قيادة الدفاع" if Game.defender == id else "قائد الدفاع",
			func(): Game.set_role(id, "defender"), "green" if Game.defender == id else "dark", 52)
		defend.name = "HeroDefender"
		defend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roles.add_child(defend)
		var govern := UI.button("إلغاء الحكم" if Game.governor == id else "حاكم المدينة",
			func(): Game.set_role(id, "governor"), "green" if Game.governor == id else "dark", 52)
		govern.name = "HeroGovernor"
		govern.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roles.add_child(govern)
