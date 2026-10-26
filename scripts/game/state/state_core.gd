extends Node
## الطبقة 1/6 — قلب الحالة: كل المتغيرات والثوابت والإشارات + استعلامات أساسية + الحفظ + الخريطة.
## قاعدة الطبقات: كل طبقة تستدعي ما في طبقتها وما تحتها فقط (يفحصها tools/split_check.py). المتغيرات والثوابت تبقى هنا حصرًا.


## حالة اللعبة الكاملة (Autoload باسم Game)
## الاقتصاد، والحرارة، والسكان، وطابور البناء، والمسيرات، والمهام، والحفظ، والتقدم أثناء الغياب.
const Defs := preload("res://scripts/defs.gd")
const Combat := preload("res://scripts/combat.gd")
const CitySkins := preload("res://scripts/city_skins.gd")
const Profile := preload("res://scripts/game/profile.gd")
const Achievements := preload("res://scripts/game/achievements.gd")
const Gear := preload("res://scripts/game/gear.gd")
const GearRules := preload("res://scripts/game/gear_defs.gd")
const SAVE_PATH := "user://frost_save.json"
var save_path_override := ""   # مسار بديل للاختبارات الآلية حتى لا تُمس حفظة اللاعب
const SAVE_VERSION := 7   # Stage 29: equipment + gear_queue; v1–v6 remain compatible.
const BUILDERS := 2        # الحد الأدنى (الأساس) — العدد الفعلي من builder_count()
const MAX_BUILDERS := 4    # أقصى عدد (يظهر في الواجهة صفًا لكل بنّاء)
const MAX_MARCHES := 2
const OFFLINE_CAP := 8.0 * 3600.0   # الأدنى فقط — السقف الفعلي من offline_cap()
const FREE_SPEEDUP := 180.0

# نظام المطور (خاص بصاحب اللعبة): كل التكاليف مجانية والتسريع فوري — لا يتأثر به اللاعب العادي
const DEV_PASSWORD := "19983010"
var dev_mode := false

signal changed
signal toast(text: String)
signal building_done(plot_id: String)
signal work_completed(kind: String, plot_id: String)
signal march_done(m: Dictionary)
signal storm_changed(active: bool)
signal raid_happened(report: Dictionary)
signal decision_ready
signal crystals_changed
signal venture_done(report: Dictionary)
signal fog_changed   # تعميق الخريطة: كُشف مناطق جديدة في ضباب الحرب
signal city_skin_changed(id: String)

var res := {}
var gems := 0
var plots := {}          # plot_id -> level
var stored := {}         # plot_id -> float (موارد جاهزة للجمع داخل المبنى)
var queue: Array = []    # [{plot, level, start, end}]
var pop := 0
var sick := 0.0
var furnace_mode := 1    # 0 مطفأ • 1 عادي • 2 مضاعف
var stats := {}
var task_index := 0
var last_daily := ""
var home := Vector2i(790, 842)
var marches: Array = []
var storm_start := 0.0
var storm_end := 0.0
var quality_high := true
var city_skin := CitySkins.DEFAULT
var offline_report: Dictionary = {}
var migration_note: Dictionary = {}   # ملاحظة ترحيل الحفظ (استرجاع موارد/منح ثكنات) تُعرض مرة واحدة
var daily_ready := false
var profile: Dictionary = {}   # Stage 24: name • avatar • id • created (يبقى عبر «لعبة جديدة»)
var market_window_start := 0.0   # Stage 22: بداية نافذة حصة السوق الحالية
var market_used := 0.0           # ما بيع في النافذة الحالية

# المرحلة الثانية: الجيش والأبطال والأبحاث واللمسات الخاصة
var aurora := 0
var trust := 60.0
var troops := {}         # "shield_1" -> عدد
var wounded := {}        # "shield_1" -> عدد الجرحى
var train := {}          # نوع الجنود (shield/spear/bow) ← {key, n, start, end} — لكل ثكنة طابورها
var heroes := {}         # id -> {lv, stars, shards, owned}
var defender := ""
var governor := ""
var techs := {}          # id -> مستوى
var research := {}       # {id, lv, start, end}
var equipment: Dictionary = {}
var gear_queue: Array = []
var crystals: Array = [] # [{x, z, v}]
var raid_next := 0.0
var _scout_vision_lv := 0
var _raid_warned := false
var raid_count := 0
var raid_wins := 0
var last_raid: Dictionary = {}
var raid_unseen := false
var decision_next := 0.0
var pending_decision := -1
var task2_index := 0

# المرحلة 3: جبهة الصقيع (نموذج أولي)
var vent := {}            # {"x": int, "y": int, "captured": bool}
var venture := {}         # المسيرة العسكرية نحو المنفث أو معلم قابل للاحتلال
var front_origin := 0.0   # بدء دورة الجبهات

# تعميق الخريطة: المعاقل والقلاع المحتلة + ضباب الحرب
var holds := {}           # معرف المعلم ← نوعه (stronghold/fortress)
var explored := PackedByteArray()   # شبكة الكشف FOG_GRID×FOG_GRID (0 مجهول، 1 مكشوف)
var _map_data_cache := {}
var _offline := false
var _crystal_acc := 0.0
var _leave_acc := 0.0

# قيم محسوبة لكل لحظة (للواجهة)
var inside_temp := 0.0
var outside_temp := 0.0
var hungry := false
var cold_level := 0      # 0 دافئ • 1 بارد • 2 متجمد
var workers := {}        # plot_id -> عدد العمال
var _grow_acc := 0.0
var _tick_acc := 0.0
var _save_acc := 0.0
var _rng := RandomNumberGenerator.new()


func now() -> float:
	return Time.get_unix_time_from_system()


func _schedule_storm(after: float) -> void:
	storm_start = after + _rng.randf_range(0.0, 360.0)
	storm_end = storm_start + _rng.randf_range(100.0, 160.0)


func _save_path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH


func save_game() -> void:
	refresh_profile_achievements()
	var d := {
		"v": SAVE_VERSION, "time": now(), "res": res, "gems": gems, "plots": plots, "stored": stored,
		"queue": queue, "pop": pop, "sick": sick, "furnace_mode": furnace_mode, "stats": stats,
		"task_index": task_index, "last_daily": last_daily, "home": [home.x, home.y],
		"marches": marches, "storm": [storm_start, storm_end], "quality_high": quality_high,
		"aurora": aurora, "trust": trust, "troops": troops, "wounded": wounded, "train": train, "heroes": heroes,
		"defender": defender, "governor": governor, "techs": techs, "research": research, "crystals": crystals,
		"raid_next": raid_next, "raid_count": raid_count, "raid_wins": raid_wins, "last_raid": last_raid,
		"decision_next": decision_next, "pending_decision": pending_decision, "task2_index": task2_index,
		"vent": vent, "venture": venture, "front_origin": front_origin, "dev_mode": dev_mode,
		"holds": holds, "explored": Marshalls.raw_to_base64(explored) if not explored.is_empty() else "",
		"city_skin": city_skin, "market_window_start": market_window_start, "market_used": market_used, "profile": profile,
		"equipment": equipment, "gear_queue": gear_queue,
	}
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func refresh_profile_achievements() -> void:
	if profile.is_empty() or not profile.has("id"):
		profile = Profile.new_profile(now())
	Achievements.sync(self)


func notify_work_completed(kind: String, plot_id: String) -> void:
	if not _offline:
		work_completed.emit(kind, plot_id)


func notify_work_type_completed(kind: String, plot_type: String) -> void:
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == plot_type:
			notify_work_completed(kind, id)


# ================================================================ الحساب
func level(id: String) -> int:
	return int(plots.get(id, 0))


func furnace_level() -> int:
	return level("furnace")


func max_level_of(type: String) -> int:
	var m := 0
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == type:
			m = maxi(m, level(id))
	return m


func count_of(type: String) -> int:
	var c := 0
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == type and level(id) > 0:
			c += 1
	return c


func pop_capacity() -> int:
	var c := 4
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == "shelter":
			c += Defs.shelter_capacity(level(id))
	return c


func healthy() -> int:
	return maxi(pop - int(floor(sick)), 0)


func storm_active(t: float = -1.0) -> bool:
	if t < 0:
		t = now()
	return t >= storm_start and t < storm_end


func storm_soon() -> float:
	## ثوانٍ حتى العاصفة إن كانت قريبة (أقل من 90 ثانية)، وإلا -1
	var s := storm_start - now()
	return s if s > 0 and s < 90 else -1.0


func _under_construction(id: String) -> bool:
	for q in queue:
		if q["plot"] == id:
			return true
	return false


# ================================================================ الأفعال
const DevTools := preload("res://scripts/game/dev_tools.gd")


func queue_entry(id: String) -> Dictionary:
	for q in queue:
		if q["plot"] == id:
			return q
	return {}


func gems_for_time(sec: float) -> int:
	if sec <= FREE_SPEEDUP:
		return 0
	return Defs.speedup_gems(sec)   # المرحلة 2: تكلفة متدرجة حتى لا تصير الأزمنة الطويلة مستحيلة


func give(reward: Dictionary) -> void:
	for k in reward:
		if k == "gems":
			gems += int(reward[k])
		elif k == "aurora":
			aurora += int(reward[k])
		elif String(k).begins_with("shards_"):
			var hid := String(k).substr(7)
			heroes[hid]["shards"] = int(heroes[hid]["shards"]) + int(reward[k])
		else:
			res[k] = float(res.get(k, 0.0)) + float(reward[k])
	changed.emit()


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


# ---------------------------------------------------------------- جبهة الصقيع (المرحلة 3 — نموذج أولي)
func front_active(t: float = -1.0) -> bool:
	if front_origin <= 0.0:
		return false
	if t < 0.0:
		t = now()
	if t < front_origin:
		return false
	return fmod(t - front_origin, Defs.FRONT_PERIOD) < Defs.FRONT_LEN


func front_eta() -> float:
	## ثوانٍ حتى بداية الجبهة القادمة
	if front_origin <= 0.0:
		return -1.0
	var t := now()
	if t < front_origin:
		return front_origin - t
	var phase := fmod(t - front_origin, Defs.FRONT_PERIOD)
	return Defs.FRONT_PERIOD - phase

# ---------------------------------------------------------------- ضباب الحرب (كشف دائم للمناطق)
const MapFog := preload("res://scripts/game/map_fog.gd")


func is_explored(x: int, y: int) -> bool:
	return MapFog.is_explored(self, x, y)


func reveal_at(x: float, y: float, radius: float) -> void:
	MapFog.reveal_at(self, x, y, radius)


func reveal_segment(x0: float, y0: float, x1: float, y1: float, radius: float) -> void:
	MapFog.reveal_segment(self, x0, y0, x1, y1, radius)


func _march_fog_pos(m: Dictionary, t: float) -> Vector2:
	return MapFog.march_fog_pos(self, m, t)


func _reveal_march_path(m: Dictionary, t_from: float, t_to: float, radius: float) -> void:
	MapFog.reveal_march_path(self, m, t_from, t_to, radius)


func holds_count(type: String) -> int:
	var n := 0
	for id in holds:
		if str(holds[id]) == type:
			n += 1
	return n


func _map_data() -> Dictionary:
	if _map_data_cache.is_empty():
		_map_data_cache = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_data.json"))
	return _map_data_cache


func _find_landmark(id: String) -> Dictionary:
	## يُستخرج الهدف من بيانات الخريطة نفسها لا من واجهة الإرسال
	for L in _map_data().get("landmarks", []):
		if str(L["id"]) == id:
			return L
	return {}


# ================================================================ المرحلة الثانية: الحسابات العامة
func bonus(eff: String) -> float:
	var b := 0.0
	for id in techs:
		if int(techs[id]) > 0 and Defs.TECHS[id]["eff"] == eff:
			b += float(Defs.TECHS[id]["val"]) * int(techs[id])
	if governor != "" and heroes.has(governor) and heroes[governor]["owned"]:
		var ce: Dictionary = Defs.HEROES[governor]["city_eff"]
		if ce.has(eff):
			# مهارة الحاكم تقوى مع النجوم
			b += float(ce[eff]) * (1.0 + 0.15 * int(heroes[governor]["stars"]))
	return b


func trust_mult() -> float:
	return 0.9 + 0.2 * clampf(trust, 0.0, 100.0) / 100.0


const EconomyStats := preload("res://scripts/game/economy_stats.gd")


func get_stats_snapshot() -> Dictionary:
	return EconomyStats.get_stats_snapshot(self)


# ---------------------------------------------------------------- الأبطال
const HeroMgr := preload("res://scripts/game/heroes.gd")


# ---------------------------------------------------------------- غارات الذئاب
const CityDefense := preload("res://scripts/game/city_defense.gd")
const WarRules := preload("res://scripts/game/war_rules.gd")   # Stage 33: تقدير المعارك وتعبئة الجنود (نقي)
