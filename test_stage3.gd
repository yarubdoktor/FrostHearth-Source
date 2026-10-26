extends SceneTree
## اختبار آلي للمرحلة 3 — جبهة الصقيع (منطق اللعبة)
## التشغيل: godot --headless -s test_stage3.gd  (يستخدم مسار حفظ اختباري معزول)

const GS := preload("res://scripts/game_state.gd")
const DefsLib := preload("res://scripts/defs.gd")
const TEST_SAVE := "user://frost_save_test_stage3.json"

func _init() -> void:
	var ok := true
	var g = GS.new()
	g.save_path_override = TEST_SAVE

	# 1) لعبة جديدة: المنفث مهيأ، والجبهة الأولى بعد دورة كاملة (إنذار مسبق)
	g.new_game()
	if g.vent.is_empty() or g.vent["captured"] or g.venture.size() > 0:
		print("FAIL: init"); ok = false
	elif g.front_active() or g.front_active(g.now() + 100.0):
		print("FAIL: first front should come after a full period"); ok = false
	elif not g.front_active(g.front_origin + 10.0):
		print("FAIL: front inactive at origin+10"); ok = false
	elif g.front_active(g.front_origin + 200.0):
		print("FAIL: front active at origin+200"); ok = false
	elif not g.front_active(g.front_origin + 910.0):
		print("FAIL: second cycle"); ok = false
	else:
		print("PASS: init + front schedule (15 min warning)")

	# 2) إرسال فرقة عسكرية: حجز الجنود فورًا
	g.troops["shield_1"] = 40
	g.troops["bow_1"] = 20
	var sent: bool = g.start_venture({"shield_1": 30, "bow_1": 15})
	if not sent or int(g.troops["shield_1"]) != 10 or int(g.troops["bow_1"]) != 5:
		print("FAIL: venture start"); ok = false
	else:
		print("PASS: venture start (troops reserved)")

	# 3) رفض إرسال فرقة ثانية
	if g.start_venture({"shield_1": 5}):
		print("FAIL: double venture"); ok = false
	else:
		print("PASS: double venture rejected")

	# 4) المعركة عند الوصول لا عند العودة: تُحسم والناجون لم يعودوا بعد
	g.venture["arrive"] = g.now() - 1.0
	g.venture["back"] = g.now() + 60.0
	g._simulate(0.5, g.now())
	if not bool(g.venture.get("resolved", false)):
		print("FAIL: battle not resolved at arrival"); ok = false
	elif not g.vent["captured"]:
		print("FAIL: vent not captured"); ok = false
	elif int(g.troops["shield_1"]) != 10 or int(g.troops["bow_1"]) != 5:
		print("FAIL: survivors returned before back time"); ok = false
	else:
		print("PASS: battle resolved at arrival, survivors still returning")

	# 5) حفظ وإعادة تحميل أثناء العودة: المعركة لا تتكرر والناجون يعودون مرة واحدة
	g.save_game()
	var g2 = GS.new()
	g2.save_path_override = TEST_SAVE
	if not g2.load_game():
		print("FAIL: mid-return load"); ok = false
	elif not bool(g2.venture.get("resolved", false)):
		print("FAIL: resolved flag not persisted"); ok = false
	else:
		var home_before := int(g2.troops["shield_1"]) + int(g2.troops["bow_1"])
		var wounded_before := int(g2.wounded["shield_1"]) + int(g2.wounded["bow_1"])
		var dead_seen: Array = []
		g2.venture_done.connect(func(r: Dictionary): dead_seen.append(int(r.get("dead", -1))))
		g2.venture["back"] = g2.now() - 1.0
		g2._simulate(0.5, g2.now())
		if not g2.venture.is_empty():
			print("FAIL: venture not returned"); ok = false
		elif dead_seen.is_empty():
			print("FAIL: dead count not reported on return"); ok = false
		else:
			var home_after := int(g2.troops["shield_1"]) + int(g2.troops["bow_1"])
			var wounded_after := int(g2.wounded["shield_1"]) + int(g2.wounded["bow_1"])
			var new_wounded := wounded_after - wounded_before
			var dead: int = int(dead_seen[0])
			# المحاسبة الدقيقة: المرسلون (45) = (العائدون للثكنات) + جرحى جدد + قتلى
			if home_after - home_before + new_wounded + dead != 45:
				print("FAIL: conservation (%d - %d + %d + %d != 45)" % [home_after, home_before, new_wounded, dead]); ok = false
			else:
				print("PASS: exactly-once return + conservation (home=%d, wounded=%d, dead=%d)" % [home_after, new_wounded, dead])

	# 5ب) امتلاء المستوصف قبل العودة (كأن غارة ذئاب سبقتها): الفائض يصبح قتلى والمحاسبة تصح
	var g5 = GS.new()
	g5.save_path_override = TEST_SAVE
	g5.new_game()
	g5.troops["shield_1"] = 60
	if not g5.start_venture({"shield_1": 50}):
		print("FAIL: 5b venture start"); ok = false
	else:
		g5.venture["arrive"] = g5.now() - 1.0
		g5.venture["back"] = g5.now() + 60.0
		g5._simulate(0.5, g5.now())
		if not bool(g5.venture.get("resolved", false)):
			print("FAIL: 5b battle not resolved"); ok = false
		else:
			# املأ المستوصف تمامًا قبل العودة
			g5.wounded["shield_1"] = g5.wounded_cap()
			var home_before5 := int(g5.troops["shield_1"])
			var dead_seen5: Array = []
			g5.venture_done.connect(func(r: Dictionary): dead_seen5.append(int(r.get("dead", -1))))
			g5.venture["back"] = g5.now() - 1.0
			g5._simulate(0.5, g5.now())
			if not g5.venture.is_empty() or dead_seen5.is_empty():
				print("FAIL: 5b return"); ok = false
			else:
				var home_after5 := int(g5.troops["shield_1"])
				var dead5: int = int(dead_seen5[0])
				# لا جرحى جدد (المستوصف ممتلئ) — والخسائر كلها قتلى
				if home_after5 - home_before5 + dead5 != 50:
					print("FAIL: 5b conservation (%d - %d + %d != 50)" % [home_after5, home_before5, dead5]); ok = false
				elif int(g5.wounded["shield_1"]) != g5.wounded_cap():
					print("FAIL: 5b wounded overflow"); ok = false
				else:
					print("PASS: infirmary-full overflow becomes dead (home=%d, dead=%d)" % [home_after5, dead5])

	# 6) رفض مهمة جديدة بعد الاحتلال
	var g3 = GS.new()
	g3.save_path_override = TEST_SAVE
	g3.load_game()
	if g3.start_venture({"shield_1": 5}):
		print("FAIL: venture allowed after capture"); ok = false
	else:
		print("PASS: venture rejected after capture")

	# 7) دفء المنفث في حساب المدينة
	g3.recompute()
	var heat_before: float = g3.inside_temp
	g3.vent["captured"] = false
	g3.recompute()
	if g3.inside_temp > heat_before - 3.9:
		print("FAIL: vent heat effect"); ok = false
	else:
		print("PASS: vent heat effect (+%.0f)" % (heat_before - g3.inside_temp))

	# 8) الجبهة تخفض الحرارة الخارجية 6 درجات
	var tt_active: float = g3.front_origin + 100.0
	var tt_calm: float = g3.front_origin + 200.0
	var expect_active: float = -16.0 + 3.0 * sin(tt_active * TAU / 600.0) - 6.0
	var expect_calm: float = -16.0 + 3.0 * sin(tt_calm * TAU / 600.0)
	if absf(g3._outside(tt_active) - expect_active) > 0.01 or absf(g3._outside(tt_calm) - expect_calm) > 0.01:
		print("FAIL: front drop"); ok = false
	else:
		print("PASS: front drop (-6 during front, 0 otherwise)")

	# 9) توافق حفظ المرحلة الثانية القديم (بدون حقول المرحلة 3)
	var old_save := {"v": 2, "time": g3.now() - 7200.0, "res": {"food": 100.0, "wood": 100.0, "coal": 50.0, "iron": 0.0}, "gems": 10, "plots": {}, "stored": {}, "queue": [], "pop": 5, "sick": 0.0, "furnace_mode": 1, "stats": {}, "task_index": 1, "last_daily": "", "home": [790, 842], "marches": [], "storm": [0.0, 0.0], "aurora": 0, "trust": 60.0, "troops": {}, "wounded": {}, "train": {}, "heroes": {}, "defender": "", "governor": "", "techs": {}, "research": {}, "crystals": [], "raid_next": 0.0, "raid_count": 0, "raid_wins": 0, "last_raid": {}, "decision_next": 0.0, "pending_decision": -1, "task2_index": 0}
	var fw := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	fw.store_string(JSON.stringify(old_save))
	fw.flush()
	fw = null
	var g4 = GS.new()
	g4.save_path_override = TEST_SAVE
	# غياب ساعتين قبل الحفظ القديم: لا جبهة على الزمن التاريخي، وأول جبهة بعد دورة
	if not g4.load_game():
		print("FAIL: old save load"); ok = false
	elif g4.vent.is_empty() or g4.front_origin <= g4.now():
		print("FAIL: old save migration"); ok = false
	elif g4.front_active(g4.now() - 3600.0):
		print("FAIL: historical front applied"); ok = false
	else:
		print("PASS: old stage-2 save migration (2h absence, no historical front)")

	# 10) نظام المطور: كلمة السر، تجاوز الأسعار والاشتراطات، وثبات أرصدة اللاعب العادي
	if g4.try_dev_mode("00000000"):
		print("FAIL: wrong dev password accepted"); ok = false
	var g6 = GS.new()
	g6.save_path_override = TEST_SAVE
	g6.new_game()
	if not g6.try_dev_mode("19983010") or not g6.dev_mode:
		print("FAIL: dev password rejected"); ok = false
	else:
		for r in g6.res:
			g6.res[r] = 0.0
		g6.gems = 0
		g6.aurora = 0
		# بناء فوري مجاني + تجاوز اشتراطات الفتح (المختبر يتطلب فرناً بمستوى 5)
		if not g6.start_upgrade("lb1", true) or not g6.start_upgrade("ba1", true):
			print("FAIL: dev build not free or requirements not bypassed"); ok = false
		else:
			print("PASS: dev build free/instant, unlock requirements bypassed (lab+barracks, zero resources)")
		# تسريع مجاني بلا جواهر
		g6.queue.clear()
		var t6: float = g6.now()
		g6.queue.append({"plot": "co1", "level": 1, "start": t6, "end": t6 + 3600.0})
		if not g6.speedup("co1") or g6.gems != 0:
			print("FAIL: dev speedup not free"); ok = false
		else:
			print("PASS: dev speedup free (zero gems)")
		# تدريب وبحث واستدعاء وضم بطل وترقية نجمة — كلها بلا خصم من أي رصيد
		if not g6.start_train("shield", 1, 10):
			print("FAIL: dev train not free"); ok = false
		elif not g6.start_research("saw"):
			print("FAIL: dev research not free"); ok = false
		elif not g6.hero_summon("siraj"):
			print("FAIL: dev summon not free"); ok = false
		else:
			var zero_ok := true
			for r in g6.res:
				if g6.res[r] != 0.0:
					zero_ok = false
			if g6.gems != 0 or g6.aurora != 0:
				zero_ok = false
			if not zero_ok:
				print("FAIL: dev actions deducted a balance"); ok = false
			else:
				print("PASS: dev train/research/summon/unlock/star-up free, all balances untouched")
		# dev_finish_all: إنهاء البناء والتدريب والبحث فوراً
		var troops_before := 0
		for k in g6.troops:
			troops_before += int(g6.troops[k])
		if not g6.start_upgrade("co1") or g6.train.is_empty() or g6.research.is_empty():
			print("FAIL: dev setup for finish-all failed"); ok = false
		else:
			g6.dev_finish_all()
			var troops_after := 0
			for k in g6.troops:
				troops_after += int(g6.troops[k])
			if not g6.queue.is_empty() or not g6.train.is_empty() or not g6.research.is_empty() or troops_after != troops_before + 10 or int(g6.techs["saw"]) < 1:
				print("FAIL: dev_finish_all did not finish everything"); ok = false
			else:
				print("PASS: dev_finish_all finished build+train+research (troops +10, tech unlocked)")
		# شظايا البطل لا تُخصم في وضع المطور: الضم والنجمة ينجحان وتبقى الشظايا كما هي
		var shards6: int = int(g6.heroes["siraj"]["shards"])
		if not g6.hero_unlock("siraj"):
			print("FAIL: dev hero unlock failed"); ok = false
		elif int(g6.heroes["siraj"]["shards"]) != shards6:
			print("FAIL: dev unlock deducted shards"); ok = false
		elif not g6.hero_star_up("siraj"):
			print("FAIL: dev star-up failed"); ok = false
		elif int(g6.heroes["siraj"]["shards"]) != shards6:
			print("FAIL: dev star-up deducted shards"); ok = false
		else:
			print("PASS: dev unlock/star-up succeed with shards untouched")
		# حد الأبطال المطلق في وضع المطور: 50 يصل و51 يرفض (دون قاعة أبطال)
		g6.heroes["siraj"]["lv"] = 49
		if not g6.hero_level_up("siraj") or int(g6.heroes["siraj"]["lv"]) != 50:
			print("FAIL: dev level-up to 50 beyond hall cap failed"); ok = false
		elif g6.hero_level_up("siraj"):
			print("FAIL: dev level-up beyond absolute max 50 accepted"); ok = false
		else:
			print("PASS: dev hero cap = absolute 50 (49→50 OK, 51 rejected)")
		# علاج الجميع: يعيد الجرحى للجنود ولا يفقدهم
		g6.troops["shield_1"] = 30
		g6.wounded["shield_1"] = 12
		g6.wounded_total()
		var total_w: int = int(g6.troops["shield_1"]) + int(g6.wounded["shield_1"])
		g6.dev_heal_all()
		if int(g6.wounded["shield_1"]) != 0 or int(g6.troops["shield_1"]) != total_w:
			print("FAIL: dev_heal_all lost troops"); ok = false
		else:
			print("PASS: dev_heal_all returns wounded to troops (conserved)")
		# بقاء الوضع مع الحفظ ثم إطفاؤه
		g6.save_game()
		var g7 = GS.new()
		g7.save_path_override = TEST_SAVE
		g7.load_game()
		if not g7.dev_mode:
			print("FAIL: dev_mode not persisted"); ok = false
		else:
			print("PASS: dev_mode persisted")
		g7.try_dev_mode("19983010")
		if g7.dev_mode:
			print("FAIL: dev off failed"); ok = false
		else:
			# تمييزي: الرفض سببه التكلفة تحديداً، لا سبب آخر
			for r in g7.res:
				g7.res[r] = 0.0
			var c7: Dictionary = g7.check_upgrade("sh1")
			if c7["ok"] or not c7["reasons"].is_empty() or c7["missing"].is_empty():
					print("FAIL: costs not restored after dev off"); ok = false
			else:
				print("PASS: dev off restores costs (rejected only for missing resources)")
				var wood_before: float = 0.0
				for r in c7["cost"]:
					g7.res[r] = c7["cost"][r]
				wood_before = g7.res["wood"]
				if not g7.start_upgrade("sh1"):
					print("FAIL: normal upgrade with resources failed"); ok = false
				elif absf(g7.res["wood"] - (wood_before - float(c7["cost"]["wood"]))) > 0.001:
					print("FAIL: normal upgrade did not deduct correctly"); ok = false
				else:
					print("PASS: normal upgrade succeeds and deducts costs")

	# 11) اللاعب العادي: التكاليف تعمل كالمعتاد في كل الأنظمة
	var g8 = GS.new()
	g8.save_path_override = TEST_SAVE
	g8.new_game()
	for r in g8.res:
		g8.res[r] = 0.0
	g8.aurora = 0
	# تدريب: معسكر مبني وموارد صفر → رفض بسبب التكلفة فقط؛ وبالموارد ينجح ويخصم
	g8.plots["ba1"] = 1
	g8.plots["bs1"] = 1
	var tc8: Dictionary = g8.train_check("shield", 1, 10)
	if tc8["ok"] or not tc8["reasons"].is_empty():
		print("FAIL: normal train blocked by something other than cost"); ok = false
	elif tc8["missing"].is_empty():
		print("FAIL: normal train not cost-gated"); ok = false
	else:
		for r in tc8["cost"]:
			g8.res[r] = tc8["cost"][r]
		var food8: float = g8.res["food"]
		if not g8.start_train("shield", 1, 10):
			print("FAIL: normal train with resources failed"); ok = false
		elif absf(g8.res["food"] - (food8 - float(tc8["cost"]["food"]))) > 0.001:
			print("FAIL: normal train deduction wrong"); ok = false
		else:
			print("PASS: normal train cost-gated, succeeds and deducts")
	# بحث: مختبر مبني وأرصدة صفر → رفض بسبب التكلفة فقط؛ وبالأرصدة ينجح ويخصم
	g8.train = {}
	g8.plots["lb1"] = 1
	var rc8: Dictionary = g8.tech_check("saw")
	if rc8["ok"] or not rc8["reasons"].is_empty():
		print("FAIL: normal research blocked by something other than cost"); ok = false
	elif rc8["missing"].is_empty():
		print("FAIL: normal research not cost-gated"); ok = false
	else:
		for r in rc8["cost"]:
			g8.res[r] = rc8["cost"][r]
		var wood8: float = g8.res["wood"]
		if not g8.start_research("saw"):
			print("FAIL: normal research with resources failed"); ok = false
		elif absf(g8.res["wood"] - (wood8 - float(rc8["cost"]["wood"]))) > 0.001:
			print("FAIL: normal research deduction wrong"); ok = false
		else:
			print("PASS: normal research cost-gated, succeeds and deducts")
	# استدعاء بطل عادي: بلورات غير كافية → رفض؛ كافية → يخصم
	g8.research = {}
	if g8.hero_summon("siraj"):
		print("FAIL: normal summon succeeded with zero aurora"); ok = false
	else:
		g8.aurora = float(DefsLib.SUMMON_COST)
		if not g8.hero_summon("siraj") or absf(g8.aurora) > 0.001:
			print("FAIL: normal summon/deduction wrong"); ok = false
		else:
			print("PASS: normal summon cost-gated and deducts aurora")
	# ضم بطل عادي: يخصم الشظايا
	g8.plots["hh1"] = 1
	g8.heroes["siraj"]["shards"] = int(DefsLib.STAR_SHARDS[0])
	if not g8.hero_unlock("siraj") or int(g8.heroes["siraj"]["shards"]) != 0:
		print("FAIL: normal hero unlock shard deduction wrong"); ok = false
	else:
		print("PASS: normal hero unlock deducts shards")

	# تنظيف مسار الحفظ الاختباري
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	print("ALL LOGIC TESTS PASSED" if ok else "SOME LOGIC TESTS FAILED")
	quit(0 if ok else 1)
