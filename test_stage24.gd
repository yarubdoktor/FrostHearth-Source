extends Node
## اختبار Stage 24 — الملف الشخصي (2.38: P1 الهوية + P2 البطاقة)
## التشغيل: godot --headless --path . res://test_stage24.tscn

const Defs := preload("res://scripts/defs.gd")
const Profile := preload("res://scripts/game/profile.gd")

var checks := 0
var failures := 0
var toasts: Array[String] = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _on_toast(msg: String) -> void:
	toasts.append(msg)


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage24.json"
	Game.dev_mode = false
	Game.profile = {}
	Game.new_game()
	Game.set_process(false)


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null


func _has_label(n: Node, part: String) -> bool:
	if n is Label and (n as Label).text.find(part) >= 0:
		return true
	for c in n.get_children():
		if _has_label(c, part):
			return true
	return false


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	Game.toast.connect(_on_toast)
	# 1) قواعد الاسم
	check(Profile.check_name("  أحمد  ")["name"] == "أحمد", "name is trimmed")
	check(Profile.check_name("قائد   الثلج")["name"] == "قائد الثلج", "inner spaces collapse")
	check(not Profile.check_name("ab")["ok"], "2-char name rejected")
	check(Profile.check_name("abc")["ok"], "3-char name accepted")
	check(Profile.check_name("1234567890123456")["ok"], "16-char name accepted")
	check(not Profile.check_name("12345678901234567")["ok"], "17-char name rejected")
	check(not Profile.check_name("   ")["ok"], "blank name rejected")
	check(not Profile.check_name("اسم\u202eمعكوس")["ok"], "bidi override char rejected")
	check(Profile.check_name("القائد الأول")["ok"], "arabic name with a space accepted")
	check(Profile.play_days(1000.0, 1000.0) == 1 and Profile.play_days(1000.0, 1000.0 + 86400.0 * 2.5) == 3, "play days count from 1")
	var np := Profile.new_profile(5000.0)
	check(int(np["id"]) >= 100000 and int(np["id"]) <= 999999, "new id has six digits")
	check(Profile.sanitize({"name": "x", "id": 5, "created": -3, "avatar": 7}, 9000.0)["name"] == Profile.DEFAULT_NAME, "bad saved name falls back to default")
	check(int(Profile.sanitize({"id": 123456}, 9000.0)["id"]) == 123456, "valid saved id is kept")
	check(Profile.sanitize("garbage", 9000.0).has("id"), "non-dictionary profile is repaired")

	# 2) اللعبة
	_fresh()
	check(Game.profile_name() == Profile.DEFAULT_NAME, "new game has the default name")
	var pid := int(Game.profile["id"])
	check(pid >= 100000, "new game has an id")
	toasts.clear()
	check(not Game.set_profile_name("ab"), "short name refused by the game")
	check(toasts.size() > 0 and String(toasts[-1]).find("أقصر") >= 0, "toast explains the short name")
	check(Game.set_profile_name("  حارس الثلج "), "valid name accepted")
	check(Game.profile_name() == "حارس الثلج", "name stored trimmed")
	check(not Game.set_profile_avatar("not_a_hero"), "unknown avatar refused")
	var hid := String(Defs.HERO_ORDER[0])
	check(not Game.set_profile_avatar(hid), "unowned hero avatar refused")
	Game.heroes[hid]["owned"] = true
	check(Game.set_profile_avatar(hid) and Game.profile_avatar_id() == hid, "owned hero avatar accepted")
	check(Game.owned_hero_ids().has(hid), "owned list contains the hero")
	Game.heroes[hid]["owned"] = false
	check(Game.profile_avatar_id() == (Game.defender if Game.defender != "" else Game.governor), "lost hero falls back to automatic avatar")
	Game.heroes[hid]["owned"] = true
	# الحفظ والتحميل
	Game.save_game()
	Game.profile = {}
	Game.load_game()
	check(Game.profile_name() == "حارس الثلج" and int(Game.profile["id"]) == pid and str(Game.profile["avatar"]) == hid, "name, id and avatar persist")
	# لعبة جديدة لا تمس الهوية
	var created := float(Game.profile["created"])
	Game.new_game()
	check(Game.profile_name() == "حارس الثلج" and int(Game.profile["id"]) == pid and float(Game.profile["created"]) == created, "new game keeps the identity")
	# حفظ قديم (v5) بلا profile
	var f := FileAccess.open("user://frost_save_test_stage24.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.erase("profile")
	data["v"] = 5
	var fw := FileAccess.open("user://frost_save_test_stage24.json", FileAccess.WRITE)
	fw.store_string(JSON.stringify(data))
	fw.close()
	Game.profile = {}
	check(Game.load_game(), "v5 save without profile loads")
	check(Game.profile_name() == Profile.DEFAULT_NAME and int(Game.profile["id"]) >= 100000, "old save gets a default profile")
	var id2 := int(Game.profile["id"])
	Game.save_game()
	Game.profile = {}
	Game.load_game()
	check(int(Game.profile["id"]) == id2, "migrated id stays stable after saving")
	check(Game.SAVE_VERSION >= 6, "save schema retains profile support (v6 or later)")

	# 3) البطاقة
	_fresh()
	Game.plots["furnace"] = 5
	Game.troops["shield_1"] = 12
	Game.raid_wins = 3
	Game.raid_count = 4
	Game.techs[String(Defs.TECHS.keys()[0])] = 2
	var cd := Game.profile_card()
	check(cd["furnace"] == 5 and cd["troops"] >= 12 and cd["raids_won"] == 3 and cd["raids"] == 4, "card reads furnace, troops and raids")
	check(cd["techs"] == 1 and cd["days"] == 1 and float(cd["power"]) > 0.0, "card reads techs, days and power")

	# 4) الواجهة
	_fresh()
	Game.res = {"food": 9999.0, "wood": 9999.0, "coal": 9999.0, "iron": 9999.0}
	Game.heroes[hid]["owned"] = true
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	city.avatar_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(city.win_dim), "avatar opens the profile window")
	check(_has_label(city.win_dim, "المعرّف  #%d" % int(Game.profile["id"])), "window shows the player id")
	check(_has_label(city.win_dim, "قوة المدينة") and _has_label(city.win_dim, "أيام اللعب"), "window shows the player card")
	var edit := _find(city.win_dim, "NameEdit") as LineEdit
	check(edit != null, "name field exists")
	edit.text = "قائد الشمال"
	(_find(city.win_dim, "SaveName") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.profile_name() == "قائد الشمال", "saving from the window changes the name")
	check(_has_label(city.win_dim, "قائد الشمال"), "window refreshes with the new name")
	edit = _find(city.win_dim, "NameEdit") as LineEdit
	edit.text = "x"
	(_find(city.win_dim, "SaveName") as Button).pressed.emit()
	await get_tree().process_frame
	check(Game.profile_name() == "قائد الشمال", "invalid name from the window is ignored")
	var avb := _find(city.win_dim, "Av_" + hid) as Button
	check(avb != null, "owned hero appears among avatar choices")
	if avb != null:
		avb.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	check(str(Game.profile["avatar"]) == hid and city.avatar_id == hid, "picking a hero changes the profile and the HUD avatar")
	var gear := _find(city.win_dim, "SettingsBtn") as Button
	check(gear != null, "settings button inside the profile")
	var r := (city.win_dim as Control).get_global_rect()
	check(r.position.x >= 0.0 and r.end.x <= 720.0 + 1.0, "profile window fits 720 px")
	if gear != null:
		gear.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	var found_audio := false
	var stack: Array = [city.modal_layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text == "الصوت":
			found_audio = true
		stack.append_array(n.get_children())
	check(found_audio, "settings button opens settings")

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
