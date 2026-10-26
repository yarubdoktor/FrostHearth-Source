extends Node
## Stage 31 / P3: unlocks, cosmetics, old saves, persistence, portrait UI.
const Rules := preload("res://scripts/game/achievements.gd")
const Profile := preload("res://scripts/game/profile.gd")
const Defs := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame


func fresh() -> void:
	Game.save_path_override = "user://stage31_profile.json"
	Game.profile = {}
	Game.new_game()
	Game.set_process(false)
	Game.dev_mode = false
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.offline_report = {}
	Game.stats["built"] = 1


func find_node(node: Node, target: String) -> Node:
	if str(node.name) == target:
		return node
	for child in node.get_children():
		var found := find_node(child, target)
		if found != null:
			return found
	return null


func test_rules() -> void:
	check(Rules.ORDER.size() == 3 and Rules.DEFS.size() == 3, "three planned milestones have definitions")
	var profile := Profile.sanitize({"name": "قائد الشمال", "id": 123456}, 10000)
	check(profile["badges"].is_empty() and profile["title"] == "" and profile["frame"] == "", "legacy profile defaults to no cosmetics")
	check(profile["name"] == "قائد الشمال" and profile["id"] == 123456, "adding defaults keeps old identity")
	profile = Profile.sanitize({"badges": ["first_hero", "first_hero", "bogus", 42],
		"title": "first_hero", "frame": "bogus"}, 10000)
	check(profile["badges"] == ["first_hero"], "save repair deduplicates and discards unknown badges")
	check(profile["title"] == "first_hero" and profile["frame"] == "", "save repair keeps unlocked selection only")
	profile = Profile.sanitize({"badges": "first_hero", "title": "first_hero", "frame": "furnace_10"}, 10000)
	check(profile["badges"].is_empty() and profile["title"] == "" and profile["frame"] == "", "bad saved list cannot unlock cosmetics")
	profile = Profile.sanitize({"badges": {}, "title": {}, "frame": null}, 10000)
	check(profile["badges"].is_empty() and Rules.title(profile) == "" and Rules.frame_color(profile) == "", "malformed optional fields safely use defaults")
	check(Rules.title({}) == "" and Rules.frame_color({}) == "", "missing decorations are safe")
	for id in Rules.ORDER:
		profile = Profile.sanitize({"badges": [id], "title": id, "frame": id}, 10000)
		check(Rules.title(profile) == str(Rules.DEFS[id]["title"]), "saved title resolves for " + id)
		check(Color(Rules.frame_color(profile)).a > 0, "saved frame has valid visible color for " + id)


func test_unlocks() -> void:
	fresh()
	check(Game.profile["badges"].is_empty(), "fresh settlement grants no milestone")
	check(not Game.set_profile_decoration("title", "first_hero"), "locked title cannot be equipped")
	check(not Game.set_profile_decoration("frame", "furnace_10"), "locked frame cannot be equipped")
	check(not Game.set_profile_decoration("name", "") and not Game.set_profile_decoration("frame", "bogus"), "unknown kinds and ids are refused")
	var hid := str(Defs.HERO_ORDER[0])
	Game.heroes[hid]["shards"] = 999
	Game.changed.emit()
	check(Game.profile["badges"].is_empty(), "hero shards alone do not count as an owned hero")
	Game.heroes[hid]["owned"] = true
	Game.changed.emit()
	check(Game.profile["badges"] == ["first_hero"], "ownership change automatically unlocks first hero")
	Game.changed.emit()
	Game.save_game()
	check(Game.profile["badges"] == ["first_hero"], "repeated updates and saves cannot duplicate badge")
	Game.plots["furnace"] = 9
	Game.raid_count = 50
	Game.raid_wins = 9
	Game.changed.emit()
	check(Game.profile["badges"].size() == 1, "furnace nine and nine wins remain below threshold")
	check(not Game.set_profile_decoration("title", "ten_defenses"), "failed raids do not unlock defense title")
	Game.plots["furnace"] = 10
	Game.changed.emit()
	check(Game.profile["badges"].has("furnace_10"), "furnace ten automatically unlocks its milestone")
	Game.raid_wins = 10
	Game.changed.emit()
	check(Game.profile["badges"].has("ten_defenses") and Game.profile["badges"].size() == 3, "ten defense victories unlock third milestone")
	var resources: Dictionary = Game.res.duplicate(true)
	var gems: int = Game.gems
	var power: float = Game.power()
	var mods: Dictionary = Game.army_mods("shield").duplicate(true)
	var gear: Dictionary = Game.equipment.duplicate(true)
	for id in Rules.ORDER:
		check(Game.set_profile_decoration("title", id), "unlocked title equips: " + id)
		check(Game.set_profile_decoration("frame", id), "unlocked frame equips: " + id)
	check(Game.res == resources and Game.gems == gems, "cosmetics neither spend nor grant currency")
	check(is_equal_approx(Game.power(), power) and Game.army_mods("shield") == mods, "cosmetics do not change strength or combat")
	check(Game.equipment == gear, "cosmetics do not modify workshop equipment")
	check(Game.set_profile_decoration("title", "") and Game.set_profile_decoration("frame", ""), "default title and frame can be restored")
	check(Game.profile["title"] == "" and Game.profile["frame"] == "", "reset selections really clear saved fields")
	Game.set_profile_decoration("title", "first_hero")
	Game.set_profile_decoration("frame", "furnace_10")
	var pid: int = Game.profile["id"]
	Game.save_game()
	Game.profile = {}
	check(Game.load_game(), "extended v7 save loads")
	check(Game.profile["badges"].size() == 3 and Game.profile["title"] == "first_hero" and Game.profile["frame"] == "furnace_10",
		"all badges and independent selections survive reload")
	Game.new_game()
	check(Game.profile["id"] == pid and Game.profile["badges"].size() == 3, "new settlement keeps earned profile milestones with identity")
	check(Game.profile["title"] == "first_hero" and Game.profile["frame"] == "furnace_10", "new settlement keeps chosen cosmetics")
	check(Game.plots["furnace"] == 1 and Game.raid_wins == 0 and Game.owned_hero_ids().is_empty(), "profile persistence does not carry over settlement progression")
	# Old v7: optional cosmetic fields missing, existing achievements backfilled.
	fresh()
	Game.heroes[hid]["owned"] = true
	Game.plots["furnace"] = 10
	Game.raid_wins = 10
	Game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	for key in ["badges", "title", "frame"]:
		data["profile"].erase(key)
	data["v"] = 7
	var file := FileAccess.open(Game._save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	Game.profile = {}
	check(Game.load_game(), "previous Stage 30 save without cosmetic fields loads")
	check(Game.profile["badges"].size() == 3 and Game.profile["title"] == "" and Game.profile["frame"] == "",
		"old settlement retroactively earns milestones without auto-equipping rewards")
	check(Game.SAVE_VERSION == 7, "cosmetic optional fields need no save-version migration")


func capture(city: Node, suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture=") + suffix + ".png")


func test_ui() -> void:
	fresh()
	var city: Node = load("res://city.tscn").instantiate()
	add_child(city)
	await frames()
	var original: StyleBox = city.avatar_btn.get_theme_stylebox("normal")
	city._show_profile()
	await frames()
	check(find_node(city.win_dim, "AchievementsPanel") != null, "profile includes achievement section")
	for id in Rules.ORDER:
		check(find_node(city.win_dim, "Badge_" + id) != null, "profile shows progress for " + id)
		check((find_node(city.win_dim, "Pick_title_" + id) as Button).disabled, "locked title control is disabled for " + id)
		check((find_node(city.win_dim, "Pick_frame_" + id) as Button).disabled, "locked frame control is disabled for " + id)
	check(find_node(city.win_dim, "ProfileTitle") == null, "default profile has no invented title")
	# An unlock while the profile is open should update it.
	Game.heroes[str(Defs.HERO_ORDER[0])]["owned"] = true
	Game.changed.emit()
	await frames()
	var title_button := find_node(city.win_dim, "Pick_title_first_hero") as Button
	check(title_button != null and not title_button.disabled, "open profile reacts to newly earned milestone")
	title_button.pressed.emit()
	await frames()
	check(Game.profile["title"] == "first_hero", "profile title button chooses earned title")
	var label := find_node(city.win_dim, "ProfileTitle") as Label
	check(label != null and label.text == "جامع الأبطال", "equipped title appears beneath player name")
	(find_node(city.win_dim, "Pick_frame_first_hero") as Button).pressed.emit()
	await frames()
	check(Game.profile["frame"] == "first_hero", "profile frame button chooses earned frame")
	var frame := find_node(city.win_dim, "ProfileFrame") as PanelContainer
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	check(style != null and style.border_color == Color("80cbe8"), "portrait displays selected frame color")
	style = city.avatar_btn.get_theme_stylebox("normal") as StyleBoxFlat
	check(style != null and style.border_color == Color("80cbe8"), "main HUD avatar displays selected frame")
	check(str((find_node(city.win_dim, "Pick_title_first_hero") as Button).text).contains("مفعّل"), "selected reward is visibly marked active")
	var dim: Rect2 = city.win_dim.get_global_rect()
	check(dim.position.x >= 0 and dim.end.x <= 721, "profile window remains within portrait width")
	await capture(city, "-top")
	city.win_scroll.scroll_vertical = 100000
	await frames()
	check(city.win_scroll.get_v_scroll_bar().max_value > city.win_scroll.size.y, "long profile scrolls vertically")
	for id in Rules.ORDER:
		var button := find_node(city.win_dim, "Pick_title_" + id) as Button
		check(button.size.y >= 50 and button.get_global_rect().end.x <= 721 and button.global_position.x >= 0,
			"reward button fits width with touch height for " + id)
	await capture(city, "-badges")
	var scroll: int = city.win_scroll.scroll_vertical
	(find_node(city.win_dim, "Reset_frame") as Button).pressed.emit()
	await frames()
	check(Game.profile["frame"] == "" and city.avatar_btn.get_theme_stylebox("normal") == original, "default frame restores original HUD style")
	check(absi(city.win_scroll.scroll_vertical - scroll) < 5, "cosmetic selection preserves scroll position")
	(find_node(city.win_dim, "Reset_title") as Button).pressed.emit()
	await frames()
	check(find_node(city.win_dim, "ProfileTitle") == null, "removing title removes header label")
	check(find_node(city.win_dim, "NameEdit") != null and find_node(city.win_dim, "SettingsBtn") != null,
		"existing name editing and settings remain available")
	city.queue_free()
	await frames()


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	test_rules()
	test_unlocks()
	await test_ui()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
