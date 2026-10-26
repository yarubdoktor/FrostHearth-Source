extends RefCounted
## وحدة الخريطة وضباب الحرب — كشف المناطق ومسار الكشف، تفوّض إليها حالة اللعبة (Game)

const Defs := preload("res://scripts/defs.gd")


static func is_explored(g: Node, x: int, y: int) -> bool:
	var cx := int(x) / Defs.FOG_CELL
	var cy := int(y) / Defs.FOG_CELL
	if cx < 0 or cy < 0 or cx >= Defs.FOG_GRID or cy >= Defs.FOG_GRID:
		return true
	return g.explored[cy * Defs.FOG_GRID + cx] > 0

static func reveal_at(g: Node, x: float, y: float, radius: float) -> void:
	## كشف دائرة حول نقطة الخريطة — تُبث إشارة التغيير مرة واحدة
	var changed := false
	var r2 := radius * radius
	var c0x := maxi(int(floor((x - radius) / Defs.FOG_CELL)), 0)
	var c0y := maxi(int(floor((y - radius) / Defs.FOG_CELL)), 0)
	var c1x := mini(int(floor((x + radius) / Defs.FOG_CELL)), Defs.FOG_GRID - 1)
	var c1y := mini(int(floor((y + radius) / Defs.FOG_CELL)), Defs.FOG_GRID - 1)
	for cy in range(c0y, c1y + 1):
		for cx in range(c0x, c1x + 1):
			var idx := cy * Defs.FOG_GRID + cx
			if g.explored[idx] > 0:
				continue
			var dx := (cx + 0.5) * Defs.FOG_CELL - x
			var dy := (cy + 0.5) * Defs.FOG_CELL - y
			if dx * dx + dy * dy <= r2:
				g.explored[idx] = 1
				changed = true
	if changed:
		g.fog_changed.emit()

static func reveal_segment(g: Node, x0: float, y0: float, x1: float, y1: float, radius: float) -> void:
	## كشف الممر المقطوع بين نقطتين (يغطي فجوات خطوات المحاكاة الكبيرة أثناء الغياب)
	var d := Vector2(x1 - x0, y1 - y0).length()
	if d < 0.01:
		reveal_at(g, x0, y0, radius)
		return
	var step := maxf(radius * 0.7, 1.0)
	var n := int(ceil(d / step))
	for i in n + 1:
		var k := float(i) / float(n)
		reveal_at(g, lerpf(x0, x1, k), lerpf(y0, y1, k), radius)

static func march_fog_pos(g: Node, m: Dictionary, t: float) -> Vector2:
	## موقع الفرقة على الخريطة عند لحظة معينة (للرسم وكشف الممر) — بلا استقطاع خارج المسار
	if t < float(m["arrive"]):
		var k := clampf(inverse_lerp(float(m["start"]), float(m["arrive"]), t), 0.0, 1.0)
		return Vector2(lerpf(float(m["fx"]), float(m["tx"]), k), lerpf(float(m["fy"]), float(m["ty"]), k))
	if t < float(m["leave"]):
		return Vector2(float(m["tx"]), float(m["ty"]))
	var k2 := clampf(inverse_lerp(float(m["leave"]), float(m["back"]), t), 0.0, 1.0)
	return Vector2(lerpf(float(m["tx"]), float(m["fx"]), k2), lerpf(float(m["ty"]), float(m["fy"]), k2))

static func reveal_march_path(g: Node, m: Dictionary, t_from: float, t_to: float, radius: float) -> void:
	## كشف المسار الفعلي المقطوع بين لحظتين — يفصل عند الهدف إذا قطعت الخطوة الذهاب والعودة معًا
	var p1 := march_fog_pos(g, m, t_from)
	var p2 := march_fog_pos(g, m, t_to)
	var crossed := (t_from < float(m["arrive"]) and t_to >= float(m["arrive"])) \
			or (t_from < float(m["leave"]) and t_to >= float(m["leave"]))
	if crossed:
		var tgt := Vector2(float(m["tx"]), float(m["ty"]))
		reveal_segment(g, p1.x, p1.y, tgt.x, tgt.y, radius)
		reveal_segment(g, tgt.x, tgt.y, p2.x, p2.y, radius)
	else:
		reveal_segment(g, p1.x, p1.y, p2.x, p2.y, radius)

# ---------------------------------------------------------------- المعاقل والقلاع
