extends RefCounted
## Stage 24 — الملف الشخصي (بند 2.38، الحزمتان P1 الهوية وP2 البطاقة): قواعد الاسم والمعرّف والصورة الرمزية

const NAME_MIN := 3
const NAME_MAX := 16
const DEFAULT_NAME := "القائد"
const Achievements := preload("res://scripts/game/achievements.gd")


static func new_profile(unix_now: float) -> Dictionary:
	## ملف جديد: اسم افتراضي، صورة تلقائية (قائد الدفاع/الحاكم)، معرّف ثابت من 6 أرقام
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {"name": DEFAULT_NAME, "avatar": "", "id": rng.randi_range(100000, 999999), "created": unix_now,
		"badges": [], "title": "", "frame": ""}


static func sanitize(raw: Variant, unix_now: float) -> Dictionary:
	## يُصلح أي قيمة محمّلة من الحفظ (قديمة أو ناقصة أو عبثية) ويُبقي ما صحّ منها
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var out := new_profile(unix_now)
	var nm := check_name(str(d.get("name", "")))
	if nm["ok"]:
		out["name"] = nm["name"]
	out["avatar"] = str(d.get("avatar", ""))
	var pid := int(d.get("id", 0))
	if pid >= 100000 and pid <= 999999:
		out["id"] = pid
	var cr := float(d.get("created", 0.0))
	if cr > 0.0 and cr <= unix_now + 86400.0:
		out["created"] = cr
	Achievements.sanitize(out, d)
	return out


static func check_name(raw: String) -> Dictionary:
	## {ok, name, reason}: يقصّ الفراغات الزائدة ويدمج المتتالية، 3–16 حرفًا، بلا أسطر أو رموز تحكم
	var s := raw.strip_edges()
	for bad in ["\n", "\r", "\t"]:
		s = s.replace(bad, " ")
	while s.find("  ") >= 0:
		s = s.replace("  ", " ")
	for i in s.length():
		var code := s.unicode_at(i)
		if code < 32 or (code >= 127 and code < 160) or code == 0x200E or code == 0x200F or code == 0x202E or code == 0x202D:
			return {"ok": false, "name": s, "reason": "الاسم يحتوي رموزًا غير مسموحة"}
	if s.length() < NAME_MIN:
		return {"ok": false, "name": s, "reason": "الاسم أقصر من %d أحرف" % NAME_MIN}
	if s.length() > NAME_MAX:
		return {"ok": false, "name": s, "reason": "الاسم أطول من %d حرفًا" % NAME_MAX}
	return {"ok": true, "name": s, "reason": ""}


static func play_days(created: float, unix_now: float) -> int:
	return maxi(int(floor((unix_now - created) / 86400.0)) + 1, 1)
