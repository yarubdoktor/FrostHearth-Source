extends Node
## Remaining small tasks in one bundle: gear art, completion highlights, map timers.
const Art := preload("res://scripts/ui/gear_art.gd")
const Rules := preload("res://scripts/game/gear_defs.gd")
const Timers := preload("res://scripts/ui/march_timers.gd")
const Defs := preload("res://scripts/defs.gd")
const Workshop := preload("res://scripts/ui/windows/workshop_window.gd")
var checks := 0
var failures := 0
var events: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)


func frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame


func fresh() -> void:
	Game.save_path_override = "user://stage31_quick.json"
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}


func capture(suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture=") + suffix + ".png")


func test_art(city: Node) -> void:
	check(Art.TEXTURES.size() == 12, "twelve gear-specific assets are registered")
	var hashes: Array = []
	for tp in Rules.TYPES:
		Workshop.show(city, tp)
		await frames()
		for slot in Rules.SLOTS:
			var key: String = tp + "_" + slot
			var texture: Texture2D = Art.TEXTURES[key]
			check(texture.get_width() == 128 and texture.get_height() == 128, "vector icon imports at 128 square: " + key)
			var hash_value := texture.get_image().get_data().hex_encode().sha256_text()
			check(not hashes.has(hash_value), "icon artwork is unique: " + key)
			hashes.append(hash_value)
			var icon := city.win_dim.find_child("GearIcon_" + key, true, false) as TextureRect
			check(icon != null and icon.texture == texture and icon.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"piece card uses correct nonblocking icon: " + key)
			check(icon.custom_minimum_size == Vector2(64, 64) and icon.get_global_rect().end.x <= 721,
				"icon fits portrait card: " + key)
		if tp == "bow":
			await capture("-workshop")
	var before: Dictionary = Game.res.duplicate(true)
	var power: float = Game.power()
	Workshop.show(city, "shield")
	await frames()
	check(Game.res == before and is_equal_approx(Game.power(), power), "viewing all gear art never changes economy or power")
	city._close_window()


func test_completion(city: Node) -> void:
	var fx: Control = city.timer_layer.get_node("CompletionFlashes")
	fx.set_process(false)
	check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx.active.is_empty(), "completion layer starts empty and passes input")
	Game.work_completed.connect(_record)
	var t := Game.now()
	Game.queue.append({"plot": "sh1", "level": 1, "start": t - 20, "end": t - 1})
	Game.train["shield"] = {"key": "shield_1", "n": 2, "start": t - 20, "end": t - 1}
	Game.research = {"id": str(Defs.TECHS.keys()[0]), "lv": 1, "start": t - 20, "end": t - 1}
	Game.gear_queue.append({"tp": "shield", "slot": "weapon", "lv": 1, "start": t - 20, "end": t - 1, "paid": {}})
	Game._simulate(0, t)
	check(events.size() == 4, "actual building training research and crafting each emit one completion")
	check(events.has(["build", "sh1"]) and events.has(["train", "bs1"]) and events.has(["research", "lb1"]) and events.has(["gear", "wk1"]),
		"completion signals identify correct buildings and work kinds")
	check(fx.active.size() == 4, "all four completed jobs create bounded building highlights")
	check(Game.train.is_empty() and Game.research.is_empty() and Game.queue.is_empty() and Game.gear_queue.is_empty(),
		"notifications do not interfere with job completion")
	Game._simulate(0, t + 1)
	Game.changed.emit()
	Game.changed.emit()
	check(events.size() == 4 and fx.active.size() == 4, "ordinary ticks do not replay completion events")
	for item in fx.active.values():
		check((item["panel"] as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "completion panel cannot steal map taps")
	fx._process(1.9)
	check(fx.active.size() == 4 and (fx.active["sh1"]["panel"] as Control).modulate.a < 1, "highlight fades rather than loops or strobes")
	await capture("-completion")
	fx._process(0.6)
	await frames()
	check(fx.active.is_empty() and fx.get_child_count() == 0, "highlight nodes are freed when duration ends")
	Game.notify_work_completed("train", "bs1")
	Game.notify_work_completed("build", "bs1")
	check(fx.active.size() == 1 and fx.active["bs1"]["kinds"].size() == 2, "simultaneous jobs on one building merge without duplicate panels")
	fx._process(3)
	await frames()
	var count := events.size()
	Game.queue.append({"plot": "sh2", "level": 1, "start": t, "end": t + 100})
	Game.cancel("sh2")
	Game.train["spear"] = {"key": "spear_1", "n": 2, "start": t, "end": t + 100, "paid": {}}
	Game.cancel_train("spear")
	check(events.size() == count and fx.active.is_empty(), "canceled construction and training never flash completion")
	Game._offline = true
	Game.queue.append({"plot": "sh2", "level": 1, "start": t - 20, "end": t - 1})
	Game.train["bow"] = {"key": "bow_1", "n": 1, "start": t - 20, "end": t - 1}
	Game._simulate(0, t)
	Game._offline = false
	check(events.size() == count and fx.active.is_empty(), "offline completions do not replay visual alerts")
	city._show_workshop()
	city._close_window()
	check(fx.active.is_empty(), "opening a window does not replay old alerts")
	Game.work_completed.disconnect(_record)


func _record(kind: String, id: String) -> void:
	events.append([kind, id])


func test_phases() -> void:
	var m := {"kind": "res", "start": 100.0, "arrive": 120.0, "leave": 150.0, "back": 170.0}
	for pair in [[110, "وصول", 10], [120, "جمع", 30], [140, "جمع", 10], [150, "عودة", 20], [169, "عودة", 1]]:
		var p := Timers.phase(m, pair[0])
		check(p["caption"] == pair[1] and p["remaining"] == pair[2] and p["progress"] >= 0 and p["progress"] <= 1,
			"phase uses correct scheduled boundary at %d" % pair[0])
	check(Timers.phase(m, 170).is_empty() and Timers.phase(m, 180).is_empty(), "returned march has no stale negative timer")
	m["leave"] = m["arrive"]
	check(Timers.phase(m, 120)["caption"] == "عودة", "zero-length task switches immediately to return")
	m["kind"] = "scout"
	m["leave"] = 150
	check(Timers.phase(m, 130)["caption"] == "مهمة", "scout uses mission caption rather than resource gathering")
	check(Timers.phase({}, 1).is_empty(), "empty expired data does not divide by zero")


func test_map() -> void:
	fresh()
	var t := Game.now()
	var x := float(Game.home.x) + 0.5
	var z := float(Game.home.y) + 0.5
	var first := {"kind": "res", "t": "wood", "l": 1, "start": t - 10, "arrive": t + 100,
		"leave": t + 200, "back": t + 310, "fx": x, "fy": z, "tx": x + 15, "ty": z + 8}
	var second: Dictionary = first.duplicate(true)
	second["start"] = t - 9
	second["kind"] = "scout"
	Game.marches = [first, second]
	var world: Node = load("res://world_map.tscn").instantiate()
	add_child(world)
	await frames()
	var timers: Control = world.ui.get_node("MarchTimers")
	world.rig.set_view(Vector3(x + 3, 0, z + 2), 45)
	await frames()
	check(timers.widgets.size() == 2 and world.march_vis.size() == 2, "world creates one timer for each actual march")
	var item: Dictionary = timers.widgets[str(first["start"])]
	check((item["label"] as Label).text.contains("وصول") and (item["panel"] as Control).visible, "outbound timer appears above visible squad")
	check((item["panel"] as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "march timer does not intercept map gestures")
	var a: Rect2 = item["panel"].get_global_rect()
	var b: Rect2 = timers.widgets[str(second["start"])]["panel"].get_global_rect()
	check(not a.intersects(b), "nearby squads have separated timer panels")
	first["arrive"] = t - 1
	first["leave"] = t + 200
	Game.marches[0] = first
	await frames()
	check((item["label"] as Label).text.contains("جمع"), "timer updates to collection phase without rebuilding world")
	first["leave"] = t - 0.5
	Game.marches[0] = first
	await frames()
	check((item["label"] as Label).text.contains("عودة"), "timer updates to return phase")
	Game.venture = first.duplicate(true)
	Game.venture["kind"] = "vent"
	Game.venture["start"] = t - 12
	Game.venture["arrive"] = t + 100
	Game.venture["leave"] = t + 100
	await frames()
	check(timers.widgets.has("venture"), "military expedition also has a timer")
	await capture("-map")
	var snapshot: String = JSON.stringify(Game.marches)
	var venture: String = JSON.stringify(Game.venture)
	timers._process(0.1)
	check(snapshot == JSON.stringify(Game.marches) and venture == JSON.stringify(Game.venture), "timers only read march data")
	first["back"] = t - 1
	Game.marches[0] = first
	Game.venture = {}
	await frames()
	check(timers.widgets.size() == 1, "finished and removed missions lose their timers immediately")
	Game.marches.clear()
	await frames()
	check(timers.widgets.is_empty() and timers.get_child_count() == 0, "all timer controls are freed on return")
	world.queue_free()
	await frames()


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	fresh()
	var city: Node = load("res://city.tscn").instantiate()
	add_child(city)
	await frames()
	await test_art(city)
	await test_completion(city)
	city.queue_free()
	await frames()
	test_phases()
	await test_map()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
