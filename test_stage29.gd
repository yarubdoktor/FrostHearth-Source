extends Node
## Stage 29 regression: rules, paid queues, combat, migration, offline and UI.
const Rules := preload("res://scripts/game/gear_defs.gd")
const Gear := preload("res://scripts/game/gear.gd")
const Combat := preload("res://scripts/combat.gd")
const Timers := preload("res://scripts/ui/job_timers.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func fresh() -> void:
	Game.save_path_override = "user://stage29_test.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.offline_report = {}
	Game.stats["built"] = 1
	Game.res = {"food": 1e9, "wood": 1e9, "coal": 1e9, "iron": 1e9}
	Game.gems = 10000
	Game.aurora = 10000
	Game.plots["wk1"] = 30


func frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame


func write_save(data: Dictionary) -> void:
	var f := FileAccess.open(Game._save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func test_rules() -> void:
	fresh()
	var names := {}
	for tp in Rules.TYPES:
		for slot in Rules.SLOTS:
			names[Rules.title(tp, slot)] = true
			check(Game.gear_level(tp, slot) == 0, "new game piece starts at zero: " + tp + slot)
	check(names.size() == 12, "12 unique Arabic piece names")
	for lv in range(1, 11):
		check(Rules.required_workshop(lv) == 3 * lv - 2, "workshop unlock level %d" % lv)
		check(is_equal_approx(Rules.duration(lv, 0), 120.0 * pow(1.65, lv - 1)), "duration curve %d" % lv)
	for pair in [[0, 0], [1, 1], [9, 1], [10, 2], [19, 2], [20, 3], [30, 4]]:
		check(Rules.capacity(pair[0]) == pair[1], "capacity at workshop %d" % pair[0])
	check(Rules.duration(4, 30) < Rules.duration(4, 1), "workshop accelerates production")
	check(not Rules.cost("rune", 4).has("aurora") and Rules.cost("rune", 5)["aurora"] == 3,
		"runes require aurora starting at level 5")
	check(Rules.cost("weapon", 2)["wood"] == 225, "cost grows by 1.5")
	check(not Game.gear_check("bad", "weapon")["ok"], "invalid troop rejected")
	check(not Game.start_gear("shield", "bad"), "invalid slot rejected without mutation")
	check(not Game.cancel_gear("shield", "bad") and not Game.speedup_gear("shield", "bad"), "missing jobs safe")
	Game.plots["wk1"] = 0
	check(not Game.start_gear("shield", "weapon"), "unbuilt workshop rejected")
	Game.plots["wk1"] = 1
	Game.equipment["shield"]["weapon"] = 1
	check(not Game.start_gear("shield", "weapon"), "workshop requirement enforced")
	Game.plots["wk1"] = 30
	Game.equipment["shield"]["weapon"] = 10
	check(not Game.start_gear("shield", "weapon"), "level cap enforced")
	Game.equipment["shield"]["weapon"] = 0
	Game.res["iron"] = 0
	check(not Game.start_gear("shield", "weapon"), "insufficient material rejected")
	Game.equipment["bow"]["rune"] = 4
	Game.res["iron"] = 1e9
	Game.aurora = 0
	check(not Game.start_gear("bow", "rune"), "insufficient aurora rejected")


func test_queue() -> void:
	fresh()
	var initial := Game.res.duplicate()
	check(Game.start_gear("shield", "weapon"), "paid craft starts")
	check(Game.res["wood"] == initial["wood"] - 150 and Game.res["iron"] == initial["iron"] - 80, "materials deducted exactly")
	check(Game.gear_level("shield", "weapon") == 0, "no bonus until completion")
	check(not Game.start_gear("shield", "weapon"), "duplicate piece blocked")
	check(Game.cancel_gear("shield", "weapon"), "cancel succeeds")
	check(Game.res == initial and Game.gear_queue.is_empty(), "full exact refund")
	check(not Game.cancel_gear("shield", "weapon") and Game.res == initial, "no double refund")
	Game.plots["wk1"] = 1
	check(Game.start_gear("shield", "armor"), "first slot starts")
	check(not Game.start_gear("spear", "weapon"), "capacity blocks second job")
	Game.plots["wk1"] = 10
	check(Game.start_gear("spear", "weapon"), "level 10 opens second parallel slot")
	check(Game.gear_queue.size() == 2, "parallel jobs retained")
	check(float(Game.gear_queue[0]["end"]) > float(Game.gear_queue[1]["start"]), "jobs overlap in time")
	var end := float(Game.gear_queue[0]["end"])
	Gear.tick(Game, end - 0.01)
	check(Game.gear_level("shield", "armor") == 0, "does not finish early")
	Gear.tick(Game, end + 1)
	check(Game.gear_level("shield", "armor") == 1 and Game.gear_level("spear", "weapon") == 1, "tick completes both jobs")
	check(Game.gear_queue.is_empty(), "completed jobs removed")
	var power := Game.power()
	Gear.tick(Game, end + 10)
	check(Game.power() == power, "completion idempotent")
	fresh()
	Game.equipment["bow"]["rune"] = 4
	var a := Game.aurora
	check(Game.start_gear("bow", "rune") and Game.aurora == a - 3, "aurora paid for rune upgrade")
	check(Game.cancel_gear("bow", "rune") and Game.aurora == a, "aurora refunded exactly")
	Game.dev_mode = true
	Game.res = {"food": 0.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	Game.aurora = 0
	check(Game.start_gear("bow", "rune"), "developer craft is free")
	check(Game.cancel_gear("bow", "rune") and Game.res["iron"] == 0 and Game.aurora == 0, "developer cancel cannot mint resources")
	fresh()
	Game.equipment["shield"]["weapon"] = 5
	check(Game.start_gear("shield", "weapon"), "long upgrade starts")
	var before := Game.gems
	var price := Game.gems_for_time(float(Game.gear_queue[0]["end"]) - Game.now())
	check(price > 0, "long job has paid speedup")
	Game.gems = 0
	check(not Game.speedup_gear("shield", "weapon") and Game.gear_queue.size() == 1, "poor player cannot speed up")
	Game.gems = before
	check(Game.speedup_gear("shield", "weapon"), "paid speedup works")
	check(Game.gear_level("shield", "weapon") == 6 and Game.gems == before - price, "speedup charges and completes")
	fresh()
	Game.start_gear("bow", "helmet")
	before = Game.gems
	check(Game.speedup_gear("bow", "helmet") and Game.gems == before, "short job uses existing free speedup rule")
	Game.start_gear("bow", "weapon")
	Game.gear_queue[0]["end"] = Game.now() - 1
	var spent := Game.res.duplicate()
	check(not Game.cancel_gear("bow", "weapon"), "expired job completes rather than refunds")
	check(Game.res == spent and Game.gear_level("bow", "weapon") == 1, "expired cancel grants piece without refund")
	Game.start_gear("spear", "rune")
	Game.dev_finish_all()
	check(Game.gear_queue.is_empty() and Game.gear_level("spear", "rune") == 1, "developer finish all includes equipment")
	fresh()
	for slot in Rules.SLOTS:
		check(Game.start_gear("bow", slot), "level 30 supports parallel job " + slot)
	check(not Game.start_gear("shield", "weapon"), "fifth job rejected at maximum capacity")
	check(Game.cancel_gear("bow", "armor"), "cancel by identity removes middle job")
	check(Game.gear_job("bow", "weapon") != {} and Game.gear_job("bow", "rune") != {}, "middle cancellation preserves other jobs")
	Game.gear_queue[0]["end"] = Game.now() - 1
	Game._simulate(0.0, Game.now())
	check(Game.gear_level("bow", "weapon") == 1, "normal simulation completes jobs")
	fresh()
	for tp in Rules.TYPES:
		for slot in Rules.SLOTS:
			check(Game.start_gear(tp, slot) and Game.speedup_gear(tp, slot)
				and Game.gear_level(tp, slot) == 1, "every piece can be crafted: " + tp + slot)


func test_bonuses() -> void:
	fresh()
	var base := Game.army_mods("")
	var power := Game.power()
	Game.equipment["shield"]["weapon"] = 2
	Game.equipment["shield"]["armor"] = 3
	Game.equipment["shield"]["helmet"] = 4
	Game.equipment["shield"]["rune"] = 5
	var mods := Game.army_mods("")
	check(is_equal_approx(mods["atk"]["shield"] - base["atk"]["shield"], 0.024), "crafted weapon attack additive")
	check(is_equal_approx(mods["def"]["shield"] - base["def"]["shield"], 0.036), "crafted armor defense additive")
	check(is_equal_approx(mods["hp"]["shield"] - base["hp"]["shield"], 0.06), "crafted helmet health additive")
	check(is_equal_approx(mods["damage"]["shield"], 0.05), "rune damage is per troop type")
	check(is_equal_approx(Game.troop_stats("shield", 1)["damage"], 0.05), "troop display exposes final damage")
	check(mods["atk"]["spear"] == base["atk"]["spear"] and mods["damage"]["bow"] == 0, "no cross-type bonus")
	check(is_equal_approx(Game.power() - power, 14.0 * 14), "each equipment level adds 14 power")
	check(Rules.set_bonus(Game.equipment, "shield") == 0, "incomplete threshold has no set bonus")
	for spec in [[3, 0.02], [6, 0.04], [10, 0.07]]:
		for slot in Rules.SLOTS:
			Game.equipment["shield"][slot] = spec[0]
		var b := Rules.bonuses(Game.equipment, "shield")
		check(is_equal_approx(Rules.set_bonus(Game.equipment, "shield"), spec[1]), "highest set threshold %d" % spec[0])
		check(is_equal_approx(b["atk"], spec[0] * 0.012 + spec[1]), "set attack additive")
		check(is_equal_approx(b["hp"], spec[0] * 0.015 + spec[1]), "set health additive")
		check(is_equal_approx(b["power"], spec[0] * 4 * 14 * (1 + spec[1])), "set power bonus")
	var unformed := Game.army_mods("")
	var formed := Combat.with_formation(unformed, "balanced")
	check(formed["damage"] == unformed["damage"], "formation preserves equipment damage")
	fresh()
	Game.troops["shield_1"] = 40
	var defense := Game.defense_profile()
	Game.equipment["shield"]["armor"] = 5
	var upgraded := Game.defense_profile()
	check(upgraded["mods"]["def"]["shield"] > defense["mods"]["def"]["shield"], "city defense consumes crafted armor")
	check(upgraded["power"] > defense["power"], "displayed defense power includes crafted effects")
	Game.troops["shield_1"] = 0
	check(Game.defense_profile()["power"] == 0, "equipment never creates a free garrison")
	fresh()
	Game.equipment["spear"]["rune"] = 10
	var normal := Game.army_mods("")
	var without := normal.duplicate(true)
	without["damage"] = {}
	var a := Combat._groups({"spear_1": 50}, normal, false)
	var d := Combat._groups({"shield_1": 50}, without, false)
	var beast_mods := {"beast": {"atk": 12, "def": 5, "hp": 45, "name": "اختبار"}}
	var beasts := Combat._groups({"beast": 50}, beast_mods, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var plain := Combat._damage(a, d, without, 1, rng)
	rng.seed = 29
	var rune := Combat._damage(a, d, normal, 1, rng)
	check(is_equal_approx(rune, plain * 1.1), "rune multiplies final army damage")
	rng.seed = 29
	plain = Combat._damage(a, beasts, without, 1, rng)
	rng.seed = 29
	rune = Combat._damage(a, beasts, normal, 1, rng)
	check(is_equal_approx(rune, plain), "rune has NO damage bonus against beasts")
	Game.troops["spear_1"] = 40
	check(Game.start_venture({"spear_1": 20}), "venture launches with equipment")
	check(is_equal_approx(Game.venture["mods"]["damage"]["spear"], 0.1), "venture snapshots crafted effects")
	Game.equipment["spear"]["rune"] = 0
	check(is_equal_approx(Game.venture["mods"]["damage"]["spear"], 0.1), "travelling army snapshot stays unchanged")


func test_save() -> void:
	fresh()
	Game.equipment["shield"]["helmet"] = 4
	Game.start_gear("bow", "weapon")
	var expected := Game.gear_queue.duplicate(true)
	Game.save_game()
	Game.equipment = {}
	Game.gear_queue = []
	check(Game.load_game(), "v7 load succeeds")
	check(Game.SAVE_VERSION == 7 and Game.gear_level("shield", "helmet") == 4, "v7 restores equipment levels")
	var restored: Dictionary = Game.gear_queue[0]
	var original: Dictionary = expected[0]
	check(restored["key"] == original["key"] and int(restored["lv"]) == int(original["lv"])
		and absf(float(restored["end"]) - float(original["end"])) < 0.0001,
		"v7 restores job identity and deadline within JSON precision")
	for r in original["paid"]:
		check(float(restored["paid"][r]) == float(original["paid"][r]), "v7 preserves exact paid amount: " + r)
	check(Game.cancel_gear("bow", "weapon"), "restored receipt refundable")
	Game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	var original_name := Game.profile_name()
	var original_iron: float = Game.res["iron"]
	data["v"] = 6
	data.erase("equipment")
	data.erase("gear_queue")
	write_save(data)
	check(Game.load_game(), "v6 migrates")
	check(Game.gear_level("shield", "helmet") == 0 and Game.gear_queue.is_empty(), "v6 begins without crafted pieces")
	check(Game.profile_name() == original_name and Game.res["iron"] == original_iron, "v6 preserves identity and resources")
	check(Game.army_mods("")["def"]["shield"] > 0, "legacy workshop blessing retained")
	Game.save_game()
	data = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	check(int(data["v"]) == 7, "migrated save writes v7")
	fresh()
	Game.start_gear("bow", "weapon")
	Game.gear_queue[0]["start"] = Game.now() - 20
	Game.gear_queue[0]["end"] = Game.now() - 1
	Game.save_game()
	Game.load_game()
	check(Game.gear_level("bow", "weapon") == 1 and Game.gear_queue.is_empty(), "short offline absence settles completed job")
	fresh()
	Game.start_gear("spear", "weapon")
	Game.gear_queue[0]["start"] = Game.now() - 600
	Game.gear_queue[0]["end"] = Game.now() - 300
	Game.save_game()
	data = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	data["time"] = Game.now() - 600
	write_save(data)
	check(Game.load_game() and Game.gear_level("spear", "weapon") == 1, "long offline simulation completes equipment")
	Gear.restore(Game, {"equipment": {"shield": {"weapon": 99, "armor": -5, "helmet": "bad"}}, "gear_queue": [{}, "bad"]})
	check(Game.gear_level("shield", "weapon") == 10 and Game.gear_level("shield", "armor") == 0 and Game.gear_level("shield", "helmet") == 0, "restore clamps invalid levels")
	check(Game.gear_queue.is_empty(), "restore ignores invalid jobs")
	Game.new_game()
	check(Game.gear_level("shield", "weapon") == 0 and Game.gear_queue.is_empty(), "new game resets equipment and jobs")


func test_ui() -> void:
	fresh()
	get_window().size = Vector2i(720, 1280)
	var city: Node3D = load("res://city.tscn").instantiate()
	add_child(city)
	await frames()
	city._select("wk1")
	check(city.bp_open.visible and city.bp_open.text == "الورشة الحربية", "workshop panel exposes entry button")
	city._open_from_panel()
	await frames()
	check(city.win_dim != null and city.win_dim.find_child("WorkshopBody", true, false) != null, "workshop window opens from building")
	for tp in Rules.TYPES:
		city.WorkshopWin.show(city, tp)
		await frames()
		for slot in Rules.SLOTS:
			check(city.win_dim.find_child("Gear_" + tp + "_" + slot, true, false) != null, "piece card visible " + tp + slot)
	city.WorkshopWin.show(city, "shield")
	await frames()
	var make: Button = city.win_dim.find_child("Craft_shield_weapon", true, false)
	check(make != null and not make.disabled, "craft button enabled with materials")
	make.pressed.emit()
	await frames(6)
	check(Game.gear_queue.size() == 1, "UI button starts craft")
	check(city.win_dim.get_combined_minimum_size().x <= 720, "workshop minimum width fits portrait viewport")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--workshop-screenshot="):
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--workshop-screenshot=")
			check(get_viewport().get_texture().get_image().save_png(path) == OK, "portrait screenshot saved")
	check(Timers.jobs_for("wk1").size() == 1 and Timers.jobs_for("wk1")[0]["kind"] == "gear", "timer above workshop")
	var jobs := Timers.city_jobs()
	check(jobs.size() == 1 and jobs[0]["kind"] == "gear", "workshop appears in side queue")
	check(city.job_rows.size() == 5, "side queue has room for workshop")
	var row: Dictionary = city.job_rows[0]
	check(row["panel"].visible and row["item"]["kind"] == "gear", "workshop side row visible")
	var event := InputEventMouseButton.new()
	event.pressed = true
	Timers.row_input(city, event, row)
	await frames()
	check(city.win_dim.find_child("WorkshopBody", true, false) != null, "side row reopens workshop")
	Game.speedup_gear("shield", "weapon")
	await frames(6)
	check(Game.gear_level("shield", "weapon") == 1 and Timers.jobs_for("wk1").is_empty(), "completion clears timer and refreshes UI")
	Game.res["iron"] = 0
	Game.changed.emit()
	await frames()
	make = city.win_dim.find_child("Craft_shield_armor", true, false)
	check(make.disabled, "resource changes disable craft without reopening")
	city._close_window()
	city.queue_free()
	await frames()


func _ready() -> void:
	test_rules()
	test_queue()
	test_bonuses()
	test_save()
	await test_ui()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
