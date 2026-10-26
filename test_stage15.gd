extends Node
## اختبار Stage 15 — الوضع العمودي (720×1280)
## التشغيل: godot --headless --path . res://test_stage15.tscn

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _ready() -> void:
	# 1) إعدادات المشروع
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 720, "viewport width is 720")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1280, "viewport height is 1280")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 1, "orientation is portrait (1)")

	# محاكاة شاشة الهاتف العمودية (النافذة الصامتة تبدأ بحجم أفقي افتراضي)
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	Game.save_path_override = "user://frost_save_test_stage15.json"
	Game.dev_mode = false
	Game.new_game()
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2) الكاميرا: تغطية أفقية ثابتة
	var cam: Camera3D = get_viewport().get_camera_3d()
	check(cam != null and cam.keep_aspect == Camera3D.KEEP_WIDTH, "camera keeps horizontal width (KEEP_WIDTH)")
	check(cam != null and cam.fov >= 45.0 and cam.fov <= 60.0, "camera horizontal fov in sane range (%s)" % (str(cam.fov) if cam else "n/a"))

	# 3) الشاشة الرئيسية داخل حدود 720 عرضًا
	var vw := 720.0
	var inside := true
	for b in city.blockers:
		var c := b as Control
		if c == null or not c.visible:
			continue
		var r := c.get_global_rect()
		if r.position.x < -1.0 or r.end.x > vw + 1.0:
			inside = false
			print("  outside: ", c.name, " ", r)
	check(inside, "all HUD blockers fit inside 720 px width")

	# 4) شريط التنقل: خمسة أزرار متساوية العرض تقريبًا ومتجاورة بلا تجاوز
	var xs: Array = []
	for k in ["map", "army", "decision", "hero", "task"]:
		var btn := city.side_btns.get(k) as Control
		check(btn != null, "nav button '%s' exists" % k)
		if btn:
			xs.append(btn.get_global_rect())
	if xs.size() == 5:
		var last: Rect2 = xs[4]
		var first: Rect2 = xs[0]
		check(maxf(first.end.x, last.end.x) <= vw + 1.0 and minf(first.position.x, last.position.x) >= -1.0, "nav bar stays within width")

	# 5) لوحة الطابور لا تتراكب مع العمود الأيسر
	var qpos: Rect2 = city.march_head.get_global_rect()
	var lpos: Rect2 = city.raid_label.get_global_rect()
	check(qpos.position.x > lpos.end.x, "queue panel does not overlap left column")

	# 6) نافذة كبيرة (الأبطال) تتسع للعرض وتفتح بلا خطأ
	city._show_heroes()
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(city.win_dim), "heroes window opens")
	if is_instance_valid(city.win_dim):
		var wr: Rect2 = city.win_dim.get_global_rect()
		check(wr.size.x <= vw + 1.0, "heroes window fits width")
	city._close_window()

	# 7) لوحة المبنى عند اختيار مبنى تتسع للعرض
	check(city.bp.custom_minimum_size.x <= vw - 20.0, "building panel min width fits portrait")

	print("---- stage15: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
