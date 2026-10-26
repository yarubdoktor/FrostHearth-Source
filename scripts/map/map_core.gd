extends Node3D
const MarchTimers := preload("res://scripts/ui/march_timers.gd")
## الطبقة 1/5 — أساس الخريطة: كل المتغيرات والثوابت + أدوات مشتركة (شبكات المجسمات، أنماط الواجهة، النصوص، اختيار المدن، مواضع الفرق).
## قاعدة الطبقات: كل طبقة تستدعي ما في طبقتها وما تحتها فقط (يفحصها tools/split_check.py). المتغيرات والثوابت تبقى هنا حصرًا.


## خريطة الصقيع 1200×1200 — المشهد الرئيسي
## يحمّل الخريطة GLB، ويوزّع المدن والموارد والوحوش من ملف JSON،
## ويبني الواجهة العربية ونظام إرسال القوات.
const StrategyCamera := preload("res://scripts/strategy_camera.gd")
const Defs := preload("res://scripts/defs.gd")
const ResourceSites := preload("res://scripts/resource_sites.gd")
const MapVisuals := preload("res://scripts/map_visuals.gd")
const MapHud := preload("res://scripts/ui/map_hud.gd")
const CitySkins := preload("res://scripts/city_skins.gd")
const CitySkinPicker := preload("res://scripts/city_skin_picker.gd")
const ExternalEnvironment := preload("res://scripts/external_environment.gd")
const CityPlacement := preload("res://scripts/city_placement.gd")
const MAP_PATH := "res://assets/frost_map.glb"
const DATA_PATH := "res://data/map_data.json"
const FONT_PATH := "res://fonts/NotoKufiArabic.ttf"

const RES_NAMES := {"coal": "منجم فحم", "wood": "معسكر خشب", "iron": "منجم حديد", "food": "أرض صيد"}
const RES_GAIN := {"coal": 1800, "wood": 3200, "iron": 600, "food": 4500}
const BEAST_NAMES := {"wolf": "ذئب الثلج", "bear": "دب قطبي"}
const TEAM_NAMES := {"me": "مدينتك", "ally": "تحالف حليف", "enemy": "تحالف عدو", "neutral": "محايد"}
const LM_TYPES := {"sun_city": "المركز — معركة السيادة", "stronghold": "معقل", "fortress": "قلعة",
		"gate": "بوابة", "pass": "ممر جبلي"}

var data: Dictionary
var rig: Node3D
var font: Font
var lookup := {}
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var night := false
var snow: CPUParticles3D

var ui: Control
var ui_blockers: Array[Control] = []
var coord_label: Label
var res_chips := {}
var power_label: Label
var tools_sheet: Control
var nav_btns := {}
var march_label: Label
var resource_sites: Node
var city_targets: Array = []
var city_clearance_material: ShaderMaterial
var skin_picker: PanelContainer
var external_environment: Node
var biome_button: Button
var city_placement: RefCounted
var placement_preview: Node3D
var placement_fill: StandardMaterial3D
var placement_outline: StandardMaterial3D
var panel: PanelContainer
var p_title: Label
var p_sub: Label
var p_info: Label
var p_action: Button
var toast: Label
var toast_time := 0.0

var selected: Dictionary = {}
var sel_ring: MeshInstance3D
var sel_rr := 1.0
var home_node: MeshInstance3D
var home_label: Label3D
var home_pos: Vector3
var home_info: Dictionary
var troop_mesh: Mesh
var march_mat: StandardMaterial3D

# المرحلة 3: جبهة الصقيع (نموذج أولي)
var vent_node: MeshInstance3D
var vent_label: Label3D
var front_label: Label
var vent_win: PanelContainer = null
var vent_spins := {}
var _front_on := false
var _scan_best := 0.0
var _scan_found := false

# تعميق الخريطة: ضباب الحرب + المعاقل والقلاع + التشكيلات
var fog_labels: Array = []          # [{"label": Label3D, "x": int, "y": int}] — تُخفى حتى الكشف
var fog_tex: ImageTexture
var fog_img: Image
var holds_label: Label
var venture_target := {}            # هدف نافذة الإرسال — مستقل عن «selected»
var venture_formation := "balanced"
var _formation_btns := {}

const FOG_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
uniform sampler2D fog_tex;
uniform vec4 fog_color : source_color = vec4(0.03, 0.06, 0.12, 0.92);
varying vec2 wxz;
void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float e = texture(fog_tex, wxz / 1200.0).r;
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * (1.0 - e);
}
"""


func _terrain_height_at(x: float, z: float) -> float:
	## أعلى قمة تضاريس قريبة من النقطة (وقوف المنفث فوق الثلج لا داخله)
	_scan_best = 0.0
	_scan_found = false
	_scan_node(self, x, z)
	return _scan_best if _scan_found else 0.6


func _scan_node(n: Node, x: float, z: float) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(i)
				if arrays.size() > ArrayMesh.ARRAY_VERTEX:
					var pos: PackedVector3Array = arrays[ArrayMesh.ARRAY_VERTEX]
					for p in pos:
						if absf(p.x - x) <= 1.25 and absf(p.z - z) <= 1.25:
							if not _scan_found or p.y > _scan_best:
								_scan_best = p.y
								_scan_found = true
	for c in n.get_children():
		_scan_node(c, x, z)


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null


## نضمن أن ألوان الرؤوس (Vertex Colors) تُستخدم كلون أساسي للمواد
func _fix_mesh(m: Mesh) -> void:
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s) as BaseMaterial3D
		if mat:
			mat.vertex_color_use_as_albedo = true
			if mat.resource_name == "Snow" or mat.resource_name == "Matte":
				mat.metallic_specular = 0.25


func _fix_materials(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		_fix_mesh(n.mesh)
	for c in n.get_children():
		_fix_materials(c)


func _mesh_from(path: String) -> Mesh:
	var inst: Node = load(path).instantiate()
	var mi := _find_mesh(inst)
	var m: Mesh = mi.mesh
	_fix_mesh(m)
	inst.free()
	return m


func _reg(x0: int, y0: int, w: int, info: Dictionary) -> void:
	for dx in w:
		for dy in w:
			lookup[Vector2i(x0 + dx, y0 + dy)] = info


func _register_city(info: Dictionary) -> void:
	var pos: Vector3 = info["pos"]
	var area: Rect2i = CityPlacement.tiles(Vector2(pos.x, pos.z))
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			var key := Vector2i(x, y)
			# Legacy saves may have a now-invalid home location. Never erase
			# resource/landmark destinations to register that old footprint.
			if not lookup.has(key):
				lookup[key] = info


func _label3d(text: String, pos: Vector3, size: int, color: Color, range_end: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.outline_size = int(size * 0.22)
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.08, 0.14, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.no_depth_test = true
	l.position = pos
	if range_end > 0:
		l.visibility_range_end = range_end
	add_child(l)
	return l


func _on_view(f: Vector3, d: float) -> void:
	if coord_label:
		coord_label.text = "X: %d   Y: %d" % [int(f.x), int(f.z)]
	if env:
		env.fog_density = (0.0022 if night else 0.0012) * clampf(60.0 / d, 0.25, 1.5)
	if snow:
		var green: bool = external_environment.green_at(Vector2(f.x, f.z))
		snow.emitting = not green
		snow.visible = not green
		var s := clampf(d * 0.9, 40.0, 200.0)
		snow.emission_box_extents = Vector3(s, 1, s)
		snow.position = Vector3(0, clampf(d * 0.45, 18.0, 90.0), 0)
		snow.scale = Vector3.ONE * clampf(d / 60.0, 1.0, 3.0)


# ================================================================ الواجهة
func _style(bg: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.border_color = Color(1, 1, 1, 0.12)
	s.set_border_width_all(1)
	return s


func _button(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_stylebox_override("normal", _style(Color("e0a33a") if accent else Color(0.07, 0.12, 0.2, 0.86)))
	b.add_theme_stylebox_override("hover", _style(Color("f0b54a") if accent else Color(0.12, 0.2, 0.32, 0.92)))
	b.add_theme_stylebox_override("pressed", _style(Color("c78a25") if accent else Color(0.04, 0.08, 0.14, 0.95)))
	b.add_theme_color_override("font_color", Color("1a1206") if accent else Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("1a1206") if accent else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("1a1206") if accent else Color.WHITE)
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: Sound.ui_click())
	return b


func _panel(anchor_preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.05, 0.1, 0.17, 0.82)))
	ui.add_child(p)
	p.set_anchors_and_offsets_preset(anchor_preset, Control.PRESET_MODE_MINSIZE, 14)
	ui_blockers.append(p)
	return p


func _over_ui(p: Vector2) -> bool:
	for c in ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _refresh_stock() -> void:
	MapHud.refresh(self)
	march_label.text = "الفرق في مهمة: %d / %d" % [Game.marches.size(), Game.MAX_MARCHES]
	if holds_label != null:
		holds_label.text = "معاقل: %d/4 • قلاع: %d/8" % [Game.holds_count("stronghold"), Game.holds_count("fortress")]


func _fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)


func _toast(t: String) -> void:
	toast.text = t
	toast.modulate.a = 1.0
	toast.visible = true
	toast_time = 3.0


func _go_city() -> void:
	Game.save_game()
	get_tree().change_scene_to_file("res://city.tscn")


# ================================================================ الاختيار
func _pick_city(world_pos: Vector3, screen_pos: Vector2) -> Dictionary:
	if not Game.is_explored(floori(world_pos.x), floori(world_pos.z)):
		return {}
	var result := {}
	var best := INF
	for city in city_targets:
		if not Game.is_explored(int(city["x"]), int(city["y"])):
			continue
		var pos: Vector3 = city["pos"]
		if rig.cam.is_position_behind(pos):
			continue
		var score := Vector2(pos.x - world_pos.x, pos.z - world_pos.z).length() / MapVisuals.CITY_PICK_RADIUS
		if screen_pos != Vector2.ZERO:
			var center: Vector2 = rig.cam.unproject_position(pos + Vector3(0, 1.4, 0))
			var edge: Vector2 = rig.cam.unproject_position(pos + Vector3(MapVisuals.CITY_PICK_RADIUS, 0, 0))
			var radius := clampf(center.distance_to(edge), 22.0, 96.0)
			score = center.distance_to(screen_pos) / radius
		if score <= 1.0 and score < best:
			result = city
			best = score
	return result


func _close_panel() -> void:
	panel.visible = false
	sel_ring.visible = false
	selected = {}
	placement_preview.visible = false


func _home_placement_reason(tile: Vector2i) -> String:
	var center := Vector2(tile) + Vector2(0.5, 0.5)
	var error: String = city_placement.reason(center)
	if not error.is_empty():
		return error
	var area: Rect2i = CityPlacement.tiles(center)
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			if not Game.is_explored(x, y):
				return "يجب استكشاف كامل مساحة المدينة قبل نقلها"
	return ""

var _formation_desc: Label = null
var vent_summary: Label = null
var vent_verdict: Label = null   # Stage 33: فرصة النصر والخسائر
var vent_home: Label = null      # Stage 33: الدفاع المتبقي في المدينة
var vent_send_btn: Button = null


# ================================================================ المسيرات (مصدرها Game.marches)
var march_vis := {}   # start time -> {troop, line, im}


func _march_pos(m: Dictionary, t: float) -> Array:
	## [الموقع، الوجهة الحالية للرسم]
	var a := Vector3(m["fx"], 0, m["fy"])
	var b := Vector3(m["tx"], 0, m["ty"])
	if t < float(m["arrive"]):
		var k := inverse_lerp(float(m["start"]), float(m["arrive"]), t)
		return [a.lerp(b, k), b]
	if t < float(m["leave"]):
		return [b, b]
	var k2 := inverse_lerp(float(m["leave"]), float(m["back"]), t)
	return [b.lerp(a, clampf(k2, 0.0, 1.0)), a]


func _draw_dashes(im: ImmediateMesh, a: Vector3, b: Vector3, phase: float) -> void:
	im.clear_surfaces()
	var d := b - a
	d.y = 0
	var length := d.length()
	if length < 0.6:
		return
	var dir := d / length
	var side := Vector3(-dir.z, 0, dir.x) * 0.22
	var y := 0.6
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := fmod(phase, 1.6)
	if s < 0:
		s += 1.6
	while s < length:
		var e := minf(s + 0.9, length)
		var p0 := Vector3(a.x, y, a.z) + dir * s
		var p1 := Vector3(a.x, y, a.z) + dir * e
		im.surface_add_vertex(p0 - side)
		im.surface_add_vertex(p0 + side)
		im.surface_add_vertex(p1 + side)
		im.surface_add_vertex(p0 - side)
		im.surface_add_vertex(p1 + side)
		im.surface_add_vertex(p1 - side)
		s += 1.6
	im.surface_end()
