extends Node3D
## الطبقة 1/6 — أساس المدينة: كل المتغيرات والثوابت + أدوات صغيرة مشتركة (إنشاء نماذج، نصوص ثلاثية، تنبيه).
## قاعدة الطبقات: كل طبقة تستدعي ما في طبقتها وما تحتها فقط (يفحصها tools/split_check.py). المتغيرات والثوابت تبقى هنا حصرًا.


## مشهد المدينة: البناء والتطوير، والفرن، والسكان، والجمع، والمهام
const Defs := preload("res://scripts/defs.gd")
const UI := preload("res://scripts/ui_kit.gd")
const StrategyCamera := preload("res://scripts/strategy_camera.gd")
const HomeHud := preload("res://scripts/ui/home_hud.gd")
const JobTimers := preload("res://scripts/ui/job_timers.gd")

var rig: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var fire_light: OmniLight3D
var snow: CPUParticles3D
var smoke: CPUParticles3D
var font: Font
var scenes := {}
var plot_nodes := {}
var citizens: Array = []
var citizen_meshes: Array = []

# الواجهة
var ui: Control
var blockers: Array[Control] = []
var res_chips := {}
var gem_label: Label
var temp_label: Label
var temp_chip: PanelContainer
var pop_label: Label
var sick_label: Label
var builder_rows: Array = []
var job_rows: Array = []        # صفوف التدريب والبحث في الطابور الجانبي (Stage 16)
var timer_layer: Control = null # طبقة مؤقتات فوق المباني
var timer_widgets := {}          # id الموقع ← لوحة المؤقت
var storm_label: Label
var frost_overlay: ColorRect
var task_title: Label
var task_prog: Label
var task_btn: Button
var toast_box: VBoxContainer
var modal_layer: Control
var dev_btn: Button = null
var avatar_btn: Button = null
var avatar_id := ""
var march_head: Label
var march_box: VBoxContainer
var march_rows: Array = []
var hud_collapsed := false

# لوحة المبنى
var sel := ""
var bp: PanelContainer
var bp_title: Label
var bp_desc: Label
var bp_stats: Label
var bp_store_row: HBoxContainer
var bp_store: Label
var bp_cost_row: HBoxContainer
var bp_cost_chips := {}
var bp_time: Label
var bp_reasons: Label
var bp_progress: ProgressBar
var bp_main: Button
var bp_instant: Button
var bp_speed: Button
var bp_cancel: Button
var bp_mode_row: HBoxContainer
var bp_mode_btns: Array = []
var bp_open: Button
var sel_ring: MeshInstance3D

# المرحلة الثانية
var aurora_label: Label
var trust_label: Label
var power_label: Label
var side_btns := {}
var raid_label: Label
var soldier_meshes := {}
var soldier_nodes: Array = []
var _soldier_sig := ""
var crystal_scene: Node3D
var crystal_nodes: Array = []
var wolf_scene: Node3D
var raid_anim: Array = []
var raid_anim_t := -1.0
var raid_anim_win := false
var win_refresh: Callable
var win_tick: Array = []
var win_layer: Control
var army_tier := 1
var train_tp := "shield"
var army_n := 20
var hero_sel := "siraj"
var hero_detail := false   # Stage 29.1: gallery / selected hero details (UI only).
var tech_branch := 0
var wall_ring: Node3D
var wall_ring_key := ""


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	# These templates are deliberately outside the tree; children are freed
	# automatically, but orphan Node templates need an explicit owner cleanup.
	var templates: Array = citizen_meshes + soldier_meshes.values()
	templates.append(crystal_scene)
	templates.append(wolf_scene)
	for template in templates:
		if is_instance_valid(template) and template.get_parent() == null:
			template.free()
	citizen_meshes.clear()
	soldier_meshes.clear()
	crystal_scene = null
	wolf_scene = null


func _fix(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for s in n.mesh.get_surface_count():
			var mat := n.mesh.surface_get_material(s) as BaseMaterial3D
			if mat:
				mat.vertex_color_use_as_albedo = true
				if mat.resource_name == "Snow" or mat.resource_name == "Matte":
					mat.metallic_specular = 0.25
				if mat.resource_name == "Glow":
					mat.emission_enabled = true
					mat.emission = Color(0.35, 0.95, 1.0)
					mat.emission_energy_multiplier = 2.5
	for c in n.get_children():
		_fix(c)


func _inst(path: String) -> Node3D:
	if not scenes.has(path):
		scenes[path] = load(path)
	var n: Node3D = scenes[path].instantiate()
	_fix(n)
	return n


# ================================================================ مواقع البناء
func _tier(id: String, lv: int) -> int:
	if lv < 5:
		return 0
	return 1 if lv < 15 else 2


func _label3d(text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.outline_size = maxi(4, int(size * 0.20))
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.08, 0.14, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.no_depth_test = true
	l.position = pos
	return l


func _random_spot() -> Vector3:
	var built: Array = []
	for id in Defs.PLOTS:
		if Game.level(id) > 0 and id != "furnace":
			built.append(id)
	if built.is_empty() or randf() < 0.35:
		var a := randf() * TAU
		return Defs.CITY_CENTER + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 11.0)
	var id: String = built[randi() % built.size()]
	var p := Defs.plot_pos(id)
	var toward := (Defs.CITY_CENTER - p).normalized()
	return p + toward * 2.6 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))


func _icon_button(icon_name: String, text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, "dark", 64)
	b.icon = UI.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(108, 64)
	return b


func _over_ui(p: Vector2) -> bool:
	if modal_layer.get_child_count() > 0:
		return true
	for c in blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _close_panel() -> void:
	sel = ""
	bp.visible = false
	sel_ring.visible = false


var _last_sig := ""


const WinAudioStats := preload("res://scripts/ui/windows/audio_stats_windows.gd")


func _vol_text(v: float) -> String:
	return WinAudioStats.vol_text(v)


func _cold_name(c: int) -> String:
	return WinAudioStats.cold_name(c)


const WinDev := preload("res://scripts/ui/windows/dev_windows.gd")


func _toast(t: String) -> void:
	if toast_box == null:
		return
	var l := UI.label(t, 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_stylebox_override("normal", UI.style(Color(0.04, 0.08, 0.14, 0.88), 18))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(l)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _go_map() -> void:
	Game.save_game()
	get_tree().change_scene_to_file("res://world_map.tscn")


func _forecast_text(fc: Dictionary) -> String:
	var out := "%d ذئب" % int(fc["wolves"]) if fc["exact"] else "من %d إلى %d ذئب" % [fc["lo"], fc["hi"]]
	if fc["storm_known"]:
		out += " • مع عاصفة" if fc["storm"] else " • بلا عاصفة"
	return out


func _forecast_acc(lv: int) -> String:
	if lv <= 0:
		return "—"
	var e := Defs.forecast_error(lv)
	return "دقيق" if e <= 0.0 else "±%d%%" % roundi(e * 100.0)


# ================================================================ النوافذ الكبيرة
var win_dim: Control
var win_scroll: ScrollContainer


var _portraits := {}
const WinProg := preload("res://scripts/ui/windows/progression_windows.gd")
const MarketWin := preload("res://scripts/ui/windows/market_window.gd")
const WorkshopWin := preload("res://scripts/ui/windows/workshop_window.gd")
const ProfileWin := preload("res://scripts/ui/windows/profile_window.gd")
