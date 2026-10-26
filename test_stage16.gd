extends Node
## اختبار Stage 16 — مؤقتات الأعمال (فوق المباني + طابور التدريب والبحث)
## التشغيل: godot --headless --path . res://test_stage16.tscn

const Defs := preload("res://scripts/defs.gd")
const JobTimers := preload("res://scripts/ui/job_timers.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _ready() -> void:
	# 1) صيغة الوقت المضغوطة
	check(Defs.fmt_time_short(45.0) == "00:45", "short time: 45s -> 00:45 (%s)" % Defs.fmt_time_short(45.0))
	check(Defs.fmt_time_short(125.0) == "02:05", "short time: 125s -> 02:05")
	check(Defs.fmt_time_short(3700.0) == "1س 01د", "short time: 3700s -> 1س 01د (%s)" % Defs.fmt_time_short(3700.0))
	check(Defs.fmt_time_short(90000.0) == "1ي 01س", "short time: 25h -> 1ي 01س (%s)" % Defs.fmt_time_short(90000.0))
	check(Defs.fmt_time_short(30.0 * 86400.0) == "1 شهر 0ي", "short time: 30 days -> 1 شهر 0ي (%s)" % Defs.fmt_time_short(30.0 * 86400.0))
	check(Defs.fmt_time_short(-5.0) == "00:00", "short time: negative clamps to 00:00")

	Game.save_path_override = "user://frost_save_test_stage16.json"
	Game.dev_mode = false
	Game.new_game()
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2) بنية الواجهة
	check(city.timer_layer != null, "timer layer exists")
	check(city.job_rows.size() == JobTimers.MAX_ROWS, "side queue has %d job rows" % JobTimers.MAX_ROWS)
	for r in city.job_rows:
		check(not (r["panel"] as Control).visible, "job row hidden when no job")
		break
	check(JobTimers.city_jobs().is_empty(), "no city jobs at start")
	check(JobTimers.jobs_for("sh1").is_empty(), "no building job at start")

	# 3) بناء/ترقية
	var t := Game.now()
	Game.queue.append({"plot": "sh1", "level": 1, "start": t, "end": t + 120.0})
	var jb := JobTimers.jobs_for("sh1")
	check(jb.size() == 1 and jb[0]["kind"] == "build", "build job found on plot")
	check(jb.size() == 1 and jb[0]["name"] == "بناء", "level 1 shows 'بناء'")
	Game.queue.clear()
	Game.queue.append({"plot": "sh1", "level": 4, "start": t, "end": t + 120.0})
	jb = JobTimers.jobs_for("sh1")
	check(jb.size() == 1 and jb[0]["name"] == "ترقية 4", "level 4 shows 'ترقية 4' (%s)" % (jb[0]["name"] if jb.size() == 1 else "?"))
	check(is_equal_approx(JobTimers.progress({"start": 0.0, "end": 100.0}, 25.0), 25.0), "progress 25%")
	check(is_equal_approx(JobTimers.progress({"start": 0.0, "end": 100.0}, 500.0), 100.0), "progress clamps at 100")

	# 4) تدريب: يظهر على الثكنة الصحيحة فقط
	Game.train["spear"] = {"key": "spear_1", "n": 20, "start": t, "end": t + 600.0}
	var jt := JobTimers.jobs_for("bp1")
	check(jt.size() == 1 and jt[0]["kind"] == "train", "training shows on spear barracks (bp1)")
	check(jt.size() == 1 and str(jt[0]["name"]).contains("×20"), "training name shows count")
	check(JobTimers.jobs_for("bs1").is_empty(), "shield barracks has no job")
	check(JobTimers.jobs_for("bb1").is_empty(), "bow barracks has no job")
	check(JobTimers.jobs_for("sh1").size() == 1, "shelter job unaffected by training")

	# 5) بناء + تدريب معًا على نفس الثكنة: بناء أولًا
	Game.queue.append({"plot": "bp1", "level": 2, "start": t, "end": t + 60.0})
	var both := JobTimers.jobs_for("bp1")
	check(both.size() == 2 and both[0]["kind"] == "build" and both[1]["kind"] == "train", "build + train both listed, build first")

	# 6) بحث: على المختبر فقط
	var rid: String = Defs.TECHS.keys()[0]
	Game.research = {"id": rid, "lv": 1, "start": t, "end": t + 300.0}
	var jr := JobTimers.jobs_for("lb1")
	check(jr.size() == 1 and jr[0]["kind"] == "research", "research shows on lab (lb1)")
	check(JobTimers.jobs_for("bs1").is_empty(), "research not shown on barracks")
	check(JobTimers.city_jobs().size() == 2, "city jobs: 1 training + 1 research")

	# 7) الطابور الجانبي والمؤقتات على الشاشة
	Game.changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check((city.job_rows[0]["panel"] as Control).visible, "first job row visible")
	check((city.job_rows[1]["panel"] as Control).visible, "second job row visible")
	check(not (city.job_rows[2]["panel"] as Control).visible, "third job row hidden")
	check((city.job_rows[0]["time"] as Label).text != "", "job row shows remaining time")
	check(city.timer_widgets.has("sh1") and city.timer_widgets.has("bp1") and city.timer_widgets.has("lb1"), "timer widgets created for sh1, bp1, lb1")
	check(not city.timer_widgets.has("bs1"), "no widget for idle plots")

	# 8) راية الثكنة والنص القديم
	check(city.plot_nodes["bp1"]["flag_mat"] is StandardMaterial3D, "barracks plot keeps flag material")
	check(city.plot_nodes["sh1"]["flag_mat"] == null, "non-barracks plot has no flag material")
	check((city.plot_nodes["sh1"]["timer"] as Label3D).text == "", "old 3D timer text is empty")

	# 9) تنظيف: عند انتهاء الأعمال تختفي اللوحات
	Game.queue.clear()
	Game.train.clear()
	Game.research = {}
	Game.changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(JobTimers.city_jobs().is_empty(), "no city jobs after finishing")
	check(not (city.timer_widgets["sh1"]["root"] as Control).visible, "widget hidden after job ends")
	check(not (city.job_rows[0]["panel"] as Control).visible, "job row hidden after job ends")

	print("---- stage16: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
