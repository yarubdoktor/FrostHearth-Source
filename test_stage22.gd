extends Node
## اختبار Stage 22 — السوق: تبادل الموارد بأسعار تتغير مع الوقت والعاصفة
## التشغيل: godot --headless --path . res://test_stage22.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0
var toasts: Array[String] = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage22.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.res = {"food": 5000.0, "wood": 5000.0, "coal": 5000.0, "iron": 5000.0}


func _on_toast(msg: String) -> void:
	toasts.append(msg)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	Game.toast.connect(_on_toast)
	# 1) التعريفات
	check(Defs.BUILDINGS.has("market") and Defs.BUILDINGS["market"]["name"] == "السوق", "market building defined")
	check(Defs.PLOTS.has("mk1") and Defs.PLOTS["mk1"]["type"] == "market", "market plot mk1 defined")
	check(int(Defs.PLOTS["mk1"]["unlock"]) == 8, "market unlocks at furnace 8")
	var ok_pos := true
	var am := float(Defs.PLOTS["mk1"]["a"])
	for id in Defs.PLOTS:
		if id == "mk1":
			continue
		var p: Dictionary = Defs.PLOTS[id]
		if absf(float(p["r"]) - float(Defs.PLOTS["mk1"]["r"])) < 1.0:
			if absf(fposmod(float(p["a"]) - am + 180.0, 360.0) - 180.0) < 20.0:
				ok_pos = false
	check(ok_pos, "mk1 does not crowd neighbouring plots")
	check(absf(fposmod(am - 90.0 + 180.0, 360.0) - 180.0) > 20.0, "mk1 is away from the main gate")
	for t in range(3):
		check(FileAccess.file_exists("res://assets/city/market_t%d.glb" % t), "market_t%d.glb exists" % t)

	# 2) المعادلات
	check(absf(Defs.market_fee(1) - 0.20) < 0.0001, "fee 20% at level 1")
	check(absf(Defs.market_fee(5) - 0.16) < 0.0001, "fee drops 1% per level")
	check(absf(Defs.market_fee(30) - 0.08) < 0.0001, "fee floor 8%")
	check(Defs.market_quota(1) == 300 and Defs.market_quota(11) == 2300, "quota grows 200 per level")
	var lo := 99.0
	var hi := 0.0
	for k in range(0, 2400, 20):
		var pr := Defs.market_price("iron", float(k), false)
		lo = minf(lo, pr)
		hi = maxf(hi, pr)
	check(lo >= 2.2 * 0.949 and hi <= 2.2 * 1.051, "iron price oscillates within +-5%")
	check(hi - lo > 0.2, "price actually moves over time")
	check(Defs.market_price("coal", 100.0, true) > Defs.market_price("coal", 100.0, false) * 1.29, "storm raises coal price 30%")
	check(absf(Defs.market_price("iron", 100.0, true) - Defs.market_price("iron", 100.0, false)) < 0.0001, "storm leaves iron price")
	check(Defs.market_quote("wood", "wood", 100, 0.0, false, 5) == 0, "same resource gives nothing")
	check(Defs.market_quote("wood", "iron", 0, 0.0, false, 5) == 0, "zero amount gives nothing")
	# جولة ذهاب وإياب تخسر دائمًا (لا ربح تحكيمي) حتى بأقصى مستوى
	var worst := 0.0
	var nofree := true
	for k in range(0, 4800, 10):
		for a in Defs.RES:
			for b in Defs.RES:
				if a == b:
					continue
				var got := Defs.market_quote(a, b, 1000, float(k), false, 30)
				var back := Defs.market_quote(b, a, got, float(k), false, 30)
				if back >= 1000:
					nofree = false
	check(nofree, "instant round trip never profits (all pairs, max level)")
	# بمرور الوقت: اشترِ عند القاع وبع عند القمة
	var gain_max := 0.0
	for k in range(0, 2400, 10):
		var got2 := Defs.market_quote("wood", "iron", 1000, float(k), false, 30)
		var back2 := Defs.market_quote("iron", "wood", got2, float(k) + 1200.0, false, 30)
		gain_max = maxf(gain_max, float(back2) / 1000.0)
	check(gain_max < 1.10, "timed arbitrage stays under 12%% (%.3f)" % gain_max)

	# 3) داخل اللعبة
	_fresh()
	check(Game.market_level() == 0, "new game has no market")
	toasts.clear()
	check(not Game.market_trade("wood", "iron", 100), "trade refused without a market")
	check(toasts.size() > 0 and String(toasts[-1]).find("السوق") >= 0, "toast asks to build the market")
	Game.plots["mk1"] = 1
	var before_w := float(Game.res["wood"])
	var before_i := float(Game.res["iron"])
	var quote := Game.market_quote("wood", "iron", 100)
	check(quote > 0, "quote positive")
	check(Game.market_trade("wood", "iron", 100), "trade accepted")
	check(absf(float(Game.res["wood"]) - (before_w - 100.0)) < 0.01 and absf(float(Game.res["iron"]) - (before_i + quote)) < 0.01, "resources move by the quote")
	check(Game.market_quota_left() == 200, "quota decreases (300 - 100)")
	toasts.clear()
	check(not Game.market_trade("wood", "iron", 250), "trade over remaining quota refused")
	check(toasts.size() > 0 and String(toasts[-1]).find("حصة") >= 0, "toast mentions quota")
	check(not Game.market_trade("wood", "wood", 10), "same resource refused")
	check(not Game.market_trade("wood", "iron", 0), "zero amount refused")
	Game.res["wood"] = 5.0
	check(not Game.market_trade("wood", "iron", 50), "trade over stock refused")
	check(int(Game.stats.get("traded", 0)) == 100, "traded stat counts units")
	# تجدد الحصة
	Game.market_window_start -= Defs.MARKET_WINDOW + 1.0
	check(Game.market_quota_left() == 300, "quota renews after the window")
	check(Game.market_reset_in() > 0.0, "reset timer positive")
	# الحفظ
	Game.res["wood"] = 5000.0
	Game.market_trade("wood", "coal", 120)
	var used := Game.market_used
	Game.save_game()
	Game.market_used = 0.0
	Game.load_game()
	check(Game.market_used == used and Game.market_level() == 1, "quota usage and market level persist")
	# مستوى أعلى = حصة ورسوم أفضل
	Game.plots["mk1"] = 11
	check(Game.market_quota_left() > 2000, "higher level has larger quota")
	check(Game.market_quote("wood", "iron", 1000) > 0, "quote works at higher level")
	# وضع المطوّر يتجاوز الحصة
	_fresh()
	Game.plots["mk1"] = 1
	Game.dev_mode = true
	check(Game.market_trade("wood", "iron", 4000), "dev mode bypasses quota")
	Game.dev_mode = false

	# 4) العاصفة تغيّر السعر الحالي
	_fresh()
	Game.storm_start = Game.now() - 10.0
	Game.storm_end = Game.now() + 100.0
	var p_storm := Game.market_price("coal")
	Game.storm_start = Game.now() + 5000.0
	Game.storm_end = Game.now() + 5100.0
	var p_calm := Game.market_price("coal")
	check(p_storm > p_calm * 1.25, "live coal price rises during a storm")

	# 5) الواجهة
	_fresh()
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.plots["mk1"] = 3
	city.call("_select", "mk1")
	await get_tree().process_frame
	var txt := String(city.bp_stats.text)
	check(txt.find("رسوم التبادل") >= 0 and txt.find("حصة التبادل") >= 0, "market panel shows fee and quota")
	check(city.bp_open.visible and city.bp_open.text == "فتح السوق", "market panel has an open button")
	city.call("_open_from_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(city.win_dim), "market window opens")
	var found := _find_label(city.win_dim, "أسعار السوق")
	check(found, "window shows the price board")
	check(_find_label(city.win_dim, "رسوم التبادل 18%"), "window shows level-3 fee (18%)")
	check(_find_label(city.win_dim, "وتستلم"), "window shows the trade preview")
	var btn := _find_button(city.win_dim, "تبادل")
	check(btn != null and not btn.disabled, "trade button enabled with a valid default")
	var w0 := float(Game.res["wood"])
	if btn != null:
		btn.pressed.emit()
	await get_tree().process_frame
	check(float(Game.res["wood"]) < w0, "pressing trade spends the sold resource")
	city.call("_close_window")
	city.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _find_label(n: Node, part: String) -> bool:
	if n is Label and (n as Label).text.find(part) >= 0:
		return true
	for c in n.get_children():
		if _find_label(c, part):
			return true
	return false


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
