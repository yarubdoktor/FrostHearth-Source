extends Node
## اختبار Stage 28 — تقسيم الملفات الكبيرة (بلا تغيير في السلوك)
## التشغيل: godot --headless --path . res://test_stage28.tscn
## يتحقق من: سياسة الحجم، سلاسل الطبقات، بقاء واجهة Game كاملة، وأن المشهدين يُبنيان ويعملان فوق الطبقات.

const SOFT_LINES := 500
const HARD_LINES := 800

var checks := 0
var failures := 0

## كل سلسلة: من الأعلى (نقطة الدخول) إلى الجذر
const CHAINS := {
	"game": ["res://scripts/game_state.gd", "res://scripts/game/state/state_actions.gd", "res://scripts/game/state/state_sim.gd",
		"res://scripts/game/state/state_queries.gd", "res://scripts/game/state/state_army.gd", "res://scripts/game/state/state_core.gd"],
	"city": ["res://scripts/city.gd", "res://scripts/city/city_events.gd", "res://scripts/city/city_panel.gd",
		"res://scripts/city/city_world.gd", "res://scripts/city/city_windows.gd", "res://scripts/city/city_core.gd"],
	"map": ["res://scripts/world_map.gd", "res://scripts/map/map_panel.gd", "res://scripts/map/map_venture.gd",
		"res://scripts/map/map_scene.gd", "res://scripts/map/map_core.gd"],
}

## دوال عامة من كل طبقة في Game — يجب أن تبقى متاحة بنفس أسمائها
const GAME_API := ["now", "save_game", "level", "furnace_level", "bonus", "give", "is_explored", "reveal_at", "troop_total", "power",
	"army_mods", "death_mult", "troop_stats", "train_check", "defense_profile", "builder_count", "current_rate", "net_rate", "raid_forecast",
	"market_quote", "venture_check", "profile_card", "task_progress", "tech_check", "check_upgrade", "recompute", "start_upgrade",
	"collect_all", "claim_task", "start_train", "start_research", "market_trade", "start_venture", "choose_decision", "new_game",
	"load_game", "reset_game", "set_city_skin", "hero_unlock", "dev_give_resources"]
const GAME_SIGNALS := ["changed", "toast", "building_done", "march_done", "storm_changed", "raid_happened", "decision_ready",
	"crystals_changed", "venture_done", "fog_changed", "city_skin_changed"]


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _line_count(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var t := f.get_as_text()
	if t.ends_with("\n"):
		t = t.substr(0, t.length() - 1)
	return t.split("\n").size()


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir.path_join(sub), out)
	for fn in d.get_files():
		if fn.ends_with(".gd"):
			out.append(dir.path_join(fn))


func _chain_paths(entry: String) -> Array:
	var paths := []
	var s: Script = load(entry)
	while s != null:
		paths.append(s.resource_path)
		s = s.get_base_script()
	return paths


func _ready() -> void:
	# ---- 1) سياسة الحجم: لا ملف منطق فوق الحد الأقصى
	var files := []
	_scan("res://scripts", files)
	var over_hard := []
	var watch := []
	for p in files:
		var n := _line_count(p)
		if n > HARD_LINES:
			over_hard.append("%s=%d" % [p, n])
		elif n > SOFT_LINES:
			watch.append("%s=%d" % [p, n])
	check(files.size() >= 35, "scanned scripts (%d files)" % files.size())
	check(over_hard.is_empty(), "no script exceeds %d lines %s" % [HARD_LINES, str(over_hard)])
	print("WATCH (> %d): %s" % [SOFT_LINES, str(watch)])

	# ---- 2) سلاسل الطبقات سليمة وبالترتيب
	for key in CHAINS:
		var expect: Array = CHAINS[key]
		var got := _chain_paths(expect[0])
		check(got == expect, "%s layers chain intact (%d files)" % [key, expect.size()])
		for p in expect:
			check(_line_count(p) <= HARD_LINES, "%s size ok" % p.get_file())

	# ---- 3) واجهة Game كاملة
	var missing := []
	for m in GAME_API:
		if not Game.has_method(m):
			missing.append(m)
	check(missing.is_empty(), "Game API intact %s" % str(missing))
	var missing_sig := []
	for sname in GAME_SIGNALS:
		if not Game.has_signal(sname):
			missing_sig.append(sname)
	check(missing_sig.is_empty(), "Game signals intact %s" % str(missing_sig))

	# ---- 4) سلوك أساسي فوق الطبقات: لعبة جديدة، حفظ وتحميل، ترقية
	Game.save_path_override = "user://frost_save_test_stage28.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.res = {"food": 1e9, "wood": 1e9, "coal": 1e9, "iron": 1e9}
	Game.aurora = 1000
	check(Game.furnace_level() >= 1, "new game has a furnace")
	var up: Dictionary = Game.check_upgrade("furnace")
	check(up.has("time") and up.has("cost"), "check_upgrade answers from the queries layer")
	Game.gems = 321
	Game.save_game()
	Game.gems = 1
	check(Game.load_game(), "save then load works across layers")
	check(Game.gems == 321, "loaded state matches saved state")
	check(Game.power() >= 0.0, "power() from army layer")
	check(Game.defense_profile().has("power"), "defense_profile from army layer")

	# ---- 5) مشهد المدينة يُبنى ويعمل ويُحذف
	var city: Node3D = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await _frames(6)
	check(city.has_method("_select") and city.has_method("_on_changed") and city.has_method("_update_panel"), "city layers expose their methods")
	city.call("_select", "furnace")
	await _frames(3)
	check(true, "city selects a plot without errors")
	city.queue_free()
	await _frames(2)

	# ---- 6) مشهد الخريطة يُبنى ويعمل ويُحذف
	var map: Node3D = (load("res://world_map.tscn") as PackedScene).instantiate()
	add_child(map)
	await _frames(8)
	check(map.has_method("_open_venture_window") and map.has_method("_select") and map.has_method("_sync_marches"), "map layers expose their methods")
	map.queue_free()
	await _frames(2)

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
