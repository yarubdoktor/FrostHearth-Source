extends Node
## اختبار Stage 17 — موازنة الموارد مع الأزمنة + البنّاؤون + سقف الغياب
## التشغيل: godot --headless --path . res://test_stage17.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0

# نموذج الدخل (نفس نموذج tools/balance_model.py): عدد مباني كل مورد، وكلها بمستوى L
const INCOME_N := {"food": 3, "wood": 3, "coal": 2, "iron": 2}
const INCOME_RATE := {"food": 720.0, "wood": 600.0, "coal": 330.0, "iron": 140.0}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func income_per_hour(r: String, lv: int) -> float:
	return float(INCOME_N[r]) * float(INCOME_RATE[r]) * lv * (1.0 + 0.09 * lv)


## φ: نسبة ما يستهلكه بنّاء واحد (تكلفة ÷ زمن البناء) من دخل المورد الكلي في الساعة
func phi(type: String, lv: int) -> float:
	var c := Defs.cost(type, lv)
	var hours := Defs.build_time(type, lv) / 3600.0
	var worst := 0.0
	for r in ["wood", "coal", "iron"]:
		if c.has(r):
			worst = maxf(worst, float(c[r]) / hours / income_per_hour(r, lv - 1))
	return worst


func _ready() -> void:
	# 1) مضاعف pace: لا يمس المستويات الأولى ويتدرج هندسيًا
	check(Defs.cost_pace("shelter", 20) == 1.0, "shelter has no pace discount")
	check(Defs.cost_pace("iron_mine", 1) == 1.0 and Defs.cost_pace("iron_mine", 6) == 1.0, "no discount up to level 6")
	check(is_equal_approx(Defs.cost_pace("iron_mine", 12), 0.35), "iron mine fully discounted at level 12 (%f)" % Defs.cost_pace("iron_mine", 12))
	check(is_equal_approx(Defs.cost_pace("iron_mine", 30), 0.35), "discount stays flat after level 12")
	check(Defs.cost_pace("iron_mine", 9) < 1.0 and Defs.cost_pace("iron_mine", 9) > 0.35, "level 9 is partway")
	check(Defs.cost("iron_mine", 5)["wood"] == 2620, "iron mine L5 wood unchanged (%d)" % Defs.cost("iron_mine", 5)["wood"])
	check(Defs.cost("furnace", 10)["wood"] == 10100, "furnace L10 wood unchanged (%d)" % Defs.cost("furnace", 10)["wood"])

	# 2) التكلفة تتصاعد دائمًا مع المستوى (لا قفزات هابطة بسبب التخفيف)
	var mono_ok := true
	for tp in Defs.BUILDINGS:
		var prev := -1.0
		for lv in range(1, 31):
			var tot := 0.0
			for r in Defs.cost(tp, lv).values():
				tot += float(r)
			if tot < prev:
				mono_ok = false
				print("  non-monotone: %s L%d" % [tp, lv])
			prev = tot
	check(mono_ok, "total cost rises with level for every building")

	# 3) الموازنة: لا مبنى يستهلك من دخل المدينة أكثر من 1.5× ما يلزمه زمنه
	var worst12 := 0.0
	var best12 := 99.0
	for tp in Defs.BUILDINGS:
		var p := phi(tp, 12)
		worst12 = maxf(worst12, p)
		best12 = minf(best12, p)
		check(p <= 1.5, "%s L12 drain <= 1.5x income (%.2f)" % [tp, p])
		check(phi(tp, 20) <= 0.8, "%s L20 drain <= 0.8x income (%.2f)" % [tp, phi(tp, 20)])
	check(worst12 / best12 <= 2.6, "heaviest/lightest building drain ratio <= 2.6 (was ~7.5) -> %.2f" % (worst12 / best12))

	# 4) الأبحاث: مثل القديم حتى المستوى 4 ثم أثقل
	check(Defs.tech_cost("saw", 4)["wood"] == 2460, "tech saw lv4 wood unchanged (%d)" % Defs.tech_cost("saw", 4)["wood"])
	check(Defs.tech_cost("saw", 5)["wood"] > 600 * pow(1.6, 4), "tech saw lv5 costlier than old curve")
	var old12 := 600.0 * pow(1.6, 11)
	check(float(Defs.tech_cost("saw", 12)["wood"]) > old12 * 3.5, "tech saw lv12 >3.5x the old cost (%d vs %d)" % [Defs.tech_cost("saw", 12)["wood"], int(old12)])
	check(Defs.tech_cost("seer", 5)["aurora"] == int(ceil(20.0 * pow(1.3, 4))), "aurora cost curve untouched")

	# 5) الجنود: ×2.2 لكل رتبة
	check(Defs.troop_cost("shield", 4, 10)["food"] == 4260, "shield tier4 x10 food = 4260 (%d)" % Defs.troop_cost("shield", 4, 10)["food"])
	check(Defs.troop_cost("shield", 1, 10)["food"] == 400, "tier1 cost unchanged")

	# 6) البنّاؤون حسب مستوى الفرن
	check(Defs.builder_count(1) == 2 and Defs.builder_count(9) == 2, "2 builders until furnace 9")
	check(Defs.builder_count(10) == 3 and Defs.builder_count(19) == 3, "3 builders at furnace 10-19")
	check(Defs.builder_count(20) == 4 and Defs.builder_count(30) == 4, "4 builders from furnace 20")

	# 7) سقف الغياب
	check(Defs.offline_cap_seconds(2.0) == 8.0 * 3600.0, "offline cap floor is 8h")
	check(Defs.offline_cap_seconds(12.0) == 12.0 * 3600.0, "offline cap follows storage hours (12h)")

	Game.save_path_override = "user://frost_save_test_stage17.json"
	Game.dev_mode = false
	Game.new_game()
	check(Game.builder_count() == 2, "new game: 2 builders")
	check(Game.next_builder_unlock() == 10, "next builder unlocks at furnace 10")
	check(is_equal_approx(Game.offline_cap(), 8.0 * 3600.0), "new game: offline cap 8h (%f)" % Game.offline_cap())

	# حدود الطابور حسب البنّائين
	var t := Game.now()
	Game.queue.clear()
	Game.queue.append({"plot": "sh1", "level": 2, "start": t, "end": t + 600.0})
	Game.queue.append({"plot": "hu1", "level": 2, "start": t, "end": t + 600.0})
	Game.plots["furnace"] = 9
	Game.recompute()
	check(not Game.check_upgrade("sa1")["builders_free"], "furnace 9 + 2 jobs: no free builder")
	Game.plots["furnace"] = 10
	Game.recompute()
	check(Game.builder_count() == 3, "furnace 10: 3 builders")
	check(Game.check_upgrade("sa1")["builders_free"], "furnace 10 + 2 jobs: third builder free")
	Game.queue.append({"plot": "sa1", "level": 2, "start": t, "end": t + 600.0})
	check(not Game.check_upgrade("sa2")["builders_free"], "furnace 10 + 3 jobs: no free builder")
	Game.plots["furnace"] = 20
	check(Game.builder_count() == 4 and Game.next_builder_unlock() == 0, "furnace 20: 4 builders, none left to unlock")

	# سقف الغياب مع المخزن
	Game.plots["st1"] = 30
	check(is_equal_approx(Game.storage_hours(), 17.0), "storehouse 30: 17 storage hours (%f)" % Game.storage_hours())
	check(is_equal_approx(Game.offline_cap(), 17.0 * 3600.0), "offline cap rises to 17h")

	# 8) الواجهة: صفوف البنّائين
	Game.new_game()
	Game.queue.clear()
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	check(city.builder_rows.size() == Game.MAX_BUILDERS, "UI has a row per possible builder (%d)" % city.builder_rows.size())
	var vis := 0
	for r in city.builder_rows:
		if (r["panel"] as Control).visible:
			vis += 1
	check(vis == 3, "start: 2 open rows + 1 locked hint row (%d visible)" % vis)
	check((city.builder_rows[2]["label"] as Label).text.contains("10"), "locked row states furnace 10")
	Game.plots["furnace"] = 20
	Game.changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	vis = 0
	for r in city.builder_rows:
		if (r["panel"] as Control).visible:
			vis += 1
	check(vis == 4, "furnace 20: all 4 rows visible, no locked hint (%d)" % vis)

	print("---- stage17: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
