extends RefCounted
## تعريفات اللعبة: المباني، والمواقع، والتكاليف، والمهام.
## عدّل الأرقام هنا لموازنة اللعبة دون لمس بقية الكود.

const RES := ["food", "wood", "coal", "iron"]
const RES_NAMES := {"food": "طعام", "wood": "خشب", "coal": "فحم", "iron": "حديد", "gems": "جواهر", "aurora": "بلورات الشفق",
		"trust": "ثقة الناس", "pop": "ناجين", "sick": "مرضى", "wounded": "جرحى", "shards": "شظايا"}

const CITY_CENTER := Vector3(60, 0, 60)

## type: الإنتاج (prod) أو غيره. max: أعلى مستوى. cost: تكلفة المستوى الأول. from: المستوى الذي تبدأ فيه تكلفة هذا المورد
const BUILDINGS := {
	"furnace": {"name": "الفرن المركزي", "max": 30, "time": 20.0,
		"cost": {"wood": 260, "coal": 90, "iron": 60}, "from": {"wood": 2, "coal": 3, "iron": 6},
		"desc": "قلب المدينة. يدفئ السكان ويحدد أعلى مستوى لبقية المباني."},
	"shelter": {"name": "مأوى", "max": 30, "time": 8.0,
		"cost": {"wood": 50, "coal": 20, "iron": 20}, "from": {"wood": 1, "coal": 4, "iron": 8},
		"desc": "يؤوي الناجين. أربعة مآوٍ فقط في المدينة، وكل مستوى يزيد سعتها كثيرًا."},
	"hunter": {"name": "كوخ الصيادين", "max": 30, "time": 9.0, "prod": "food", "rate": 720.0,
		"cost": {"wood": 60, "coal": 25, "iron": 20}, "from": {"wood": 1, "coal": 3, "iron": 7},
		"desc": "ينتج الطعام. يحتاج عمالًا من السكان الأصحاء."},
	"sawmill": {"name": "المنشرة", "max": 30, "time": 9.0, "prod": "wood", "rate": 600.0,
		"cost": {"wood": 45, "coal": 25, "iron": 20}, "from": {"wood": 1, "coal": 3, "iron": 7},
		"desc": "تقطع الخشب اللازم للبناء."},
	"coal_mine": {"name": "منجم الفحم", "max": 30, "time": 10.0, "pace": 0.9, "prod": "coal", "rate": 330.0,
		"cost": {"wood": 120, "coal": 30, "iron": 25}, "from": {"wood": 1, "coal": 4, "iron": 7},
		"desc": "يستخرج الفحم وقود الفرن. بدونه تتجمد المدينة."},
	"iron_mine": {"name": "منجم الحديد", "max": 30, "time": 14.0, "pace": 0.35, "prod": "iron", "rate": 140.0,
		"cost": {"wood": 420, "coal": 160, "iron": 40}, "from": {"wood": 1, "coal": 1, "iron": 6},
		"desc": "يستخرج الحديد للمباني المتقدمة."},
	"storehouse": {"name": "المخزن", "max": 30, "time": 12.0, "pace": 0.6,
		"cost": {"wood": 220, "coal": 60, "iron": 40}, "from": {"wood": 1, "coal": 2, "iron": 6},
		"desc": "يزيد سعة تخزين مباني الإنتاج، فتتحمل غيابك مدة أطول."},
	"infirmary": {"name": "المستوصف", "max": 30, "time": 12.0, "pace": 0.45,
		"cost": {"wood": 300, "coal": 90, "iron": 40}, "from": {"wood": 1, "coal": 1, "iron": 6},
		"desc": "يعالج المرضى المصابين بالبرد والجنود الجرحى ويعيدهم."},
	"barracks": {"name": "المعسكر", "max": 30, "time": 14.0, "pace": 0.4,
		"cost": {"wood": 380, "coal": 120, "iron": 50}, "from": {"wood": 1, "coal": 1, "iron": 4},
		"desc": "مكان تجمّع القوات واستعراضها. مستواه يحدد سعة الجيش، وفيه تُراجع أعداد الجنود ورتبهم وتفاصيلهم."},
	"bk_shield": {"name": "ثكنة الدروع", "max": 30, "time": 14.0, "pace": 0.5,
		"cost": {"wood": 300, "coal": 100, "iron": 40}, "from": {"wood": 1, "coal": 1, "iron": 4},
		"desc": "تدرّب حاملي الدروع. المستوى يسرّع التدريب، ويكبّر الدفعة، ويفتح رتبًا أقوى."},
	"bk_spear": {"name": "ثكنة الرماح", "max": 30, "time": 14.0, "pace": 0.45,
		"cost": {"wood": 320, "coal": 110, "iron": 45}, "from": {"wood": 1, "coal": 1, "iron": 4},
		"desc": "تدرّب الرمّاحين. المستوى يسرّع التدريب، ويكبّر الدفعة، ويفتح رتبًا أقوى."},
	"bk_bow": {"name": "ميدان الرماة", "max": 30, "time": 14.0, "pace": 0.45,
		"cost": {"wood": 340, "coal": 110, "iron": 45}, "from": {"wood": 1, "coal": 1, "iron": 4},
		"desc": "تدرّب الرماة. المستوى يسرّع التدريب، ويكبّر الدفعة، ويفتح رتبًا أقوى."},
	"hero_hall": {"name": "قاعة الأبطال", "max": 30, "time": 16.0, "pace": 0.35,
		"cost": {"wood": 520, "coal": 160, "iron": 80}, "from": {"wood": 1, "coal": 1, "iron": 1},
		"desc": "مقر الأبطال. كل مستوى يرفع الحد الأعلى لمستوى الأبطال بخمسة."},
	"lab": {"name": "مختبر الجمر", "max": 30, "time": 16.0, "pace": 0.3,
		"cost": {"wood": 600, "coal": 200, "iron": 90}, "from": {"wood": 1, "coal": 1, "iron": 1},
		"desc": "يطوّر تقنيات الاقتصاد والبقاء والحرب. مستواه يفتح أبحاثًا أعمق."},
	"workshop": {"name": "الورشة الحربية", "max": 30, "time": 15.0, "pace": 0.4,
		"cost": {"wood": 400, "coal": 140, "iron": 70}, "from": {"wood": 1, "coal": 1, "iron": 4},
		"desc": "تصنع تجهيزات الجنود: دروع مقوّاة ورماحًا مشحوذة وأقواسًا أمتن، وتفتح أبحاث الحرب العليا."},
	"market": {"name": "السوق", "max": 30, "time": 15.0, "pace": 0.4,
		"cost": {"wood": 420, "coal": 130, "iron": 60}, "from": {"wood": 1, "coal": 1, "iron": 5},
		"desc": "تبادل الموارد بأسعار تتغير مع الوقت والطقس. المستوى يخفض رسوم التبادل ويرفع حصة التبادل."},
	"scout_tower": {"name": "برج الاستطلاع", "max": 30, "time": 14.0, "pace": 0.4,
		"cost": {"wood": 340, "coal": 110, "iron": 50}, "from": {"wood": 1, "coal": 1, "iron": 5},
		"desc": "عين المدينة. يكشف الخريطة حول مدينتك، وينذرك بالغارات قبل وقوعها مع تقدير لعدد الذئاب."},
	"war_depot": {"name": "المستودع الحربي", "max": 30, "time": 15.0, "pace": 0.4,
		"cost": {"wood": 380, "coal": 120, "iron": 60}, "from": {"wood": 1, "coal": 1, "iron": 5},
		"desc": "يخزن مؤن الحملات ويحدد حجم المسيرات العسكرية: كل مستوى يرفع عدد الجنود المسموح بإرسالهم ويخفض تكلفة المؤن."},
	"wall": {"name": "السور والأبراج", "max": 30, "time": 16.0, "pace": 0.45,
		"cost": {"wood": 360, "coal": 100, "iron": 60}, "from": {"wood": 1, "coal": 1, "iron": 1},
		"desc": "سور المدينة عند البوابة الرئيسية. كل مستوى يعزز دفاع الجنود الحاضرين 2% وهجومهم من الأبراج 1%، وكل مرحلة جديدة تغيّر شكل السور كله وتضيف مكافأة. لا يقاتل بلا جنود."},
}

## مواقع البناء الثابتة: المعرّف ← النوع، والزاوية بالدرجات، ونصف القطر، ومستوى الفرن المطلوب
const PLOTS := {
	"furnace": {"type": "furnace", "a": 0.0, "r": 0.0, "unlock": 0},
	"sh1": {"type": "shelter", "a": 0.0, "r": 17.0, "unlock": 1},
	"sh2": {"type": "shelter", "a": 60.0, "r": 17.0, "unlock": 1},
	"sh3": {"type": "shelter", "a": 120.0, "r": 17.0, "unlock": 2},
	"sh4": {"type": "shelter", "a": 180.0, "r": 17.0, "unlock": 3},
	"hu1": {"type": "hunter", "a": 15.0, "r": 30.5, "unlock": 1},
	"sa1": {"type": "sawmill", "a": 45.0, "r": 30.5, "unlock": 1},
	"co1": {"type": "coal_mine", "a": 75.0, "r": 30.5, "unlock": 2},
	"hu2": {"type": "hunter", "a": 105.0, "r": 30.5, "unlock": 3},
	"sa2": {"type": "sawmill", "a": 135.0, "r": 30.5, "unlock": 3},
	"ir1": {"type": "iron_mine", "a": 165.0, "r": 30.5, "unlock": 4},
	"st1": {"type": "storehouse", "a": 195.0, "r": 30.5, "unlock": 2},
	"co2": {"type": "coal_mine", "a": 225.0, "r": 30.5, "unlock": 5},
	"in1": {"type": "infirmary", "a": 255.0, "r": 30.5, "unlock": 3},
	"hu3": {"type": "hunter", "a": 285.0, "r": 30.5, "unlock": 7},
	"sa3": {"type": "sawmill", "a": 315.0, "r": 30.5, "unlock": 8},
	"ir2": {"type": "iron_mine", "a": 345.0, "r": 30.5, "unlock": 10},
	"ba1": {"type": "barracks", "a": 0.0, "r": 41.0, "unlock": 3},
	"bs1": {"type": "bk_shield", "a": 60.0, "r": 41.0, "unlock": 3},
	"bp1": {"type": "bk_spear", "a": 120.0, "r": 41.0, "unlock": 4},
	"bb1": {"type": "bk_bow", "a": 300.0, "r": 41.0, "unlock": 5},
	"hh1": {"type": "hero_hall", "a": 270.0, "r": 41.0, "unlock": 4},
	"lb1": {"type": "lab", "a": 180.0, "r": 41.0, "unlock": 5},
	"sk1": {"type": "scout_tower", "a": 150.0, "r": 41.0, "unlock": 6},
	"mk1": {"type": "market", "a": 205.0, "r": 41.0, "unlock": 8},
	"wd1": {"type": "war_depot", "a": 30.0, "r": 41.0, "unlock": 7},
	"wk1": {"type": "workshop", "a": 330.0, "r": 41.0, "unlock": 5},
	"wl1": {"type": "wall", "a": 90.0, "r": 46.0, "unlock": 3},   # المرحلة 26: عند البوابة الرئيسية (جنوب +Z)
}

## مواقع أُلغيت (المآوي صارت 4 فقط) — تُعاد تكلفتها كاملة عند ترحيل حفظ قديم
const REMOVED_PLOTS := {"sh5": "shelter", "sh6": "shelter", "sh7": "shelter", "sh8": "shelter", "sh9": "shelter", "sh10": "shelter"}

## مهام الفصل بالترتيب. الأنواع: level (أعلى مستوى لنوع) • count (عدد المباني المبنية) • pop • temp • collect • march
const TASKS := [
	{"text": "ابنِ أول مأوى للناجين", "type": "count", "b": "shelter", "n": 1, "reward": {"wood": 300, "gems": 20}},
	{"text": "ابنِ كوخ الصيادين", "type": "count", "b": "hunter", "n": 1, "reward": {"food": 600, "wood": 200}},
	{"text": "ابنِ المنشرة", "type": "count", "b": "sawmill", "n": 1, "reward": {"wood": 400}},
	{"text": "اجمع 500 خشب من المباني", "type": "collect", "r": "wood", "n": 500, "reward": {"wood": 500, "gems": 20}},
	{"text": "طوّر الفرن إلى المستوى 2", "type": "level", "b": "furnace", "n": 2, "reward": {"coal": 400, "gems": 30}},
	{"text": "ابنِ منجم الفحم", "type": "count", "b": "coal_mine", "n": 1, "reward": {"coal": 500}},
	{"text": "ابنِ المخزن", "type": "count", "b": "storehouse", "n": 1, "reward": {"wood": 800, "food": 800}},
	{"text": "ابنِ مأويين", "type": "count", "b": "shelter", "n": 2, "reward": {"wood": 600, "gems": 20}},
	{"text": "طوّر الفرن إلى المستوى 3", "type": "level", "b": "furnace", "n": 3, "reward": {"coal": 800, "iron": 200, "gems": 40}},
	{"text": "ابنِ المستوصف", "type": "count", "b": "infirmary", "n": 1, "reward": {"food": 1500, "wood": 800}},
	{"text": "اجعل حرارة المدينة فوق 0°", "type": "temp", "n": 0, "reward": {"coal": 1000, "gems": 30}},
	{"text": "وصّل عدد السكان إلى 20", "type": "pop", "n": 20, "reward": {"food": 2500, "gems": 30}},
	{"text": "أرسل فرقة جمع من الخريطة", "type": "march", "n": 1, "reward": {"wood": 1500, "gems": 30}},
	{"text": "طوّر كوخ الصيادين إلى 4", "type": "level", "b": "hunter", "n": 4, "reward": {"food": 3000}},
	{"text": "طوّر الفرن إلى المستوى 4", "type": "level", "b": "furnace", "n": 4, "reward": {"iron": 500, "gems": 50}},
	{"text": "ابنِ منجم الحديد", "type": "count", "b": "iron_mine", "n": 1, "reward": {"iron": 600, "coal": 1200}},
	{"text": "اجمع 5000 طعام", "type": "collect", "r": "food", "n": 5000, "reward": {"wood": 3000, "gems": 40}},
	{"text": "طوّر الفرن إلى المستوى 5", "type": "level", "b": "furnace", "n": 5, "reward": {"iron": 1000, "gems": 60}},
	{"text": "ابنِ 4 مآوٍ", "type": "count", "b": "shelter", "n": 4, "reward": {"wood": 5000, "food": 5000}},
	{"text": "وصّل عدد السكان إلى 60", "type": "pop", "n": 60, "reward": {"coal": 5000, "gems": 80}},
	{"text": "طوّر الفرن إلى المستوى 7", "type": "level", "b": "furnace", "n": 7, "reward": {"iron": 3000, "gems": 100}},
	{"text": "اجمع 10000 فحم", "type": "collect", "r": "coal", "n": 10000, "reward": {"iron": 2500, "gems": 60}},
	{"text": "طوّر الفرن إلى المستوى 10", "type": "level", "b": "furnace", "n": 10, "reward": {"gems": 300}},
]

## مهام الفصل الثاني: الجيش والأبطال والأبحاث (تُعرض بعد الفصل الأول أو بالتوازي معه حين يُبنى المعسكر)
const TASKS2 := [
	{"text": "ابنِ المعسكر", "type": "count", "b": "barracks", "n": 1, "reward": {"food": 2000, "iron": 200, "gems": 30}},
	{"text": "درّب 30 جنديًا", "type": "train", "n": 30, "reward": {"food": 3000, "wood": 1500}},
	{"text": "ابنِ قاعة الأبطال", "type": "count", "b": "hero_hall", "n": 1, "reward": {"shards_siraj": 10, "gems": 40}},
	{"text": "انضم إليك بطلك الأول", "type": "hero", "n": 1, "reward": {"aurora": 40, "food": 2000}},
	{"text": "عيّن بطلًا قائدًا للدفاع", "type": "defender", "n": 1, "reward": {"iron": 400, "gems": 20}},
	{"text": "اجمع 30 بلورة شفق من العواصف", "type": "aurora", "n": 30, "reward": {"aurora": 30, "gems": 30}},
	{"text": "اتخذ قرارًا في دفتر القائد", "type": "decision", "n": 1, "reward": {"food": 2500, "wood": 2500}},
	{"text": "اصمد أمام غارة ذئاب", "type": "raid_win", "n": 1, "reward": {"iron": 800, "aurora": 20, "gems": 40}},
	{"text": "ابنِ مختبر الجمر", "type": "count", "b": "lab", "n": 1, "reward": {"coal": 3000, "gems": 40}},
	{"text": "أكمل بحثًا واحدًا", "type": "research", "n": 1, "reward": {"wood": 4000, "iron": 600}},
	{"text": "طوّر بطلًا إلى المستوى 5", "type": "hero_lv", "n": 5, "reward": {"aurora": 40, "gems": 40}},
	{"text": "عيّن حاكمًا للمدينة", "type": "governor", "n": 1, "reward": {"food": 5000, "gems": 30}},
	{"text": "درّب 150 جنديًا", "type": "train", "n": 150, "reward": {"iron": 2000, "gems": 60}},
	{"text": "وصّل قوة المدينة إلى 5000", "type": "power", "n": 5000, "reward": {"aurora": 60, "gems": 80}},
	{"text": "اصمد أمام 3 غارات", "type": "raid_win", "n": 3, "reward": {"iron": 3000, "gems": 80}},
	{"text": "أكمل 8 مستويات أبحاث", "type": "research", "n": 8, "reward": {"aurora": 80, "gems": 100}},
	{"text": "اجمع بطلين", "type": "hero", "n": 2, "reward": {"gems": 150}},
	{"text": "طوّر المعسكر إلى المستوى 6", "type": "level", "b": "barracks", "n": 6, "reward": {"iron": 5000, "gems": 120}},
]

# ================================================================ الجيش
## مثلث التفوق: الرمح يخترق الدرع • الدرع يصد السهام • السهم يصيب الرماح
const TROOPS := {
	"shield": {"name": "حامل الدرع", "plural": "الدروع", "atk": 8.0, "def": 14.0, "hp": 30.0, "row": 0, "beats": "bow",
		"cost": {"food": 40, "wood": 25, "iron": 3}, "time": 2.5,
		"desc": "الصف الأول. يتحمل الضربات ويصد السهام. أقوى دفاعًا وقت العاصفة."},
	"spear": {"name": "الرمّاح", "plural": "الرمّاحون", "atk": 13.0, "def": 9.0, "hp": 24.0, "row": 1, "beats": "shield",
		"cost": {"food": 45, "wood": 30, "iron": 4}, "time": 2.8,
		"desc": "الصف الثاني. رماحه تخترق الدروع، وتتفوق على الوحوش."},
	"bow": {"name": "الرامي", "plural": "الرماة", "atk": 16.0, "def": 5.0, "hp": 18.0, "row": 2, "beats": "spear",
		"cost": {"food": 50, "wood": 35, "iron": 2}, "time": 3.2,
		"desc": "الصف الخلفي. ضرره الأعلى ويصيب الرمّاحين، لكن العاصفة تضعف سهامه."},
}
const TROOP_ORDER := ["shield", "spear", "bow"]
## كل نوع جنود يُدرَّب في ثكنته الخاصة (نوع المبنى + موقعه)
const BARRACKS_TYPE := {"shield": "bk_shield", "spear": "bk_spear", "bow": "bk_bow"}
const BARRACKS_PLOT := {"shield": "bs1", "spear": "bp1", "bow": "bb1"}
const TIER_NAMES := ["", "مجنّد", "محارب", "نخبة", "حارس الجمر"]
const TIER_BARRACKS := [0, 1, 6, 12, 18]
const COUNTER_BONUS := 1.35

static func tier_mult(t: int) -> float:
	return pow(1.5, t - 1)

## Stage 17: تكلفة الجندي تتضاعف ×2.2 لكل رتبة (كانت ×1.7) كي لا تصير النخبة رخيصة قياسًا بزمنها (×3 لكل رتبة)
const TROOP_COST_TIER_GROWTH := 2.2

static func troop_cost(type: String, tier: int, n: int) -> Dictionary:
	var out := {}
	for r in TROOPS[type]["cost"]:
		out[r] = int(ceil(float(TROOPS[type]["cost"][r]) * pow(TROOP_COST_TIER_GROWTH, tier - 1) * n))
	return out

## المرحلة 2 (الموازنة): كل رتبة أطول من سابقتها 3 أضعاف للجندي الواحد (تكلفتها 1.7 فقط)، فالنخبة بالمئات تأخذ ساعات
const TROOP_TIER_TIME := 3.0

static func troop_time(type: String, tier: int, n: int) -> float:
	return float(TROOPS[type]["time"]) * pow(TROOP_TIER_TIME, tier - 1) * n

static func troop_power(type: String, tier: int) -> float:
	var t: Dictionary = TROOPS[type]
	return (float(t["atk"]) + float(t["def"]) + float(t["hp"]) / 3.0) * tier_mult(tier) * 0.25

static func train_batch(barracks_lv: int) -> int:
	## حجم الدفعة لثكنة واحدة
	return 0 if barracks_lv <= 0 else 20 + 10 * barracks_lv

static func barracks_speed(barracks_lv: int) -> float:
	## مضاعف سرعة التدريب لثكنة بهذا المستوى (المستوى 1 = ×1)
	return 1.0 + 0.06 * maxf(float(barracks_lv) - 1.0, 0.0)

static func camp_capacity(camp_lv: int) -> int:
	## سعة المعسكر من الجنود (الموجودين + قيد التدريب + في مهمة)
	return 0 if camp_lv <= 0 else 80 + 70 * camp_lv

## Stage 18 — السور والأبراج مبنى واحد، بلا حامية أو جنود مجانية.
const WALL_PLOT := "wl1"
const WALL_DEF_PER_LEVEL := 0.02
const TOWER_ATK_PER_LEVEL := 0.01

## Stage 26 — السور الحقيقي: حلقة حول المدينة بخمس مراحل، تُلمس للتطوير، وترتبط بمستوى الفرن في الاتجاهين
## from = أول مستوى للسور في المرحلة • furnace = أدنى فرن لدخول المرحلة • def/atk = مكافأة ثابتة لكل مرحلة تُضاف لمكافأة المستويات
## cost/time = مضاعف التكلفة والمدة لمستويات المرحلة (الصعوبة تتصاعد)
const WALL_STAGES := [
	{"name": "سياج خشبي", "from": 0, "furnace": 0, "def": 0.0, "atk": 0.0, "cost": 1.0, "time": 1.0},
	{"name": "سور خشبي مقوّى", "from": 1, "furnace": 3, "def": 0.02, "atk": 0.01, "cost": 1.0, "time": 1.0},
	{"name": "سور حجري", "from": 8, "furnace": 10, "def": 0.04, "atk": 0.03, "cost": 1.25, "time": 1.2},
	{"name": "سور حجري بأبراج", "from": 15, "furnace": 17, "def": 0.07, "atk": 0.05, "cost": 1.6, "time": 1.5},
	{"name": "قلعة", "from": 23, "furnace": 25, "def": 0.10, "atk": 0.08, "cost": 2.1, "time": 1.9},
]
## الاتجاه المعاكس: مستوى الفرن الهدف ← أدنى مرحلة سور مطلوبة (كل شرط أعلى من فرن دخول تلك المرحلة فلا حلقة مغلقة)
const FURNACE_NEEDS_WALL := {12: 1, 19: 2, 27: 3, 30: 4}
const WALL_RING_R := 46.0

static func wall_stage(lv: int) -> int:
	var st := 0
	for i in WALL_STAGES.size():
		if lv >= int(WALL_STAGES[i]["from"]):
			st = i
	return st

static func wall_stage_entry(nxt: int) -> int:
	## إن كان nxt أول مستوى في مرحلة جديدة (>0) تُعاد المرحلة وإلا -1
	for i in range(1, WALL_STAGES.size()):
		if nxt == int(WALL_STAGES[i]["from"]):
			return i
	return -1

static func furnace_wall_need(nxt: int) -> int:
	var need := 0
	for k in FURNACE_NEEDS_WALL:
		if nxt >= int(k):
			need = maxi(need, int(FURNACE_NEEDS_WALL[k]))
	return need

static func wall_bonuses(lv: int) -> Dictionary:
	var n := clampi(lv, 0, int(BUILDINGS["wall"]["max"]))
	var st: Dictionary = WALL_STAGES[wall_stage(n)] if n > 0 else WALL_STAGES[0]
	return {"def": n * WALL_DEF_PER_LEVEL + float(st["def"]), "atk": n * TOWER_ATK_PER_LEVEL + float(st["atk"])}

static func on_wall_ring(x: float, z: float) -> bool:
	var d := Vector2(x - CITY_CENTER.x, z - CITY_CENTER.z).length()
	return absf(d - WALL_RING_R) < 2.6

## Stage 19 — الورشة الحربية: تجهيزات لكل نوع جنود، ثابتة لكل مستوى (تضاف إلى معدّلات الأبحاث والقائد)
const WORKSHOP_GEAR := {
	"shield": {"name": "دروع مقوّاة", "def": 0.010, "hp": 0.006},
	"spear": {"name": "رماح مشحوذة", "atk": 0.010, "hp": 0.004},
	"bow": {"name": "أقواس أمتن", "atk": 0.010, "def": 0.004},
}

static func workshop_gear(tp: String, lv: int) -> Dictionary:
	## ما تضيفه الورشة بمستوى lv لنوع الجنود tp: {atk, def, hp}
	var n := clampi(lv, 0, int(BUILDINGS["workshop"]["max"]))
	var g: Dictionary = WORKSHOP_GEAR[tp]
	return {"atk": n * float(g.get("atk", 0.0)), "def": n * float(g.get("def", 0.0)), "hp": n * float(g.get("hp", 0.0))}

## أبحاث الدفاع (فرع 3): كل ثلاثة مستويات تتطلب مرحلة سور أعلى (م1–3 ← مرحلة 1، م4–6 ← 2، م7–9 ← 3، م10–12 ← 4)
static func tech_wall_req(id: String, lv: int) -> int:
	if int(TECHS[id]["branch"]) != 3:
		return 0
	return clampi(int(ceil(lv / 3.0)), 1, WALL_STAGES.size() - 1)

## أبحاث الحرب (فرع 2): المستويان الأولان بلا ورشة، وبعدهما كل مستوى يطلب ورشة أعلى بمستويين
static func tech_workshop_req(id: String, lv: int) -> int:
	if int(TECHS[id]["branch"]) != 2 or lv <= 2:
		return 0
	return (lv - 2) * 2

## Stage 19 (بند 2.16) — قابلية الجرحى للعلاج مقابل الموت
const INFIRMARY_DEATH_CUT := 0.012   # كل مستوى مستوصف يخفض حصة القتلى من الخسائر بهذه النسبة
const HP_DEATH_FACTOR := 0.5         # كل +100% متانة تخفض الحصة بمقدار النصف تقريبًا
const DEATH_MULT_MIN := 0.2          # أدنى حصة قتلى نسبةً إلى الأساس (25%) مهما بلغت التحسينات

static func death_mult(infirmary_lv: int, hp_bonus: float) -> float:
	var inf := maxf(1.0 - INFIRMARY_DEATH_CUT * clampi(infirmary_lv, 0, 30), 0.0)
	var tough := 1.0 / (1.0 + HP_DEATH_FACTOR * maxf(hp_bonus, 0.0))
	return maxf(inf * tough, DEATH_MULT_MIN)

## Stage 20 — برج الاستطلاع: كشف الخريطة وإنذار الغارات وتقدير حجمها
const SCOUT_VISION_PER_LEVEL := 8.0    # يُضاف إلى نصف قطر الكشف حول المدينة لكل مستوى
const RAID_WARN_BASE := 90.0           # الإنذار الأساسي بلا برج (ثوانٍ)
const RAID_WARN_PER_LEVEL := 20.0      # كل مستوى برج يمدد الإنذار بهذا القدر
const FORECAST_ERR_BASE := 0.30        # هامش خطأ تقدير الذئاب عند المستوى 1
const FORECAST_ERR_PER_LEVEL := 0.025  # ينقص هذا الهامش بكل مستوى (يصير دقيقًا عند م13)
const FORECAST_STORM_LEVEL := 8        # من هذا المستوى يُذكر إن كانت عاصفة ستصاحب الغارة

static func scout_vision(lv: int) -> float:
	return FOG_REVEAL_HOME + SCOUT_VISION_PER_LEVEL * clampi(lv, 0, int(BUILDINGS["scout_tower"]["max"]))

static func raid_warning_lead(lv: int) -> float:
	return RAID_WARN_BASE + RAID_WARN_PER_LEVEL * clampi(lv, 0, int(BUILDINGS["scout_tower"]["max"]))

static func forecast_error(lv: int) -> float:
	return maxf(FORECAST_ERR_BASE - FORECAST_ERR_PER_LEVEL * (clampi(lv, 1, 30) - 1), 0.0) if lv > 0 else 1.0

## Stage 21 — المستودع الحربي: حجم المسيرة العسكرية ومؤن الحملات
const MARCH_CAP_BASE := 60           # أقصى جنود في مسيرة واحدة بلا مستودع
const MARCH_CAP_PER_LEVEL := 30      # يُضاف لكل مستوى مستودع
const SUPPLY_FOOD_PER_TROOP := 2.0   # مؤنة الطعام لكل جندي مرسل (قبل الخصم)
const SUPPLY_DISCOUNT_PER_LEVEL := 0.015   # خصم تكلفة المؤن لكل مستوى
const SUPPLY_DISCOUNT_MAX := 0.5     # أقصى خصم

static func march_capacity(lv: int) -> int:
	return MARCH_CAP_BASE + MARCH_CAP_PER_LEVEL * clampi(lv, 0, int(BUILDINGS["war_depot"]["max"]))

static func supply_discount(lv: int) -> float:
	return minf(SUPPLY_DISCOUNT_PER_LEVEL * clampi(lv, 0, 30), SUPPLY_DISCOUNT_MAX)

static func supply_cost(n: int, lv: int) -> int:
	## طعام المؤن لمسيرة من n جندي بمستودع بمستوى lv
	if n <= 0:
		return 0
	return maxi(int(ceil(float(n) * SUPPLY_FOOD_PER_TROOP * (1.0 - supply_discount(lv)))), 1)

## Stage 22 — السوق: تبادل الموارد بأسعار تتغير مع الوقت والعاصفة
const MARKET_VALUE := {"food": 1.0, "wood": 1.0, "coal": 1.4, "iron": 2.2}   # القيمة الأساسية لوحدة من كل مورد
const MARKET_FEE_BASE := 0.20        # رسوم التبادل بلا تطوير (م1)
const MARKET_FEE_PER_LEVEL := 0.01   # ينقص هذا بكل مستوى
const MARKET_FEE_MIN := 0.08
const MARKET_QUOTA_BASE := 300       # حصة التبادل (وحدات تُباع) لكل نافذة عند م1
const MARKET_QUOTA_PER_LEVEL := 200
const MARKET_WINDOW := 1800.0        # مدة نافذة الحصة بالثواني
const MARKET_SWING := 0.05           # تذبذب السعر الأساسي ±5%
const MARKET_PERIOD := 2400.0        # دورة التذبذب بالثواني
const MARKET_STORM := {"food": 0.20, "wood": 0.0, "coal": 0.30, "iron": 0.0}   # علاوة السعر أثناء العاصفة

static func market_fee(lv: int) -> float:
	return maxf(MARKET_FEE_BASE - MARKET_FEE_PER_LEVEL * float(maxi(lv - 1, 0)), MARKET_FEE_MIN)

static func market_quota(lv: int) -> int:
	return MARKET_QUOTA_BASE + MARKET_QUOTA_PER_LEVEL * maxi(lv - 1, 0)

static func market_price(r: String, t: float, storm: bool) -> float:
	## سعر وحدة المورد r الآن؛ تذبذب جيبي لكل مورد بطور مختلف + علاوة العاصفة
	var idx: int = RES.find(r)
	var osc := sin(TAU * t / MARKET_PERIOD + float(idx) * 1.7) * MARKET_SWING
	var p: float = float(MARKET_VALUE[r]) * (1.0 + osc)
	if storm:
		p *= 1.0 + float(MARKET_STORM[r])
	return p

static func market_quote(sell: String, buy: String, amount: int, t: float, storm: bool, lv: int) -> int:
	## كمية المورد المشترى لقاء بيع amount من المورد sell (بعد الرسوم)
	if sell == buy or amount <= 0:
		return 0
	var raw := float(amount) * market_price(sell, t, storm) / market_price(buy, t, storm)
	return int(floor(raw * (1.0 - market_fee(lv))))

# ================================================================ الأبطال
## لكل بطل دوران: قائد في المعركة، أو حاكم للمدينة (لمسة خاصة بلعبتنا)
## الاستدعاء بلا حظ: تختار البطل الذي تريده وتدفع بلورات الشفق مقابل شظاياه
const HEROES := {
	"siraj": {"name": "سراج", "title": "رامي الجمر", "elem": "نار", "troop": "bow", "color": "ff9a4a",
		"skill": "سهام الجمر", "skill_desc": "الرماة لا يضعفون في العاصفة، ويزيد ضررهم 15% في أول 3 جولات.",
		"city": "حارس الموقد", "city_desc": "يرفع حرارة المدينة 3 درجات.", "city_eff": {"heat": 3.0},
		"story": "آخر من بقي من قافلة النار. يقسم أن الجمر لا ينطفئ ما دام يحمل قوسه."},
	"reem": {"name": "ريم", "title": "درع الصقيع", "elem": "جليد", "troop": "shield", "color": "8fd3ff",
		"skill": "جدار الجليد", "skill_desc": "يقل الضرر الذي يتلقاه جيشها 15%.",
		"city": "حامية المرضى", "city_desc": "يقل المرض بسبب البرد 30%.", "city_eff": {"sick_res": 0.3},
		"story": "حارسة البوابة الشمالية. وقفت وحدها أمام العاصفة الكبرى ثلاث ليالٍ."},
	"nimr": {"name": "نمر", "title": "رمح العاصفة", "elem": "ريح", "troop": "spear", "color": "9fe39a",
		"skill": "الاندفاع", "skill_desc": "ضرر جيشه مضاعف في الجولة الأولى.",
		"city": "مدرّب الكتائب", "city_desc": "يسرّع التدريب 15%.", "city_eff": {"train_speed": 0.15},
		"story": "صياد وحوش تحول إلى قائد. يرتدي جلد النمر الذي هزمه في صباه."},
	"bariq": {"name": "بارق", "title": "حدّاد العتمة", "elem": "معدن", "troop": "shield", "color": "e0b070",
		"skill": "صائد الوحوش", "skill_desc": "يزيد الضرر ضد الوحوش 25%.",
		"city": "سيد المناجم", "city_desc": "يزيد إنتاج الفحم والحديد 12%.", "city_eff": {"prod_coal": 0.12, "prod_iron": 0.12},
		"story": "صنع أول فرن في المدينة بيديه. يقول إن الحديد يسمع من يحترمه."},
	"layla": {"name": "ليلى", "title": "عرّافة الشفق", "elem": "شفق", "troop": "bow", "color": "c8a0ff",
		"skill": "نور الشفاء", "skill_desc": "نصف قتلى جيشها يعودون جرحى بعد المعركة.",
		"city": "قارئة السماء", "city_desc": "تزيد بلورات الشفق من العواصف 50%، والعلاج 30%.", "city_eff": {"aurora_gain": 0.5, "heal": 0.3},
		"story": "ظهرت مع أول شفق بعد التجمد. لا أحد يعرف من أين أتت."},
	"salma": {"name": "سلمى", "title": "حكيمة القافلة", "elem": "حكمة", "troop": "spear", "color": "ffd36b",
		"skill": "خطة محكمة", "skill_desc": "يزيد هجوم ودفاع كل الجيش 6%.",
		"city": "أمينة المؤن", "city_desc": "تزيد الطعام والخشب 12%، وسرعة البحث 10%.", "city_eff": {"prod_food": 0.12, "prod_wood": 0.12, "research_speed": 0.1},
		"story": "تحفظ خرائط العالم القديم في ذاكرتها، وتعرف أين يختبئ الدفء."},
}
const HERO_ORDER := ["siraj", "reem", "nimr", "bariq", "layla", "salma"]
const STAR_SHARDS := [10, 10, 20, 30, 50, 80]   # [للفتح، ثم لكل نجمة]
const SUMMON_COST := 60       # بلورة شفق مقابل 10 شظايا

static func hero_bonus(lv: int, stars: int) -> float:
	## نسبة تعزيز نوع جنود البطل (هجوم ودفاع وصحة)
	return 0.05 + 0.008 * lv + 0.05 * stars

static func hero_level_cost(lv: int) -> Dictionary:
	return {"food": int(round(300.0 * pow(lv, 1.45) / 10.0) * 10), "iron": int(round(25.0 * pow(lv, 1.35) / 5.0) * 5)}

static func hero_power(lv: int, stars: int) -> float:
	return 60.0 + 22.0 * lv + 150.0 * stars

# ================================================================ الأبحاث
## eff: مفتاح التأثير • val: قيمته لكل مستوى • lab: مستوى المختبر المطلوب للمستوى الأول • req: بحث سابق
const TECHS := {
	# الاقتصاد
	"saw": {"branch": 0, "name": "مناشير مسنونة", "eff": "prod_wood", "val": 0.05, "max": 12, "lab": 1, "req": "", "cost": {"wood": 600, "coal": 150}, "time": 30.0},
	"trap": {"branch": 0, "name": "فخاخ الصيد", "eff": "prod_food", "val": 0.05, "max": 12, "lab": 1, "req": "", "cost": {"wood": 700, "coal": 150}, "time": 30.0},
	"deep": {"branch": 0, "name": "حفر أعمق", "eff": "prod_coal", "val": 0.05, "max": 12, "lab": 2, "req": "saw", "cost": {"wood": 900, "iron": 120}, "time": 45.0},
	"smelt": {"branch": 0, "name": "صهر الحديد", "eff": "prod_iron", "val": 0.05, "max": 12, "lab": 3, "req": "deep", "cost": {"wood": 1400, "coal": 500}, "time": 60.0},
	"crane": {"branch": 0, "name": "روافع البناء", "eff": "build_speed", "val": 0.04, "max": 15, "lab": 2, "req": "trap", "cost": {"wood": 1200, "iron": 150}, "time": 50.0},
	# البقاء
	"insul": {"branch": 1, "name": "عزل الجدران", "eff": "heat", "val": 1.0, "max": 12, "lab": 1, "req": "", "cost": {"wood": 800, "coal": 300}, "time": 35.0},
	"herbs": {"branch": 1, "name": "طب الأعشاب", "eff": "heal", "val": 0.12, "max": 10, "lab": 1, "req": "", "cost": {"food": 900, "wood": 400}, "time": 35.0},
	"cellar": {"branch": 1, "name": "أقبية مبطنة", "eff": "storage", "val": 0.5, "max": 10, "lab": 2, "req": "insul", "cost": {"wood": 1100, "iron": 100}, "time": 50.0},
	"sled": {"branch": 1, "name": "زلاجات القوافل", "eff": "march_speed", "val": 0.08, "max": 10, "lab": 2, "req": "herbs", "cost": {"wood": 1000, "coal": 400}, "time": 45.0},
	"seer": {"branch": 1, "name": "قراءة الشفق", "eff": "aurora_gain", "val": 0.1, "max": 8, "lab": 3, "req": "cellar", "cost": {"coal": 900, "aurora": 20}, "time": 70.0},
	# الحرب
	"drill": {"branch": 2, "name": "تدريب مكثف", "eff": "train_speed", "val": 0.06, "max": 12, "lab": 1, "req": "", "cost": {"food": 1000, "iron": 80}, "time": 40.0},
	"camp": {"branch": 2, "name": "خيام أوسع", "eff": "train_cap", "val": 10.0, "max": 12, "lab": 1, "req": "", "cost": {"wood": 1000, "food": 600}, "time": 40.0},
	"plate": {"branch": 2, "name": "دروع مصقولة", "eff": "def_shield", "val": 0.04, "max": 12, "lab": 2, "req": "drill", "cost": {"iron": 300, "coal": 400}, "time": 55.0},
	"pike": {"branch": 2, "name": "رماح مقساة", "eff": "atk_spear", "val": 0.04, "max": 12, "lab": 2, "req": "drill", "cost": {"iron": 300, "wood": 600}, "time": 55.0},
	"string": {"branch": 2, "name": "أوتار متينة", "eff": "atk_bow", "val": 0.04, "max": 12, "lab": 2, "req": "camp", "cost": {"iron": 250, "wood": 800}, "time": 55.0},
	"banner": {"branch": 2, "name": "راية الجمر", "eff": "hp_all", "val": 0.04, "max": 10, "lab": 3, "req": "plate", "cost": {"iron": 600, "aurora": 25}, "time": 80.0},
	# الحرب — المرحلة 2: هجوم ودفاع ومتانة (صحة) لكل نوع جنود
	"bash": {"branch": 2, "name": "ضربة الترس", "eff": "atk_shield", "val": 0.04, "max": 12, "lab": 2, "req": "plate", "cost": {"iron": 350, "wood": 500}, "time": 60.0},
	"ironwall": {"branch": 2, "name": "جدار حديدي", "eff": "hp_shield", "val": 0.04, "max": 12, "lab": 3, "req": "plate", "cost": {"iron": 500, "coal": 600}, "time": 75.0},
	"chain": {"branch": 2, "name": "زرد الرمّاحين", "eff": "def_spear", "val": 0.04, "max": 12, "lab": 2, "req": "pike", "cost": {"iron": 350, "coal": 450}, "time": 60.0},
	"vigor": {"branch": 2, "name": "لياقة الرمّاحين", "eff": "hp_spear", "val": 0.04, "max": 12, "lab": 3, "req": "pike", "cost": {"food": 1200, "iron": 400}, "time": 75.0},
	"hide": {"branch": 2, "name": "دروع الجلد", "eff": "def_bow", "val": 0.04, "max": 12, "lab": 2, "req": "string", "cost": {"wood": 700, "coal": 400}, "time": 60.0},
	"endure": {"branch": 2, "name": "جلد الرماة", "eff": "hp_bow", "val": 0.04, "max": 12, "lab": 3, "req": "string", "cost": {"food": 1200, "iron": 350}, "time": 75.0},
	# الدفاع — المرحلة 26 (ل3): تقوّي السور والأبراج، وكل ثلاثة مستويات تتطلب مرحلة سور أعلى
	"bulwark": {"branch": 3, "name": "تحصين الأساسات", "eff": "wall_def", "val": 0.01, "max": 12, "lab": 1, "req": "", "cost": {"wood": 900, "iron": 250}, "time": 50.0},
	"ballista": {"branch": 3, "name": "مجانيق الأبراج", "eff": "tower_atk", "val": 0.01, "max": 12, "lab": 1, "req": "", "cost": {"wood": 800, "iron": 300}, "time": 50.0},
	"mortar": {"branch": 3, "name": "ملاط الحجر", "eff": "wall_hp", "val": 0.02, "max": 12, "lab": 2, "req": "bulwark", "cost": {"iron": 350, "coal": 500}, "time": 60.0},
	"firearrow": {"branch": 3, "name": "سهام مشتعلة", "eff": "tower_atk", "val": 0.01, "max": 12, "lab": 2, "req": "ballista", "cost": {"coal": 600, "wood": 700}, "time": 60.0},
	"gatehouse": {"branch": 3, "name": "بوابة محصنة", "eff": "wall_def", "val": 0.01, "max": 10, "lab": 3, "req": "mortar", "cost": {"iron": 600, "coal": 700}, "time": 80.0},
}
const BRANCHES := ["الاقتصاد", "البقاء", "الحرب", "الدفاع"]
const EFF_NAMES := {"prod_wood": "إنتاج الخشب", "prod_food": "إنتاج الطعام", "prod_coal": "إنتاج الفحم", "prod_iron": "إنتاج الحديد",
	"build_speed": "سرعة البناء", "heat": "حرارة المدينة", "heal": "سرعة العلاج", "storage": "ساعات التخزين",
	"march_speed": "سرعة الفرق", "aurora_gain": "بلورات الشفق", "train_speed": "سرعة التدريب", "train_cap": "حجم الدفعة",
	"def_shield": "دفاع الدروع", "atk_spear": "هجوم الرمّاحين", "atk_bow": "هجوم الرماة", "hp_all": "صحة كل الجيش",
	"atk_shield": "هجوم الدروع", "def_spear": "دفاع الرمّاحين", "def_bow": "دفاع الرماة",
	"hp_shield": "متانة الدروع", "hp_spear": "متانة الرمّاحين", "hp_bow": "متانة الرماة",
	"sick_res": "مقاومة المرض", "research_speed": "سرعة البحث",
	"wall_def": "دفاع الجنود خلف السور", "tower_atk": "هجوم الأبراج", "wall_hp": "متانة الجنود خلف السور"}

static func eff_text(eff: String, v: float) -> String:
	match eff:
		"heat":
			return "+%d°" % int(v)
		"storage":
			return "+%s ساعة" % str(v)
		"train_cap":
			return "+%d جندي" % int(v)
	return "+%d%%" % int(round(v * 100.0))

## Stage 17: زمن البحث يتضاعف كل مستوى (×2) بينما التكلفة كانت ×1.6 فقط، فتصير الموارد وفيرة جدًا عند المستويات العليا.
## نبقي ×1.6 حتى المستوى TECH_COST_LATE_FROM ثم ×1.9 بعده (الأبحاث الأولى لا تتغير).
const TECH_COST_GROWTH := 1.6
const TECH_COST_LATE_GROWTH := 1.9
const TECH_COST_LATE_FROM := 4

static func tech_cost_mult(lv: int) -> float:
	var late := maxi(lv - TECH_COST_LATE_FROM, 0)
	return pow(TECH_COST_GROWTH, lv - 1) * pow(TECH_COST_LATE_GROWTH / TECH_COST_GROWTH, late)


static func tech_cost(id: String, lv: int) -> Dictionary:
	var out := {}
	for r in TECHS[id]["cost"]:
		out[r] = int(round(float(TECHS[id]["cost"][r]) * tech_cost_mult(lv) / 10.0) * 10) if r != "aurora" else int(ceil(float(TECHS[id]["cost"][r]) * pow(1.3, lv - 1)))
	return out

## المرحلة 2 (الموازنة): زمن البحث يتضاعف كل مستوى (م8 نحو ساعة ونصف، م12 نحو يوم، م15 أسبوع فأكثر)
const TECH_TIME_GROWTH := 2.0

static func tech_time(id: String, lv: int) -> float:
	return float(TECHS[id]["time"]) * pow(TECH_TIME_GROWTH, lv - 1)

static func tech_lab_req(id: String, lv: int) -> int:
	return int(TECHS[id]["lab"]) + (lv - 1) * 2

# ================================================================ دفتر القائد (قرارات ذات عواقب)
const DECISIONS := [
	{"title": "قافلة لاجئين عند البوابة", "text": "عشرون ناجيًا يرتجفون عند البوابة، ومعهم أطفال. طعامنا محدود.",
		"a": {"label": "افتحوا البوابة", "eff": {"pop": 6, "food": -800, "trust": 8}},
		"b": {"label": "أعطوهم طعامًا وارحلوا", "eff": {"food": -300, "trust": -4}}},
	{"title": "صياد عاد بجرح غريب", "text": "يقول الصياد إنه رأى عرين ذئاب خلف التلال، ويطلب رجالًا للهجوم عليه.",
		"a": {"label": "أرسل الصيادين", "eff": {"food": 1500, "sick": 2}},
		"b": {"label": "لا نخاطر بأحد", "eff": {"trust": 3}}},
	{"title": "تاجر الشمال", "text": "تاجر غامض يعرض بلورات شفق مقابل الحديد.",
		"a": {"label": "بادل الحديد", "eff": {"iron": -300, "aurora": 25}},
		"b": {"label": "اطرده", "eff": {"trust": 2}}},
	{"title": "عمال المنجم يطلبون راحة", "text": "يشكو عمال المنجم من البرد، ويطلبون يوم راحة.",
		"a": {"label": "امنحهم الراحة", "eff": {"coal": -400, "trust": 7}},
		"b": {"label": "العمل لا يتوقف", "eff": {"coal": 600, "trust": -6}}},
	{"title": "مخزن قديم تحت الثلج", "text": "عثر الأطفال على باب حديدي مدفون قرب السور.",
		"a": {"label": "احفروا فورًا", "eff": {"wood": 1200, "iron": 150, "sick": 1}},
		"b": {"label": "أغلقوه، قد يكون فخًا", "eff": {"trust": 1, "gems": 10}}},
	{"title": "حفل الجمر", "text": "يقترح كبار المدينة حفلًا حول الفرن ليرفع المعنويات.",
		"a": {"label": "أقيموا الحفل", "eff": {"food": -600, "wood": -400, "trust": 12}},
		"b": {"label": "ليس الآن", "eff": {"trust": -2}}},
	{"title": "جندي نائم في الحراسة", "text": "وُجد أحد الحراس نائمًا في نوبته الليلية.",
		"a": {"label": "عاقبه أمام الجميع", "eff": {"trust": -5, "troop_bonus": 10}},
		"b": {"label": "سامحه هذه المرة", "eff": {"trust": 4}}},
	{"title": "ضوء الشفق الكبير", "text": "السماء تتوهج بشكل لم نره من قبل. البلورات تتساقط بعيدًا عن المدينة.",
		"a": {"label": "أرسل فريقًا لجمعها", "eff": {"aurora": 35, "sick": 3}},
		"b": {"label": "ابقوا في الدفء", "eff": {"trust": 3, "aurora": 8}}},
	{"title": "طفل مريض في المأوى", "text": "طفل حرارته مرتفعة، والدواء قليل.",
		"a": {"label": "استخدم مخزون الدواء", "eff": {"sick": -4, "trust": 6, "wood": -300}},
		"b": {"label": "انتظروا المستوصف", "eff": {"trust": -5}}},
	{"title": "حطاب يقترح قطع الغابة المقدسة", "text": "شجر ضخم قديم يعتبره الناس رمزًا للمدينة.",
		"a": {"label": "اقطعوها", "eff": {"wood": 2500, "trust": -8}},
		"b": {"label": "احموها", "eff": {"trust": 6}}},
	{"title": "مبارزة تدريبية", "text": "يطلب الجنود مبارزة علنية بين الكتائب.",
		"a": {"label": "وافق وقدّم جائزة", "eff": {"food": -500, "troop_bonus": 15, "trust": 3}},
		"b": {"label": "وفّروا طاقتكم", "eff": {"trust": -1}}},
	{"title": "رسالة من مدينة بعيدة", "text": "طائر يحمل رسالة: مدينة أخرى نجت وتطلب الفحم.",
		"a": {"label": "أرسل الفحم", "eff": {"coal": -700, "gems": 25, "trust": 4}},
		"b": {"label": "نحتاجه أكثر منهم", "eff": {"trust": -3}}},
]

static func decision_effect_text(eff: Dictionary) -> String:
	var parts: Array[String] = []
	for k in eff:
		var v: float = float(eff[k])
		var sgn := "+" if v > 0 else "−"
		if k == "troop_bonus":
			parts.append("%s%d جنود متدربين" % [sgn, int(absf(v))])
		elif k == "trust":
			parts.append("%s%d ثقة" % [sgn, int(absf(v))])
		else:
			parts.append("%s%s %s" % [sgn, fmt(absf(v)), RES_NAMES.get(k, k)])
	return "، ".join(parts)


## المرحلة 2 (Stage 17): مواءمة التكلفة مع الزمن. المباني الثقيلة (منجم الحديد، المختبر، قاعة الأبطال، الثكنات...)
## كانت تستهلك من دخل المدينة 3–5 أضعاف ما يستهلكه الفرن أو الصيادون في الوقت نفسه. لكل مبنى مضاعف "pace" (≤ 1)
## يُطبَّق تدريجيًا بين المستويين PACE_FROM وPACE_TO (هندسيًا، فلا قفزات)، ولا يمس المستويات الأولى (المهام والبدايات).
const PACE_FROM := 6
const PACE_TO := 12

static func cost_pace(type: String, level: int) -> float:
	var m: float = float(BUILDINGS[type].get("pace", 1.0))
	if m >= 1.0 or level <= PACE_FROM:
		return 1.0
	var k := clampf(float(level - PACE_FROM) / float(PACE_TO - PACE_FROM), 0.0, 1.0)
	return pow(m, k)


static func cost(type: String, level: int) -> Dictionary:
	## تكلفة الوصول إلى المستوى level
	var b: Dictionary = BUILDINGS[type]
	var out := {}
	var g := 1.58
	var pace := cost_pace(type, level)
	if type == "wall":
		pace *= float(WALL_STAGES[wall_stage(level)]["cost"])
	for r in b["cost"]:
		var from: int = b["from"][r]
		if level >= from:
			var v: float = b["cost"][r] * pow(g, level - from) * pace
			out[r] = int(round(v / 10.0) * 10)
	return out


## المرحلة 2 (الموازنة): منحنى زمني يتصاعد من ثوانٍ ← دقائق ← ساعات ← أيام ← أشهر
## (الفرن: م5 دقيقة • م10 17د • م15 2.5س • م20 23س • م25 8ي • م30 نحو 76ي) — انظر ROADMAP_AR.md للجدول الكامل
const BUILD_TIME_GROWTH := 1.55

static func build_time(type: String, level: int) -> float:
	var t := float(BUILDINGS[type]["time"]) * pow(BUILD_TIME_GROWTH, level - 1)
	if type == "wall":
		t *= float(WALL_STAGES[wall_stage(level)]["time"])
	return t


## Stage 17 (2.12): عدد البنّائين يزيد مع مستوى الفرن، لأن الترقيات صارت تأخذ ساعات وأيامًا
const BUILDERS_BASE := 2
const BUILDERS_MAX := 4
const BUILDER_UNLOCK := [0, 0, 0, 10, 20]   # الفهرس = رقم البنّاء (1..4) ← مستوى الفرن المطلوب

static func builder_count(furnace_lv: int) -> int:
	var n := 0
	for i in range(1, BUILDERS_MAX + 1):
		if furnace_lv >= int(BUILDER_UNLOCK[i]):
			n = i
	return maxi(n, BUILDERS_BASE)


## Stage 17 (2.13): سقف الغياب. كان 8 ساعات ثابتة فتضيع قيمة المخزن والأقبية؛ صار الأعلى بين 8 ساعات وساعات التخزين
const OFFLINE_CAP_BASE_HOURS := 8.0

static func offline_cap_seconds(storage_hours: float) -> float:
	return maxf(OFFLINE_CAP_BASE_HOURS, storage_hours) * 3600.0


static func prod_rate(type: String, level: int) -> float:
	## الإنتاج في الساعة بكامل العمال
	if level <= 0 or not BUILDINGS[type].has("prod"):
		return 0.0
	return float(BUILDINGS[type]["rate"]) * level * (1.0 + 0.09 * level)


static func workers_needed(type: String, level: int) -> int:
	if level <= 0:
		return 0
	if BUILDINGS[type].has("prod"):
		return 1 + level
	if type == "infirmary":
		return 1 + level / 2
	return 0


static func shelter_capacity(level: int) -> int:
	## أربعة مآوٍ فقط، لذا كل مأوى يؤوي أكثر من السابق
	return 0 if level <= 0 else 6 + 4 * level


static func furnace_heat(level: int) -> float:
	return 8.0 + 1.6 * level


static func furnace_coal(level: int) -> float:
	## استهلاك الفحم في الساعة (الوضع العادي)
	return 24.0 + 16.0 * level


static func plot_pos(id: String) -> Vector3:
	var p: Dictionary = PLOTS[id]
	var a := deg_to_rad(float(p["a"]))
	return CITY_CENTER + Vector3(cos(a), 0, sin(a)) * float(p["r"])


static func fmt(n: float) -> String:
	var a := absf(n)
	if a >= 1000000.0:
		return "%.1fM" % (n / 1000000.0)
	if a >= 10000.0:
		return "%dK" % int(n / 1000.0)
	if a >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return str(int(n))


# ================================================================ المرحلة 3: جبهة الصقيع (نموذج أولي)
## منفث حراري جوفي واحد + جبهة برد دورية — إثبات الفكرة قبل التوسع فيها
const VENT := {"x": 700, "y": 920, "guards": 12}
const FRONT_PERIOD := 900.0   # دورة الجبهة: 15 دقيقة
const FRONT_LEN := 180.0     # مدة الجبهة: 3 دقائق
const FRONT_DROP := 6.0      # انخفاض إضافي في الحرارة الخارجية أثناء الجبهة
const VENT_HEAT := 4.0       # دفء المنفث المُحتل (درجات)
const VENT_FIGHT_WORK := 8.0 # مدة المعركة عند المنفث (للرسم والتوقيت)

# ================================================================ تعميق الخريطة: المعاقل والتشكيلات وضباب الحرب
## التشكيلات القتالية لفرقة الاحتلال — تُختار عند الإرسال وتُثبَّت مع ظروف المعركة
const FORMATIONS := {
	"balanced": {"name": "متوازنة", "desc": "الصفوف القياسية: لا مكسب ولا مخاطرة.",
		"atk": 0.0, "def": 0.0, "taken": 1.0, "dead": 0.25},
	"aggressive": {"name": "هجومية", "desc": "زحف كاسح: هجوم +15% ودفاع −15%، وضرر متلقّى +15% وقتلى أكثر.",
		"atk": 0.15, "def": -0.15, "taken": 1.15, "dead": 0.30},
	"defensive": {"name": "دفاعية", "desc": "ترسّح محكم: دفاع +20% وهجوم −10%، وضرر متلقّى −15% وقتلى أقل.",
		"atk": -0.10, "def": 0.20, "taken": 0.85, "dead": 0.18},
}
const FORMATION_ORDER := ["balanced", "aggressive", "defensive"]

## المعاقل والقلاع القابلة للاحتلال (من معالم الخريطة) — الحراس يقوون مع مستوى الفرن
const HOLD_DEFS := {
	"stronghold": {"name": "معقل", "guards": 10, "g_atk": 9.0, "g_def": 6.0, "g_hp": 26.0, "g_scale": 0.11,
		"reward_aurora": 6, "reward_gems": 4, "eff": "+4% إنتاج لكل مورد لكل معقل محتل"},
	"fortress": {"name": "قلعة", "guards": 14, "g_atk": 11.0, "g_def": 8.0, "g_hp": 34.0, "g_scale": 0.13,
		"reward_aurora": 10, "reward_gems": 6, "eff": "−5% قوة غارات الذئاب لكل قلعة محتلة (حتى −40%)"},
}
const STRONGHOLD_PROD := 0.04   # مكافأة المعقل الدائمة: إنتاج لكل مورد
const FORT_RAID_RED := 0.05     # مكافأة القلعة الدائمة: تخفيف الغارات
const FORT_RAID_CAP := 0.40

## ضباب الحرب: شبكة كشف 150×150 (كل خلية 8×8 خانة) — كشف دائم للمناطق لا رؤية آنية
const FOG_CELL := 8
const FOG_GRID := 150
const FOG_REVEAL_HOME := 60.0    # نصف قطر الكشف حول المدينة عند البداية
const FOG_REVEAL_MARCH := 18.0   # نصف قطر الكشف حول مسار الفرق أثناء الحركة
const FOG_REVEAL_SCOUT := 30.0   # نصف قطر كشف فرقة الاستطلاع عند الهدف

## تكلفة التسريع بالجواهر: جوهرة لكل دقيقة في أول ساعة (كما كانت)، ثم نصف جوهرة للدقيقة حتى يوم، ثم ربع جوهرة
static func speedup_gems(sec: float) -> int:
	var m := maxf(sec, 0.0) / 60.0
	var t1 := minf(m, 60.0)
	var t2 := minf(maxf(m - 60.0, 0.0), 1380.0)
	var t3 := maxf(m - 1440.0, 0.0)
	return int(ceil(t1 + 0.5 * t2 + 0.25 * t3))

static func fmt_time(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	var d := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	var ss := s % 60
	if d >= 30:
		return "%d شهر %dي %02d:%02d" % [d / 30, d % 30, h, m]
	if d > 0:
		return "%dي %02d:%02d:%02d" % [d, h, m, ss]
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, ss]
	return "%02d:%02d" % [m, ss]


## صيغة مضغوطة للمؤقتات الصغيرة: وحدتان كحد أقصى (2 شهر 15ي • 3ي 04س • 2س 30د • 12:05)
static func fmt_time_short(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	var d := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	var ss := s % 60
	if d >= 30:
		return "%d شهر %dي" % [d / 30, d % 30]
	if d > 0:
		return "%dي %02dس" % [d, h]
	if h > 0:
		return "%dس %02dد" % [h, m]
	return "%02d:%02d" % [m, ss]


static func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for k in reward:
		if String(k).begins_with("shards_"):
			parts.append("%d شظايا %s" % [int(reward[k]), HEROES[String(k).substr(7)]["name"]])
		else:
			parts.append("%s %s" % [fmt(float(reward[k])), RES_NAMES.get(k, k)])
	return "، ".join(parts)
