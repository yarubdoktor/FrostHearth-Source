extends RefCounted
## Stage 24 — نافذة الملف الشخصي: الهوية (اسم + صورة + معرّف) وبطاقة اللاعب، وزر الإعدادات داخلها

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const Profile := preload("res://scripts/game/profile.gd")
const AchievementsPanel := preload("res://scripts/ui/windows/achievements_panel.gd")


static func show(city: Node) -> void:
	city._window("الملف الشخصي", "hero", func(body: VBoxContainer): _build(city, body))


static func _avatar_tex(city: Node, id: String) -> Texture2D:
	return city._portrait(id) if id != "" else UI.icon("hero")


static func _build(city: Node, body: VBoxContainer) -> void:
	Game.refresh_profile_achievements()
	var card := Game.profile_card()
	# بطاقة الهوية
	var head: PanelContainer = city._card()
	body.add_child(head)
	var hh: HBoxContainer = city._hrow(14)
	head.add_child(hh)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(info)
	var nm := UI.label(str(card["name"]), 30, UI.GOLD)
	info.add_child(nm)
	var title := Profile.Achievements.title(Game.profile)
	if title != "":
		var title_label: Label = city._wrap(title, 18, UI.GOLD)
		title_label.name = "ProfileTitle"
		info.add_child(title_label)
	info.add_child(UI.label("المعرّف  #%d" % int(card["id"]), 18, Color("b9cbe0")))
	info.add_child(UI.label("%d يوم لعب" % int(card["days"]), 17, Color("b9cbe0")))
	var pic := TextureRect.new()
	pic.texture = _avatar_tex(city, str(card["avatar"]))
	pic.custom_minimum_size = Vector2(110, 110)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "ProfileFrame"
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color := Profile.Achievements.frame_color(Game.profile)
	portrait_frame.add_theme_stylebox_override("panel", AchievementsPanel.frame_style(color if color != "" else "49657b"))
	portrait_frame.add_child(pic)
	hh.add_child(portrait_frame)

	# تعديل الاسم
	var nc: PanelContainer = city._card()
	body.add_child(nc)
	var nv := VBoxContainer.new()
	nc.add_child(nv)
	nv.add_child(city._wrap("اسم اللاعب (%d–%d حرفًا)" % [Profile.NAME_MIN, Profile.NAME_MAX], 17, Color("b9cbe0")))
	var nrow: HBoxContainer = city._hrow(8)
	nv.add_child(nrow)
	var edit := LineEdit.new()
	edit.text = str(card["name"])
	edit.max_length = Profile.NAME_MAX + 8
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 50)
	edit.add_theme_font_size_override("font_size", 22)
	edit.name = "NameEdit"
	var save := UI.button("حفظ", func(): _save_name(city, edit), "gold", 50)
	save.custom_minimum_size = Vector2(110, 50)
	save.name = "SaveName"
	edit.text_submitted.connect(func(_t): _save_name(city, edit))
	nrow.add_child(save)
	nrow.add_child(edit)

	# اختيار الصورة
	var ac: PanelContainer = city._card()
	body.add_child(ac)
	var av := VBoxContainer.new()
	ac.add_child(av)
	av.add_child(city._wrap("الصورة الرمزية — من أبطالك المملوكين", 17, Color("b9cbe0")))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	av.add_child(flow)
	var chosen := str(Game.profile["avatar"])
	flow.add_child(_avatar_button(city, "", "تلقائي", chosen == ""))
	for hid in Game.owned_hero_ids():
		flow.add_child(_avatar_button(city, hid, str(Defs.HEROES[hid]["name"]), chosen == hid))
	if Game.owned_hero_ids().is_empty():
		av.add_child(city._wrap("استدعِ بطلًا من قاعة الأبطال لتختار صورته. «تلقائي» يعرض قائد الدفاع ثم الحاكم.", 16, Color("b9cbe0")))

	# البطاقة
	var sc: PanelContainer = city._card()
	body.add_child(sc)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sc.add_child(sv)
	sv.add_child(city._wrap("بطاقة اللاعب", 20, UI.GOLD))
	var rows := [
		["قوة المدينة", Defs.fmt(float(card["power"]))],
		["مستوى الفرن", str(int(card["furnace"]))],
		["الجنود", Defs.fmt(float(card["troops"]))],
		["الأبطال", str(int(card["heroes"]))],
		["الأبحاث المكتملة", str(int(card["techs"]))],
		["غارات صمدت أمامها", "%d من %d" % [int(card["raids_won"]), int(card["raids"])]],
		["أيام اللعب", str(int(card["days"]))],
	]
	for r in rows:
		var rw: HBoxContainer = city._hrow()
		sv.add_child(rw)
		var val := UI.label(str(r[1]), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rw.add_child(val)
		rw.add_child(UI.label(str(r[0]), 19, Color("b9cbe0")))

	AchievementsPanel.build(city, body)

	# الإعدادات داخل الملف
	var gear := UI.button("الإعدادات", func():
		city._close_window()
		city._show_settings(), "blue", 56)
	gear.name = "SettingsBtn"
	body.add_child(gear)
	var last := [_achievement_signature()]
	city.win_tick.append(func():
		if is_instance_valid(body) and last[0] != _achievement_signature():
			last[0] = _achievement_signature()
			city._refresh_window())


static func _achievement_signature() -> String:
	return str(Game.profile) + str(Game.owned_hero_ids()) \
		+ str(Game.plots.get("furnace", 0)) + str(Game.raid_wins)


static func _avatar_button(city: Node, id: String, label: String, on: bool) -> Button:
	var b := UI.button("", func(): _pick(city, id), "gold" if on else "dark", 84)
	b.custom_minimum_size = Vector2(96, 96)
	b.icon = _avatar_tex(city, id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 64)
	b.tooltip_text = label
	if id == "":
		b.text = label
		b.add_theme_font_size_override("font_size", 15)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 48)
	b.name = "Av_" + (id if id != "" else "auto")
	return b


static func _pick(city: Node, id: String) -> void:
	Game.set_profile_avatar(id)
	city._refresh_window()


static func _save_name(city: Node, edit: LineEdit) -> void:
	if Game.set_profile_name(edit.text):
		city._toast("تم حفظ الاسم")
		city._refresh_window()
