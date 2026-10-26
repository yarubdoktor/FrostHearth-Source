extends Control
## Read-only projection of existing march phases, no new state or saved timers.
const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
var world: Node
var widgets := {}


static func phase(m: Dictionary, t: float) -> Dictionary:
	var start := float(m.get("start", 0))
	var arrive := float(m.get("arrive", start))
	var leave := float(m.get("leave", arrive))
	var back := float(m.get("back", leave))
	if t >= back:
		return {}
	var from := start
	var until := arrive
	var caption := "وصول"
	if t >= leave:
		from = leave
		until = back
		caption = "عودة"
	elif t >= arrive:
		from = arrive
		until = leave
		caption = "جمع" if str(m.get("kind", "")) == "res" else "مهمة"
	return {"caption": caption, "remaining": maxf(until - t, 0),
		"progress": clampf((t - from) / maxf(until - from, 0.001), 0, 1)}


func _ready() -> void:
	name = "MarchTimers"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_widget() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 144
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.10, 0.17, 0.9), 9, Color("80cbe8"), 6))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var label := UI.label("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	var bar := UI.progress_bar(Color("80cbe8"))
	bar.custom_minimum_size.y = 4
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	add_child(panel)
	return {"panel": panel, "label": label, "bar": bar}


func _process(_delta: float) -> void:
	var alive := {}
	var all: Array = Game.marches.duplicate()
	if not Game.venture.is_empty():
		all.append(Game.venture)
	var t := Game.now()
	var placed: Array[Rect2] = []
	for march in all:
		var key := "venture" if march == Game.venture else str(march["start"])
		var current := phase(march, t)
		if current.is_empty() or not world.march_vis.has(key):
			continue
		alive[key] = true
		if not widgets.has(key):
			widgets[key] = _make_widget()
		var item: Dictionary = widgets[key]
		var panel: Control = item["panel"]
		(item["label"] as Label).text = "%s • %s" % [current["caption"], Defs.fmt_time_short(current["remaining"])]
		(item["bar"] as ProgressBar).value = float(current["progress"]) * 100
		var troop: Node3D = world.march_vis[key]["troop"]
		var position3 := troop.global_position + Vector3(0, 2, 0)
		panel.visible = not world.rig.cam.is_position_behind(position3)
		if not panel.visible:
			continue
		var screen: Vector2 = world.rig.cam.unproject_position(position3)
		var safe := Rect2(8, 170, maxf(size.x - 16, 0), maxf(size.y - 290, 0))
		panel.visible = safe.has_point(screen)
		if not panel.visible:
			continue
		var position2 := screen - Vector2(panel.size.x / 2, panel.size.y + 16)
		for occupied in placed:
			if Rect2(position2, panel.size).intersects(occupied):
				position2.y = occupied.position.y - panel.size.y - 5
		position2.x = clampf(position2.x, 8, maxf(8, size.x - panel.size.x - 8))
		position2.y = maxf(position2.y, 170)
		panel.position = position2
		placed.append(Rect2(position2, panel.size))
	for key in widgets.keys():
		if not alive.has(key):
			(widgets[key]["panel"] as Control).queue_free()
			widgets.erase(key)
