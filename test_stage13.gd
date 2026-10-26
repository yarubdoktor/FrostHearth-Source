extends Node
## اختبارات المرحلة 13 — أساس الجيش: ثلاث ثكنات بطوابير مستقلة، المعسكر كسعة وتجمع، 4 مآوٍ، وترحيل الحفظ
## التشغيل: godot --headless --path . res://test_stage13.tscn

const D := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.dev_mode = false
	Game.new_game()
	for r in Game.res:
		Game.res[r] = 1000000.0
	Game.gems = 1000


func _has_reason(chk: Dictionary, part: String) -> bool:
	for r in chk["reasons"]:
		if String(r).find(part) >= 0:
			return true
	return false


func _ready() -> void:
	Game.save_path_override = "user://frost_stage13_%s_test_only.json" % DisplayServer.get_name()
	Game.set_process(false)

	# 1) المواقع: 4 مآوٍ فقط + ثلاث ثكنات + المعسكر
	_fresh()
	var shelters := 0
	for id in D.PLOTS:
		if D.PLOTS[id]["type"] == "shelter":
			shelters += 1
	check(shelters == 4, "exactly 4 shelter plots (%d)" % shelters)
	for tp in D.TROOP_ORDER:
		check(D.PLOTS.has(D.BARRACKS_PLOT[tp]) and D.PLOTS[D.BARRACKS_PLOT[tp]]["type"] == D.BARRACKS_TYPE[tp], "barracks plot exists for " + tp)
	check(D.PLOTS.has("ba1") and D.PLOTS["ba1"]["type"] == "barracks", "camp plot still exists")
	check(D.shelter_capacity(1) == 10 and D.shelter_capacity(0) == 0, "shelter capacity formula")
	var pos_ok := true
	var ids: Array = D.PLOTS.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if D.plot_pos(ids[i]).distance_to(D.plot_pos(ids[j])) < 8.0:
				pos_ok = false
	check(pos_ok, "no two plots closer than 8 units")

	# 2) كل نوع يحتاج ثكنته ومعسكرًا
	_fresh()
	var c := Game.train_check("shield", 1, 10)
	check(not c["ok"] and _has_reason(c, "ثكنة الدروع"), "no barracks -> refused naming shield barracks")
	Game.plots["bs1"] = 1
	c = Game.train_check("shield", 1, 10)
	check(not c["ok"] and _has_reason(c, "المعسكر"), "barracks without camp -> refused (camp needed)")
	Game.plots["ba1"] = 1
	c = Game.train_check("shield", 1, 10)
	check(c["ok"], "camp + shield barracks -> shield training allowed")
	c = Game.train_check("spear", 1, 10)
	check(not c["ok"] and _has_reason(c, "ثكنة الرماح"), "spear needs its own barracks")

	# 3) طوابير مستقلة
	Game.plots["bp1"] = 1
	check(Game.start_train("shield", 1, 10), "start shield batch")
	check(Game.start_train("spear", 1, 10), "start spear batch in parallel")
	check(Game.train.has("shield") and Game.train.has("spear") and Game.train.size() == 2, "two independent queues")
	c = Game.train_check("shield", 1, 5)
	check(not c["ok"] and _has_reason(c, "مشغولة"), "same barracks busy")
	check(Game.training_total() == 20, "training_total counts both queues")

	# 4) اكتمال طابور واحد لا يمس الآخر
	Game.train["shield"]["end"] = Game.now() - 1.0
	Game._simulate(0.0, Game.now())
	check(not Game.train.has("shield") and Game.train.has("spear"), "finishing shield leaves spear queue")
	check(int(Game.troops["shield_1"]) == 10, "shield troops added on completion")

	# 5) إلغاء يعيد الموارد
	var food_before: float = Game.res["food"]
	var cost: Dictionary = D.troop_cost("spear", 1, 10)
	Game.cancel_train("spear")
	check(not Game.train.has("spear") and absf(Game.res["food"] - (food_before + float(cost["food"]))) < 0.01, "cancel refunds cost and clears queue")

	# 6) السرعة تتصاعد مع مستوى الثكنة
	_fresh()
	Game.plots["ba1"] = 1
	Game.plots["bs1"] = 1
	var t1 := Game.train_time("shield", 1, 20)
	Game.plots["bs1"] = 11
	var t11 := Game.train_time("shield", 1, 20)
	check(t11 < t1 and absf(t1 / t11 - D.barracks_speed(11)) < 0.001, "higher barracks level trains faster (x%.2f)" % (t1 / t11))
	check(Game.train_time("shield", 2, 20) > Game.train_time("shield", 1, 20), "higher tier takes longer")
	check(Game.train_time("shield", 1, 40) > Game.train_time("shield", 1, 20), "bigger batch takes longer")
	check(D.troop_cost("shield", 2, 10)["food"] > D.troop_cost("shield", 1, 10)["food"], "higher tier costs more")

	# 7) الرتب وحجم الدفعة
	_fresh()
	Game.plots["ba1"] = 3
	Game.plots["bs1"] = 1
	check(not Game.train_check("shield", 2, 10)["ok"], "tier 2 locked at barracks level 1")
	Game.plots["bs1"] = 6
	check(Game.train_check("shield", 2, 10)["ok"], "tier 2 unlocked at barracks level 6")
	check(Game.max_tier_of("shield") == 2 and Game.max_tier_of("bow") == 0, "max tier per barracks")
	var cap: int = Game.train_batch_of("shield")
	check(cap == D.train_batch(6) and Game.train_batch_of("bow") == 0, "batch per barracks (%d)" % cap)
	check(not Game.train_check("shield", 1, cap + 1)["ok"], "batch over limit refused")

	# 8) سعة المعسكر
	_fresh()
	Game.plots["ba1"] = 1
	Game.plots["bs1"] = 10
	var camp_cap: int = Game.army_cap()
	check(camp_cap == D.camp_capacity(1), "camp capacity from camp level (%d)" % camp_cap)
	Game.troops["spear_1"] = camp_cap - 5
	check(not Game.train_check("shield", 1, 10)["ok"], "camp full -> training refused")
	check(Game.train_check("shield", 1, 5)["ok"], "exactly filling camp allowed")
	Game.troops["spear_1"] = 0
	Game.venture = {"units": {"spear_1": camp_cap - 5}}
	check(Game.army_away() == camp_cap - 5 and not Game.train_check("shield", 1, 10)["ok"], "troops away still occupy the camp")
	Game.venture = {}
	Game.plots["ba1"] = 0
	check(Game.army_cap() == 0 and not Game.train_check("shield", 1, 1)["ok"], "no camp -> no capacity")

	# 9) غارات تبدأ مع أي مبنى عسكري
	_fresh()
	check(not Game.has_military(), "new game has no military building")
	Game.plots["bb1"] = 1
	check(Game.has_military(), "any barracks counts as military")

	# 10) المطور يتجاوز الاشتراطات
	_fresh()
	Game.dev_mode = true
	check(Game.train_check("bow", 4, 50)["ok"], "dev mode bypasses barracks/camp/tier")
	Game.dev_mode = false

	# 11) ترحيل حفظ إصدار 4
	_fresh()
	Game.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	var t0 := Game.now()
	d["v"] = 4
	d["time"] = t0
	d["plots"]["ba1"] = 4
	d["plots"]["sh7"] = 3
	d["plots"]["sh9"] = 1
	d["queue"] = [{"plot": "sh8", "level": 2, "start": t0, "end": t0 + 1000.0}]
	d["train"] = {"key": "spear_1", "n": 5, "start": t0, "end": t0 + 1000.0}
	d["res"] = {"food": 0.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	var f := FileAccess.open(Game._save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check(Game.load_game(), "v4 save loads")
	check(not Game.plots.has("sh7") and not Game.plots.has("sh9"), "removed shelters dropped")
	check(Game.queue.is_empty(), "queue entry of removed shelter dropped")
	var expect_wood := 0.0
	for l in range(1, 4):
		expect_wood += float(D.cost("shelter", l)["wood"])
	expect_wood += float(D.cost("shelter", 1)["wood"])      # sh9 مستوى 1
	expect_wood += float(D.cost("shelter", 2)["wood"])      # بناء sh8 مستوى 2 أُلغي
	check(absf(float(Game.res["wood"]) - expect_wood) < 0.5, "removed shelters + cancelled build fully refunded (%d wood)" % int(expect_wood))
	check(Game.level("bs1") == 4 and Game.level("bp1") == 4 and Game.level("bb1") == 4, "new barracks granted at old camp level")
	check(Game.level("ba1") == 4, "camp keeps its level")
	check(Game.train.has("spear") and int(Game.train["spear"]["n"]) == 5, "old single train queue migrated to per-type queue")
	check(not Game.migration_note.is_empty() and int(Game.migration_note.get("shelters_removed", 0)) == 2, "migration note recorded")
	Game.save_game()
	var d2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	check(int(d2["v"]) == Game.SAVE_VERSION, "re-saved as the current save version")
	check(Game.load_game() and Game.migration_note.is_empty(), "v5 save loads without migration")

	# 12) المهام
	var found := false
	for tk in D.TASKS:
		if tk.get("b", "") == "shelter" and int(tk["n"]) > 4:
			found = true
	check(not found, "no task asks for more than 4 shelters")

	print("---- stage13: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
