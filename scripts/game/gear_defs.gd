extends RefCounted
## Stage 29: pure equipment rules; separate from the large legacy Defs file.
const TYPES := ["shield", "spear", "bow"]
const SLOTS := ["weapon", "armor", "helmet", "rune"]
const MAX_LEVEL := 10
const NAMES := {
	"shield": ["سيف الحارس", "درع الحصن", "خوذة الصمود", "نقش الحماية"],
	"spear": ["رمح الجليد", "درع الطليعة", "خوذة الرماح", "نقش الاختراق"],
	"bow": ["قوس الصقيع", "درع الكشافة", "خوذة الرامي", "نقش الدقة"],
}
const EFFECTS := {"weapon": "atk", "armor": "def", "helmet": "hp", "rune": "damage"}
const LABELS := {"atk": "هجوم", "def": "دفاع", "hp": "صحة", "damage": "ضرر نهائي (عدا الوحوش)"}
const RATES := {"weapon": 0.012, "armor": 0.012, "helmet": 0.015, "rune": 0.01}
const BASE_COST := {
	"weapon": {"wood": 150, "iron": 80},
	"armor": {"iron": 120, "coal": 80},
	"helmet": {"iron": 90, "wood": 100},
	"rune": {"coal": 160, "iron": 100},
}


static func valid(tp: String, slot: String) -> bool:
	return TYPES.has(tp) and SLOTS.has(slot)


static func title(tp: String, slot: String) -> String:
	return str(NAMES[tp][SLOTS.find(slot)]) if valid(tp, slot) else ""


static func required_workshop(lv: int) -> int:
	return 3 * lv - 2


static func capacity(workshop: int) -> int:
	return 0 if workshop <= 0 else 1 + int(clampi(workshop, 0, 30) / 10.0)


static func cost(slot: String, lv: int) -> Dictionary:
	var out := {}
	for resource in BASE_COST[slot]:
		out[resource] = ceili(float(BASE_COST[slot][resource]) * pow(1.5, lv - 1))
	if slot == "rune" and lv >= 5:
		out["aurora"] = ceili(3.0 * pow(1.5, lv - 5))
	return out


static func duration(lv: int, workshop: int) -> float:
	return 120.0 * pow(1.65, lv - 1) / (1.0 + 0.03 * workshop)


static func blank() -> Dictionary:
	var out := {}
	for tp in TYPES:
		out[tp] = {}
		for slot in SLOTS:
			out[tp][slot] = 0
	return out


static func set_bonus(equipment: Dictionary, tp: String) -> float:
	var minimum := MAX_LEVEL
	for slot in SLOTS:
		minimum = mini(minimum, int(equipment.get(tp, {}).get(slot, 0)))
	if minimum >= 10:
		return 0.07
	if minimum >= 6:
		return 0.04
	return 0.02 if minimum >= 3 else 0.0


static func bonuses(equipment: Dictionary, tp: String) -> Dictionary:
	var b := set_bonus(equipment, tp)
	var out := {"atk": b, "def": b, "hp": b, "damage": 0.0, "power": 0.0}
	for slot in SLOTS:
		var lv := int(equipment.get(tp, {}).get(slot, 0))
		out[EFFECTS[slot]] += lv * float(RATES[slot])
		out["power"] += lv * 14.0
	out["power"] *= 1.0 + b
	return out
