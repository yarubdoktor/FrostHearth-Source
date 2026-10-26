extends RefCounted
## وحدة الأبطال — فتح واستدعاء وترقية، تفوّض إليها حالة اللعبة (Game)

const Defs := preload("res://scripts/defs.gd")


static func hero_unlock(g: Node, id: String) -> bool:
	var h: Dictionary = g.heroes[id]
	if h["owned"] or (int(h["shards"]) < Defs.STAR_SHARDS[0] and not g.dev_mode):
		return false
	if g.max_level_of("hero_hall") <= 0 and not g.dev_mode:
		g.toast.emit("ابنِ قاعة الأبطال أولًا")
		return false
	if not g.dev_mode:
		h["shards"] = int(h["shards"]) - Defs.STAR_SHARDS[0]
	h["owned"] = true
	g.toast.emit("انضم إليك البطل %s" % Defs.HEROES[id]["name"])
	g.changed.emit()
	g.save_game()
	return true


static func hero_summon(g: Node, id: String) -> bool:
	if g.aurora < Defs.SUMMON_COST and not g.dev_mode:
		g.toast.emit("بلورات الشفق غير كافية")
		return false
	if not g.dev_mode:
		g.aurora -= Defs.SUMMON_COST
	g.heroes[id]["shards"] = int(g.heroes[id]["shards"]) + 10
	g.toast.emit("حصلت على 10 شظايا من %s" % Defs.HEROES[id]["name"])
	g.changed.emit()
	g.save_game()
	return true


static func hero_level_check(g: Node, id: String) -> Dictionary:
	var h: Dictionary = g.heroes[id]
	var lv := int(h["lv"]) + 1
	var reasons: Array[String] = []
	var cap := 50 if g.dev_mode else int(g.hero_cap())   # المطور: الحد المطلق دون اشتراط القاعة
	if lv > cap:
		reasons.append("طوّر قاعة الأبطال لرفع الحد (%d)" % cap)
	var c := Defs.hero_level_cost(lv)
	var missing := {}
	for r in c:
		if g.res[r] < c[r]:
			missing[r] = c[r] - g.res[r]
	if g.dev_mode:
		missing = {}
	return {"ok": h["owned"] and reasons.is_empty() and missing.is_empty(), "reasons": reasons, "missing": missing, "cost": c}


static func hero_level_up(g: Node, id: String) -> bool:
	var chk := hero_level_check(g, id)
	if not chk["ok"]:
		return false
	if not g.dev_mode:
		for r in chk["cost"]:
			g.res[r] -= chk["cost"][r]
	g.heroes[id]["lv"] = int(g.heroes[id]["lv"]) + 1
	g.changed.emit()
	return true


static func hero_star_up(g: Node, id: String) -> bool:
	var h: Dictionary = g.heroes[id]
	var st := int(h["stars"])
	if not h["owned"] or st >= 5 or (int(h["shards"]) < Defs.STAR_SHARDS[st + 1] and not g.dev_mode):
		return false
	if not g.dev_mode:
		h["shards"] = int(h["shards"]) - Defs.STAR_SHARDS[st + 1]
	h["stars"] = st + 1
	g.toast.emit("ارتقى %s إلى %d نجوم" % [Defs.HEROES[id]["name"], st + 1])
	g.changed.emit()
	g.save_game()
	return true


static func set_role(g: Node, id: String, role: String) -> void:
	if role == "defender":
		g.defender = "" if g.defender == id else id
		if g.governor == id and g.defender == id:
			g.governor = ""
	else:
		g.governor = "" if g.governor == id else id
		if g.defender == id and g.governor == id:
			g.defender = ""
	g.recompute()
	g.changed.emit()
	g.save_game()
