extends Node
## Stage 30: deterministic input, frame rates, coast, pinch, limits, city/world.
const Camera := preload("res://scripts/strategy_camera.gd")
const Motion := preload("res://scripts/camera_motion.gd")
var checks := 0
var failures := 0
var rig: Node3D
var taps := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func reset(distance: float = 60.0) -> void:
	rig.ui_hit_test = Callable()
	rig.set_view(Vector3(600, 0, 600), distance)


func touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	rig._on_touch(event)


func drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	rig._on_drag(event)


func swipe(distance: float = 60.0, pause: float = 0.0, fps: int = 60) -> void:
	reset(distance)
	var center := Vector2(360, 640)
	touch(7, center, true)
	var count := maxi(1, roundi(fps * 0.1))
	for i in count:
		rig._process(1.0 / fps)
		drag(7, center + Vector2(-60.0 * (i + 1) / count, 0))
	if pause > 0:
		rig._process(pause)
	touch(7, center + Vector2(-60, 0), false)


func test_samples() -> void:
	var samples: Array = []
	Motion.begin(samples, 0)
	for i in 12:
		Motion.record(samples, Vector2(1, 0), (i + 1) / 100.0, 0.12)
	check(Motion.release_velocity(samples, 0.12, 0.12).distance_to(Vector2(100, 0)) < 0.01, "120 ms average recovers constant velocity")
	check(Motion.release_velocity(samples, 0.22, 0.12).x > 0 and Motion.release_velocity(samples, 0.22, 0.12).x < 100,
		"100 ms pause attenuates rather than abruptly cuts momentum")
	check(Motion.release_velocity(samples, 0.26, 0.12) == Vector2.ZERO, "long stationary hold has no fling")
	Motion.begin(samples, 0)
	Motion.record(samples, Vector2(2, 0), 0.02, 0.12)
	Motion.record(samples, Vector2(3, 0), 0.02, 0.12)
	check(samples.size() == 2 and is_equal_approx(Motion.release_velocity(samples, 0.02, 0.12).x, 250), "same-frame events aggregate without extra time")
	Motion.begin(samples, 0)
	for i in 30:
		Motion.record(samples, Vector2(0.5, -0.25), (i + 1) / 60.0, 0.12)
	check(samples.size() <= 10, "history remains bounded to recent samples")
	check(Motion.release_velocity(samples, 0.5, 0.12).distance_to(Vector2(30, -15)) < 0.01, "rolling window interpolates partial segments")
	check(Motion.release_velocity([], 1, 0.12) == Vector2.ZERO, "empty motion is safe")
	var whole := Motion.decay_distance(100, 2.6, 1)
	for fps in [30, 60, 120]:
		var speed := 100.0
		var displacement := 0.0
		for i in fps:
			displacement += Motion.decay_distance(speed, 2.6, 1.0 / fps)
			speed *= exp(-2.6 / fps)
		check(absf(displacement - whole) < 0.001, "exact integrated distance at %d Hz" % fps)


func test_drag() -> void:
	for fps in [30, 60, 120]:
		swipe(60, 0, fps)
		check(rig.velocity.length() > 1, "touch release has velocity at %d Hz" % fps)
		var before: Vector3 = rig.focus
		var previous_speed: float = rig.velocity.length()
		for i in 12:
			rig._process(1.0 / fps)
			check(rig.velocity.length() <= previous_speed + 0.0001, "coast decelerates at %d Hz frame %d" % [fps, i])
			previous_speed = rig.velocity.length()
		check(rig.focus.distance_to(before) > 0.05, "camera continues moving after finger up at %d Hz" % fps)
	swipe(60, 0.1)
	check(rig.velocity.length() > 0.01, "brief pause over old 90 ms cutoff still permits gentle fling")
	swipe(60, 0.2)
	check(rig.velocity == Vector2.ZERO, "intentional stationary hold stops fling")
	swipe(24)
	var near_speed: float = rig.velocity.length()
	swipe(120)
	check(rig.velocity.length() > near_speed * 3, "world speed scales naturally with zoom distance")
	check(rig.velocity.length() <= rig._glide_limit() + 0.001, "fling respects zoom-scaled speed cap")
	var endpoints: Array[Vector3] = []
	for fps in [30, 60, 120]:
		reset()
		rig.velocity = Vector2(90, 45)
		for i in fps:
			rig._process(1.0 / fps)
		endpoints.append(rig.focus)
	check(endpoints[0].distance_to(endpoints[1]) < 0.002 and endpoints[1].distance_to(endpoints[2]) < 0.002,
		"camera endpoints agree across 30/60/120 Hz")
	reset()
	touch(2, Vector2(360, 640), true)
	var anchored: Vector3 = rig.screen_to_ground(Vector2(360, 640))
	rig._process(0.02)
	drag(2, Vector2(400, 650))
	check(rig.screen_to_ground(Vector2(400, 650)).distance_to(anchored) < 0.001, "ground stays under the dragging finger")
	touch(2, Vector2(400, 650), false)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(360, 640)
	event.pressed = true
	rig._on_mouse_button(event)
	check(rig.velocity == Vector2.ZERO, "new mouse press stops prior fling")
	rig._process(0.03)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(300, 640)
	move.relative = Vector2(-60, 0)
	rig._unhandled_input(move)
	event.position = move.position
	event.pressed = false
	rig._on_mouse_button(event)
	check(rig.velocity.length() > 0.1, "mouse drag and release has inertia")
	for i in 240:
		rig._process(1.0 / 60.0)
	check(rig.velocity.length() < 0.04, "coast settles without persistent tiny drift")


func test_taps_and_ui() -> void:
	reset()
	var before_taps := taps
	touch(4, Vector2(360, 640), true)
	rig._process(0.05)
	touch(4, Vector2(360, 640), false)
	check(taps == before_taps + 1 and rig.velocity == Vector2.ZERO, "simple tap selects once without fling")
	reset()
	before_taps = taps
	var before: Vector3 = rig.focus
	touch(4, Vector2(360, 640), true)
	rig._process(0.02)
	drag(4, Vector2(365, 641))
	touch(4, Vector2(365, 641), false)
	check(taps == before_taps + 1 and rig.focus == before, "small tap jitter does not pan")
	reset()
	before_taps = taps
	touch(4, Vector2(360, 640), true)
	rig._process(0.5)
	touch(4, Vector2(360, 640), false)
	check(taps == before_taps, "long hold is not mistaken for a tap")
	reset()
	before = rig.focus
	rig.ui_hit_test = func(position: Vector2): return position.x < 150
	touch(9, Vector2(100, 640), true)
	drag(9, Vector2(400, 640))
	touch(9, Vector2(400, 640), false)
	check(rig.focus == before and rig._touches.is_empty() and rig._ignored.is_empty(), "touch starting on UI never pans or sticks")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = Vector2(100, 640)
	wheel.pressed = true
	rig._on_mouse_button(wheel)
	check(rig.target_dist == rig.dist, "wheel over UI does not zoom map")
	reset()
	touch(3, Vector2(360, 640), true)
	rig._process(0.03)
	drag(3, Vector2(300, 640))
	touch(3, Vector2(300, 640), false, true)
	check(rig.velocity == Vector2.ZERO and rig._touches.is_empty(), "canceled touch has no phantom fling")
	reset()
	touch(3, Vector2(360, 640), true)
	rig._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(rig._touches.is_empty() and not rig._mouse_down and rig.velocity == Vector2.ZERO, "focus loss clears active gestures")
	var stray: Vector3 = rig.focus
	drag(3, Vector2(50, 10))
	touch(3, Vector2(50, 10), false)
	check(rig.focus == stray, "stray events after focus loss do not move map")


func test_edges_and_zoom() -> void:
	reset()
	rig.focus = Vector3(rig.edge_margin + 0.1, 0, rig.edge_margin + 0.1)
	rig._apply()
	rig.velocity = Vector2(-100, -60)
	rig._process(0.05)
	check(rig.focus.x >= rig.edge_margin and rig.focus.z >= rig.edge_margin, "lower edges never expose outside map")
	check(rig.velocity.x > 0 and rig.velocity.y > 0, "edge collision creates small inward rebound")
	check(rig.velocity.length() < 20, "rebound is strongly damped")
	rig._process(0.05)
	check(rig.focus.x > rig.edge_margin, "edge rebound moves gently inward")
	rig.focus = Vector3(rig.map_size - rig.edge_margin - 0.1, 0, 600)
	rig._apply()
	rig.velocity = Vector2(300, 30)
	for i in 180:
		rig._process(1.0 / 60)
		check(rig.focus.x >= rig.edge_margin and rig.focus.x <= rig.map_size - rig.edge_margin, "upper edge remains bounded frame %d" % i)
	reset()
	touch(1, Vector2(300, 640), true)
	var before: Vector3 = rig.focus
	touch(8, Vector2(420, 640), true)
	check(rig.focus == before and rig.dist == 60, "adding second finger does not jump camera")
	rig._process(0.025)
	drag(1, Vector2(250, 640))
	rig._process(0.025)
	drag(8, Vector2(470, 640))
	check(rig.dist < 60, "spreading fingers zooms in")
	before = rig.focus
	var distance: float = rig.dist
	var before_taps := taps
	touch(8, Vector2(470, 640), false)
	check(rig.focus == before and rig.dist == distance, "two-to-one transition does not jump")
	touch(1, Vector2(250, 640), false)
	check(taps == before_taps, "pinch release never selects a location")
	check(rig._zoom_velocity < 0 and absf(rig._zoom_velocity) <= rig.max_zoom_glide, "pinch release has bounded zoom momentum")
	rig._process(0.025)
	check(rig.dist < distance, "zoom continues briefly after release")
	for i in 180:
		rig._process(1.0 / 60)
	check(rig.dist >= rig.min_dist and absf(rig._zoom_velocity) < 0.003, "zoom settles within limits")
	reset()
	rig._zoom_velocity = 0.9
	rig.set_view(Vector3(600, 0, 600), rig.max_dist - 0.01)
	rig._zoom_velocity = 0.9
	rig._process(0.1)
	check(rig.dist <= rig.max_dist and rig._zoom_velocity == 0, "zoom momentum stops at far limit")
	reset()
	var anchor := Vector2(450, 700)
	var ground: Vector3 = rig.screen_to_ground(anchor)
	rig._zoom_keep(anchor, 45)
	check(rig.screen_to_ground(anchor).distance_to(ground) < 0.001, "zoom preserves the ground under its anchor")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = Vector2(360, 640)
	wheel.pressed = true
	rig.target_dist = rig.dist
	rig._on_mouse_button(wheel)
	distance = rig.dist
	rig._process(0.02)
	check(rig.dist < distance and rig.dist > rig.target_dist, "wheel zoom eases rather than jumping")
	rig.velocity = Vector2(100, 20)
	rig.set_view(Vector3(500, 0, 500), 40)
	check(rig.velocity == Vector2.ZERO and rig._zoom_velocity == 0 and rig.dist == 40, "set_view clears old motion")


func test_actual_scenes() -> void:
	Game.save_path_override = "user://stage30_camera_test.json"
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}
	for scene in ["city", "world_map"]:
		var node: Node3D = load("res://%s.tscn" % scene).instantiate()
		add_child(node)
		await frames()
		var camera: Node3D = node.rig
		camera.set_process(false)
		var position: Vector3 = camera.focus
		camera.velocity = Vector2(5, 2)
		camera._process(0.05)
		check(camera.focus.distance_to(position) > 0.01, "actual %s camera coasts" % scene)
		check(camera.focus.x >= camera.edge_margin and camera.focus.x <= camera.map_size - camera.edge_margin,
			"actual %s respects its own bounds" % scene)
		check(camera.cam.keep_aspect == Camera3D.KEEP_WIDTH, "actual %s keeps portrait projection" % scene)
		camera.set_process(true)
		camera.fly_to(position, 45, 0.08)
		await get_tree().create_timer(0.2).timeout
		check(not camera._fly and camera.focus.distance_to(position) < 0.1, "actual %s fly_to still reaches destination" % scene)
		node.queue_free()
		await frames()


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	rig = Camera.new()
	add_child(rig)
	rig.set_process(false)
	rig.set_process_unhandled_input(false)
	rig.tapped.connect(func(_world, _screen): taps += 1)
	test_samples()
	test_drag()
	test_taps_and_ui()
	test_edges_and_zoom()
	rig.queue_free()
	await frames()
	await test_actual_scenes()
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
