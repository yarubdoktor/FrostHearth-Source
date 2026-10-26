extends "res://scripts/game/state/state_army.gd"
## الطبقة 3/6 — الاستعلامات: إنتاج/تخزين/بنّاؤون، توقّع الغارات، السوق، المسيرات، الملف الشخصي، المهام، الأبحاث (قراءة وحساب).


func builder_count() -> int:
	## عدد البنّائين المتاحين الآن (يزيد مع مستوى الفرن)
	return Defs.builder_count(furnace_level())


func next_builder_unlock() -> int:
	## مستوى الفرن الذي يفتح البنّاء التالي، أو 0 إن بلغنا الحد
	var n := Defs.builder_count(furnace_level())
	if n >= Defs.BUILDERS_MAX:
		return 0
	return int(Defs.BUILDER_UNLOCK[n + 1])


func offline_cap() -> float:
	## أقصى مدة غياب تُحتسب (ثوانٍ): الأعلى بين 8 ساعات وساعات التخزين
	return Defs.offline_cap_seconds(storage_hours())


func storage_hours() -> float:
	return 2.0 + 0.5 * max_level_of("storehouse") + bonus("storage")


func storage_cap(id: String) -> float:
	var tp: String = Defs.PLOTS[id]["type"]
	return Defs.prod_rate(tp, level(id)) * storage_hours()


func efficiency(id: String) -> float:
	var tp: String = Defs.PLOTS[id]["type"]
	var need := Defs.workers_needed(tp, level(id))
	if need <= 0:
		return 1.0
	return float(workers.get(id, 0)) / need


func current_rate(id: String) -> float:
	## الإنتاج الفعلي في الساعة
	var tp: String = Defs.PLOTS[id]["type"]
	var r := Defs.prod_rate(tp, level(id)) * efficiency(id)
	if Defs.BUILDINGS[tp].has("prod"):
		r *= (1.0 + bonus("prod_" + str(Defs.BUILDINGS[tp]["prod"]))) * trust_mult()
		r *= 1.0 + Defs.STRONGHOLD_PROD * holds_count("stronghold")
	if cold_level == 2:
		r *= 0.5
	if _under_construction(id):
		r = 0.0
	return r


func coal_use() -> float:
	if furnace_mode == 0:
		return 0.0
	return Defs.furnace_coal(furnace_level()) * (2.0 if furnace_mode == 2 else 1.0)


func food_use() -> float:
	return pop * 6.0 + troop_total() * 1.0


func net_rate(r: String) -> float:
	var n := 0.0
	for id in Defs.PLOTS:
		var tp: String = Defs.PLOTS[id]["type"]
		if Defs.BUILDINGS[tp].get("prod", "") == r:
			n += current_rate(id)
	if r == "coal":
		n -= coal_use()
	if r == "food":
		n -= food_use()
	return n


func _outside(t: float) -> float:
	var o := -16.0 + 3.0 * sin(t * TAU / 600.0)
	if storm_active(t):
		o -= 22.0
	if front_active(t):
		o -= Defs.FRONT_DROP
	return o


func check_upgrade(id: String) -> Dictionary:
	## {ok, reasons[], cost, time, next}
	var tp: String = Defs.PLOTS[id]["type"]
	var nxt := level(id) + 1
	var reasons: Array[String] = []
	var c := Defs.cost(tp, nxt)
	if nxt > int(Defs.BUILDINGS[tp]["max"]):
		reasons.append("وصل المبنى لأعلى مستوى")
	if not dev_mode:   # المطور: تُتجاوز اشتراطات الفتح والتسلسل، تبقى السقوف والتعارضات
		if furnace_level() < int(Defs.PLOTS[id]["unlock"]):
			reasons.append("يتطلب الفرن المستوى %d" % Defs.PLOTS[id]["unlock"])
		if tp != "furnace" and nxt > furnace_level():
			reasons.append("لا يتجاوز مستوى الفرن (%d)" % furnace_level())
		if tp == "furnace":
			if nxt >= 3 and max_level_of("shelter") < nxt - 1:
				reasons.append("يتطلب مأوى بالمستوى %d" % (nxt - 1))
			if nxt >= 4 and max_level_of("coal_mine") < nxt - 2:
				reasons.append("يتطلب منجم فحم بالمستوى %d" % (nxt - 2))
			if nxt >= 6 and max_level_of("storehouse") < nxt - 2:
				reasons.append("يتطلب مخزنًا بالمستوى %d" % (nxt - 2))
			var wneed := Defs.furnace_wall_need(nxt)
			if wneed > 0 and Defs.wall_stage(level(Defs.WALL_PLOT)) < wneed:
				reasons.append("يتطلب السور بمرحلة «%s» (المستوى %d)" % [Defs.WALL_STAGES[wneed]["name"], Defs.WALL_STAGES[wneed]["from"]])
		if tp == "wall":
			var ent := Defs.wall_stage_entry(nxt)
			if ent > 0 and furnace_level() < int(Defs.WALL_STAGES[ent]["furnace"]):
				reasons.append("مرحلة «%s» تتطلب الفرن المستوى %d" % [Defs.WALL_STAGES[ent]["name"], Defs.WALL_STAGES[ent]["furnace"]])
	if not queue_entry(id).is_empty():
		reasons.append("قيد البناء")
	var missing := {}
	for r in c:
		if res[r] < c[r]:
			missing[r] = c[r] - res[r]
	if dev_mode:
		missing = {}   # المطور: لا تُطلب الموارد
	var builders_free := queue.size() < builder_count() or dev_mode
	return {"ok": reasons.is_empty() and missing.is_empty() and builders_free, "reasons": reasons,
			"missing": missing, "cost": c, "time": Defs.build_time(tp, nxt) / (1.0 + bonus("build_speed")), "next": nxt,
			"builders_free": builders_free}


# ================================================================ المهام والمكافآت
func current_task() -> Dictionary:
	if task_index >= Defs.TASKS.size():
		return {}
	return Defs.TASKS[task_index]


func task_progress(tk: Dictionary) -> Vector2:
	match tk["type"]:
		"count":
			return Vector2(count_of(tk["b"]), tk["n"])
		"level":
			return Vector2(max_level_of(tk["b"]), tk["n"])
		"collect":
			return Vector2(float(stats["collected"].get(tk["r"], 0)), tk["n"])
		"pop":
			return Vector2(pop, tk["n"])
		"temp":
			return Vector2(1 if inside_temp >= float(tk["n"]) else 0, 1)
		"march":
			return Vector2(int(stats.get("marches", 0)), tk["n"])
		"train":
			return Vector2(int(stats.get("trained", 0)), tk["n"])
		"hero":
			return Vector2(heroes_owned(), tk["n"])
		"defender":
			return Vector2(1 if defender != "" else 0, 1)
		"governor":
			return Vector2(1 if governor != "" else 0, 1)
		"aurora":
			return Vector2(int(stats.get("aurora", 0)), tk["n"])
		"decision":
			return Vector2(int(stats.get("decisions", 0)), tk["n"])
		"raid_win":
			return Vector2(raid_wins, tk["n"])
		"research":
			return Vector2(int(stats.get("research", 0)), tk["n"])
		"hero_lv":
			var m := 0
			for id in heroes:
				if heroes[id]["owned"]:
					m = maxi(m, int(heroes[id]["lv"]))
			return Vector2(m, tk["n"])
		"power":
			return Vector2(int(power()), tk["n"])
	return Vector2(0, 1)


func task_done(tk: Dictionary) -> bool:
	var p := task_progress(tk)
	return p.x >= p.y


func chapter2_open() -> bool:
	return furnace_level() >= 3


func current_task2() -> Dictionary:
	if not chapter2_open() or task2_index >= Defs.TASKS2.size():
		return {}
	return Defs.TASKS2[task2_index]


func tracked_task() -> Dictionary:
	## المهمة الظاهرة في الشريط: الجاهزة للاستلام أولًا
	var t1 := current_task()
	var t2 := current_task2()
	if not t1.is_empty() and task_done(t1):
		return {"ch": 1, "tk": t1}
	if not t2.is_empty() and task_done(t2):
		return {"ch": 2, "tk": t2}
	if not t2.is_empty() and (t1.is_empty() or max_level_of("barracks") > 0 or furnace_level() >= 5):
		return {"ch": 2, "tk": t2}
	if not t1.is_empty():
		return {"ch": 1, "tk": t1}
	return {}


func daily_reward() -> Dictionary:
	var f := maxi(furnace_level(), 1)
	return {"food": 1500 * f, "wood": 1200 * f, "coal": 500 * f, "aurora": 10, "gems": 50}


# ================================================================ المسيرات (الخريطة الكبرى)
func march_speed() -> float:
	return 7.0 * (1.0 + bonus("march_speed"))   # خانة في الثانية


func _ensure_profile() -> void:
	if profile.is_empty() or not profile.has("id"):
		profile = Profile.new_profile(Time.get_unix_time_from_system())


func profile_name() -> String:
	_ensure_profile()
	return str(profile["name"])


func owned_hero_ids() -> Array:
	var out: Array = []
	for id in heroes:
		if heroes[id]["owned"]:
			out.append(id)
	return out


func profile_avatar_id() -> String:
	## الصورة الفعلية: ما اختاره اللاعب إن كان البطل ما زال مملوكًا، وإلا قائد الدفاع ثم الحاكم، وإلا فارغ (أيقونة افتراضية)
	_ensure_profile()
	var pick := str(profile["avatar"])
	if pick != "" and heroes.has(pick) and heroes[pick]["owned"]:
		return pick
	return defender if defender != "" else governor


func profile_card() -> Dictionary:
	## بطاقة الملف (P2): كلها تُقرأ من الحالة الموجودة بلا حفظ إضافي
	_ensure_profile()
	var done := 0
	for id in techs:
		if int(techs[id]) > 0:
			done += 1
	return {"name": str(profile["name"]), "id": int(profile["id"]), "avatar": profile_avatar_id(),
		"power": power(), "furnace": furnace_level(), "troops": army_count(), "heroes": owned_hero_ids().size(),
		"techs": done, "raids_won": raid_wins, "raids": raid_count,
		"days": Profile.play_days(float(profile["created"]), Time.get_unix_time_from_system())}


func market_level() -> int:
	return max_level_of("market")


func market_price(r: String) -> float:
	return Defs.market_price(r, now(), storm_active())


func _market_roll() -> void:
	if now() >= market_window_start + Defs.MARKET_WINDOW:
		market_window_start = now()
		market_used = 0.0


func market_quota_left() -> int:
	## ما يمكن بيعه من الحصة في النافذة الحالية
	_market_roll()
	return maxi(Defs.market_quota(market_level()) - int(market_used), 0)


func market_reset_in() -> float:
	_market_roll()
	return maxf(market_window_start + Defs.MARKET_WINDOW - now(), 0.0)


func market_quote(sell: String, buy: String, amount: int) -> int:
	return Defs.market_quote(sell, buy, amount, now(), storm_active(), market_level())


func march_capacity() -> int:
	## أقصى عدد جنود في مسيرة عسكرية واحدة (المستودع الحربي)
	return Defs.march_capacity(max_level_of("war_depot"))


func venture_supply_cost(n: int) -> int:
	return Defs.supply_cost(n, max_level_of("war_depot"))


func venture_check(units: Dictionary) -> Dictionary:
	## فحص قبل الإرسال (للقراءة فقط): {ok, total, cap, cost, reason}
	var total := 0
	for k in units:
		total += maxi(int(units[k]), 0)
	var cap := march_capacity()
	var cost := venture_supply_cost(total)
	var reason := ""
	if total <= 0:
		reason = "اختر جنودًا لإرسالهم أولًا"
	elif total > cap and not dev_mode:
		reason = "حجم المسيرة %d يتجاوز المسموح %d — طوّر المستودع الحربي" % [total, cap]
	elif float(res["food"]) < cost and not dev_mode:
		reason = "المؤن ناقصة: يلزم %s طعام" % Defs.fmt(float(cost))
	return {"ok": reason == "", "total": total, "cap": cap, "cost": cost, "reason": reason}


func venture_enemy(tgt: Dictionary, f: int = -1) -> Dictionary:
	## حراس هدف الحملة: {n, stats, name, type} — مصدر واحد تستعمله المعركة الفعلية ومعاينة الإرسال
	var fl := f if f > 0 else maxi(furnace_level(), 1)
	if str(tgt.get("kind", "vent")) == "hold":
		var lm := _find_landmark(str(tgt.get("id", "")))
		var type := str(tgt.get("type", lm.get("type", "stronghold")))
		var hd: Dictionary = Defs.HOLD_DEFS[type]
		var s := 1.0 + float(hd["g_scale"]) * fl
		return {"n": int(hd["guards"]) + 2 * fl, "type": type, "name": str(lm.get("name", hd["name"])),
				"stats": {"atk": float(hd["g_atk"]) * s, "def": float(hd["g_def"]) * s, "hp": float(hd["g_hp"]) * s,
						"name": "حرّاس %s" % hd["name"]}}
	var s2 := 1.0 + 0.12 * fl
	return {"n": int(Defs.VENT["guards"]) + 3 * fl, "type": "vent", "name": "المنفث الحراري",
			"stats": {"atk": 10.0 * s2, "def": 7.0 * s2, "hp": 30.0 * s2, "name": "حرّاس المنفث"}}


func venture_travel_time(tgt: Dictionary) -> float:
	## زمن الذهاب فقط بالثواني (نفس حساب start_venture)
	var from := Vector2(home.x + 0.5, home.y + 0.5)
	var to := Vector2(float(vent["x"]) + 0.5, float(vent["y"]) + 0.5)
	if str(tgt.get("kind", "vent")) == "hold":
		var lm := _find_landmark(str(tgt.get("id", "")))
		if not lm.is_empty():
			to = Vector2(float(lm["x"]), float(lm["y"]))
	return clampf(from.distance_to(to) / march_speed(), 8.0, 300.0)


func venture_preview(units: Dictionary, formation: String, tgt: Dictionary) -> Dictionary:
	## معاينة الحملة قبل الإرسال (قراءة فقط): فرصة النصر والخسائر المتوقعة والزمن والدفاع المتبقي في المدينة
	var take := {}
	for k in units:
		if int(units[k]) > 0:
			take[k] = int(units[k])
	var chk := venture_check(take)
	var en := venture_enemy(tgt)
	var err := WarRules.intel_error(max_level_of("scout_tower"))
	var rng := WarRules.enemy_range(int(en["n"]), err)
	var mods := Combat.with_formation(army_mods(defender), formation)
	var storm := storm_active()
	var mid := {"win_pct": 0, "att_loss_pct": 0, "def_loss_pct": 0, "retreat_pct": 0}
	var win_lo := 0
	var win_hi := 0
	if not take.is_empty():
		mid = WarRules.estimate(take, mods, {"beast": int(en["n"])}, {"beast": en["stats"]}, storm)
		win_lo = int(mid["win_pct"])
		win_hi = int(mid["win_pct"])
		if err > 0.0:
			win_hi = int(WarRules.estimate(take, mods, {"beast": rng.x}, {"beast": en["stats"]}, storm)["win_pct"])
			win_lo = int(WarRules.estimate(take, mods, {"beast": rng.y}, {"beast": en["stats"]}, storm)["win_pct"])
		win_lo = mini(win_lo, int(mid["win_pct"]))
		win_hi = maxi(win_hi, int(mid["win_pct"]))
	# من يبقى في المدينة يدافع عنها أثناء غياب الفرقة
	var remaining := {}
	var rem_total := 0
	for k in troops:
		var r := int(troops[k]) - int(take.get(k, 0))
		if r > 0:
			remaining[k] = r
			rem_total += r
	var raid := raid_strength()
	var dprof := defense_profile()
	var hold := WarRules.raid_hold_pct(remaining, dprof["mods"], bool(dprof["storm"]), int(raid["n"]), raid["beast"])
	var travel := venture_travel_time(tgt)
	return {"check": chk, "enemy_name": en["name"], "enemy_n": int(en["n"]), "enemy_lo": rng.x, "enemy_hi": rng.y,
			"intel_err": err, "win_pct": int(mid["win_pct"]), "win_lo": win_lo, "win_hi": win_hi,
			"att_loss_pct": int(mid["att_loss_pct"]), "def_loss_pct": int(mid["def_loss_pct"]), "retreat_pct": int(mid["retreat_pct"]),
			"power": WarRules.power_of(take), "travel": travel, "round_trip": travel * 2.0 + float(Defs.VENT_FIGHT_WORK),
			"remaining": remaining, "remaining_total": rem_total, "home_hold_pct": hold, "raid_n": int(raid["n"])}


# ---------------------------------------------------------------- الأبحاث
func tech_check(id: String) -> Dictionary:
	var lv := int(techs[id]) + 1
	var tdef: Dictionary = Defs.TECHS[id]
	var reasons: Array[String] = []
	if lv > int(tdef["max"]):
		reasons.append("وصل البحث لأعلى مستوى")
	if not dev_mode:   # المطور: تجاوز اشتراطات المختبر وسلسلة البحث
		if max_level_of("lab") <= 0:
			reasons.append("ابنِ مختبر الجمر أولًا")
		elif max_level_of("lab") < Defs.tech_lab_req(id, lv):
			reasons.append("يتطلب المختبر بالمستوى %d" % Defs.tech_lab_req(id, lv))
		if max_level_of("workshop") < Defs.tech_workshop_req(id, lv):
			reasons.append("يتطلب الورشة الحربية بالمستوى %d" % Defs.tech_workshop_req(id, lv))
		var wreq := Defs.tech_wall_req(id, lv)
		if wreq > 0 and Defs.wall_stage(level(Defs.WALL_PLOT)) < wreq:
			reasons.append("يتطلب السور بمرحلة «%s» (المستوى %d)" % [Defs.WALL_STAGES[wreq]["name"], Defs.WALL_STAGES[wreq]["from"]])
		if tdef["req"] != "" and int(techs[tdef["req"]]) < 1:
			reasons.append("يتطلب بحث: %s" % Defs.TECHS[tdef["req"]]["name"])
	if not research.is_empty():
		reasons.append("المختبر مشغول ببحث آخر")
	var c := Defs.tech_cost(id, lv)
	var missing := {}
	for r in c:
		var have: float = float(aurora) if r == "aurora" else float(res[r])
		if have < c[r]:
			missing[r] = c[r] - have
	if dev_mode:
		missing = {}
	var time := Defs.tech_time(id, lv) / (1.0 + bonus("research_speed"))
	return {"ok": reasons.is_empty() and missing.is_empty(), "reasons": reasons, "missing": missing, "cost": c, "time": time, "next": lv}


func raid_strength() -> Dictionary:
	var f := furnace_level()
	var red := minf(Defs.FORT_RAID_CAP, Defs.FORT_RAID_RED * holds_count("fortress"))
	var s := (1.0 + 0.07 * (f - 1) + 0.04 * raid_count) * (1.0 - red)
	return {"n": int(round((10 + 5 * mini(raid_count, 20) + 3 * f) * (1.0 - red))),
			"beast": {"atk": 9.0 * s, "def": 6.0 * s, "hp": 26.0 * s, "name": "الذئاب"}}


func raid_soon() -> float:
	if raid_next <= 0.0:
		return -1.0
	var r := raid_next - now()
	return r if r > 0 and r < raid_warning_lead() else -1.0


func raid_warning_lead() -> float:
	## مدة الإنذار قبل الغارة: أساسي 90 ثانية، ويمدده برج الاستطلاع
	return Defs.raid_warning_lead(max_level_of("scout_tower"))


func raid_forecast() -> Dictionary:
	## تقدير الغارة القادمة من برج الاستطلاع (للقراءة فقط). بلا برج: active=false
	var lv := max_level_of("scout_tower")
	if lv <= 0 or raid_next <= 0.0:
		return {"active": false}
	var n := int(raid_strength()["n"])
	var err := Defs.forecast_error(lv)
	var lo := maxi(int(round(n * (1.0 - err))), 1)
	var hi := maxi(int(round(n * (1.0 + err))), lo)
	return {"active": true, "level": lv, "lo": lo, "hi": hi, "exact": err <= 0.0 or lo == hi, "wolves": n,
			"storm": lv >= Defs.FORECAST_STORM_LEVEL and storm_active(raid_next),
			"storm_known": lv >= Defs.FORECAST_STORM_LEVEL, "eta": raid_next - now()}


func _apply_scout_vision() -> void:
	## كشف الخريطة حول المدينة بحسب مستوى البرج — مرة عند كل تغيّر في المستوى (يشمل التحميل)
	var lv := max_level_of("scout_tower")
	if lv == _scout_vision_lv:
		return
	_scout_vision_lv = lv
	if lv > 0:
		reveal_at(home.x + 0.5, home.y + 0.5, Defs.scout_vision(lv))


# ---------------------------------------------------------------- دفتر القائد
func decision_option_ok(opt: Dictionary) -> bool:
	for k in opt["eff"]:
		var v := float(opt["eff"][k])
		if v >= 0:
			continue
		if res.has(k) and res[k] < -v:
			return false
		if k == "aurora" and aurora < -v:
			return false
	return true
