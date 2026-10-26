extends Node3D
## Shared city/world camera: direct ground drag, recent-motion fling and pinch.
## Stage 30: frame-rate-independent coast, soft edge rebound and zoom momentum.
const Motion := preload("res://scripts/camera_motion.gd")

signal tapped(world_pos: Vector3, screen_pos: Vector2)
signal view_changed(focus: Vector3, dist: float)

@export var map_size := 1200.0
@export var edge_margin := 10.0
@export var min_dist := 12.0
@export var max_dist := 300.0
@export var near_pitch_deg := 40.0
@export var far_pitch_deg := 64.0
@export var yaw_deg := 0.0
@export var friction := 2.6
@export var max_glide_speed := 240.0   # Ground units/s at distance 60; scales with zoom.
@export var sample_window := 0.12
@export var edge_rebound := 0.14
@export var zoom_smooth := 12.0
@export var zoom_friction := 5.0
@export var max_zoom_glide := 0.9      # Log-distance/s; short, restrained continuation.
@export var tap_max_move := 14.0
@export var tap_max_time := 0.35
@export var ground_y := 0.2

var cam: Camera3D
var focus := Vector3(600, 0, 600)
var dist := 60.0
var target_dist := 60.0
var velocity := Vector2.ZERO
var ui_hit_test: Callable = Callable()

var _touches := {}
var _ignored := {}
var _tap_start := Vector2.ZERO
var _tap_time := 0.0
var _tap_moved := false
var _clock := 0.0
var _pan_samples: Array = []
var _zoom_samples: Array = []
var _zoom_velocity := 0.0
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _zoom_anchor := Vector2(-1, -1)
var _mouse_down := false
var _tween: Tween
var _fly := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 2200.0
	add_child(cam)
	cam.make_current()
	_apply()


func screen_to_ground(sp: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(sp)
	var direction := cam.project_ray_normal(sp)
	if absf(direction.y) < 0.0001:
		return focus
	var t := (ground_y - origin.y) / direction.y
	return focus if t < 0 else origin + direction * t


func _pitch() -> float:
	var k := pow(clampf(inverse_lerp(min_dist, max_dist, dist), 0, 1), 0.7)
	return deg_to_rad(lerpf(near_pitch_deg, far_pitch_deg, k))


func _apply() -> void:
	focus.x = clampf(focus.x, edge_margin, map_size - edge_margin)
	focus.z = clampf(focus.z, edge_margin, map_size - edge_margin)
	focus.y = ground_y
	global_position = focus
	var pitch := _pitch()
	var offset := (Vector3(0, sin(pitch), cos(pitch)) * dist).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	cam.global_position = focus + offset
	cam.look_at(focus, Vector3.UP)
	view_changed.emit(focus, dist)


func _glide_limit() -> float:
	return max_glide_speed * maxf(dist, min_dist) / 60.0


func _pan(from_sp: Vector2, to_sp: Vector2) -> void:
	var displacement := screen_to_ground(from_sp) - screen_to_ground(to_sp)
	var before := focus
	focus += Vector3(displacement.x, 0, displacement.z)
	_apply()
	# Measure the actual clamped move, so dragging against an edge cannot
	# charge up a hidden fling velocity.
	Motion.record(_pan_samples, Vector2(focus.x - before.x, focus.z - before.z), _clock, sample_window)
	velocity = Motion.release_velocity(_pan_samples, _clock, sample_window).limit_length(_glide_limit())


func _zoom_keep(sp: Vector2, new_dist: float) -> void:
	var before := screen_to_ground(sp)
	dist = clampf(new_dist, min_dist, max_dist)
	_apply()
	var after := screen_to_ground(sp)
	focus += Vector3(before.x - after.x, 0, before.z - after.z)
	_apply()


func _stop_motion() -> void:
	velocity = Vector2.ZERO
	_zoom_velocity = 0.0
	target_dist = dist
	_pan_samples.clear()
	_zoom_samples.clear()
	if _tween and _tween.is_valid():
		_tween.kill()
	_fly = false


func _reset_input() -> void:
	_touches.clear()
	_ignored.clear()
	_mouse_down = false
	_tap_moved = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_stop_motion()
		_reset_input()


func _over_ui(position: Vector2) -> bool:
	return ui_hit_test.is_valid() and ui_hit_test.call(position)


func _release_motion() -> void:
	velocity = Motion.release_velocity(_pan_samples, _clock, sample_window).limit_length(_glide_limit())
	_zoom_velocity = clampf(Motion.release_velocity(_zoom_samples, _clock, sample_window).x, -max_zoom_glide, max_zoom_glide)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_down:
		if (event.position - _tap_start).length() > tap_max_move:
			_tap_moved = true
		if _tap_moved:
			_pan(event.position - event.relative, event.position)
	elif event is InputEventMagnifyGesture:
		if not _over_ui(event.position) and event.factor > 0:
			_zoom_velocity = 0
			_zoom_keep(event.position, dist / event.factor)
			target_dist = dist
	elif event is InputEventPanGesture:
		if not _over_ui(event.position):
			_pan(event.position, event.position - event.delta * 8.0)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _over_ui(event.position):
			_ignored[event.index] = true
			return
		_stop_motion()
		_touches[event.index] = event.position
		Motion.begin(_pan_samples, _clock)
		if _touches.size() == 1:
			_tap_start = event.position
			_tap_time = _clock
			_tap_moved = false
		else:
			_tap_moved = true
			_init_pinch()
		return
	if _ignored.has(event.index):
		_ignored.erase(event.index)
		return
	if not _touches.has(event.index):
		return
	_touches.erase(event.index)
	if event.canceled:
		_stop_motion()
		_tap_moved = true
		if _touches.size() >= 2:
			_init_pinch()
		return
	if _touches.is_empty():
		if not _tap_moved and _clock - _tap_time < tap_max_time:
			_stop_motion()
			tapped.emit(screen_to_ground(event.position), event.position)
		else:
			_release_motion()
	elif _touches.size() == 1:
		# Lifting a second finger neither jumps the view nor creates a tap.
		_tap_moved = true
		_tap_start = _touches.values()[0]
	else:
		_init_pinch()


func _init_pinch() -> void:
	var points := _touches.values()
	_pinch_dist = maxf((points[0] - points[1]).length(), 1.0)
	_pinch_mid = (points[0] + points[1]) * 0.5
	_zoom_anchor = _pinch_mid
	Motion.begin(_zoom_samples, _clock)


func _on_drag(event: InputEventScreenDrag) -> void:
	if _ignored.has(event.index) or not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if _touches.size() == 1:
		if (event.position - _tap_start).length() > tap_max_move:
			_tap_moved = true
		if _tap_moved:
			# A deliberate one-finger drag after pinching cancels residual zoom.
			_zoom_samples.clear()
			_zoom_velocity = 0
			_pan(previous, event.position)
	else:
		var points := _touches.values()
		var separation := maxf((points[0] - points[1]).length(), 1.0)
		var midpoint: Vector2 = (points[0] + points[1]) * 0.5
		var old_dist := dist
		_zoom_keep(_pinch_mid, dist * _pinch_dist / separation)
		Motion.record(_zoom_samples, Vector2(log(dist / old_dist), 0), _clock, sample_window)
		target_dist = dist
		_pan(_pinch_mid, midpoint)
		_zoom_anchor = midpoint
		_pinch_dist = separation
		_pinch_mid = midpoint


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _over_ui(event.position):
					return
				_stop_motion()
				_mouse_down = true
				_tap_start = event.position
				_tap_time = _clock
				_tap_moved = false
				Motion.begin(_pan_samples, _clock)
			elif _mouse_down:
				_mouse_down = false
				if not _tap_moved and _clock - _tap_time < tap_max_time:
					_stop_motion()
					tapped.emit(screen_to_ground(event.position), event.position)
				else:
					_release_motion()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and not _over_ui(event.position):
				_zoom_velocity = 0
				var factor := 0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18
				target_dist = clampf(target_dist * factor, min_dist, max_dist)
				_zoom_anchor = event.position


func _coast(delta: float) -> bool:
	if velocity.length() <= 0.04:
		velocity = Vector2.ZERO
		return false
	var before := focus
	var step := Vector2(Motion.decay_distance(velocity.x, friction, delta),
		Motion.decay_distance(velocity.y, friction, delta))
	focus += Vector3(step.x, 0, step.y)
	velocity *= exp(-maxf(friction, 0.001) * delta)
	var rebound := clampf(edge_rebound, 0, 0.3)
	if focus.x < edge_margin:
		focus.x = edge_margin
		velocity.x = absf(velocity.x) * rebound
	elif focus.x > map_size - edge_margin:
		focus.x = map_size - edge_margin
		velocity.x = -absf(velocity.x) * rebound
	if focus.z < edge_margin:
		focus.z = edge_margin
		velocity.y = absf(velocity.y) * rebound
	elif focus.z > map_size - edge_margin:
		focus.z = map_size - edge_margin
		velocity.y = -absf(velocity.y) * rebound
	return before != focus


func _process(delta: float) -> void:
	_clock += delta
	if _fly:
		_apply()
		return
	var free := _touches.is_empty() and not _mouse_down
	if free and _coast(delta):
		_apply()
	var anchor := _zoom_anchor
	if anchor.x < 0:
		anchor = get_viewport().get_visible_rect().size * 0.5
	if free and absf(_zoom_velocity) > 0.002:
		var log_step := Motion.decay_distance(_zoom_velocity, zoom_friction, delta)
		_zoom_keep(anchor, dist * exp(log_step))
		target_dist = dist
		_zoom_velocity *= exp(-maxf(zoom_friction, 0.001) * delta)
		if (dist <= min_dist and _zoom_velocity < 0) or (dist >= max_dist and _zoom_velocity > 0):
			_zoom_velocity = 0
	elif absf(target_dist - dist) > 0.001:
		_zoom_keep(anchor, lerpf(dist, target_dist, 1.0 - exp(-zoom_smooth * delta)))
	else:
		_zoom_velocity = 0


func fly_to(position: Vector3, to_dist: float = -1.0, time: float = 0.9) -> void:
	_stop_motion()
	_reset_input()
	if to_dist < 0:
		to_dist = dist
	to_dist = clampf(to_dist, min_dist, max_dist)
	_fly = true
	var from_focus := focus
	var from_dist := dist
	var lift := clampf(from_focus.distance_to(position) * 0.25, 0, 120)
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		var eased := t * t * (3.0 - 2.0 * t)
		focus = from_focus.lerp(position, eased)
		dist = lerpf(from_dist, to_dist, eased) + sin(t * PI) * lift,
		0.0, 1.0, maxf(time, 0.001))
	_tween.finished.connect(func():
		_fly = false
		target_dist = dist
		_zoom_anchor = Vector2(-1, -1)
		_apply())


func set_view(position: Vector3, distance: float) -> void:
	_stop_motion()
	_reset_input()
	focus = position
	dist = clampf(distance, min_dist, max_dist)
	target_dist = dist
	_zoom_anchor = Vector2(-1, -1)
	_apply()
