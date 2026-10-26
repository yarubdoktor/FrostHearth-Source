extends RefCounted
const Defs := preload("res://scripts/defs.gd")
## وحدة اقتصاد وإحصاءات — حسابات مشتقة للقراءة فقط، تفوّض إليها حالة اللعبة (Game)

static func get_stats_snapshot(g: Node) -> Dictionary:
	## لقطة للقراءة فقط لشاشة الإحصائيات — لا تغيّر شيئًا في الحالة ولا تشغّل المحاكاة
	var explored_cells := 0
	for i in range(g.explored.size()):
		if g.explored[i] != 0:
			explored_cells += 1
	var built := 0
	for id in g.plots:
		if int(g.plots[id]) > 0:
			built += 1
	var tech_count := 0
	for id in g.techs:
		if int(g.techs[id]) > 0:
			tech_count += 1
	var net := {}
	for r in g.res:
		net[r] = g.net_rate(r)
	return {
		"furnace": g.furnace_level(),
		"built": built,
		"plots_total": Defs.PLOTS.size(),
		"healthy": g.healthy(),
		"pop_total": g.pop,
		"pop_cap": g.pop_capacity(),
		"sick": int(floor(g.sick)),
		"trust": g.trust,
		"res": g.res.duplicate(),
		"net": net,
		"troops": g.troop_total(),
		"army_cap": g.army_cap(),
		"army_count": g.army_count(),
		"wounded": g.wounded_total(),
		"wounded_cap": g.wounded_cap(),
		"power": g.power(),
		"marches": g.marches.size(),
		"marches_max": g.MAX_MARCHES,
		"venture_active": not g.venture.is_empty(),
		"strongholds": g.holds_count("stronghold"),
		"fortresses": g.holds_count("fortress"),
		"explored_pct": 100.0 * float(explored_cells) / maxf(float(g.explored.size()), 1.0),
		"storm": g.storm_active(),
		"cold": g.cold_level,
		"heroes": g.heroes_owned(),
		"hero_cap": g.hero_cap(),
		"techs": tech_count,
		"lifetime": {
			"collected": (g.stats.get("collected", {}) as Dictionary).duplicate(),
			"marches": int(g.stats.get("marches", 0)),
			"built": int(g.stats.get("built", 0)),
			"trained": int(g.stats.get("trained", 0)),
			"research": int(g.stats.get("research", 0)),
			"aurora": int(g.stats.get("aurora", 0)),
			"decisions": int(g.stats.get("decisions", 0)),
		},
	}


# ---------------------------------------------------------------- كل نبضة
