extends Control
## A single gentle highlight, never a repeating strobe or a gameplay timer.
const UI := preload("res://scripts/ui_kit.gd")
const Defs := preload("res://scripts/defs.gd")
const DURATION := 2.4
const CAPTIONS := {"build": "اكتمل البناء", "train": "اكتمل التدريب",
	"research": "اكتمل البحث", "gear": "اكتمل التصنيع"}
var city: Node
var active := {}


func _ready() -> void:
	name = "CompletionFlashes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.work_completed.connect(_on_completed)


func _on_completed(kind: String, id: String) -> void:
	if Game._offline or not CAPTIONS.has(kind) or not city.plot_nodes.has(id):
		return
	if active.has(id):
		var existing: Dictionary = active[id]
		existing["remaining"] = DURATION
		if not existing["kinds"].has(kind):
			existing["kinds"].append(kind)
		return
	var panel := PanelContainer.new()
	panel.name = "Completed_" + id
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(Color("234536"), 10, UI.GOLD, 10))
	var label := UI.label(str(CAPTIONS[kind]), 17, UI.GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	active[id] = {"panel": panel, "label": label, "remaining": DURATION, "kinds": [kind]}


func _process(delta: float) -> void:
	for id in active.keys():
		var entry: Dictionary = active[id]
		entry["remaining"] = float(entry["remaining"]) - delta
		var panel: PanelContainer = entry["panel"]
		if float(entry["remaining"]) <= 0 or not city.plot_nodes.has(id):
			panel.queue_free()
			active.erase(id)
			continue
		var texts: Array[String] = []
		for kind in entry["kinds"]:
			texts.append(CAPTIONS[kind])
		(entry["label"] as Label).text = " • ".join(texts)
		panel.modulate.a = clampf(float(entry["remaining"]) / 0.7, 0, 1)
		var pos := Defs.plot_pos(id) + Vector3(0, float(city.plot_nodes[id]["top"]) + 2, 0)
		panel.visible = not city.rig.cam.is_position_behind(pos)
		if panel.visible:
			var screen: Vector2 = city.rig.cam.unproject_position(pos)
			panel.visible = get_viewport_rect().has_point(screen)
			panel.position = screen - Vector2(panel.size.x / 2, panel.size.y + 18)
			var job: Dictionary = city.timer_widgets.get(id, {})
			if not job.is_empty() and (job["root"] as Control).visible:
				panel.position.y = minf(panel.position.y, (job["root"] as Control).position.y - panel.size.y - 8)
