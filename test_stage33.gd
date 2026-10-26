extends Node
## اختبار Stage 33 — عمق منطق الحرب: تراجع المهاجم، تقدير المعركة، تعبئة الجنود، معاينة الإرسال، الدفاع المتبقي، نافذة الإرسال
## التشغيل: godot --headless --path . res://test_stage33.tscn

const Defs := preload("res://scripts/defs.gd")
const Combat := preload("res://scripts/combat.gd")
const WarRules := preload("res://scripts/game/war_rules.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage33.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)


func _army(n: int) -> Dictionary:
	var third := n / 3
	return {"shield_1": third, "spear_1": third, "bow_1": n - 2 * third}


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)

	# 1) السلوك القديم محفوظ: بلا opts لا تراجع ولا تغيير، ومعها نفس النتيجة
	var plain := Combat.fight(_army(60), {}, _army(60), {}, false, 7)
	var plain2 := Combat.fight(_army(60), {}, _army(60), {}, false, 7, {})
	check(plain["att_loss"].hash() == plain2["att_loss"].hash() and int(plain["rounds"]) == int(plain2["rounds"]), "fight without opts is identical to fight with empty opts")
	check(not bool(plain["retreated"]), "no retreat without the retreat option")
	var wipe := Combat.fight(_army(30), {}, _army(150), {}, false, 7)
	check(_sum(wipe["att_left"]) == 0, "legacy fight: a far weaker attacker is wiped out (unchanged)")

	# 2) التراجع المنظم: المهاجم الأضعف بوضوح ينسحب بناجين بدل الفناء
	var all_retreat := true
	var all_survivors := true
	var never_win := true
	for sd in [11, 23, 37, 51, 77]:
		var rep := Combat.fight(_army(100), {}, _army(150), {}, false, sd, WarRules.ATTACK_OPTS)
		all_retreat = all_retreat and bool(rep["retreated"])
		all_survivors = all_survivors and _sum(rep["att_left"]) > 0
		never_win = never_win and not bool(rep["att_win"])
	check(all_retreat, "weaker attacker retreats (5 seeds)")
	check(all_survivors, "retreat leaves survivors instead of total wipe")
	check(never_win, "a retreat is never reported as a win")
	var wiped := Combat.fight(_army(3), {}, _army(150), {}, false, 5, WarRules.ATTACK_OPTS)
	check(not bool(wiped["retreated"]) or _sum(wiped["att_left"]) > 0, "total wipe is not labelled a retreat")
	var strong := Combat.fight(_army(200), {}, _army(30), {}, false, 9, WarRules.ATTACK_OPTS)
	check(bool(strong["att_win"]) and not bool(strong["retreated"]), "much stronger attacker still wins without retreating")
	var lost := _sum(strong["att_loss"])
	check(lost < 40, "the winner of a 200 vs 30 fight loses little (%d)" % lost)

	# 3) التقدير: ثابت لنفس المدخلات، ويعكس القوة
	var guard := {"atk": 10.0, "def": 7.0, "hp": 30.0, "name": "حرّاس"}
	var e1 := WarRules.estimate(_army(120), {}, {"beast": 15}, {"beast": guard}, false)
	var e2 := WarRules.estimate(_army(120), {}, {"beast": 15}, {"beast": guard}, false)
	check(e1["win_pct"] == e2["win_pct"] and e1["att_loss_pct"] == e2["att_loss_pct"], "estimate is deterministic for the same inputs")
	check(int(e1["win_pct"]) == 100, "120 troops vs 15 guards: certain win")
	var e3 := WarRules.estimate(_army(6), {}, {"beast": 40}, {"beast": guard}, false)
	check(int(e3["win_pct"]) == 0, "6 troops vs 40 guards: certain loss")
	check(int(e1["att_loss_pct"]) < int(e3["att_loss_pct"]), "the weaker side loses a bigger share")
	var e4 := WarRules.estimate({}, {}, {"beast": 15}, {"beast": guard}, false)
	check(int(e4["win_pct"]) == 0 and int(e4["samples"]) == 0, "estimate with no troops is zero")
	var more := WarRules.estimate(_army(60), {}, {"beast": 30}, {"beast": guard}, false)
	var less := WarRules.estimate(_army(30), {}, {"beast": 30}, {"beast": guard}, false)
	check(int(more["win_pct"]) >= int(less["win_pct"]), "more troops never lowers the win chance")

	# 4) تعبئة الجنود بنسبة
	var avail := {"shield_1": 50, "spear_1": 30, "bow_1": 20}
	var f50 := WarRules.quick_fill(avail, 0.5, 9999)
	check(_sum(f50) == 50, "quick fill 50% of 100 = 50 troops (got %d)" % _sum(f50))
	var f_cap := WarRules.quick_fill(avail, 1.0, 60)
	check(_sum(f_cap) == 60, "quick fill respects the march cap (got %d)" % _sum(f_cap))
	var within := true
	for k in f_cap:
		within = within and int(f_cap[k]) <= int(avail[k])
	check(within, "quick fill never exceeds availability per type")
	check(WarRules.quick_fill(avail, 0.0, 60).is_empty() and WarRules.quick_fill({}, 1.0, 60).is_empty(), "quick fill of zero / nothing is empty")
	check(_sum(WarRules.quick_fill(avail, 1.0, 9999)) == 100, "quick fill 100% takes everything when the cap allows")

	# 5) الحكم والاستخبارات
	check(WarRules.verdict(95)["text"] != WarRules.verdict(5)["text"] and WarRules.verdict(50)["color"] != WarRules.verdict(95)["color"], "verdict differs between certain win and certain loss")
	check(is_equal_approx(WarRules.intel_error(0), WarRules.INTEL_ERR_CAP), "no scout tower: intel error is capped, not 100%")
	check(WarRules.intel_error(1) <= WarRules.intel_error(0) and WarRules.intel_error(20) == 0.0, "scout tower improves intel down to exact")
	var rg := WarRules.enemy_range(20, 0.3)
	check(rg.x == 14 and rg.y == 26, "enemy range ±30 percent of 20 = 14..26 (got %d..%d)" % [rg.x, rg.y])
	check(WarRules.power_of({"shield_1": 10}) == int(round(10.0 * Defs.troop_power("shield", 1))), "power_of matches troop_power")

	# 6) حراس الهدف مصدر واحد للمعركة والمعاينة
	_fresh()
	var fl := maxi(Game.furnace_level(), 1)
	var ev := Game.venture_enemy({"kind": "vent"})
	check(int(ev["n"]) == int(Defs.VENT["guards"]) + 3 * fl, "vent guards = base + 3 per furnace level")
	check(is_equal_approx(float(ev["stats"]["atk"]), 10.0 * (1.0 + 0.12 * fl)), "vent guard attack scales with furnace")
	var eh := Game.venture_enemy({"kind": "hold", "id": "stronghold_1"})
	check(String(eh["type"]) == "stronghold" and int(eh["n"]) == int(Defs.HOLD_DEFS["stronghold"]["guards"]) + 2 * fl, "stronghold guards = base + 2 per furnace level")
	check(Game.venture_travel_time({"kind": "vent"}) >= 8.0, "travel time has a floor")

	# 7) معاينة الإرسال والدفاع المتبقي
	Game.troops["shield_1"] = 120
	Game.troops["spear_1"] = 60
	Game.troops["bow_1"] = 60
	Game.res["food"] = 99999.0
	var pv_none := Game.venture_preview({}, "balanced", {"kind": "vent"})
	var pv_some := Game.venture_preview({"shield_1": 60, "spear_1": 30, "bow_1": 30}, "balanced", {"kind": "vent"})
	var pv_all := Game.venture_preview({"shield_1": 120, "spear_1": 60, "bow_1": 60}, "balanced", {"kind": "vent"})
	check(int(pv_none["win_pct"]) == 0 and int(pv_none["remaining_total"]) == 240, "empty preview: no chance, everyone stays home")
	check(int(pv_some["remaining_total"]) == 120 and int(pv_some["enemy_n"]) == int(ev["n"]), "preview counts who stays home and the guards")
	check(int(pv_some["win_lo"]) <= int(pv_some["win_pct"]) and int(pv_some["win_pct"]) <= int(pv_some["win_hi"]), "win range brackets the estimate")
	check(int(pv_all["home_hold_pct"]) == 0 and int(pv_all["remaining_total"]) == 0, "sending everyone leaves the city without defense")
	check(int(pv_none["home_hold_pct"]) >= int(pv_some["home_hold_pct"]) and int(pv_some["home_hold_pct"]) >= int(pv_all["home_hold_pct"]), "city hold chance never rises when more troops leave")
	check(float(pv_some["round_trip"]) > float(pv_some["travel"]) * 2.0 - 0.001, "round trip includes both legs and the fight")
	check(int(pv_some["power"]) > 0 and int(pv_some["check"]["total"]) == 120, "preview reports power and march size")

	# 8) المعركة الفعلية عبر المحاكاة: ضعيفة تُصَدّ بلا خسارة غير مفسّرة، وقوية تنتصر
	_fresh()
	Game.troops["shield_1"] = 300
	Game.res["food"] = 99999.0
	Game.plots["wd1"] = 14
	check(Game.start_venture({"shield_1": 4}, "balanced", {"kind": "vent"}), "weak venture starts")
	Game.venture["arrive"] = Game.now() - 1.0
	Game.venture["back"] = Game.now() + 60.0
	Game._simulate(0.5, Game.now())
	var rep_w: Dictionary = Game.venture.get("report", {})
	check(not bool(Game.venture.get("won", true)) and not bool(Game.vent["captured"]), "weak venture fails and vent stays free")
	check(rep_w.has("retreated") and rep_w.has("guards") and rep_w.has("guards_left"), "report carries retreat flag and guard counts")
	var surv := _sum(Game.venture.get("survivors", {}))
	var lost_w := _sum(Game.venture.get("losses", {}))
	check(surv + lost_w == 4, "survivors + losses account for every sent troop (%d + %d)" % [surv, lost_w])
	Game.venture = {}
	check(Game.start_venture({"shield_1": 200}, "balanced", {"kind": "vent"}), "strong venture starts")
	Game.venture["arrive"] = Game.now() - 1.0
	Game.venture["back"] = Game.now() + 60.0
	Game._simulate(0.5, Game.now())
	check(bool(Game.venture.get("won", false)) and bool(Game.vent["captured"]), "strong venture captures the vent")
	check(int(Game.venture["report"].get("guards", 0)) == int(ev["n"]), "report guard count equals the preview's guard count")

	# 9) نافذة الإرسال
	check((load("res://scripts/map/map_venture.gd") as GDScript).can_instantiate(), "venture window script compiles")
	_fresh()
	Game.res = {"food": 5000.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	Game.troops["shield_1"] = 40
	Game.troops["spear_1"] = 40
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map._open_vent_window()
	await get_tree().process_frame
	check(map.vent_verdict != null and map.vent_verdict.text.find("فرصة النصر") >= 0, "window shows the win chance")
	check(map.vent_home != null and map.vent_home.text.find("صمودها") >= 0, "window shows the home defense left behind")
	var picked := 0
	for k in map.vent_spins:
		picked += int(map.vent_spins[k].value)
	check(picked > 0 and not map.vent_send_btn.disabled, "window opens with a recommended force already chosen (%d)" % picked)
	map._fill_fraction(1.0)
	var all_val := 0
	for k in map.vent_spins:
		all_val += int(map.vent_spins[k].value)
	check(all_val == 60, "max button respects the 60 march cap (got %d)" % all_val)
	map._fill_fraction(0.5)
	all_val = 0
	for k in map.vent_spins:
		all_val += int(map.vent_spins[k].value)
	check(all_val == 40, "50%% button fills 40 of 80 (got %d)" % all_val)
	check(map.vent_summary.text.find("40 / 60") >= 0, "summary shows sent size over cap")
	map._fill_fraction(0.0)
	check(map.vent_send_btn.disabled and map.vent_home.text == "", "zero troops: send disabled, no defense line")
	map._pick_formation("aggressive")
	map._fill_fraction(0.5)
	check(map.vent_verdict.text.find("فرصة النصر") >= 0, "changing formation refreshes the preview")
	map._close_vent_window()
	Game.venture = {"back": Game.now() + 100.0}
	map._open_vent_window()
	await get_tree().process_frame
	check(map.vent_send_btn.disabled, "send disabled while another venture is out")
	map._close_vent_window()
	Game.venture = {}
	map.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
