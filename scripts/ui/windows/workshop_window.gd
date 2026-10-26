extends RefCounted
## Stage 29: portrait, scrollable workshop with per-type permanent equipment.
const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const Rules := preload("res://scripts/game/gear_defs.gd")
const Art := preload("res://scripts/ui/gear_art.gd")
static var selected := "shield"


static func show(city: Node, tp: String = "shield") -> void:
	selected = tp if Rules.TYPES.has(tp) else "shield"
	city._window("الورشة الحربية", "hammer", func(body: VBoxContainer): _build(city, body))


static func _signature() -> String:
	return str(Game.equipment) + str(Game.gear_queue) + str(Game.max_level_of("workshop"))


static func _build(city: Node, outer: VBoxContainer) -> void:
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_left", 4)
	outer.add_child(inset)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	inset.add_child(body)
	var tp := selected
	body.name = "WorkshopBody"
	var wk := Game.max_level_of("workshop")
	body.add_child(city._wrap("الورشة مستوى %d | خانات مشغولة: %d من %d" % [
		wk, Game.gear_queue.size(), Rules.capacity(wk)], 20, UI.GOLD))
	body.add_child(city._wrap("التجهيزات دائمة لكل جنود النوع، وتُضاف إلى بركة الورشة القديمة. لا تنتهي القطعة إلا بعد اكتمال التصنيع.", 17, Color("b9cbe0")))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for kind in Rules.TYPES:
		var button := UI.button(Defs.TROOPS[kind]["plural"], func(): show(city, kind),
			"gold" if tp == kind else "dark", 52)
		button.name = "Tab_" + kind
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var b := Rules.bonuses(Game.equipment, tp)
	body.add_child(city._wrap("هجوم +%.1f%% | دفاع +%.1f%% | صحة +%.1f%%\nضرر نهائي +%.1f%% (عدا الوحوش) | قوة تجهيزات %d" % [
		float(b["atk"]) * 100, float(b["def"]) * 100, float(b["hp"]) * 100,
		float(b["damage"]) * 100, roundi(float(b["power"]))], 18, UI.GREEN))
	body.add_child(city._wrap("علاوة الطقم الحالية: %.0f%%. عند اكتمال القطع الأربع بمستوى 3 ثم 6 ثم 10 تحصل على أعلى علاوة: 2%% ثم 4%% ثم 7%% للهجوم والدفاع والصحة وقوة التجهيزات." % [
		Rules.set_bonus(Game.equipment, tp) * 100], 16, Color("b9cbe0")))
	for q in Game.gear_queue:
		_queue_card(city, body, q)
	for slot in Rules.SLOTS:
		_piece_card(city, body, tp, slot)
	# Structural changes rebuild once; ordinary ticks only update text/buttons.
	var previous := [_signature()]
	city.win_tick.append(func():
		if is_instance_valid(body) and previous[0] != _signature():
			previous[0] = _signature()
			city._refresh_window())


static func _queue_card(city: Node, body: VBoxContainer, q: Dictionary) -> void:
	var card: PanelContainer = city._card()
	body.add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	box.add_child(Art.icon(q["tp"], q["slot"], 44))
	box.add_child(city._wrap("قيد التصنيع: %s م%d (%s)" % [
		Rules.title(q["tp"], q["slot"]), int(q["lv"]), Defs.TROOPS[q["tp"]]["plural"]], 19, UI.GOLD))
	var clock: Label = city._wrap("", 17)
	box.add_child(clock)
	var bar := UI.progress_bar(UI.GOLD)
	bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(bar)
	var speed := UI.button("", func(): _confirm_speed(city, q["tp"], q["slot"]), "gold", 52)
	box.add_child(speed)
	box.add_child(UI.button("إلغاء التصنيع واسترداد المدفوع كاملًا",
		func(): _confirm_cancel(city, q["tp"], q["slot"]), "dark", 48))
	var update := func():
		if not is_instance_valid(clock):
			return
		var remaining := maxf(float(q["end"]) - Game.now(), 0)
		clock.text = "متبقٍ " + Defs.fmt_time(remaining)
		bar.value = 100.0 * clampf((Game.now() - float(q["start"])) / maxf(float(q["end"]) - float(q["start"]), 0.01), 0, 1)
		var price := Game.gems_for_time(remaining)
		speed.text = "إنهاء مجانًا" if price == 0 or Game.dev_mode else "إنهاء الآن: %d جواهر" % price
		speed.disabled = not Game.dev_mode and Game.gems < price
	update.call()
	city.win_tick.append(update)


static func _piece_card(city: Node, body: VBoxContainer, tp: String, slot: String) -> void:
	var card: PanelContainer = city._card()
	card.name = "Gear_" + tp + "_" + slot
	body.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)
	var lv := Game.gear_level(tp, slot)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	header.add_child(Art.icon(tp, slot))
	var title: Label = city._wrap("%s | المستوى %d من %d" % [Rules.title(tp, slot), lv, Rules.MAX_LEVEL], 22, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var effect: String = Rules.EFFECTS[slot]
	box.add_child(city._wrap("%s: +%.1f%%" % [Rules.LABELS[effect], lv * float(Rules.RATES[slot]) * 100], 18))
	if lv >= Rules.MAX_LEVEL:
		box.add_child(city._wrap("المستوى الأقصى", 18, UI.GREEN))
		return
	var check := Game.gear_check(tp, slot)
	box.add_child(city._wrap("التالي م%d: +%.1f%% | ورشة م%d | %s" % [
		lv + 1, (lv + 1) * float(Rules.RATES[slot]) * 100, Rules.required_workshop(lv + 1),
		Defs.fmt_time(float(check["time"]))], 16, Color("b9cbe0")))
	box.add_child(city._cost_chips(check["cost"]))
	var reason: Label = city._wrap("", 16, UI.RED)
	box.add_child(reason)
	var make := UI.button("تصنيع" if lv == 0 else "ترقية التجهيز", func():
		if not Game.start_gear(tp, slot):
			Game.toast.emit("تعذر التصنيع: " + "، ".join(Game.gear_check(tp, slot)["reasons"])),
		"green", 54)
	make.name = "Craft_" + tp + "_" + slot
	box.add_child(make)
	var update := func():
		if not is_instance_valid(make):
			return
		var c := Game.gear_check(tp, slot)
		make.disabled = not c["ok"]
		reason.text = "، ".join(c["reasons"])
	update.call()
	city.win_tick.append(update)


static func _confirm_cancel(city: Node, tp: String, slot: String) -> void:
	if Game.gear_job(tp, slot).is_empty():
		return
	city._modal("إلغاء التصنيع", "إلغاء %s؟ ستسترد المواد التي دفعتها كاملة، ولن تُمنح القطعة." % Rules.title(tp, slot),
		[["إلغاء التصنيع", func(): Game.cancel_gear(tp, slot), "red"], ["رجوع", func(): pass, "dark"]], "hammer")


static func _confirm_speed(city: Node, tp: String, slot: String) -> void:
	var q := Game.gear_job(tp, slot)
	if q.is_empty():
		return
	var price := 0 if Game.dev_mode else Game.gems_for_time(float(q["end"]) - Game.now())
	city._modal("إنهاء التصنيع", "إنهاء %s الآن؟ التكلفة الحالية %d جواهر، وقد تنقص بمرور الوقت." % [
		Rules.title(tp, slot), price],
		[["إنهاء الآن", func(): Game.speedup_gear(tp, slot), "gold"], ["رجوع", func(): pass, "dark"]], "hammer")
