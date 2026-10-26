extends RefCounted
## Workshop operations. No static mutable state; Game owns persistent data.
const Rules := preload("res://scripts/game/gear_defs.gd")
const Defs := preload("res://scripts/defs.gd")


static func level(g: Node, tp: String, slot: String) -> int:
	return int(g.equipment.get(tp, {}).get(slot, 0))


static func job(g: Node, tp: String, slot: String) -> Dictionary:
	for q in g.gear_queue:
		if q["key"] == tp + ":" + slot:
			return q
	return {}


static func check(g: Node, tp: String, slot: String) -> Dictionary:
	var reasons: Array[String] = []
	if not Rules.valid(tp, slot):
		return {"ok": false, "reasons": ["قطعة غير صالحة"], "cost": {}, "time": 0.0}
	var lv := level(g, tp, slot) + 1
	var wk: int = g.max_level_of("workshop")
	var cost := Rules.cost(slot, lv)
	if lv > Rules.MAX_LEVEL:
		reasons.append("وصلت القطعة إلى المستوى الأقصى")
	if wk < Rules.required_workshop(lv) and not g.dev_mode:
		reasons.append("تحتاج ورشة بمستوى %d" % Rules.required_workshop(lv))
	if wk <= 0:
		reasons.append("ابنِ الورشة أولًا")
	if not job(g, tp, slot).is_empty():
		reasons.append("هذه القطعة قيد التصنيع")
	if g.gear_queue.size() >= Rules.capacity(wk):
		reasons.append("خانات التصنيع ممتلئة")
	if not g.dev_mode:
		for r in cost:
			var have := float(g.aurora) if r == "aurora" else float(g.res.get(r, 0.0))
			if have < float(cost[r]):
				reasons.append("غير كافٍ: " + str(Defs.RES_NAMES[r]))
	return {"ok": reasons.is_empty(), "reasons": reasons, "cost": cost,
		"time": Rules.duration(lv, wk), "level": lv}


static func start(g: Node, tp: String, slot: String) -> bool:
	var c := check(g, tp, slot)
	if not c["ok"]:
		return false
	var paid := {}
	if not g.dev_mode:
		paid = c["cost"].duplicate(true)
		for r in paid:
			if r == "aurora":
				g.aurora -= int(paid[r])
			else:
				g.res[r] -= float(paid[r])
	var t: float = g.now()
	g.gear_queue.append({"key": tp + ":" + slot, "tp": tp, "slot": slot,
		"lv": c["level"], "start": t, "end": t + float(c["time"]), "paid": paid})
	g.changed.emit()
	g.save_game()
	return true


static func tick(g: Node, t: float) -> bool:
	var completed := false
	for i in range(g.gear_queue.size() - 1, -1, -1):
		var q: Dictionary = g.gear_queue[i]
		if float(q["end"]) > t:
			continue
		g.equipment[q["tp"]][q["slot"]] = maxi(level(g, q["tp"], q["slot"]), int(q["lv"]))
		g.gear_queue.remove_at(i)
		g.notify_work_type_completed("gear", "workshop")
		g.toast.emit("اكتمل تصنيع %s — المستوى %d" % [Rules.title(q["tp"], q["slot"]), int(q["lv"])])
		completed = true
	return completed


static func cancel(g: Node, tp: String, slot: String) -> bool:
	var q := job(g, tp, slot)
	if q.is_empty():
		return false
	if float(q["end"]) <= g.now():
		tick(g, g.now())
		g.changed.emit()
		g.save_game()
		return false
	# Refund exactly what was actually paid, never the recomputed current cost.
	for r in q["paid"]:
		if r == "aurora":
			g.aurora += int(q["paid"][r])
		else:
			g.res[r] = float(g.res.get(r, 0.0)) + float(q["paid"][r])
	g.gear_queue.erase(q)
	g.changed.emit()
	g.save_game()
	return true


static func speedup(g: Node, tp: String, slot: String) -> bool:
	var q := job(g, tp, slot)
	if q.is_empty():
		return false
	var price: int = g.gems_for_time(float(q["end"]) - g.now())
	if not g.dev_mode:
		if g.gems < price:
			g.toast.emit("الجواهر غير كافية")
			return false
		g.gems -= price
	q["end"] = g.now()
	tick(g, g.now())
	g.changed.emit()
	g.save_game()
	return true


static func restore(g: Node, data: Dictionary) -> void:
	g.equipment = Rules.blank()
	var saved = data.get("equipment", {})
	if saved is Dictionary:
		for tp in Rules.TYPES:
			var pieces = saved.get(tp, {})
			if pieces is Dictionary:
				for slot in Rules.SLOTS:
					var value = pieces.get(slot, 0)
					if value is float or value is int:
						g.equipment[tp][slot] = clampi(int(value), 0, Rules.MAX_LEVEL)
	g.gear_queue = []
	var queued = data.get("gear_queue", [])
	if not queued is Array:
		return
	for raw in queued:
		if not raw is Dictionary:
			continue
		var tp := str(raw.get("tp", ""))
		var slot := str(raw.get("slot", ""))
		if not Rules.valid(tp, slot) or not job(g, tp, slot).is_empty():
			continue
		var lv := int(raw.get("lv", 0))
		var s := float(raw.get("start", 0.0))
		var e := float(raw.get("end", 0.0))
		if lv != level(g, tp, slot) + 1 or lv > Rules.MAX_LEVEL or not is_finite(s) or not is_finite(e) or e < s:
			continue
		var paid := {}
		var raw_paid = raw.get("paid", {})
		if raw_paid is Dictionary:
			for r in Rules.cost(slot, lv):
				var v = raw_paid.get(r, 0)
				if (v is int or v is float) and is_finite(float(v)) and float(v) >= 0:
					paid[r] = minf(float(v), float(Rules.cost(slot, lv)[r]))
		g.gear_queue.append({"key": tp + ":" + slot, "tp": tp, "slot": slot,
			"lv": lv, "start": s, "end": e, "paid": paid})
		if g.gear_queue.size() >= 4:
			break
