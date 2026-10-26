extends "res://scripts/game/state/state_queries.gd"
## الطبقة 4/6 — المحاكاة: حلقة الزمن (recompute/_simulate)، الغارات، الغنائم، نتائج المسيرات، البلورات.


func recompute(t: float = -1.0) -> void:
	if t < 0:
		t = now()
	outside_temp = _outside(t)
	_apply_scout_vision()
	var heat := 0.0
	if furnace_mode > 0 and res["coal"] > 0.0:
		heat = Defs.furnace_heat(furnace_level()) + (10.0 if furnace_mode == 2 else 0.0) + bonus("heat")
	if vent.get("captured", false):
		heat += Defs.VENT_HEAT
	inside_temp = outside_temp + heat
	cold_level = 0 if inside_temp >= -5.0 else (1 if inside_temp >= -15.0 else 2)
	hungry = res["food"] <= 0.0
	# توزيع العمال: الأولوية للطعام ثم الفحم ثم الخشب ثم الحديد ثم المستوصف
	workers = {}
	var avail := healthy()
	for tp in ["hunter", "coal_mine", "sawmill", "iron_mine", "infirmary"]:
		for id in Defs.PLOTS:
			if Defs.PLOTS[id]["type"] != tp or level(id) <= 0:
				continue
			var need := Defs.workers_needed(tp, level(id))
			var w := mini(need, avail)
			workers[id] = w
			avail -= w


func _simulate(dt: float, t: float) -> void:
	Gear.tick(self, t)
	recompute(t)
	var h := dt / 3600.0
	# إنتاج المباني (يُخزّن داخلها حتى تجمعه)
	for id in Defs.PLOTS:
		var tp: String = Defs.PLOTS[id]["type"]
		if not Defs.BUILDINGS[tp].has("prod") or level(id) <= 0:
			continue
		var s := float(stored.get(id, 0.0)) + current_rate(id) * h
		stored[id] = minf(s, storage_cap(id))
	# الاستهلاك
	res["food"] = maxf(res["food"] - food_use() * h, 0.0)
	res["coal"] = maxf(res["coal"] - coal_use() * h, 0.0)
	# المرض والشفاء
	var mins := dt / 60.0
	var rate: float = ([0.0, 0.02, 0.06][cold_level] + (0.03 if hungry else 0.0)) * (1.0 - bonus("sick_res"))
	sick = minf(sick + healthy() * rate * mins, float(pop))
	if cold_level < 2:
		var heal := 0.25
		for id in Defs.PLOTS:
			if Defs.PLOTS[id]["type"] == "infirmary" and level(id) > 0:
				heal += 0.6 * level(id) * efficiency(id)
		sick = maxf(sick - heal * (1.0 + bonus("heal")) * mins, 0.0)
	_simulate_stage2(dt, t)
	# وصول ناجين جدد
	if pop < pop_capacity() and cold_level < 2 and not hungry:
		_grow_acc += dt
		while _grow_acc >= 15.0 and pop < pop_capacity():
			_grow_acc -= 15.0
			pop += 1
	else:
		_grow_acc = 0.0
	# طابور البناء
	for i in range(queue.size() - 1, -1, -1):
		var q: Dictionary = queue[i]
		if float(q["end"]) <= t:
			_finish(i)
	# العاصفة
	if t >= storm_end:
		_schedule_storm(t + 480.0)
	# ضباب الحرب: الفرق تكشف ممرها أثناء الحركة، والاستطلاع يكشف عند الوصول
	for m in marches:
		_reveal_march_path(m, t - dt, t, Defs.FOG_REVEAL_MARCH)
		if str(m.get("kind", "")) == "scout" and not bool(m.get("revealed", false)) and t >= float(m["arrive"]):
			reveal_at(float(m["tx"]), float(m["ty"]), Defs.FOG_REVEAL_SCOUT)
			m["revealed"] = true
	if not venture.is_empty():
		_reveal_march_path(venture, t - dt, t, Defs.FOG_REVEAL_MARCH)
		if t >= float(venture["arrive"]):
			reveal_at(float(venture["tx"]), float(venture["ty"]), Defs.FOG_REVEAL_MARCH + 6.0)
	# المسيرات
	for i in range(marches.size() - 1, -1, -1):
		var m: Dictionary = marches[i]
		if float(m["back"]) <= t:
			_march_reward(m)
			marches.remove_at(i)
	# المرحلة 3: المسيرة العسكرية — المعركة بتوقيت الوصول المجدول والعودة بعدها
	if not venture.is_empty():
		if not bool(venture.get("resolved", false)) and t >= float(venture["arrive"]):
			_resolve_venture_battle(float(venture["arrive"]))
		if float(venture["back"]) <= t:
			_return_venture()


func _finish(i: int) -> void:
	var q: Dictionary = queue[i]
	var id: String = q["plot"]
	plots[id] = int(q["level"])
	queue.remove_at(i)
	stats["built"] = int(stats.get("built", 0)) + 1
	building_done.emit(id)
	notify_work_completed("build", id)
	var tp: String = Defs.PLOTS[id]["type"]
	toast.emit("اكتمل: %s — المستوى %d" % [Defs.BUILDINGS[tp]["name"], plots[id]])


func _process(delta: float) -> void:
	_tick_acc += delta
	_save_acc += delta
	if _tick_acc >= 0.5:
		var was_storm := storm_active(now() - _tick_acc)
		_simulate(_tick_acc, now())
		_tick_acc = 0.0
		if storm_active() != was_storm:
			storm_changed.emit(storm_active())
			toast.emit("عاصفة ثلجية تضرب المدينة — شغّل الفرن بالوضع المضاعف" if storm_active() else "انتهت العاصفة الثلجية")
		changed.emit()
	if _save_acc >= 15.0:
		_save_acc = 0.0
		save_game()


func _march_reward(m: Dictionary) -> void:
	var reward := {}
	var lv := int(m["l"])
	match m["kind"]:
		"res":
			var amount := {"food": 4500, "wood": 3200, "coal": 1800, "iron": 600}
			reward[m["t"]] = amount[m["t"]] * lv
		"beast":
			reward = {"food": 2000 * lv, "wood": 800 * lv, "gems": 2 + lv / 3}
		"scout":
			toast.emit("اكتمل استطلاع المنطقة — كُشف ما حول الهدف")
			march_done.emit(m)
			return
		_:
			reward = {"wood": 500}
	give(reward)
	var parts: Array[String] = []
	for k in reward:
		parts.append("%s %s" % [Defs.fmt(reward[k]), Defs.RES_NAMES[k]])
	toast.emit("عادت الفرقة: " + "، ".join(parts))
	march_done.emit(m)


func _resolve_venture_battle(t: float) -> void:
	## المعركة تُحسم بتوقيت الوصول المجدول (لا بتوقيت المعالجة)، وبظروف مثبتة عند الإرسال
	var army: Dictionary = venture["units"]
	## التشكيل يُطبّق مرة واحدة هنا — نسخة عميقة لا تمس تعديلات الجيش المخزنة
	var mods: Dictionary = Combat.with_formation(venture["mods"], str(venture.get("formation", "balanced")))
	var f := int(venture["guards_f"])
	var tgt: Dictionary = venture.get("target", {"kind": "vent"})
	# حراس الهدف من مصدر واحد مشترك مع معاينة الإرسال (venture_enemy)
	var en := venture_enemy(tgt, f)
	var guards_n := int(en["n"])
	var guards: Dictionary = en["stats"]
	var target_name := str(en["name"])
	var rep := Combat.fight(army, mods, {"beast": guards_n}, {"beast": guards}, storm_active(t), 0, WarRules.ATTACK_OPTS)
	var survivors := {}
	for k in rep["att_left"]:
		survivors[k] = int(rep["att_left"][k])
	venture["survivors"] = survivors
	venture["resolved"] = true
	venture["won"] = bool(rep["att_win"])
	# الخسائر الخام تُخزن — والجرحى والقتلى يُحسمون عند العودة وفق سعة المستوصف حينها
	var losses := {}
	for k in rep["att_loss"]:
		if int(rep["att_loss"][k]) > 0:
			losses[k] = int(rep["att_loss"][k])
	venture["losses"] = losses
	venture["report"] = {"win": bool(rep["att_win"]), "rounds": int(rep["rounds"]), "log": rep["log"], "dead": 0,
		"target": target_name, "retreated": bool(rep.get("retreated", false)), "guards": guards_n,
		"guards_left": int(rep["def_left"].get("beast", 0))}
	if rep["att_win"]:
		if str(tgt.get("kind", "vent")) == "hold":
			var hid := str(tgt["id"])
			holds[hid] = str(tgt.get("type", "stronghold"))
			var hd2: Dictionary = Defs.HOLD_DEFS[str(holds[hid])]
			var rew := {"aurora": int(hd2["reward_aurora"]) + f, "gems": int(hd2["reward_gems"])}
			give(rew)
			venture["report"]["reward"] = rew
			venture["report"]["hold"] = hid
			toast.emit("احتُلّ %s — %s" % [target_name, hd2["eff"]])
		else:
			vent["captured"] = true
			var rew2 := {"aurora": 8 + 2 * f, "gems": 5}
			give(rew2)
			venture["report"]["reward"] = rew2
			toast.emit("احتُلّ المنفث الحراري — المدينة اكتسبت +%d° دفئًا دائمًا" % int(Defs.VENT_HEAT))
	else:
		if bool(rep.get("retreated", false)):
			toast.emit("تراجعت الفرقة عن %s وأنقذت من بقي من جنودها — الحرّاس أقوى" % target_name)
		else:
			toast.emit("صُدّ الهجوم عن %s — الحرّاس أقوى من المتوقع" % target_name)
	recompute()
	changed.emit()
	save_game()


func _return_venture() -> void:
	## عودة الناجين مرة واحدة فقط — والجرحى تخضع لسعة المستوصف وقت العودة فعليًا
	var room_left := maxi(wounded_cap() - wounded_total(), 0)
	var dead_total := 0
	for k in venture.get("losses", {}):
		var lost := int(venture["losses"][k])
		var dead := int(round(lost * float(venture.get("dead_factor", 0.25)) * death_mult(k)))
		var w := mini(lost - dead, room_left)
		room_left -= w
		dead += (lost - dead) - w
		wounded[k] = int(wounded.get(k, 0)) + w
		dead_total += dead
	for k in venture.get("survivors", {}):
		troops[k] = int(troops.get(k, 0)) + int(venture["survivors"][k])
	var rep: Dictionary = venture.get("report", {})
	rep["dead"] = dead_total
	venture_done.emit(rep)
	venture = {}
	changed.emit()
	save_game()


func _simulate_stage2(dt: float, t: float) -> void:
	var mins := dt / 60.0
	# الثقة تتأثر بالبرد والجوع، وتميل للاستقرار عند الدفء
	if cold_level == 2:
		trust -= 0.6 * mins
	if hungry:
		trust -= 1.0 * mins
	if cold_level == 0 and not hungry and trust < 70.0:
		trust = minf(trust + 0.15 * mins, 70.0)
	trust = clampf(trust, 0.0, 100.0)
	if trust < 15.0 and pop > 4:
		_leave_acc += dt
		if _leave_acc >= 60.0:
			_leave_acc = 0.0
			pop -= 1
			if not _offline:
				toast.emit("غادر أحد الناجين المدينة لفقدان الثقة")
	else:
		_leave_acc = 0.0
	# التدريب
	for tp in train.keys():
		var tr: Dictionary = train[tp]
		if float(tr["end"]) <= t:
			var k: String = tr["key"]
			troops[k] = int(troops.get(k, 0)) + int(tr["n"])
			stats["trained"] = int(stats.get("trained", 0)) + int(tr["n"])
			toast.emit("اكتمل تدريب %d %s" % [int(tr["n"]), Defs.TROOPS[tp]["plural"]])
			train.erase(tp)
			notify_work_type_completed("train", "bk_" + tp)
	# البحث
	if not research.is_empty() and float(research["end"]) <= t:
		var rid: String = research["id"]
		techs[rid] = int(research["lv"])
		stats["research"] = int(stats.get("research", 0)) + 1
		toast.emit("اكتمل البحث: %s — المستوى %d" % [Defs.TECHS[rid]["name"], techs[rid]])
		research = {}
		notify_work_type_completed("research", "lab")
	# علاج الجرحى في المستوصف
	var wt := wounded_total()
	if wt > 0:
		var inf := 0
		for id in Defs.PLOTS:
			if Defs.PLOTS[id]["type"] == "infirmary":
				inf += level(id)
		var heal := (2.0 + 3.0 * inf) * (1.0 + bonus("heal")) * mins
		var budget := int(floor(heal + randf()))
		for k in wounded:
			if budget <= 0:
				break
			var h := mini(int(wounded[k]), budget)
			wounded[k] = int(wounded[k]) - h
			troops[k] = int(troops[k]) + h
			budget -= h
	if _offline:
		return
	# بلورات الشفق: العاصفة فرصة وليست كارثة فقط
	if storm_active(t):
		_crystal_acc += dt
		while _crystal_acc >= 9.0:
			_crystal_acc -= 9.0
			if crystals.size() < 10:
				_spawn_crystal()
	else:
		_crystal_acc = 0.0
	# غارات الذئاب
	if has_military() and raid_next <= 0.0:
		raid_next = t + 420.0
	if raid_next > 0.0 and t >= raid_next:
		_run_raid()
	elif raid_next > 0.0 and max_level_of("scout_tower") > 0:
		if raid_soon() > 0.0 and not _raid_warned:
			_raid_warned = true
			var fc := raid_forecast()
			toast.emit("إنذار من برج الاستطلاع: غارة ذئاب خلال %s (نحو %s ذئب)" % [Defs.fmt_time(raid_soon()), str(fc["wolves"]) if fc["exact"] else "من %d إلى %d" % [fc["lo"], fc["hi"]]])
		elif raid_soon() <= 0.0:
			_raid_warned = false
	# دفتر القائد
	if pending_decision < 0 and furnace_level() >= 2 and t >= decision_next:
		pending_decision = randi() % Defs.DECISIONS.size()
		decision_ready.emit()
		toast.emit("قرار جديد ينتظرك في دفتر القائد")


func _spawn_crystal() -> void:
	for attempt in 12:
		var a := randf() * TAU
		var r := randf_range(9.0, 44.0)
		var p := Defs.CITY_CENTER + Vector3(cos(a), 0, sin(a)) * r
		var ok := true
		for id in Defs.PLOTS:
			if Defs.plot_pos(id).distance_to(p) < 4.5:
				ok = false
				break
		if ok:
			crystals.append({"x": p.x, "z": p.z, "v": randi_range(3, 6)})
			crystals_changed.emit()
			return


func _run_raid() -> void:
	_raid_warned = false
	var st := raid_strength()
	var defense := defense_profile()
	var army: Dictionary = defense["units"]
	var rep := {}
	var storm: bool = defense["storm"]
	if army.is_empty():
		rep = {"att_win": true, "rounds": 0, "att_left": {"beast": st["n"]}, "att_loss": {"beast": 0},
				"def_left": {}, "def_loss": {}, "log": ["لم يكن في المدينة جنود للدفاع، فاقتحمت الذئاب المخازن."]}
	else:
		rep = Combat.fight({"beast": st["n"]}, {"beast": st["beast"]}, army, defense["mods"], storm)
	var win: bool = not rep["att_win"]
	# الخسائر: معظمها جرحى، والباقي قتلى
	var dead_total := 0
	var wounded_total_new := 0
	for k in rep["def_loss"]:
		var lost := int(rep["def_loss"][k])
		if lost <= 0:
			continue
		var dead := int(round(lost * 0.25 * death_mult(k)))
		if defender == "layla":
			dead = int(round(dead * 0.5))
		var w := lost - dead
		var room := maxi(wounded_cap() - wounded_total(), 0)
		if w > room:
			dead += w - room
			w = room
		troops[k] = maxi(int(troops[k]) - lost, 0)
		wounded[k] = int(wounded[k]) + w
		dead_total += dead
		wounded_total_new += w
	var reward := {}
	var loss := {}
	var f := maxi(furnace_level(), 1)
	if win:
		reward = {"food": 400 * f, "iron": 40 * f, "aurora": 6 + raid_count, "gems": 5}
		give(reward)
		trust = minf(trust + 4.0, 100.0)
		raid_wins += 1
	else:
		for r in ["food", "wood"]:
			loss[r] = int(res[r] * 0.08)
			res[r] -= loss[r]
		trust = maxf(trust - 6.0, 0.0)
		sick = minf(sick + 2.0, float(pop))
	raid_count += 1
	raid_next = now() + randf_range(780.0, 1140.0)
	toast.emit("غارة ذئاب: صمدت المدينة" if win else "غارة ذئاب: اخترقت الذئاب الدفاع")
	last_raid = {"win": win, "wolves": st["n"], "killed": int(rep["att_loss"].get("beast", 0)), "dead": dead_total,
			"wounded": wounded_total_new, "reward": reward, "loss": loss, "log": rep["log"], "storm": storm,
			"hero": defense["hero"], "time": now(),
			"defense_power": defense["power"], "wall_level": defense["wall"]["level"],
			"wall_bonus": defense["wall"].duplicate(true), "defenders": army.duplicate(true)}
	raid_unseen = true
	raid_happened.emit(last_raid)
	changed.emit()
	save_game()
