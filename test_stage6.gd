extends SceneTree
## اختبار آلي لتعميق الخريطة — التشكيلات والمعاقل وضباب الحرب (منطق اللعبة)
## التشغيل: godot --headless -s test_stage6.gd  (مسار حفظ اختباري معزول)

const GS := preload("res://scripts/game_state.gd")
const Combat := preload("res://scripts/combat.gd")
const DefsLib := preload("res://scripts/defs.gd")
const TEST_SAVE := "user://frost_save_test_stage6.json"

func _init() -> void:
	var ok := true
	var g = GS.new()
	g.save_path_override = TEST_SAVE
	g.new_game()

	# ================================================================ 1) التشكيلات: نقاء ونسخ عميق
	var mods := {"atk": {"shield": 0.1, "spear": 0.0, "bow": 0.2}, "def": {"shield": 0.05, "spear": 0.0, "bow": 0.0},
		"hp": {}, "hp_all": 0.0, "all": 0.0, "skill": "siraj", "taken": 0.9}
	var m_b: Dictionary = Combat.with_formation(mods, "balanced")
	if absf(float(m_b["atk"]["shield"]) - 0.1) > 1e-9 or absf(float(m_b["taken"]) - 0.9) > 1e-9 \
			or String(m_b["skill"]) != "siraj" or not m_b.has("formation_dead") or absf(float(m_b["formation_dead"]) - 0.25) > 1e-9:
		print("FAIL: balanced formation must not change anything"); ok = false
	elif absf(float(mods["atk"]["shield"]) - 0.1) > 1e-9 or absf(float(mods["def"]["shield"]) - 0.05) > 1e-9:
		print("FAIL: with_formation mutated the original mods"); ok = false
	else:
		print("PASS: with_formation balanced = identical deep copy")

	# 2) معاملات التشكيلات صحيحة داخل الدالة
	var m_a: Dictionary = Combat.with_formation(mods, "aggressive")
	var m_d: Dictionary = Combat.with_formation(mods, "defensive")
	if absf(float(m_a["atk"]["shield"]) - 0.25) > 1e-9 or absf(float(m_a["def"]["shield"]) - (-0.10)) > 1e-9 \
			or absf(float(m_a["taken"]) - 0.9 * 1.15) > 1e-9:
		print("FAIL: aggressive mods wrong"); ok = false
	elif absf(float(m_d["atk"]["bow"]) - 0.1) > 1e-9 or absf(float(m_d["def"]["shield"]) - 0.25) > 1e-9 \
			or absf(float(m_d["formation_dead"]) - 0.18) > 1e-9:
		print("FAIL: defensive mods wrong"); ok = false
	else:
		print("PASS: aggressive/defensive modifiers correct")

	# 3) التشكيل يغير نتيجة المعركة فعلًا (بذرة واحدة)
	var att := {"shield_1": 40, "spear_1": 30, "bow_1": 30}
	var defu := {"beast": 30}
	var dmods := {"beast": {"atk": 10.0, "def": 7.0, "hp": 30.0, "name": "حرّاس"}}
	var rep_b: Dictionary = Combat.fight(att, Combat.with_formation(g.army_mods(""), "balanced"), defu, dmods, false, 777)
	var rep_a: Dictionary = Combat.fight(att, Combat.with_formation(g.army_mods(""), "aggressive"), defu, dmods, false, 777)
	var rep_d: Dictionary = Combat.fight(att, Combat.with_formation(g.army_mods(""), "defensive"), defu, dmods, false, 777)
	if rep_b["log"].hash() == rep_a["log"].hash() and rep_b["att_loss"].hash() == rep_a["att_loss"].hash():
		print("FAIL: aggressive formation did not change the battle"); ok = false
	elif int(rep_a["def_loss"]["beast"]) < int(rep_b["def_loss"]["beast"]):
		print("FAIL: aggressive should hit defenders harder with same seed"); ok = false
	elif int(rep_d["att_loss"]["shield_1"]) > int(rep_a["att_loss"]["shield_1"]):
		print("FAIL: defensive should not lose more shield troops than aggressive"); ok = false
	else:
		print("PASS: formation changes battle outcome (aggressive hits harder, defensive loses less)")

	# ================================================================ 4) المعاقل: فشل الاحتلال ثم نجاحه ثم رفض التكرار
	# Stage 21: المسيرات صارت محدودة بالمستودع الحربي ومؤنها طعام — نجهّز مستودعًا ومؤنًا لهذا المشهد
	g.plots["wd1"] = 14
	g.res["food"] = 99999.0
	g.troops["shield_1"] = 200
	g.troops["spear_1"] = 200
	g.troops["bow_1"] = 200
	var aurora_before := int(g.aurora)
	# فشل: جيش ضعيف جدًا
	var weak = GS.new()
	weak.save_path_override = TEST_SAVE
	weak.new_game()
	weak.troops["shield_1"] = 2
	if not weak.start_venture({"shield_1": 2}, "balanced", {"kind": "hold", "id": "stronghold_1"}):
		print("FAIL: weak hold venture start"); ok = false
	else:
		weak.venture["arrive"] = weak.now() - 1.0
		weak.venture["back"] = weak.now() + 60.0
		weak._simulate(0.5, weak.now())
		if bool(weak.venture.get("won", true)) or not weak.holds.is_empty():
			print("FAIL: weak army should fail the stronghold"); ok = false
		else:
			print("PASS: failed occupation leaves stronghold free")

	# نجاح: جيش قوي — والمكافأة تُمنح مرة واحدة
	if not g.start_venture({"shield_1": 150, "spear_1": 150, "bow_1": 150}, "aggressive", {"kind": "hold", "id": "stronghold_1"}):
		print("FAIL: hold venture start"); ok = false
	elif g.holds.has("stronghold_1"):
		print("FAIL: hold captured before battle"); ok = false
	else:
		g.venture["arrive"] = g.now() - 1.0
		g.venture["back"] = g.now() + 60.0
		g._simulate(0.5, g.now())
		if not g.holds.has("stronghold_1") or String(g.holds["stronghold_1"]) != "stronghold":
			print("FAIL: stronghold not captured after win"); ok = false
		elif int(g.aurora) <= aurora_before:
			print("FAIL: capture reward not given"); ok = false
		else:
			print("PASS: stronghold captured with one-time reward")
	# رفض التكرار
	if g.start_venture({"shield_1": 50}, "balanced", {"kind": "hold", "id": "stronghold_1"}):
		print("FAIL: repeat capture accepted"); ok = false
	else:
		print("PASS: repeat capture rejected")

	# 5) مكافأة المعقل الدائمة: +4% إنتاج لكل مورد
	g.venture = {}
	g._simulate(0.0, g.now())
	var rate_no_hold := 0.0
	for id in DefsLib.PLOTS:
		if DefsLib.PLOTS[id]["type"] == "hunter" and g.level(id) > 0:
			g.holds.erase("stronghold_1")
			g.recompute()
			rate_no_hold = g.current_rate(id)
			g.holds["stronghold_1"] = "stronghold"
			g.recompute()
			var rate_hold := g.current_rate(id)
			if absf(rate_hold - rate_no_hold * 1.04) > 1e-6:
				print("FAIL: stronghold production bonus wrong (%f vs %f)" % [rate_hold, rate_no_hold * 1.04]); ok = false
			else:
				print("PASS: stronghold production bonus +4%")
			break

	# 6) مكافأة القلعة الدائمة: غارات الذئاب أضعف
	var raid_before: int = int(g.raid_strength()["n"])
	g.holds["fortress_1"] = "fortress"
	var raid_after: int = int(g.raid_strength()["n"])
	if raid_after >= raid_before:
		print("FAIL: fortress did not reduce raid strength"); ok = false
	else:
		print("PASS: fortress reduces raid strength (%d -> %d)" % [raid_before, raid_after])

	# 7) المنفث المحتل لا يمنع مهاجمة معقل آخر (والعكس صحيح)
	g.vent["captured"] = true
	g.venture = {}
	if not g.start_venture({"shield_1": 50}, "balanced", {"kind": "hold", "id": "fortress_2"}):
		print("FAIL: captured vent blocked hold attack"); ok = false
	else:
		print("PASS: captured vent does not block hold attacks")
	g.venture = {}

	# ================================================================ 8) ضباب الحرب: البداية والكشف والحفظ
	var fresh = GS.new()
	fresh.save_path_override = TEST_SAVE
	fresh.new_game()
	if not fresh.is_explored(fresh.home.x, fresh.home.y) or not fresh.is_explored(fresh.home.x + 30, fresh.home.y):
		print("FAIL: home area should start explored"); ok = false
	elif fresh.is_explored(600, 600) or fresh.is_explored(100, 100):
		print("FAIL: far map should start unexplored"); ok = false
	else:
		print("PASS: fog starts revealed around home only")
	fresh.reveal_at(600, 600, 30.0)
	if not fresh.is_explored(600, 600) or fresh.is_explored(700, 700):
		print("FAIL: reveal_at broken"); ok = false
	else:
		print("PASS: reveal_at marks a circle only")

	# 9) فرقة الاستطلاع تكشف عند الوصول (لا عند العودة) — والممر يُكشف أثناء الحركة
	fresh.marches = []
	if not fresh.start_march({"kind": "scout", "x": 500, "y": 500}):
		print("FAIL: scout march start"); ok = false
	else:
		var sm: Dictionary = fresh.marches[0]
		# محاكاة قفزة زمنية تتجاوز الوصول: الكشف عند الوصول والممر كله
		fresh._simulate(120.0, fresh.now() + 120.0)
		if not fresh.is_explored(500, 500):
			print("FAIL: scout did not reveal target at arrival"); ok = false
		elif not fresh.is_explored(645, 671):
			print("FAIL: march corridor not revealed"); ok = false
		elif not fresh.is_explored(520, 484):
			# على بعد ~25 من الهدف (ضمن نطاق الكشف 30) لكن خارج ممر الحركة
			print("FAIL: scout reveal radius too small"); ok = false
		elif fresh.is_explored(530, 474):
			# على بعد ~40 من الهدف ومن خط المسار — يجب أن يبقى مجهولًا
			print("FAIL: scout reveal radius too big"); ok = false
		else:
			print("PASS: scout reveals at arrival + corridor revealed en route")

	# 10) المسيرة العادية تكشف ممرها حتى مع خطوات محاكاة كبيرة (غياب 30 ثانية)
	var big = GS.new()
	big.save_path_override = TEST_SAVE
	big.new_game()
	if not big.start_march({"kind": "res", "t": "wood", "l": 1, "x": 100, "y": 100}):
		print("FAIL: res march start"); ok = false
	else:
		var m0: Dictionary = big.marches[0]
		var t0 := float(m0["start"])
		# محاكاة الغياب: خطوات 30 ثانية متتالية (كما في اللعب الحقيقي) — الممر يجب أن يُكشف بلا فجوات
		var mid := Vector2((big.home.x + 100) / 2.0, (big.home.y + 100) / 2.0)
		var sim_t := t0
		for i in range(40):
			sim_t += 30.0
			big._simulate(30.0, sim_t)
		if not big.is_explored(int(mid.x), int(mid.y)):
			print("FAIL: big simulation step left corridor gaps"); ok = false
		else:
			print("PASS: corridor revealed across big offline steps")

	# 11) الحفظ والإعادة: الشبكة تبقى، والمكافآت الدائمة تبقى
	fresh.holds["stronghold_2"] = "stronghold"
	fresh.save_game()
	var again = GS.new()
	again.save_path_override = TEST_SAVE
	if not again.load_game():
		print("FAIL: stage6 reload"); ok = false
	elif not again.is_explored(600, 600) or again.is_explored(700, 700):
		print("FAIL: explored grid not persisted"); ok = false
	elif not again.holds.has("stronghold_2") or again.holds_count("stronghold") != 1:
		print("FAIL: holds not persisted"); ok = false
	else:
		print("PASS: fog grid + holds persisted through save/load")

	# 12) هجرة حفظ v3: لا «explored» ولا «holds» ولا «target/formation» في المسيرة العسكرية
	var g3 = GS.new()
	g3.save_path_override = TEST_SAVE
	g3.new_game()
	g3.plots["wd1"] = 2
	g3.res["food"] = 99999.0
	g3.troops["shield_1"] = 100
	g3.start_venture({"shield_1": 80})
	g3.save_game()
	var path := ProjectSettings.globalize_path(TEST_SAVE)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d["v"] = 3
	d.erase("explored")
	d.erase("holds")
	d["venture"].erase("target")
	d["venture"].erase("formation")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var old = GS.new()
	old.save_path_override = TEST_SAVE
	if not old.load_game():
		print("FAIL: v3 migration load"); ok = false
	elif old.is_explored(600, 600) or not old.is_explored(old.home.x, old.home.y):
		print("FAIL: v3 migration should reveal only home area"); ok = false
	elif String(old.venture.get("target", {}).get("kind", "")) != "vent" or String(old.venture.get("formation", "")) != "balanced":
		print("FAIL: old venture target/formation defaults"); ok = false
	elif not old.holds.is_empty():
		print("FAIL: v3 holds should default empty"); ok = false
	else:
		print("PASS: v3 save migration (home revealed, venture defaults, no holds)")

	# 13) قفزة الغياب تتجاوز عودة الاستطلاع: يكشف مرة واحدة ويعود دون تكرار
	var jump = GS.new()
	jump.save_path_override = TEST_SAVE
	jump.new_game()
	jump.start_march({"kind": "scout", "x": 300, "y": 300})
	var m3: Dictionary = jump.marches[0]
	jump.save_game()
	# محاكاة ما بعد التحميل مباشرة (كأن اللاعب غاب فترة طويلة عندها رحلة كاملة)
	var after = GS.new()
	after.save_path_override = TEST_SAVE
	after.load_game()
	var march_cnt: int = after.marches.size()
	after._simulate(600.0, after.now() + 600.0)
	if not after.is_explored(300, 300):
		print("FAIL: offline scout did not reveal"); ok = false
	elif after.marches.size() >= march_cnt and int(after.marches.size()) > 0:
		# المهمة قد تكون انتهت (حجم أقل) — الفشل فقط إذا بقيت موجودة رغم تجاوز عودتها
		if not after.marches.is_empty():
			print("FAIL: scout march not consumed after long offline"); ok = false
	else:
		print("PASS: offline jump reveals once and consumes the scout march")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("ALL STAGE6 LOGIC TESTS PASSED" if ok else "SOME STAGE6 LOGIC TESTS FAILED")
	quit(0 if ok else 1)
