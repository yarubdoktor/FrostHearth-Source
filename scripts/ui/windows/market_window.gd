extends RefCounted
## Stage 22 — نافذة السوق: أسعار الموارد الآن + تبادل مورد بمورد بحصة ورسوم يحددها مستوى السوق

const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")

static var sell := "wood"
static var buy := "iron"
static var amount := 100


static func show(city: Node) -> void:
	sell = "wood"
	buy = "iron"
	amount = 100
	city._window("السوق", "coal", func(body: VBoxContainer): _build(city, body))


static func _build(city: Node, body: VBoxContainer) -> void:
	var lv := Game.market_level()
	var quota_left := Game.market_quota_left()
	var head: PanelContainer = city._card()
	body.add_child(head)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(city._wrap("رسوم التبادل %d%%   •   حصة النافذة: %d / %d وحدة" % [roundi(Defs.market_fee(lv) * 100.0), quota_left, Defs.market_quota(lv)], 18, Color("ffd36b")))
	hv.add_child(city._wrap("تتجدد الحصة بعد %s" % Defs.fmt_time(Game.market_reset_in()), 16, Color("b9cbe0")))
	if Game.storm_active():
		hv.add_child(city._wrap("العاصفة الثلجية ترفع سعر الفحم والطعام", 16, Color("8fd3ff")))

	# أسعار الموارد الآن
	var pc: PanelContainer = city._card()
	body.add_child(pc)
	var pv := VBoxContainer.new()
	pc.add_child(pv)
	pv.add_child(city._wrap("أسعار السوق الآن (القيمة الأساسية = 1.0 للخشب)", 17, Color("b9cbe0")))
	for r in Defs.RES:
		var row: HBoxContainer = city._hrow()
		pv.add_child(row)
		var price := Game.market_price(r)
		var base := float(Defs.MARKET_VALUE[r])
		var ratio := price / base
		var arrow := "▲" if ratio > 1.03 else ("▼" if ratio < 0.97 else "■")
		var col := Color("ff9a8a") if ratio > 1.03 else (Color("8fe3a1") if ratio < 0.97 else Color.WHITE)
		var l := UI.label("%s %.2f" % [arrow, price], 19, col, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var have := UI.label("لديك " + Defs.fmt(float(Game.res[r])), 17, Color("b9cbe0"))
		row.add_child(have)
		row.add_child(UI.label(Defs.RES_NAMES[r], 19))
		row.add_child(UI.icon_rect(r, 28))

	# اختيار البيع والشراء
	body.add_child(_picker(city, "أبيع", true))
	body.add_child(_picker(city, "أشتري", false))

	# الكمية
	var ac: PanelContainer = city._card()
	body.add_child(ac)
	var av := VBoxContainer.new()
	ac.add_child(av)
	av.add_child(city._wrap("الكمية المباعة", 17, Color("b9cbe0")))
	var arow: HBoxContainer = city._hrow()
	av.add_child(arow)
	var sp := SpinBox.new()
	sp.min_value = 0
	sp.max_value = maxi(int(Game.res[sell]), 0)
	sp.step = 10
	sp.value = mini(amount, int(sp.max_value))
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(sp)
	var preview: Label = city._wrap("", 19, Color.WHITE)
	var go := UI.button("تبادل", func(): _do_trade(city), "gold", 54)
	var upd := func():
		amount = int(sp.value)
		var got := Game.market_quote(sell, buy, amount)
		preview.text = "تبيع %s %s وتستلم %s %s" % [Defs.fmt(float(amount)), Defs.RES_NAMES[sell], Defs.fmt(float(got)), Defs.RES_NAMES[buy]]
		var bad := amount <= 0 or got <= 0 or sell == buy or (amount > quota_left and not Game.dev_mode) or float(Game.res[sell]) < amount
		go.disabled = bad
		if amount > quota_left and not Game.dev_mode and amount > 0:
			preview.text += "\nتتجاوز حصة النافذة (%d)" % quota_left
	sp.value_changed.connect(func(_v): upd.call())
	for q in [["100", 100], ["500", 500], ["الحصة", quota_left]]:
		var qb := UI.button(q[0], func(): sp.value = mini(int(q[1]), int(sp.max_value)), "dark", 46)
		qb.custom_minimum_size = Vector2(90, 46)
		arow.add_child(qb)
	av.add_child(preview)
	av.add_child(go)
	upd.call()
	body.set_meta("market_preview", preview)


static func _picker(city: Node, title: String, is_sell: bool) -> PanelContainer:
	var c: PanelContainer = city._card()
	var v := VBoxContainer.new()
	c.add_child(v)
	v.add_child(city._wrap(title, 17, Color("b9cbe0")))
	var row: HBoxContainer = city._hrow(6)
	v.add_child(row)
	for r in Defs.RES:
		var on: bool = (sell == r) if is_sell else (buy == r)
		var b := UI.button(Defs.RES_NAMES[r], func(): _pick(city, r, is_sell), "gold" if on else "dark", 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return c


static func _pick(city: Node, r: String, is_sell: bool) -> void:
	if is_sell:
		sell = r
		if buy == r:
			buy = Defs.RES[(Defs.RES.find(r) + 1) % Defs.RES.size()]
	else:
		buy = r
		if sell == r:
			sell = Defs.RES[(Defs.RES.find(r) + 1) % Defs.RES.size()]
	city._refresh_window()


static func _do_trade(city: Node) -> void:
	if Game.market_trade(sell, buy, amount):
		city._toast("تم التبادل")
	city._refresh_window()
