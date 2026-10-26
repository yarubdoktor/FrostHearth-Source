extends Node
const DefsLib := preload("res://scripts/defs.gd")
## اختبار واجهة نظام المطور — من داخل مشهد المدينة الفعلي (الأزرار والنوافذ)
## التشغيل: godot --headless --path . res://test_dev_ui.tscn

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _walk(n: Node, kind: String, text := "") -> Array:
	var found: Array = []
	if kind == "Button" and n is Button:
		if text == "" or (n as Button).text == text:
			found.append(n)
	elif kind == "LineEdit" and n is LineEdit:
		found.append(n)
	for c in n.get_children():
		found.append_array(_walk(c, kind, text))
	return found

func _press_close(city: Node) -> void:
	var closes: Array = _walk(city.modal_layer, "Button", "إغلاق")
	if closes.is_empty():
		fail("close button missing")
	else:
		(closes[0] as Button).pressed.emit()
		await get_tree().process_frame

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_ui.json"
	Game.new_game()
	for r in Game.res:
		Game.res[r] = 0.0
	Game.gems = 0
	Game.aurora = 0
	var city_scene: PackedScene = load("res://city.tscn")
	var city: Node = city_scene.instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) زر «نظام المطور» موجود داخل نافذة الإعدادات
	city._show_settings()
	var dev_btns: Array = _walk(city.modal_layer, "Button", "نظام المطور")
	if dev_btns.is_empty():
		fail("dev button missing in settings modal")
	else:
		(dev_btns[0] as Button).pressed.emit()
		await get_tree().process_frame

	# 2) كلمة سر خاطئة مرفوضة من الواجهة
	var edits: Array = _walk(city.modal_layer, "LineEdit")
	if edits.is_empty():
		fail("password LineEdit missing in dev window")
	else:
		(edits[0] as LineEdit).text = "00000000"
		var login: Array = _walk(city.modal_layer, "Button", "دخول")
		if login.is_empty():
			fail("login button missing")
		else:
			(login[0] as Button).pressed.emit()
			await get_tree().process_frame
			if Game.dev_mode:
				fail("wrong password accepted via UI")
			else:
				print("PASS: wrong password rejected via UI")

	# 3) كلمة السر الصحيحة تفعّل الوضع من الواجهة
	if not edits.is_empty():
		(edits[0] as LineEdit).text = "19983010"
		var login: Array = _walk(city.modal_layer, "Button", "دخول")
		if login.is_empty():
			fail("login button disappeared")
		else:
			(login[0] as Button).pressed.emit()
			await get_tree().process_frame
			if not Game.dev_mode:
				fail("correct password rejected via UI")
			else:
				print("PASS: correct password activates dev mode via UI")

	# 4) لوحة أدوات المطور: كل أزرارها تعمل فعلاً عبر الضغط
	var tool: Array = _walk(city.modal_layer, "Button", "+100 ألف لكل مورد")
	if tool.is_empty():
		fail("dev tool button missing in dev panel")
	else:
		(tool[0] as Button).pressed.emit()
		await get_tree().process_frame
		if Game.res["wood"] < 100000.0:
			fail("dev_give_resources did not run via UI button")
		else:
			print("PASS: dev resource tool button works via UI")
	var prem: Array = _walk(city.modal_layer, "Button", "+1000 جوهرة و+1000 بلورة")
	if not prem.is_empty():
		(prem[0] as Button).pressed.emit()
		await get_tree().process_frame
		if Game.gems < 1000 or Game.aurora < 1000:
			fail("dev premium tool did not run via UI")
		else:
			print("PASS: dev premium tool button works via UI")
	var pop: Array = _walk(city.modal_layer, "Button", "+50 ساكن")
	if not pop.is_empty():
		var pop_before: int = int(Game.pop)
		(pop[0] as Button).pressed.emit()
		await get_tree().process_frame
		if int(Game.pop) < pop_before + 50:
			fail("dev pop tool did not run via UI")
		else:
			print("PASS: dev pop tool button works via UI")
	# إغلاق لوحة الأدوات بزرها
	_press_close(city)

	# 5) بناء عبر الواجهة لموقعين مقفلين (مختبر + معسكر) بموارد صفرية — بزر البناء الفعلي
	for r in Game.res:
		Game.res[r] = 0.0
	city._select("lb1")
	await get_tree().process_frame
	if city.bp_main.disabled:
		fail("build button disabled in dev mode for locked plot")
	else:
		city.bp_main.pressed.emit()   # الزر الفعلي وليس استدعاء داخلي
		await get_tree().process_frame
		if Game.queue_entry("lb1").is_empty():
			fail("UI build did not start for locked plot in dev mode")
		elif Game.res["wood"] != 0.0:
			fail("UI build charged resources in dev mode")
		else:
			print("PASS: UI build of locked plot works free via actual build button")
	city._select("ba1")
	await get_tree().process_frame
	if not city.bp_main.disabled:
		city.bp_main.pressed.emit()
		await get_tree().process_frame
		if Game.queue_entry("ba1").is_empty():
			fail("UI barracks build did not start")
		else:
			print("PASS: UI barracks build starts via actual build button")

	# 6) زر النجمة العائم يظهر فقط في وضع المطور
	if not city.dev_btn.visible:
		fail("floating dev button not visible in dev mode")
	else:
		print("PASS: floating dev button visible in dev mode")

	# 7) تدريب عبر نافذة الجيش الفعلية (معسكر قيد البناء/مبني بموارد صفرية)
	city._show_training("shield")
	await get_tree().process_frame
	var train_btns: Array = _walk(city.modal_layer, "Button", "تدريب")
	var trained := false
	for tb in train_btns:
		if not (tb as Button).disabled:
			(tb as Button).pressed.emit()
			await get_tree().process_frame
			if not Game.train.is_empty():
				trained = true
			break
	if Game.train.is_empty() and not trained:
		# المعسكر ما زال قيد البناء — أنهِ البناء ثم أعد المحاولة
		city._dev_panel()
		await get_tree().process_frame
		var fin: Array = _walk(city.modal_layer, "Button", "تسريع كل شيء (بناء وتدريب وبحث)")
		if not fin.is_empty():
			(fin[0] as Button).pressed.emit()
			await get_tree().process_frame
		_press_close(city)
		city._show_training("shield")
		await get_tree().process_frame
		train_btns = _walk(city.modal_layer, "Button", "تدريب")
		for tb in train_btns:
			if not (tb as Button).disabled:
				(tb as Button).pressed.emit()
				await get_tree().process_frame
				break
	if Game.train.is_empty():
		fail("train via UI window did not start in dev mode")
	else:
		print("PASS: training starts via actual army window button (zero resources)")

	# 8) بحث عبر نافذة الأبحاث الفعلية
	city._show_research()
	await get_tree().process_frame
	var res_btns: Array = _walk(city.modal_layer, "Button", "بحث")
	for rb in res_btns:
		if not (rb as Button).disabled:
			(rb as Button).pressed.emit()
			await get_tree().process_frame
			break
	if Game.research.is_empty():
		fail("research via UI window did not start in dev mode")
	else:
		print("PASS: research starts via actual research window button (zero resources)")

	# 9) استدعاء بطل عبر نافذة الأبطال الفعلية ببلورات صفرية
	Game.aurora = 0
	city._show_heroes()
	await get_tree().process_frame
	# Stage 29.1: choose a portrait before showing the hero's actions.
	var siraj_card: Button = city.win_dim.find_child("HeroCard_siraj", true, false)
	if siraj_card != null:
		siraj_card.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	var summon_txt := "استدعاء • %d بلورة" % int(DefsLib.SUMMON_COST)
	var sum_btns: Array = _walk(city.modal_layer, "Button", summon_txt)
	if sum_btns.is_empty():
		fail("hero summon button missing")
	else:
		var shards_before: int = int(Game.heroes["siraj"]["shards"])
		if (sum_btns[0] as Button).disabled:
			fail("hero summon button disabled in dev mode with zero aurora")
		else:
			(sum_btns[0] as Button).pressed.emit()
			await get_tree().process_frame
			if int(Game.heroes["siraj"]["shards"]) <= shards_before or Game.aurora != 0:
				fail("hero summon via UI failed or charged aurora in dev mode")
			else:
				print("PASS: hero summon works via actual window button (zero aurora, no charge)")

	# 10) أداة «تسريع كل شيء» تنهي البناء والتدريب والبحث عبر زرها
	city._dev_panel()
	await get_tree().process_frame
	var fin2: Array = _walk(city.modal_layer, "Button", "تسريع كل شيء (بناء وتدريب وبحث)")
	if fin2.is_empty():
		fail("finish-all tool button missing")
	else:
		if Game.queue.is_empty() and Game.train.is_empty() and Game.research.is_empty():
			fail("nothing pending before finish-all (test setup)")
		else:
			(fin2[0] as Button).pressed.emit()
			await get_tree().process_frame
			if not Game.queue.is_empty() or not Game.train.is_empty() or not Game.research.is_empty():
				fail("finish-all did not finish everything via UI")
			else:
				print("PASS: finish-all tool completes build+train+research via UI button")

	# 11) أداة العلاج تعيد الجرحى للجنود ولا تفقدهم
	Game.wounded["shield_1"] = 5
	Game.troops["shield_1"] = 20
	var heal: Array = _walk(city.modal_layer, "Button", "علاج الجرحى والمرضى")
	if heal.is_empty():
		fail("heal tool button missing")
	else:
		(heal[0] as Button).pressed.emit()
		await get_tree().process_frame
		if int(Game.wounded.get("shield_1", 0)) != 0 or int(Game.troops["shield_1"]) != 25:
			fail("heal tool lost troops via UI")
		else:
			print("PASS: heal tool returns wounded to troops via UI button")
	_press_close(city)

	# 12) إطفاء الوضع من النافذة: يعيد تعطيل البناء لناقصي الموارد
	city._dev_window()
	await get_tree().process_frame
	var off: Array = _walk(city.modal_layer, "Button", "إيقاف الوضع")
	if off.is_empty():
		fail("toggle-off button missing")
	else:
		(off[0] as Button).pressed.emit()
		await get_tree().process_frame
		if Game.dev_mode:
			fail("toggle off failed via UI")
		else:
			city._select("sh1")
			await get_tree().process_frame
			if not city.bp_main.disabled:
				fail("build button not disabled for normal player with zero resources")
			else:
				print("PASS: UI gates restored for normal player after toggle off")
	if city.dev_btn.visible:
		fail("floating dev button still visible after toggle off")

	# 13) الحفظ بعد الإطفاء: الوضع مطفأ عند التحميل
	var GS: GDScript = load("res://scripts/game_state.gd")
	var g2: Object = GS.new()
	g2.save_path_override = "user://frost_save_test_ui.json"
	g2.load_game()
	if bool(g2.dev_mode):
		fail("dev_mode still on in saved game after toggle off")
	else:
		print("PASS: saved game has dev mode off after toggle")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frost_save_test_ui.json"))
	print("ALL UI TESTS PASSED" if ok else "SOME UI TESTS FAILED")
	get_tree().quit(0 if ok else 1)
