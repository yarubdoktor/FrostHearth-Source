extends RefCounted
## Stage 31 / P3: cosmetic milestones; never changes resources or combat.
const ORDER := ["first_hero", "furnace_10", "ten_defenses"]
const DEFS := {
	"first_hero": {"name": "رفيق البداية", "description": "امتلك بطلًا واحدًا", "goal": 1,
		"title": "جامع الأبطال", "color": "80cbe8", "icon": "hero"},
	"furnace_10": {"name": "قلب المدينة", "description": "ارفع الفرن إلى المستوى 10", "goal": 10,
		"title": "حارس الجمر", "color": "efb65c", "icon": "furnace"},
	"ten_defenses": {"name": "صامد الصقيع", "description": "انتصر في الدفاع أمام 10 غارات", "goal": 10,
		"title": "درع المدينة", "color": "b59bea", "icon": "shield"},
}


static func sanitize(out: Dictionary, raw: Dictionary) -> void:
	var badges: Array = []
	var saved: Variant = raw.get("badges", [])
	if saved is Array:
		for id in ORDER:
			if saved.has(id):
				badges.append(id)
	out["badges"] = badges
	for kind in ["title", "frame"]:
		var id := str(raw.get(kind, ""))
		out[kind] = id if badges.has(id) else ""


static func progress(g, id: String) -> int:
	match id:
		"first_hero":
			var count := 0
			for hero in g.heroes.values():
				if bool(hero.get("owned", false)):
					count += 1
			return count
		"furnace_10":
			return maxi(int(g.plots.get("furnace", 0)), 0)
		"ten_defenses":
			return maxi(int(g.raid_wins), 0)
	return 0


static func sync(g) -> Array:
	if typeof(g.profile.get("badges")) != TYPE_ARRAY or not g.profile.has("title") or not g.profile.has("frame"):
		sanitize(g.profile, g.profile)
	var added: Array = []
	for id in ORDER:
		if not g.profile["badges"].has(id) and progress(g, id) >= int(DEFS[id]["goal"]):
			g.profile["badges"].append(id)
			added.append(id)
	return added


static func title(profile: Dictionary) -> String:
	var id := str(profile.get("title", ""))
	return str(DEFS[id]["title"]) if DEFS.has(id) and profile.get("badges", []).has(id) else ""


static func frame_color(profile: Dictionary) -> String:
	var id := str(profile.get("frame", ""))
	return str(DEFS[id]["color"]) if DEFS.has(id) and profile.get("badges", []).has(id) else ""
