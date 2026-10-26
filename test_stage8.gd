extends Node
## اختبارات شاشة الإحصائيات — المنطق (لقطة get_stats_snapshot)
## التشغيل: godot --headless --path . res://test_stage8.tscn

const D := preload("res://scripts/defs.gd")

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_stage8.json"
	Game.new_game()

	# 1) لقطة لعبة جديدة: كل المفاتيح موجودة والقيم الافتراضية صحيحة
	var s: Dictionary = Game.get_stats_snapshot()
	var keys := ["furnace", "built", "plots_total", "healthy", "pop_total", "pop_cap", "sick", "trust", "res", "net",
		"troops", "wounded", "wounded_cap", "power", "marches", "marches_max", "venture_active",
		"strongholds", "fortresses", "explored_pct", "storm", "cold", "heroes", "hero_cap", "techs", "lifetime"]
	for k in keys:
		if not s.has(k):
			fail("snapshot missing key: " + k)
	if int(s["furnace"]) != 1:
		fail("new game furnace should be 1: %s" % s["furnace"])
	elif int(s["built"]) != 1:
		fail("new game built should be 1 (furnace only): %s" % s["built"])
	elif int(s["plots_total"]) < 10:
		fail("plots_total looks wrong: %s" % s["plots_total"])
	elif int(s["marches"]) != 0 or int(s["marches_max"]) != 2:
		fail("new game marches should be 0/2: %s/%s" % [s["marches"], s["marches_max"]])
	elif s["venture_active"]:
		fail("new game should have no active venture")
	elif int(s["strongholds"]) != 0 or int(s["fortresses"]) != 0:
		fail("new game holds should be 0: %s/%s" % [s["strongholds"], s["fortresses"]])
	elif int(s["troops"]) != 0 or int(s["wounded"]) != 0:
		fail("new game army should be empty: %s/%s" % [s["troops"], s["wounded"]])
	elif float(s["explored_pct"]) <= 0.0 or float(s["explored_pct"]) > 100.0:
		fail("explored_pct out of (0,100]: %s" % s["explored_pct"])
	elif int(s["healthy"]) != 4 or int(s["pop_total"]) != 4 or int(s["pop_cap"]) != 4:
		fail("new game pop should be 4 healthy/4 total/4 cap: %s/%s/%s" % [s["healthy"], s["pop_total"], s["pop_cap"]])
	elif int(s["techs"]) != 0 or int(s["heroes"]) != 0:
		fail("new game techs/heroes should be 0: %s/%s" % [s["techs"], s["heroes"]])
	elif not (s["lifetime"] as Dictionary).get("collected", {}).has("wood"):
		fail("lifetime.collected.wood missing")
	elif int(s["lifetime"]["marches"]) != 0 or int(s["lifetime"]["built"]) != 0:
		fail("new game lifetime counters should be 0")
	if ok:
		print("PASS: new-game snapshot keys and defaults")

	# 2) حالة معدلة معروفة: القيم المشتقة صحيحة بالضبط
	var pct_before: float = float(s["explored_pct"])
	Game.plots["sa1"] = 1          # منشرة
	Game.plots["sh2"] = 2          # مأوى
	Game.troops["shield_1"] = 10
	Game.troops["bow_2"] = 5
	Game.wounded["shield_1"] = 3
	Game.holds["stronghold_1"] = "stronghold"
	Game.holds["fortress_1"] = "fortress"
	Game.pop = 10
	Game.sick = 2.5
	Game.techs["saw"] = 1
	var h0: String = D.HEROES.keys()[0]
	Game.heroes[h0]["owned"] = true
	Game.reveal_at(400.5, 400.5, 60.0)
	var s2: Dictionary = Game.get_stats_snapshot()
	if int(s2["healthy"]) != 8 or int(s2["pop_total"]) != 10 or int(s2["sick"]) != 2:
		fail("pop breakdown wrong (expected healthy 8, total 10, sick 2): %s/%s/%s" % [s2["healthy"], s2["pop_total"], s2["sick"]])
	elif int(s2["built"]) != 3:
		fail("built should count furnace+sa1+sh2 = 3: %s" % s2["built"])
	elif int(s2["troops"]) != 15:
		fail("troops should be 10+5 = 15: %s" % s2["troops"])
	elif int(s2["wounded"]) != 3:
		fail("wounded should be 3: %s" % s2["wounded"])
	elif int(s2["strongholds"]) != 1 or int(s2["fortresses"]) != 1:
		fail("holds should be 1/1: %s/%s" % [s2["strongholds"], s2["fortresses"]])
	elif int(s2["techs"]) != 1:
		fail("techs should be 1: %s" % s2["techs"])
	elif int(s2["heroes"]) != 1:
		fail("heroes should be 1: %s" % s2["heroes"])
	elif float(s2["explored_pct"]) <= pct_before:
		fail("explored_pct should increase after reveal_at: %.2f → %.2f" % [pct_before, s2["explored_pct"]])
	elif float(s2["power"]) <= 0.0:
		fail("power should be positive with troops")
	if ok:
		print("PASS: derived values on known modified state")

	# 3) مسار حقيقي للعداد التراكمي: الجمع من مبنى يزيد سجل الإحصائيات
	Game.stored["sa1"] = 500.0
	var got: float = Game.collect("sa1")
	var s3: Dictionary = Game.get_stats_snapshot()
	if got != 500.0:
		fail("collect should return 500: %s" % got)
	elif absf(float(s3["res"]["wood"]) - (1800.0 + 500.0)) > 0.01:
		fail("wood balance wrong after collect: %s" % s3["res"]["wood"])
	elif absf(float(s3["lifetime"]["collected"]["wood"]) - 500.0) > 0.01:
		fail("lifetime collected wood should be 500: %s" % s3["lifetime"]["collected"]["wood"])
	if ok:
		print("PASS: lifetime counters follow real collect() path")

	# 4) اللقطة للقراءة فقط: لا تغيّر الحالة ولا ملف الحفظ
	var res_before: Dictionary = Game.res.duplicate(true)
	var stats_before: Dictionary = Game.stats.duplicate(true)
	var plots_before: Dictionary = Game.plots.duplicate(true)
	var marches_before: int = Game.marches.size()
	var explored_before: PackedByteArray = Game.explored.duplicate()
	Game.save_game()
	var save_before: Dictionary = _save_dict()
	for i in 3:
		Game.get_stats_snapshot()
	Game.save_game()
	var save_after: Dictionary = _save_dict()
	if Game.res.duplicate(true) != res_before:
		fail("snapshot changed res")
	elif Game.stats.duplicate(true) != stats_before:
		fail("snapshot changed stats")
	elif Game.plots.duplicate(true) != plots_before:
		fail("snapshot changed plots")
	elif Game.marches.size() != marches_before:
		fail("snapshot changed marches")
	elif Game.explored != explored_before:
		fail("snapshot changed explored")
	elif save_after != save_before:
		fail("snapshot changed save file (excluding time)")
	if ok:
		print("PASS: snapshot is read-only (state and save file)")

	# 5) كشف الخريطة الكامل: 100% عبر أداة المطور
	Game.dev_reveal_map()
	var s5: Dictionary = Game.get_stats_snapshot()
	if absf(float(s5["explored_pct"]) - 100.0) > 0.001:
		fail("full reveal should give 100%%: %s" % s5["explored_pct"])
	if ok:
		print("PASS: full map reveal gives 100%")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	if ok:
		print("ALL STAGE8 STATS TESTS PASSED")
	get_tree().quit(0 if ok else 1)

## قراءة الحفظ كقاموس مع استبعاد الحقول المتغيرة زمنيًا (time)
func _save_dict() -> Dictionary:
	var f := FileAccess.open(Game._save_path(), FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.erase("time")
	return d
