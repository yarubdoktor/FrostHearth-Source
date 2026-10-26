extends "res://scripts/game/state/state_actions.gd"
## حالة اللعبة الكاملة (Autoload باسم Game) — الطبقة 6/6 (الأعلى): دورة الحياة والحفظ والتحميل والترحيل.
## الإبقاء على هذا الملف هو نقطة الدخول (project.godot) — بقية المنطق في scripts/game/state/ بسلسلة extends: core ← army ← queries ← sim ← actions ← game_state.


func _ready() -> void:
	_rng.randomize()
	if not load_game():
		new_game()
	_check_daily()
	recompute()
	refresh_profile_achievements()
	changed.connect(refresh_profile_achievements)


# ================================================================ لعبة جديدة / حفظ / تحميل
func new_game() -> void:
	_ensure_profile()
	city_skin = CitySkins.DEFAULT
	res = {"food": 2500, "wood": 1800, "coal": 600, "iron": 0}
	gems = 200
	plots = {}
	for id in Defs.PLOTS:
		plots[id] = 0
	plots["furnace"] = 1
	stored = {}
	queue = []
	pop = 4
	sick = 0.0
	furnace_mode = 1
	stats = {"collected": {"food": 0, "wood": 0, "coal": 0, "iron": 0}, "marches": 0, "built": 0}
	task_index = 0
	last_daily = ""
	home = Vector2i(790, 842)
	marches = []
	_init_stage2({})
	vent = {"x": int(Defs.VENT["x"]), "y": int(Defs.VENT["y"]), "captured": false}
	venture = {}
	holds = {}
	explored = PackedByteArray()
	explored.resize(Defs.FOG_GRID * Defs.FOG_GRID)
	reveal_at(home.x + 0.5, home.y + 0.5, Defs.FOG_REVEAL_HOME)
	_scout_vision_lv = 0
	# أول جبهة بعد دورة كاملة (15 دقيقة إنذار مسبق) لا فورًا
	front_origin = now() + Defs.FRONT_PERIOD
	_schedule_storm(now() + 420.0)
	save_game()


func _init_stage2(d: Dictionary) -> void:
	Gear.restore(self, d)
	aurora = int(d.get("aurora", 0))
	trust = float(d.get("trust", 60.0))
	troops = {}
	wounded = {}
	for tp in Defs.TROOP_ORDER:
		for t in range(1, 5):
			var k := "%s_%d" % [tp, t]
			troops[k] = int(d.get("troops", {}).get(k, 0))
			wounded[k] = int(d.get("wounded", {}).get(k, 0))
	train = _migrate_train(d.get("train", {}))
	heroes = {}
	for id in Defs.HERO_ORDER:
		var h: Dictionary = d.get("heroes", {}).get(id, {})
		heroes[id] = {"lv": int(h.get("lv", 1)), "stars": int(h.get("stars", 0)), "shards": int(h.get("shards", 0)),
				"owned": bool(h.get("owned", false))}
	defender = str(d.get("defender", ""))
	governor = str(d.get("governor", ""))
	techs = {}
	for id in Defs.TECHS:
		techs[id] = int(d.get("techs", {}).get(id, 0))
	research = d.get("research", {})
	crystals = d.get("crystals", [])
	raid_next = float(d.get("raid_next", 0.0))
	market_window_start = float(d.get("market_window_start", 0.0))
	if d.is_empty():
		_ensure_profile()   # لعبة جديدة: تبقى هوية اللاعب كما هي
	else:
		profile = Profile.sanitize(d.get("profile", {}), Time.get_unix_time_from_system())
	market_used = float(d.get("market_used", 0.0))
	raid_count = int(d.get("raid_count", 0))
	raid_wins = int(d.get("raid_wins", 0))
	last_raid = d.get("last_raid", {})
	raid_unseen = false
	decision_next = float(d.get("decision_next", now() + 240.0))
	pending_decision = int(d.get("pending_decision", -1))
	task2_index = int(d.get("task2_index", 0))
	for k in ["trained", "aurora", "decisions", "research"]:
		if not stats.has(k):
			stats[k] = 0
	# المرحلة 3: المنفث والجبهة (توافق مع الحفظ القديم)
	vent = d.get("vent", {})
	if vent.is_empty():
		vent = {"x": int(Defs.VENT["x"]), "y": int(Defs.VENT["y"]), "captured": false}
	venture = d.get("venture", {})
	if not venture.is_empty():
		# توافق الحفظ القديم: غياب الهدف يعني المنفث، وغياب التشكيل يعني «متوازنة»
		if not venture.has("target"):
			venture["target"] = {"kind": "vent"}
		if not venture.has("formation"):
			venture["formation"] = "balanced"
	front_origin = float(d.get("front_origin", 0.0))
	if front_origin <= 0.0:
		# حفظ قديم: أول جبهة بعد دورة كاملة، ولا تُطبق الجبهة على زمن الغياب السابق
		front_origin = now() + Defs.FRONT_PERIOD
	dev_mode = bool(d.get("dev_mode", false))
	# تعميق الخريطة: المعاقل المحتلة وشبكة الكشف (توافق مع الحفظ القديم)
	holds = d.get("holds", {})
	var eb := str(d.get("explored", ""))
	explored = PackedByteArray()
	if eb != "":
		explored = Marshalls.base64_to_raw(eb)
	if explored.size() != Defs.FOG_GRID * Defs.FOG_GRID:
		# حفظ قديم بلا ضباب: تُكشف منطقة المدينة فقط ويبقى الباقي مجهولًا
		explored = PackedByteArray()
		explored.resize(Defs.FOG_GRID * Defs.FOG_GRID)
		reveal_at(home.x + 0.5, home.y + 0.5, Defs.FOG_REVEAL_HOME)
	_scout_vision_lv = 0


func _migrate_train(old: Dictionary) -> Dictionary:
	## الحفظ القديم: طابور واحد {key,n,start,end} ← طابور لكل نوع جنود
	if old.has("key"):
		var tp := String(old["key"]).split("_")[0]
		return {tp: old}
	var out := {}
	for tp in old:
		if Defs.TROOPS.has(tp) and typeof(old[tp]) == TYPE_DICTIONARY and not (old[tp] as Dictionary).is_empty():
			out[tp] = old[tp]
	return out


func _migrate_v4(d: Dictionary) -> void:
	## ترحيل حفظ أقدم من 5: إلغاء المآوي الزائدة (تُعاد تكلفتها) ومنح الثكنات الجديدة بمستوى المعسكر القديم
	var refund := {}
	var plots_old: Dictionary = d["plots"]
	var note := {}
	for id in Defs.REMOVED_PLOTS:
		var lv := int(plots_old.get(id, 0))
		if lv <= 0:
			continue
		for l in range(1, lv + 1):
			var c := Defs.cost(str(Defs.REMOVED_PLOTS[id]), l)
			for r in c:
				refund[r] = float(refund.get(r, 0.0)) + float(c[r])
		note["shelters_removed"] = int(note.get("shelters_removed", 0)) + 1
	var q_new: Array = []
	for q in d["queue"]:
		if Defs.PLOTS.has(str(q["plot"])):
			q_new.append(q)
		elif Defs.REMOVED_PLOTS.has(str(q["plot"])):
			var c2 := Defs.cost(str(Defs.REMOVED_PLOTS[q["plot"]]), int(q["level"]))
			for r in c2:
				refund[r] = float(refund.get(r, 0.0)) + float(c2[r])
	d["queue"] = q_new
	for r in refund:
		d["res"][r] = float(d["res"].get(r, 0.0)) + float(refund[r])
	if not refund.is_empty():
		note["refund"] = refund
	var camp_lv := int(plots_old.get("ba1", 0))
	if camp_lv > 0:
		for tp in Defs.TROOP_ORDER:
			var pid: String = Defs.BARRACKS_PLOT[tp]
			if int(plots_old.get(pid, 0)) <= 0:
				plots_old[pid] = camp_lv
		note["barracks_granted"] = camp_lv
	migration_note = note


func set_city_skin(id: String) -> bool:
	if not CitySkins.DEFINITIONS.has(id):
		return false
	city_skin = id
	save_game()
	city_skin_changed.emit(city_skin)
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(_save_path()):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) < 1 or int(d.get("v", 0)) > SAVE_VERSION:
		return false
	migration_note = {}
	if int(d.get("v", 0)) < 5:
		_migrate_v4(d)
	res = d["res"]
	for r in Defs.RES:
		res[r] = float(res.get(r, 0))
	gems = int(d["gems"])
	plots = {}
	for id in Defs.PLOTS:
		plots[id] = int(d["plots"].get(id, 0))
	stored = d["stored"]
	queue = d["queue"]
	for q in queue:
		q["level"] = int(q["level"])
	pop = int(d["pop"])
	sick = float(d["sick"])
	furnace_mode = int(d["furnace_mode"])
	stats = d["stats"]
	task_index = int(d["task_index"])
	last_daily = str(d["last_daily"])
	home = Vector2i(int(d["home"][0]), int(d["home"][1]))
	marches = d["marches"]
	storm_start = float(d["storm"][0])
	storm_end = float(d["storm"][1])
	quality_high = bool(d.get("quality_high", true))
	city_skin = CitySkins.valid_id(str(d.get("city_skin", CitySkins.DEFAULT)))
	_init_stage2(d)
	# التقدم أثناء الغياب
	var t0 := float(d["time"])
	var elapsed := clampf(now() - t0, 0.0, offline_cap())
	if elapsed > 60.0:
		var before := {}
		for id in stored:
			before[id] = float(stored[id])
		var built_before := queue.size()
		var pop_before := pop
		var t := t0
		var step := 30.0
		_offline = true
		while t < t0 + elapsed:
			var dt := minf(step, t0 + elapsed - t)
			t += dt
			_simulate(dt, t)
		_offline = false
		var gained := {"food": 0.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
		for id in stored:
			var tp: String = Defs.PLOTS[id]["type"]
			if Defs.BUILDINGS[tp].has("prod"):
				gained[Defs.BUILDINGS[tp]["prod"]] += float(stored[id]) - float(before.get(id, 0.0))
		offline_report = {"elapsed": elapsed, "gained": gained, "built": built_before - queue.size(),
				"pop": pop - pop_before}
	# Settle absolute job deadlines even for an absence shorter than 60 seconds,
	# after chronological offline simulation so bonuses cannot apply early.
	Gear.tick(self, now())
	# الذئاب لا تهاجم وأنت غائب: تتأجل الغارة إلى ما بعد عودتك
	if raid_next > 0.0 and raid_next < now() + 180.0:
		raid_next = now() + 240.0
	refresh_profile_achievements()
	return true


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path()))
	new_game()
	recompute()
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()
