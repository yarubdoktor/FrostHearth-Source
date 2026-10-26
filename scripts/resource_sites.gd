extends Node
## Stage 10 presentation only. Game.marches remains the authoritative clock.
## A bounded marker pool avoids 3600 permanent labels / independent scenes.

const Defs := preload("res://scripts/defs.gd")
const MapVisuals := preload("res://scripts/map_visuals.gd")
const POOL_SIZE := 32
const MARKER_RANGE := 78.0
const PICK_RADIUS := MapVisuals.RESOURCE_PICK_RADIUS
const AXE_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><circle cx="48" cy="48" r="43" fill="#126345" stroke="#b6efca" stroke-width="4"/><circle cx="48" cy="48" r="36" fill="#249a63"/><path d="M32 72L59 29" stroke="#fff6dc" stroke-width="9" stroke-linecap="round"/><path d="M25 35Q49 11 76 37L69 46Q48 30 31 43Z" fill="#ffffff"/></svg>"""
const LEVEL_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M48 5L89 48 48 91 7 48Z" fill="#183950" stroke="#90b7cb" stroke-width="4"/></svg>"""
const TIMER_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="64"><rect x="2" y="2" width="252" height="60" rx="13" fill="#102b3d" fill-opacity="0.97" stroke="#8bcbac" stroke-width="2"/></svg>"""

var world: Node3D
var markers: Array = []
var active_markers := {}
var rows: Array = []
var header: Label
var empty_hint: Label
var clock := 0.0
var axe_texture: ImageTexture
var level_texture: ImageTexture
var timer_texture: ImageTexture
var candidates: Array = []


static func phase(m: Dictionary, at: float) -> Dictionary:
	var start := float(m["start"])
	var arrive := float(m["arrive"])
	var leave := float(m["leave"])
	var back := float(m["back"])
	if at >= back:
		return {"id": "done", "text": "اكتملت", "remaining": 0.0, "progress": 1.0}
	var id := "outbound"
	var text := "في الطريق"
	var begin := start
	var end := arrive
	if at >= leave:
		id = "return"
		text = "عائدة"
		begin = leave
		end = back
	elif at >= arrive:
		id = "gather" if str(m.get("kind", "")) == "res" else "work"
		text = "جمع الموارد" if id == "gather" else "تنفيذ المهمة"
		begin = arrive
		end = leave
	return {"id": id, "text": text, "remaining": maxf(end - at, 0.0),
		"progress": clampf((at - begin) / maxf(end - begin, 0.001), 0.0, 1.0)}


static func timer(seconds: float) -> String:
	var whole := maxi(0, int(ceil(seconds)))
	return "%02d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]


func setup(owner_world: Node3D) -> void:
	world = owner_world
	axe_texture = _svg_texture(AXE_SVG)
	level_texture = _svg_texture(LEVEL_SVG)
	timer_texture = _svg_texture(TIMER_SVG)
	# Cached spatial list for nearby candidates; refreshed at 4 Hz.
	for r in world.data["resources"]:
		candidates.append(r)
	_build_panel()
	refresh()


func _svg_texture(svg: String) -> ImageTexture:
	var im := Image.new()
	im.load_svg_from_string(svg)
	return ImageTexture.create_from_image(im)


func _sprite(texture: Texture2D, pos: Vector3, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.fixed_size = true
	sprite.pixel_size = pixel_size
	sprite.position = pos
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite


func _label(text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = world.font
	label.font_size = size
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0007
	label.position = pos
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "MarchStatusPanel"
	panel.add_theme_stylebox_override("panel", world._style(Color(0.035, 0.08, 0.14, 0.94), 12))
	panel.custom_minimum_size = Vector2(270, 0)
	world.ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	panel.offset_top = 150
	panel.offset_right = -8
	panel.offset_left = -278
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	world.ui_blockers.append(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	panel.add_child(list)
	header = Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_theme_font_size_override("font_size", 17)
	list.add_child(header)
	empty_hint = Label.new()
	empty_hint.text = "اختر موقع موارد لإرسال فرقة"
	empty_hint.add_theme_font_size_override("font_size", 14)
	empty_hint.modulate = Color("aec1d0")
	list.add_child(empty_hint)
	for i in Game.MAX_MARCHES:
		var box := VBoxContainer.new()
		list.add_child(box)
		var button := Button.new()
		button.custom_minimum_size = Vector2(232, 46)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", world._style(Color("15354b"), 7))
		button.pressed.connect(_focus_march.bind(i))
		box.add_child(button)
		var time_label := Label.new()
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.text_direction = Control.TEXT_DIRECTION_LTR
		time_label.add_theme_font_size_override("font_size", 17)
		box.add_child(time_label)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 5
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.add_theme_stylebox_override("background", world._style(Color("0a1a29"), 3))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("51c58b")
		fill.set_corner_radius_all(3)
		progress.add_theme_stylebox_override("fill", fill)
		box.add_child(progress)
		rows.append({"box": box, "button": button, "time": time_label, "progress": progress})


func _focus_march(index: int) -> void:
	if index >= Game.marches.size():
		return
	var m: Dictionary = Game.marches[index]
	world.rig.fly_to(Vector3(float(m["tx"]), 0, float(m["ty"])), 34.0)


func _process(delta: float) -> void:
	if world == null:
		return
	clock -= delta
	if clock <= 0:
		clock = 0.25
		refresh()


func refresh() -> void:
	var at := Game.now()
	header.text = "الفرق في مهمة: %d من %d" % [Game.marches.size(), Game.MAX_MARCHES]
	empty_hint.visible = Game.marches.is_empty()
	for i in rows.size():
		var row: Dictionary = rows[i]
		row["box"].visible = i < Game.marches.size()
		if i >= Game.marches.size():
			continue
		var m: Dictionary = Game.marches[i]
		var state := phase(m, at)
		var kind := str(m.get("kind", ""))
		var name: String = Defs.RES_NAMES.get(str(m.get("t", "")), "استطلاع" if kind == "scout" else "مهمة")
		row["button"].text = "%s : %s" % [name, state["text"]]
		row["time"].text = timer(float(state["remaining"]))
		row["time"].modulate = Color("7fe2a2") if state["id"] == "gather" else Color("acd8f5")
		row["progress"].value = float(state["progress"]) * 100.0
	_update_nearby()
	_update_active(at)


func _update_nearby() -> void:
	var near: Array = []
	var focus: Vector3 = world.rig.focus
	var cam: Camera3D = world.rig.cam
	for r in candidates:
		var pos := Vector3(r["x"], r["h"], r["y"])
		var distance := Vector2(pos.x - focus.x, pos.z - focus.z).length_squared()
		if distance > MARKER_RANGE * MARKER_RANGE or world.rig.dist > 115:
			continue
		if not Game.is_explored(int(r["x"]), int(r["y"])) or cam.is_position_behind(pos):
			continue
		if not world.get_viewport().get_visible_rect().has_point(cam.unproject_position(pos)):
			continue
		near.append({"resource": r, "distance": distance})
	near.sort_custom(func(a: Dictionary, b: Dictionary): return a["distance"] < b["distance"])
	var count := mini(POOL_SIZE, near.size())
	while markers.size() < count:
		markers.append({"plate": _sprite(level_texture, Vector3.ZERO, 0.00028),
			"label": _label("", Vector3.ZERO, 22, Color.WHITE)})
	for i in markers.size():
		var marker: Dictionary = markers[i]
		marker["plate"].visible = i < count
		marker["label"].visible = i < count
		if i < count:
			var r: Dictionary = near[i]["resource"]
			var pos := Vector3(r["x"], r["h"], r["y"]) + MapVisuals.RESOURCE_BADGE_OFFSET
			marker["plate"].position = pos
			marker["label"].position = pos + Vector3(0, 0.02, 0)
			marker["label"].text = str(int(r["l"]))


func _update_active(at: float) -> void:
	var alive := {}
	for m in Game.marches:
		if m.get("kind", "") != "res" or phase(m, at)["id"] != "gather":
			continue
		var key := "%d:%d" % [floori(m["tx"]), floori(m["ty"])]
		if not alive.has(key):
			alive[key] = {"march": m, "count": 0}
		alive[key]["count"] += 1
	for key in alive:
		if not active_markers.has(key):
			active_markers[key] = {"icon": _sprite(axe_texture, Vector3.ZERO, 0.0004),
				"plate": _sprite(timer_texture, Vector3.ZERO, 0.00055),
				"label": _label("", Vector3.ZERO, 24, Color("c0ffd6"))}
			active_markers[key]["plate"].render_priority = -1
			active_markers[key]["label"].render_priority = 1
		var m: Dictionary = alive[key]["march"]
		var marker: Dictionary = active_markers[key]
		var height := 0.2
		for r in candidates:
			if int(r["x"]) == int(m["tx"]) and int(r["y"]) == int(m["ty"]):
				height = float(r["h"])
				break
		var pos := Vector3(m["tx"], height + MapVisuals.RESOURCE_ACTIVE_HEIGHT, m["ty"])
		var shown: bool = Game.is_explored(int(m["tx"]), int(m["ty"])) and world.rig.dist <= 115
		marker["icon"].visible = shown
		marker["plate"].visible = shown
		marker["label"].visible = shown
		marker["icon"].position = pos
		marker["plate"].position = pos + Vector3(0, 1.35, 0)
		marker["label"].position = pos + Vector3(0, 1.35, 0)
		var count_text := " ×%d" % int(alive[key]["count"]) if int(alive[key]["count"]) > 1 else ""
		# Icon and mission panel communicate "gathering"; a digits-only plaque
		# avoids BiDi collisions between Arabic and the colon-separated clock.
		marker["label"].text = timer(float(m["leave"]) - at) + count_text
	for key in active_markers.keys():
		if not alive.has(key):
			active_markers[key]["icon"].queue_free()
			active_markers[key]["plate"].queue_free()
			active_markers[key]["label"].queue_free()
			active_markers.erase(key)


func pick(world_pos: Vector3, screen_pos: Vector2) -> Dictionary:
	# Never replace a click in unexplored land by a nearby explored resource.
	if not Game.is_explored(floori(world_pos.x), floori(world_pos.z)):
		return {}
	var best := {}
	var best_score := INF
	var cam: Camera3D = world.rig.cam
	for r in candidates:
		if not Game.is_explored(int(r["x"]), int(r["y"])):
			continue
		var pos := Vector3(r["x"], r["h"], r["y"])
		if cam.is_position_behind(pos):
			continue
		var distance := Vector2(pos.x - world_pos.x, pos.z - world_pos.z).length()
		var score := distance / PICK_RADIUS
		if screen_pos != Vector2.ZERO:
			var center := cam.unproject_position(pos + Vector3(0, 0.65, 0))
			var edge := cam.unproject_position(pos + Vector3(PICK_RADIUS, 0, 0))
			var radius := clampf(center.distance_to(edge), 18.0, 44.0)
			score = center.distance_to(screen_pos) / radius
		if score <= 1.0 and score < best_score:
			best_score = score
			best = {"kind": "res", "t": r["t"], "l": r["l"],
				"x": int(r["x"]), "y": int(r["y"]), "pos": pos}
	return best
