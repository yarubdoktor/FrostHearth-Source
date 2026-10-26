extends "res://scripts/game/state/state_sim.gd"
## الطبقة 5/6 — الأفعال: كل ما يغيّر الحالة بأمر اللاعب (بناء، تدريب، بحث، تجهيزات، سوق، مسيرات).


func start_gear(tp: String, slot: String) -> bool:
	return Gear.start(self, tp, slot)


func cancel_gear(tp: String, slot: String) -> bool:
	return Gear.cancel(self, tp, slot)


func speedup_gear(tp: String, slot: String) -> bool:
	return Gear.speedup(self, tp, slot)


func try_dev_mode(pw: String) -> bool:
	return DevTools.try_dev_mode(self, pw)


func dev_give_resources() -> void:
	DevTools.dev_give_resources(self)


func dev_give_premium() -> void:
	DevTools.dev_give_premium(self)


func dev_add_pop(n: int) -> void:
	DevTools.dev_add_pop(self, n)


func dev_finish_all() -> void:
	DevTools.dev_finish_all(self)


func dev_heal_all() -> void:
	DevTools.dev_heal_all(self)


func dev_reveal_map() -> void:
	DevTools.dev_reveal_map(self)


func collect(id: String) -> float:
	var v := floorf(float(stored.get(id, 0.0)))
	if v < 1.0:
		return 0.0
	var tp: String = Defs.PLOTS[id]["type"]
	var r: String = Defs.BUILDINGS[tp]["prod"]
	res[r] += v
	stored[id] = float(stored[id]) - v
	stats["collected"][r] = float(stats["collected"].get(r, 0)) + v
	changed.emit()
	return v


func collect_all() -> Dictionary:
	var out := {}
	for id in stored:
		var tp: String = Defs.PLOTS[id]["type"]
		var r: String = Defs.BUILDINGS[tp]["prod"]
		var v := collect(id)
		if v > 0:
			out[r] = float(out.get(r, 0.0)) + v
	return out


func start_upgrade(id: String, instant: bool = false) -> bool:
	var chk := check_upgrade(id)
	if not chk["reasons"].is_empty() or not chk["missing"].is_empty():
		return false
	if not instant and not chk["builders_free"]:
		toast.emit("كل البنائين مشغولون")
		return false
	if instant:
		var g := gems_for_time(chk["time"])
		if not dev_mode:
			if gems < g:
				toast.emit("الجواهر غير كافية")
				return false
			gems -= g
	if not dev_mode:
		for r in chk["cost"]:
			res[r] -= chk["cost"][r]
	var t := now()
	queue.append({"plot": id, "level": chk["next"], "start": t, "end": t + (0.0 if instant else chk["time"])})
	if instant:
		_finish(queue.size() - 1)
	recompute()
	changed.emit()
	save_game()
	return true


func speedup(id: String) -> bool:
	var q := queue_entry(id)
	if q.is_empty():
		return false
	var remain := float(q["end"]) - now()
	var g := gems_for_time(remain)
	if not dev_mode:
		if gems < g:
			toast.emit("الجواهر غير كافية")
			return false
		gems -= g
	q["end"] = now()
	_simulate(0.0, now())
	changed.emit()
	save_game()
	return true


func cancel(id: String) -> void:
	for i in queue.size():
		if queue[i]["plot"] == id:
			var tp: String = Defs.PLOTS[id]["type"]
			var c := Defs.cost(tp, int(queue[i]["level"]))
			for r in c:
				res[r] += c[r]
			queue.remove_at(i)
			toast.emit("تم إلغاء البناء واسترجاع الموارد")
			changed.emit()
			return


func set_furnace_mode(m: int) -> void:
	furnace_mode = m
	recompute()
	changed.emit()


func claim_task() -> bool:
	var tk := current_task()
	if tk.is_empty() or not task_done(tk):
		return false
	give(tk["reward"])
	task_index += 1
	toast.emit("تم استلام مكافأة المهمة")
	save_game()
	return true


func claim_task2() -> bool:
	var tk := current_task2()
	if tk.is_empty() or not task_done(tk):
		return false
	give(tk["reward"])
	task2_index += 1
	toast.emit("تم استلام مكافأة مهمة الفصل الثاني")
	save_game()
	return true


func _check_daily() -> void:
	daily_ready = last_daily != _today()


func claim_daily() -> void:
	if not daily_ready:
		return
	give(daily_reward())
	last_daily = _today()
	daily_ready = false
	save_game()


func start_march(target: Dictionary) -> bool:
	if marches.size() >= MAX_MARCHES:
		toast.emit("كل الفرق في مهمة — انتظر عودة إحداها")
		return false
	var from := Vector2(home.x + 0.5, home.y + 0.5)
	var to := Vector2(float(target["x"]) + 0.5, float(target["y"]) + 0.5)
	var travel := clampf(from.distance_to(to) / march_speed(), 4.0, 180.0)
	var work := 0.0
	match target["kind"]:
		"res":
			work = 12.0 + 2.0 * float(target["l"])
		"beast":
			work = 3.0
		"lm", "city":
			work = 5.0
		"scout":
			work = 0.0   # فرقة استطلاع: تكشف عند الوصول ثم تعود مباشرة
	var t := now()
	var m := {"kind": target["kind"], "t": target.get("t", ""), "l": int(target.get("l", 1)),
			"name": str(target.get("n", "")), "fx": from.x, "fy": from.y, "tx": to.x, "ty": to.y,
			"start": t, "arrive": t + travel, "leave": t + travel + work, "back": t + travel * 2 + work}
	marches.append(m)
	stats["marches"] = int(stats.get("marches", 0)) + 1
	changed.emit()
	save_game()
	return true


func set_profile_name(raw: String) -> bool:
	_ensure_profile()
	var chk := Profile.check_name(raw)
	if not chk["ok"]:
		toast.emit(String(chk["reason"]))
		return false
	profile["name"] = chk["name"]
	changed.emit()
	save_game()
	return true


func set_profile_decoration(kind: String, id: String) -> bool:
	refresh_profile_achievements()
	if not kind in ["title", "frame"]:
		return false
	if id != "" and (not Achievements.DEFS.has(id) or not profile["badges"].has(id)):
		toast.emit("أكمل الإنجاز أولًا لفتح هذا التخصيص")
		return false
	profile[kind] = id
	save_game()
	changed.emit()
	return true


func set_profile_avatar(id: String) -> bool:
	## "" = تلقائي (قائد الدفاع ثم الحاكم)، وإلا بطل مملوك فقط
	_ensure_profile()
	if id != "" and not (heroes.has(id) and heroes[id]["owned"]):
		toast.emit("هذا البطل غير مملوك بعد")
		return false
	profile["avatar"] = id
	changed.emit()
	save_game()
	return true


func market_trade(sell: String, buy: String, amount: int) -> bool:
	## بيع amount من المورد sell لشراء المورد buy بسعر السوق الحالي
	if market_level() <= 0:
		toast.emit("ابنِ السوق أولًا")
		return false
	if not (sell in Defs.RES) or not (buy in Defs.RES) or sell == buy:
		toast.emit("اختر موردين مختلفين")
		return false
	if amount <= 0:
		toast.emit("حدّد كمية للتبادل")
		return false
	if float(res[sell]) < amount:
		toast.emit("لا تملك هذه الكمية من %s" % Defs.RES_NAMES[sell])
		return false
	if amount > market_quota_left() and not dev_mode:
		toast.emit("تجاوزت حصة التبادل — تتجدد بعد %s" % Defs.fmt_time(market_reset_in()))
		return false
	var got := market_quote(sell, buy, amount)
	if got <= 0:
		toast.emit("الكمية أصغر من أن تُبادَل")
		return false
	res[sell] = float(res[sell]) - float(amount)
	res[buy] = float(res[buy]) + float(got)
	market_used += float(amount)
	stats["traded"] = int(stats.get("traded", 0)) + amount
	changed.emit()
	save_game()
	return true


func start_venture(units: Dictionary, formation := "balanced", target := {}) -> bool:
	## إرسال فرقة عسكرية لاحتلال المنفث أو معلم قابل للاحتلال — الجنود تُحجز فورًا والمعركة عند الوصول
	## الهدف يُستخرج من بيانات الخريطة، وغيابه يعني المنفث (توافق مع النداءات والحفظ القديم)
	var tgt: Dictionary = target.duplicate() if not target.is_empty() else {"kind": "vent"}
	var lm := {}
	if str(tgt.get("kind", "vent")) == "hold":
		lm = _find_landmark(str(tgt.get("id", "")))
		if lm.is_empty():
			toast.emit("هدف غير معروف")
			return false
		if holds.has(str(tgt["id"])):
			toast.emit("هذا الموقع تحت سيطرتك أصلًا")
			return false
	elif vent.get("captured", false):
		toast.emit("المنفث تحت سيطرتك أصلًا")
		return false
	if not venture.is_empty():
		toast.emit("الفرقة العسكرية في مهمة بالفعل")
		return false
	var take := {}
	for k in units:
		var n := int(units[k])
		if n > 0:
			take[k] = n
	if take.is_empty():
		toast.emit("اختر جنودًا لإرسالهم أولًا")
		return false
	for k in take:
		if int(troops.get(k, 0)) < int(take[k]):
			toast.emit("عدد الجنود المتاح أقل من المطلوب")
			return false
	var vchk := venture_check(take)
	if not vchk["ok"]:
		toast.emit(String(vchk["reason"]))
		return false
	var from := Vector2(home.x + 0.5, home.y + 0.5)
	var to := Vector2(float(vent["x"]) + 0.5, float(vent["y"]) + 0.5)
	var fight_work := float(Defs.VENT_FIGHT_WORK)
	if not lm.is_empty():
		to = Vector2(float(lm["x"]), float(lm["y"]))
		tgt["type"] = str(lm["type"])
	var travel := clampf(from.distance_to(to) / march_speed(), 8.0, 300.0)
	var t := now()
	var fdef: Dictionary = Defs.FORMATIONS.get(formation, Defs.FORMATIONS["balanced"])
	# ظروف المعركة تُثبّت عند الإرسال (التعديلات، القائد، قوة الحرّاس، التشكيل) — لا تتغير أثناء السفر
	venture = {"units": take, "fx": from.x, "fy": from.y, "tx": to.x, "ty": to.y,
		"start": t, "arrive": t + travel, "leave": t + travel + fight_work,
		"back": t + travel * 2.0 + fight_work,
		"resolved": false, "survivors": {}, "losses": {},
		"dead_factor": float(fdef["dead"]) * (0.5 if defender == "layla" else 1.0),
		"mods": army_mods(defender), "guards_f": maxi(furnace_level(), 1),
		"target": tgt, "formation": String(formation),
		"won": false, "report": {}, "supplies": 0 if dev_mode else int(vchk["cost"])}
	if not dev_mode:
		res["food"] = float(res["food"]) - float(vchk["cost"])
	for k in take:
		troops[k] = int(troops[k]) - int(take[k])
	changed.emit()
	save_game()
	return true


func collect_crystal(i: int) -> int:
	if i < 0 or i >= crystals.size():
		return 0
	var v := int(round(float(crystals[i]["v"]) * (1.0 + bonus("aurora_gain"))))
	crystals.remove_at(i)
	aurora += v
	stats["aurora"] = int(stats.get("aurora", 0)) + v
	crystals_changed.emit()
	changed.emit()
	return v


func start_train(tp: String, tier: int, n: int) -> bool:
	var chk := train_check(tp, tier, n)
	if not chk["ok"]:
		return false
	if not dev_mode:
		for r in chk["cost"]:
			res[r] -= chk["cost"][r]
	var t := now()
	train[tp] = {"key": "%s_%d" % [tp, tier], "n": n, "start": t, "end": t + float(chk["time"])}
	changed.emit()
	save_game()
	return true


func speedup_train(tp: String = "") -> bool:
	tp = _train_tp(tp)
	if tp == "" or not train.has(tp):
		return false
	var g := gems_for_time(float(train[tp]["end"]) - now())
	if not dev_mode:
		if gems < g:
			toast.emit("الجواهر غير كافية")
			return false
		gems -= g
	train[tp]["end"] = now()
	_simulate(0.0, now())
	changed.emit()
	save_game()
	return true


func cancel_train(tp: String = "") -> void:
	tp = _train_tp(tp)
	if tp == "" or not train.has(tp):
		return
	var parts: PackedStringArray = String(train[tp]["key"]).split("_")
	var c := Defs.troop_cost(parts[0], int(parts[1]), int(train[tp]["n"]))
	for r in c:
		res[r] += c[r]
	train.erase(tp)
	toast.emit("تم إلغاء التدريب واسترجاع الموارد")
	changed.emit()


func start_research(id: String) -> bool:
	var chk := tech_check(id)
	if not chk["ok"]:
		return false
	if not dev_mode:
		for r in chk["cost"]:
			if r == "aurora":
				aurora -= int(chk["cost"][r])
			else:
				res[r] -= chk["cost"][r]
	var t := now()
	research = {"id": id, "lv": chk["next"], "start": t, "end": t + float(chk["time"])}
	changed.emit()
	save_game()
	return true


func speedup_research() -> bool:
	if research.is_empty():
		return false
	var g := gems_for_time(float(research["end"]) - now())
	if not dev_mode:
		if gems < g:
			toast.emit("الجواهر غير كافية")
			return false
		gems -= g
	research["end"] = now()
	_simulate(0.0, now())
	changed.emit()
	save_game()
	return true


func hero_unlock(id: String) -> bool:
	return HeroMgr.hero_unlock(self, id)


func hero_summon(id: String) -> bool:
	return HeroMgr.hero_summon(self, id)


func hero_level_check(id: String) -> Dictionary:
	return HeroMgr.hero_level_check(self, id)


func hero_level_up(id: String) -> bool:
	return HeroMgr.hero_level_up(self, id)


func hero_star_up(id: String) -> bool:
	return HeroMgr.hero_star_up(self, id)


func set_role(id: String, role: String) -> void:
	HeroMgr.set_role(self, id, role)


func choose_decision(which: String) -> void:
	if pending_decision < 0:
		return
	var dd: Dictionary = Defs.DECISIONS[pending_decision]
	var opt: Dictionary = dd[which]
	if not decision_option_ok(opt):
		toast.emit("لا تملك ما يكفي لهذا الخيار")
		return
	for k in opt["eff"]:
		var v := float(opt["eff"][k])
		match k:
			"trust":
				trust = clampf(trust + v, 0.0, 100.0)
			"pop":
				pop = maxi(pop + int(v), 1)
			"sick":
				sick = clampf(sick + v, 0.0, float(pop))
			"aurora":
				aurora = maxi(aurora + int(v), 0)
			"gems":
				gems += int(v)
			"troop_bonus":
				troops["shield_1"] = int(troops["shield_1"]) + int(v / 2)
				troops["spear_1"] = int(troops["spear_1"]) + int(v) - int(v / 2)
			_:
				res[k] = maxf(float(res[k]) + v, 0.0)
	stats["decisions"] = int(stats.get("decisions", 0)) + 1
	pending_decision = -1
	decision_next = now() + randf_range(360.0, 600.0)
	recompute()
	changed.emit()
	save_game()
