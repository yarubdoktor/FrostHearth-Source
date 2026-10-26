extends PanelContainer
## Isolated preview: browsing never changes the real city or save state.
const Catalog := preload("res://scripts/city_skins.gd")
const Visuals := preload("res://scripts/map_visuals.gd")

var world: Node3D
var preview_id := Catalog.DEFAULT
var preview_mesh: MeshInstance3D
var description: Label
var status: Label
var equip_button: Button
var options := {}
var viewport: SubViewport


func setup(owner_world: Node3D) -> void:
	world = owner_world
	name = "CitySkinPicker"
	custom_minimum_size = Vector2(412, 0)
	add_theme_stylebox_override("panel", world._style(Color("102335"), 12))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	add_child(list)
	var title := Label.new()
	title.text = "مظهر المدينة الخارجية"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color("f1cb8b")
	list.add_child(title)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(380, 218)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(380, 218)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X if Game.quality_high else Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("192f43")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c8e3ef")
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	preview_mesh = MeshInstance3D.new()
	preview_mesh.scale = Vector3.ONE * Visuals.CITY_SCALE
	viewport.add_child(preview_mesh)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(8, 7, 10)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.fov = 36
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	list.add_child(row)
	for id in Catalog.ORDER:
		var button := Button.new()
		button.text = Catalog.DEFINITIONS[id]["name"]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(preview_skin.bind(id))
		row.add_child(button)
		options[id] = button
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(380, 48)
	description.add_theme_font_size_override("font_size", 15)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list.add_child(description)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.modulate = Color("a9c7d8")
	list.add_child(status)
	var actions := HBoxContainer.new()
	list.add_child(actions)
	equip_button = world._button("تجهيز المظهر", equip, true)
	equip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(equip_button)
	actions.add_child(world._button("إغلاق", close))
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(154, 150)


func show_picker() -> void:
	world._close_panel()
	preview_skin(Game.city_skin)
	visible = true


func preview_skin(id: String) -> void:
	preview_id = Catalog.valid_id(id)
	preview_mesh.mesh = world._mesh_from(Catalog.mesh_path(preview_id))
	description.text = Catalog.DEFINITIONS[preview_id]["description"]
	var equipped := preview_id == Game.city_skin
	status.text = "مظهر تجميلي فقط، بلا تغيير القوة أو الموارد"
	equip_button.text = "مجهّز حاليًا" if equipped else "تجهيز المظهر"
	equip_button.disabled = equipped
	for key in options:
		options[key].modulate = Color("f3c67c") if key == preview_id else Color.WHITE


func equip() -> void:
	if Game.set_city_skin(preview_id):
		preview_skin(Game.city_skin)
		world._toast("تم تجهيز مظهر: %s" % Catalog.DEFINITIONS[Game.city_skin]["name"])


func close() -> void:
	visible = false
