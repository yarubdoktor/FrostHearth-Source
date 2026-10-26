extends Node
## Hero UI regression. Optional rendered screenshots:
## godot res://test_stage29_1.tscn -- --heroes-screenshots=/absolute/folder
const Defs := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0
var city: Node


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func frames(n: int = 5) -> void:
	for i in n:
		await get_tree().process_frame


func control(name: String) -> Control:
	return city.win_dim.find_child(name, true, false) as Control


func click(name: String) -> void:
	var button := control(name) as Button
	check(button != null and not button.disabled, "button available: " + name)
	if button != null and not button.disabled:
		button.pressed.emit()
	await frames()


func screenshot(name: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--heroes-screenshots="):
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--heroes-screenshots=").path_join(name + ".png")
			check(get_viewport().get_texture().get_image().save_png(path) == OK, "saved " + name)


func snapshot() -> Dictionary:
	return {"heroes": Game.heroes.duplicate(true), "aurora": Game.aurora,
		"gems": Game.gems, "equipment": Game.equipment.duplicate(true),
		"defender": Game.defender, "governor": Game.governor, "res": Game.res.duplicate(true)}


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	Game.save_path_override = "user://hero_layout_291_test.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}
	# Find the actual hall plot from the game's definitions.
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == "hero_hall":
			Game.plots[id] = 3
	Game.res = {"food": 100000.0, "wood": 100000.0, "coal": 100000.0, "iron": 100000.0}
	Game.aurora = 600
	Game.heroes["reem"]["owned"] = true
	Game.heroes["reem"]["lv"] = 4
	Game.heroes["reem"]["stars"] = 2
	Game.defender = "reem"
	Game.heroes["salma"]["owned"] = true
	Game.governor = "salma"
	Game.heroes["siraj"]["shards"] = 10
	city = load("res://city.tscn").instantiate()
	add_child(city)
	await frames()
	var before := snapshot()
	city._show_heroes()
	await frames()
	check(control("HeroesGallery") != null, "gallery is the first view")
	check(control("HeroDetails") == null, "details are not buried below the gallery")
	var grid := control("HeroesGrid") as GridContainer
	check(grid != null and grid.columns == 3 and grid.get_child_count() == 6, "six cards in a three-column gallery")
	for id in Defs.HERO_ORDER:
		var card := control("HeroCard_" + id) as Button
		check(card != null and not card.disabled, "owned or locked hero can be inspected: " + id)
		if card != null:
			var rect := card.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= 720, "card fits portrait width: " + id)
			check(rect.size.y >= 290, "large touch target: " + id)
	check(grid.get_global_rect().end.y <= 1200, "all six cards fit the portrait screen")
	check(snapshot() == before, "opening gallery is read-only")
	await screenshot("Stage29_1_Heroes_Gallery")
	for id in Defs.HERO_ORDER:
		await click("HeroCard_" + id)
		check(city.hero_sel == id and control("HeroDetails") != null, "details select correct hero: " + id)
		var image := control("SelectedHeroPortrait") as TextureRect
		check(image != null and image.texture != null and image.size.x >= 189, "large portrait loads: " + id)
		check(control("HeroSkills") != null and control("HeroActions") != null, "skills and actions remain available")
		var minimum := (control("SelectedHero") as Control).get_combined_minimum_size()
		check(minimum.x <= 650, "details do not force horizontal scrolling")
		await click("HeroBack")
		check(control("HeroesGallery") != null and city.win_scroll.scroll_vertical == 0, "back returns to gallery at top")
	check(snapshot() == before, "browsing all heroes changes no game data")
	await click("HeroCard_siraj")
	check(control("HeroUnlock") != null and control("HeroLevelUp") == null, "unowned hero shows unlock not level action")
	await screenshot("Stage29_1_Heroes_Details")
	await click("HeroUnlock")
	check(Game.heroes["siraj"]["owned"] and Game.heroes["siraj"]["shards"] == 0, "unlock still uses existing shard rules")
	check(control("HeroLevelUp") != null and control("HeroUnlock") == null, "unlock refreshes action panel")
	var cost: Dictionary = Game.hero_level_check("siraj")["cost"].duplicate()
	var food: float = Game.res["food"]
	var iron: float = Game.res["iron"]
	await click("HeroLevelUp")
	check(Game.heroes["siraj"]["lv"] == 2 and Game.res["food"] == food - float(cost["food"])
		and Game.res["iron"] == iron - float(cost["iron"]), "level upgrade preserves cost and effect")
	var aurora := Game.aurora
	await click("HeroSummon")
	check(Game.aurora == aurora - Defs.SUMMON_COST and Game.heroes["siraj"]["shards"] == 10, "summon grants the selected hero ten shards")
	await click("HeroStarUp")
	check(Game.heroes["siraj"]["stars"] == 1 and Game.heroes["siraj"]["shards"] == 0, "star upgrade still consumes correct shards")
	await click("HeroDefender")
	check(Game.defender == "siraj" and Game.governor == "salma", "defense role updates without displacing another governor")
	await click("HeroGovernor")
	check(Game.governor == "siraj" and Game.defender == "", "same hero cannot hold both roles")
	await screenshot("Stage29_1_Heroes_Owned")
	await click("HeroBack")
	Game.res["food"] -= 0.25
	Game.changed.emit()
	await frames()
	var stable := control("HeroCard_siraj")
	Game.res["food"] -= 0.25
	Game.changed.emit()
	await frames()
	check(stable == control("HeroCard_siraj"), "ordinary resource drift does not rebuild hero cards")
	await click("HeroCard_siraj")
	Game.res["iron"] = 0
	Game.aurora = 0
	Game.changed.emit()
	await frames()
	check((control("HeroLevelUp") as Button).disabled, "resource threshold updates level button")
	check((control("HeroSummon") as Button).disabled, "resource threshold updates summon button")
	Game.dev_mode = true
	Game.changed.emit()
	await frames()
	check(not (control("HeroSummon") as Button).disabled, "developer mode still bypasses summon cost")
	Game.heroes["siraj"]["stars"] = 5
	Game.changed.emit()
	await frames()
	check((control("HeroStarUp") as Button).disabled, "maximum stars cannot be raised")
	city.hero_sel = "unknown"
	city._show_heroes()
	await frames()
	check(Defs.HEROES.has(city.hero_sel), "invalid selection falls back safely")
	check(Game.SAVE_VERSION == 7, "UI update does not change save schema")
	city._close_window()
	city.queue_free()
	await frames()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
