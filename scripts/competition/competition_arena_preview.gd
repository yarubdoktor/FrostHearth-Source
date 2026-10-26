extends Control
## Local schematic preview of the two competition maps. Not a playable or network match.
const Arena := preload("res://scripts/competition/competition_arena.gd")
const BG := Color("#07111f")
const GOLD := Color("#f3c86a")
const TEXT := Color("#f1f5fa")
const MUTED := Color("#9db0c6")
var mode := Arena.MODE_QUALIFIER
var layout: Dictionary = {}
var map_canvas: Control
var info_label: Label
var qualifier_button: Button
var king_button: Button

func _ready() -> void:
	_build_ui()
	_set_mode(Arena.MODE_QUALIFIER)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 14
	root.offset_bottom = -14
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var back := _button("رجوع", false)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://competition_hub.tscn"))
	header.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("مخطط ساحة المنافسة", 24, GOLD))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	root.add_child(modes)
	qualifier_button = _button("ميدان التأهل · 4 مدن", true)
	qualifier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qualifier_button.pressed.connect(func(): _set_mode(Arena.MODE_QUALIFIER))
	modes.add_child(qualifier_button)
	king_button = _button("مبنى الملك · 100 لاعب", false)
	king_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	king_button.pressed.connect(func(): _set_mode(Arena.MODE_KING))
	modes.add_child(king_button)
	info_label = _label("", 15, TEXT)
	root.add_child(info_label)
	map_canvas = Control.new()
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.custom_minimum_size = Vector2(280, 320)
	map_canvas.draw.connect(_draw_map)
	root.add_child(map_canvas)
	root.add_child(_label("معاينة محلية فقط. أصول الخريطة القديمة محفوظة؛ لا يوجد قتال شبكي أو مكافآت.", 13, MUTED))

func _set_mode(next_mode: String) -> void:
	var next_layout: Dictionary = Arena.create_layout(next_mode)
	if not Arena.validate_layout(next_layout):
		info_label.text = "تعذر تحميل مخطط الخريطة."
		return
	mode = next_mode
	layout = next_layout
	qualifier_button.disabled = mode == Arena.MODE_QUALIFIER
	king_button.disabled = mode == Arena.MODE_KING
	info_label.text = "%s • %d×%d • حتى %d لاعبين" % [str(layout.get("title", "")), int(layout.get("width", 0)), int(layout.get("height", 0)), int(layout.get("max_players", 0))]
	map_canvas.queue_redraw()

func _draw_map() -> void:
	if layout.is_empty() or map_canvas.size.x < 1.0 or map_canvas.size.y < 1.0:
		return
	var margin := 12.0
	var area := Rect2(Vector2(margin, margin), map_canvas.size - Vector2(margin * 2.0, margin * 2.0))
	map_canvas.draw_rect(area, Color("#12283a"), true)
	map_canvas.draw_rect(area, Color("#52657b"), false, 2.0)
	var scale_factor := minf(area.size.x / float(layout.width), area.size.y / float(layout.height))
	var rendered_size := Vector2(float(layout.width), float(layout.height)) * scale_factor
	var origin := area.position + (area.size - rendered_size) * 0.5
	if mode == Arena.MODE_QUALIFIER:
		for i in range(1, 5):
			var fraction := float(i) / 5.0
			map_canvas.draw_line(origin + Vector2(rendered_size.x * fraction, 0), origin + Vector2(rendered_size.x * fraction, rendered_size.y), Color("#29465a"), 1.0)
			map_canvas.draw_line(origin + Vector2(0, rendered_size.y * fraction), origin + Vector2(rendered_size.x, rendered_size.y * fraction), Color("#29465a"), 1.0)
		var center := origin + Vector2(500, 500) * scale_factor
		map_canvas.draw_circle(center, 22.0, Color("#8c6a30"))
		map_canvas.draw_circle(center, 16.0, GOLD)
		map_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-24, -27), "الهدف", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		for i in range(layout.spawns.size()):
			var spawn: Vector2 = layout.spawns[i]
			var point := origin + spawn * scale_factor
			map_canvas.draw_circle(point, 10.0, Color("#182638"))
			map_canvas.draw_circle(point, 7.0, GOLD if i == 0 else Color("#8ba7bd"))
			map_canvas.draw_string(ThemeDB.fallback_font, point + Vector2(12, 4), "مدينة %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	else:
		for sector in layout.get("sectors", []):
			var center: Vector2 = origin + sector.get("center", Vector2.ZERO) * scale_factor
			var side := 480.0 * scale_factor
			var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
			var is_king := str(sector.get("kind", "")) == "king_core"
			map_canvas.draw_rect(rect, Color("#5b4726") if is_king else Color("#1b3948"), true)
			map_canvas.draw_rect(rect, Color("#f3c86a", 0.85) if is_king else Color("#3a6072"), false, 1.0)
			if is_king:
				map_canvas.draw_circle(center, maxf(9.0, side * 0.18), GOLD)
				map_canvas.draw_circle(center, maxf(5.0, side * 0.10), Color("#7b4c22"))

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT if not emphasized else Color("#17202b"))
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD if emphasized else Color("#101f31")
	style.border_color = GOLD if emphasized else Color("#52657b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	return button
