extends RefCounted
## Stage 33 — قواعد الحرب النقية (بلا Node ولا حالة): خيارات الهجوم، تقدير نتيجة المعركة، تعبئة الجنود بنسبة، حكم الفرصة.
## ملف قابل للنقل إلى السيرفر لاحقًا (بند ز5): كل الدوال static وتأخذ قيمًا وتعيد قيمًا ولا تعدّل شيئًا.

const Defs := preload("res://scripts/defs.gd")
const Combat := preload("res://scripts/combat.gd")

## معارك الهجوم (الحملات): ضرر الجولة ×0.45 فتطول المعركة ويظهر أثر التشكيل والتفوق،
## والمهاجم الخاسر يتراجع عند بقاء أقل من نصف قوته بدل الفناء الكامل (مقاسة بنموذج محاكاة: الخسارة الواضحة 55–75% لا 100%).
## الغارات على المدينة لا تستخدم هذه الخيارات — سلوكها القديم محفوظ.
const ATTACK_OPTS := {"dmg_scale": 0.45, "retreat": 0.5, "max_rounds": 16}
const SAMPLES := 12            # عدد المعارك التجريبية في التقدير (ببذور ثابتة فالنتيجة ثابتة لنفس المدخلات)
const INTEL_ERR_CAP := 0.35    # أقصى هامش خطأ في تقدير حراس الهدف (بلا برج استطلاع)
const SEND_GOAL_PCT := 85      # الفرصة التي تعتبرها «التوصية» كافية


static func _total(units: Dictionary) -> float:
	var s := 0.0
	for k in units:
		s += maxf(float(units[k]), 0.0)
	return s


## هامش الخطأ في معرفة قوة الهدف: يتحسن مع برج الاستطلاع (يُعيد استخدام منحنى تقدير الغارات)
static func intel_error(scout_lv: int) -> float:
	return minf(Defs.forecast_error(scout_lv), INTEL_ERR_CAP)


static func enemy_range(n: int, err: float) -> Vector2i:
	var lo := maxi(int(round(n * (1.0 - err))), 1)
	var hi := maxi(int(round(n * (1.0 + err))), lo)
	return Vector2i(lo, hi)


static func power_of(units: Dictionary) -> int:
	var p := 0.0
	for k in units:
		var parts: PackedStringArray = String(k).split("_")
		if parts.size() == 2 and Defs.TROOPS.has(parts[0]):
			p += float(units[k]) * Defs.troop_power(parts[0], int(parts[1]))
	return int(round(p))


## تقدير معركة هجوم: {win_pct, att_loss_pct, def_loss_pct, retreat_pct, samples}
static func estimate(att_units: Dictionary, att_mods: Dictionary, def_units: Dictionary, def_mods: Dictionary,
		storm: bool, opts: Dictionary = ATTACK_OPTS, samples: int = SAMPLES) -> Dictionary:
	var a_total := _total(att_units)
	var d_total := _total(def_units)
	if a_total < 0.5 or samples <= 0:
		return {"win_pct": 0, "att_loss_pct": 0, "def_loss_pct": 0, "retreat_pct": 0, "samples": 0}
	var wins := 0
	var retreats := 0
	var a_loss := 0.0
	var d_loss := 0.0
	for i in samples:
		var rep: Dictionary = Combat.fight(att_units, att_mods, def_units, def_mods, storm, 1000 + i * 7919, opts)
		if bool(rep["att_win"]):
			wins += 1
		if bool(rep.get("retreated", false)):
			retreats += 1
		a_loss += _total(rep["att_loss"]) / a_total
		d_loss += _total(rep["def_loss"]) / maxf(d_total, 1.0)
	return {"win_pct": int(round(100.0 * wins / samples)), "att_loss_pct": int(round(100.0 * a_loss / samples)),
			"def_loss_pct": int(round(100.0 * d_loss / samples)), "retreat_pct": int(round(100.0 * retreats / samples)),
			"samples": samples}


## صمود المدينة أمام الغارة القادمة بمن يبقى فيها (سلوك الغارة القديم بلا opts): نسبة مئوية
static func raid_hold_pct(home_units: Dictionary, def_mods: Dictionary, storm: bool, wolves: int, wolf_stats: Dictionary) -> int:
	if _total(home_units) < 0.5:
		return 0
	var est := estimate({"beast": wolves}, {"beast": wolf_stats}, home_units, def_mods, storm, {}, SAMPLES)
	return 100 - int(est["win_pct"])


## تعبئة الجنود بنسبة من المتاح مع احترام سقف المسيرة — توزيع تناسبي ثم توزيع الباقي بالترتيب
static func quick_fill(avail: Dictionary, frac: float, cap: int) -> Dictionary:
	var total := int(_total(avail))
	var out := {}
	if total <= 0 or frac <= 0.0:
		return out
	var target := mini(int(round(float(total) * clampf(frac, 0.0, 1.0))), maxi(cap, 0))
	if target <= 0:
		return out
	var ratio := float(target) / float(total)
	var given := 0
	var keys: Array = avail.keys()
	keys.sort()
	for k in keys:
		var v := mini(int(floor(float(avail[k]) * ratio)), int(avail[k]))
		if v > 0:
			out[k] = v
			given += v
	var guard := 0
	while given < target and guard < 100000:
		var progressed := false
		for k in keys:
			if given >= target:
				break
			if int(out.get(k, 0)) < int(avail[k]):
				out[k] = int(out.get(k, 0)) + 1
				given += 1
				progressed = true
		if not progressed:
			break
		guard += 1
	return out


## حكم الفرصة: نص ولون (للواجهة فقط)
static func verdict(win_pct: int) -> Dictionary:
	if win_pct >= 90:
		return {"text": "نصر شبه مؤكد", "color": "8ee89a"}
	if win_pct >= 65:
		return {"text": "نصر مرجّح", "color": "c6e98a"}
	if win_pct >= 35:
		return {"text": "معركة متكافئة — مخاطرة", "color": "ffd36b"}
	if win_pct >= 10:
		return {"text": "هزيمة مرجّحة", "color": "ffb070"}
	return {"text": "هزيمة شبه مؤكدة", "color": "ff8a7a"}
