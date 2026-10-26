extends RefCounted
## وحدة أدوات المطور — تفوّض إليها حالة اللعبة (Game)

const Defs := preload("res://scripts/defs.gd")


static func try_dev_mode(g: Node, pw: String) -> bool:
	## تفعيل/إيقاف وضع المطور بكلمة السر — يبقى محفوظًا مع اللعبة
	if pw != g.DEV_PASSWORD:
		g.toast.emit("كلمة السر غير صحيحة")
		return false
	g.dev_mode = not g.dev_mode
	g.toast.emit("تم تفعيل وضع المطور" if g.dev_mode else "تم إيقاف وضع المطور")
	g.changed.emit()
	g.save_game()
	return true


static func dev_give_resources(g: Node) -> void:
	for r in Defs.RES:
		g.res[r] = float(g.res.get(r, 0.0)) + 100000.0
	g.changed.emit()
	g.save_game()


static func dev_give_premium(g: Node) -> void:
	g.gems += 1000
	g.aurora += 1000
	g.changed.emit()
	g.save_game()


static func dev_add_pop(g: Node, n: int) -> void:
	g.pop += n
	g.recompute()
	g.changed.emit()
	g.save_game()


static func dev_finish_all(g: Node) -> void:
	## تسريع كل شيء فورًا: البناء والتدريب والبحث
	for q in g.queue:
		q["end"] = g.now()
	for tp in g.train:
		g.train[tp]["end"] = g.now()
	if not g.research.is_empty():
		g.research["end"] = g.now()
	for q in g.gear_queue:
		q["end"] = g.now()
	g._simulate(0.0, g.now())
	g.changed.emit()
	g.save_game()


static func dev_heal_all(g: Node) -> void:
	for k in g.wounded:
		g.troops[k] = int(g.troops.get(k, 0)) + int(g.wounded[k])   # يعود الجرحى للثكنات ولا يفقدوا
		g.wounded[k] = 0
	g.sick = 0.0
	g.recompute()
	g.changed.emit()
	g.save_game()


static func dev_reveal_map(g: Node) -> void:
	## أداة المطور: كشف كامل ضباب الحرب
	var any_changed := false
	for i in range(g.explored.size()):
		if g.explored[i] == 0:
			g.explored[i] = 1
			any_changed = true
	if any_changed:
		g.fog_changed.emit()
	g.save_game()
