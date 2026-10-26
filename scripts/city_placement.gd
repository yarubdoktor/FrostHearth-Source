extends RefCounted
## Four large building plots (2x2), not four of the old one-unit tiles.
const PLOT_SIDE := 5.0
const PLOTS_PER_SIDE := 2
const FOOTPRINT_SIDE := PLOT_SIDE * PLOTS_PER_SIDE
const HALF := FOOTPRINT_SIDE * 0.5
const MIN_CITY_SPACING := FOOTPRINT_SIDE + 2.0
var data: Dictionary
var rows: Array


func _init(world_data: Dictionary) -> void:
	data = world_data
	var grid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city_placement_grid.json"))
	rows = grid["rows"]


static func overlaps(a: Vector2, b: Vector2, clearance := MIN_CITY_SPACING) -> bool:
	return absf(a.x - b.x) < clearance and absf(a.y - b.y) < clearance


static func tiles(center: Vector2) -> Rect2i:
	var start := Vector2i(floori(center.x - HALF), floori(center.y - HALF))
	var end := Vector2i(ceili(center.x + HALF), ceili(center.y + HALF))
	return Rect2i(start, end - start)


func reason(center: Vector2, ignore_city_index := -1) -> String:
	var x := floori(center.x)
	var y := floori(center.y)
	if x < 0 or y < 0 or x >= 1200 or y >= 1200:
		return "خارج حدود الخريطة"
	var terrain_ok := false
	for span in rows[y]:
		if x >= int(span[0]) and x < int(span[1]):
			terrain_ok = true
			break
	if not terrain_ok:
		return "تحتاج المدينة أرضًا مستوية وجافة تكفي كامل مساحتها"
	for index in data["cities"].size():
		if index == ignore_city_index:
			continue
		var city: Dictionary = data["cities"][index]
		if overlaps(center, Vector2(city["x"], city["y"])):
			return "قريب جدًا من مدينة أخرى؛ اترك حرمًا فاصلًا"
	for res in data["resources"]:
		if overlaps(center, Vector2(res["x"], res["y"]), HALF + 2.3):
			return "مساحة المدينة تتداخل مع موقع موارد"
	for beast in data["beasts"]:
		if overlaps(center, Vector2(beast["x"], beast["y"]), HALF + 1.0):
			return "مساحة المدينة تتداخل مع موقع وحش"
	for landmark in data["landmarks"]:
		if overlaps(center, Vector2(landmark["x"], landmark["y"]), HALF + float(landmark["r"]) + 3.0):
			return "مساحة المدينة تتداخل مع معلم أو ممر"
	if overlaps(center, Vector2(700.5, 920.5), HALF + 2.0):
		return "مساحة المدينة تتداخل مع المنفث الحراري"
	return ""
