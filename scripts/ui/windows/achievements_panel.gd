extends RefCounted
## Compact, scrolling profile section using existing art, no new window layer.
const UI := preload("res://scripts/ui_kit.gd")
const Rules := preload("res://scripts/game/achievements.gd")


static func frame_style(color: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102238")
	style.border_color = Color(color)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(5)
	return style


static func refresh_hud(button: Button) -> void:
	var color := Rules.frame_color(Game.profile)
	if str(button.get_meta("profile_frame", "unset")) == color:
		return
	if not button.has_meta("profile_original_styles"):
		var originals := {}
		for state in ["normal", "hover", "pressed"]:
			originals[state] = button.get_theme_stylebox(state)
		button.set_meta("profile_original_styles", originals)
	button.set_meta("profile_frame", color)
	for state in ["normal", "hover", "pressed"]:
		if color == "":
			button.add_theme_stylebox_override(state, button.get_meta("profile_original_styles")[state])
		else:
			var style := frame_style(color)
			if state == "pressed":
				style.bg_color = Color("20364e")
			button.add_theme_stylebox_override(state, style)


static func build(city: Node, body: VBoxContainer) -> void:
	var panel: PanelContainer = city._card()
	panel.name = "AchievementsPanel"
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(city._wrap("الإنجازات والتخصيص  %d/%d" % [Game.profile["badges"].size(), Rules.ORDER.size()], 21, UI.GOLD))
	column.add_child(city._wrap("كل إنجاز يفتح لقبًا وإطارًا للصورة. تخصيص تجميلي فقط، بلا مكافأة قوة أو موارد.", 16, UI.TEXT_DIM))
	for id in Rules.ORDER:
		_badge(city, column, id)
	var defaults := HBoxContainer.new()
	defaults.add_theme_constant_override("separation", 8)
	column.add_child(defaults)
	for kind in ["title", "frame"]:
		var button := UI.button("بدون لقب" if kind == "title" else "الإطار الافتراضي",
			func(): _choose(city, kind, ""), "dark", 52)
		button.name = "Reset_" + kind
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		defaults.add_child(button)


static func _badge(city: Node, column: VBoxContainer, id: String) -> void:
	var definition: Dictionary = Rules.DEFS[id]
	var unlocked: bool = Game.profile["badges"].has(id)
	var goal := int(definition["goal"])
	var value := goal if unlocked else mini(Rules.progress(Game, id), goal)
	var row := VBoxContainer.new()
	row.name = "Badge_" + id
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var color := Color(str(definition["color"])) if unlocked else UI.TEXT_DIM
	row.add_child(city._wrap("%s • %s" % [definition["name"], "مكتمل" if unlocked else "مقفل"], 19, color))
	row.add_child(city._wrap("%s  (%d/%d)" % [definition["description"], value, goal], 16, UI.TEXT_DIM))
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 14
	progress.max_value = goal
	progress.value = value
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(str(definition["color"]))
	fill.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("24364c")
	background.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("background", background)
	row.add_child(progress)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	row.add_child(buttons)
	for kind in ["title", "frame"]:
		var chosen: bool = str(Game.profile[kind]) == id
		var caption := "لقب: " + str(definition["title"]) if kind == "title" else "إطار الصورة"
		if chosen:
			caption += " • مفعّل"
		var button := UI.button(caption, func(): _choose(city, kind, id), "gold" if chosen else "dark", 54)
		button.name = "Pick_%s_%s" % [kind, id]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not unlocked
		button.tooltip_text = "" if unlocked else str(definition["description"])
		button.add_theme_font_size_override("font_size", 15)
		buttons.add_child(button)


static func _choose(city: Node, kind: String, id: String) -> void:
	if Game.set_profile_decoration(kind, id):
		city._refresh_window()
