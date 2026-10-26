extends Node
## Stage 12 review-only presentation. Not a province or a server authority.
const CENTER := Vector2(790, 842)
const RADIUS := 185.0
const BLEND := 25.0
var enabled := true
var whole_exterior := true
var materials: Array[ShaderMaterial] = []
var terrain_surfaces := 0
var lake_surfaces := 0
var ground_material: ShaderMaterial
var water_material: ShaderMaterial
var resource_meshes := {}


func register_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("green_enabled", enabled)
	material.set_shader_parameter("whole_exterior", whole_exterior)
	material.set_shader_parameter("preview_center", CENTER)
	material.set_shader_parameter("preview_radius", RADIUS)
	material.set_shader_parameter("preview_blend", BLEND)
	materials.append(material)


func create_material(shader: Shader, name_hint := "") -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = name_hint
	register_material(material)
	return material


func setup(map_root: Node, forest: ShaderMaterial) -> void:
	register_material(forest)
	_paint_map(map_root)


func _paint_map(n: Node) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var original: Material = n.mesh.surface_get_material(i)
			if original == null:
				continue
			if str(n.name).begins_with("Chunk_") and original.resource_name == "Snow":
				if ground_material == null:
					ground_material = create_material(preload("res://shaders/external_grass.gdshader"))
				n.set_surface_override_material(i, ground_material)
				terrain_surfaces += 1
			elif str(n.name).begins_with("Lake_"):
				if water_material == null:
					water_material = create_material(preload("res://shaders/external_water.gdshader"))
				n.set_surface_override_material(i, water_material)
				lake_surfaces += 1
	for child in n.get_children():
		_paint_map(child)


func prepare_resource(source: Mesh, asset_path: String) -> Mesh:
	# Keep imported source assets immutable so two view contexts cannot repaint
	# one another through Godot's resource cache.
	var mesh: Mesh = source.duplicate()
	mesh.set_meta("source_asset", asset_path)
	resource_meshes[asset_path] = mesh
	for i in mesh.get_surface_count():
		var original: Material = mesh.surface_get_material(i)
		if original == null:
			continue
		if original.resource_name == "Snow":
			mesh.surface_set_material(i, create_material(preload("res://shaders/external_resource_snow.gdshader"), "Snow"))
		elif original.resource_name == "Matte":
			mesh.surface_set_material(i, create_material(preload("res://shaders/external_resource_matte.gdshader"), "Matte"))
	return mesh


func set_enabled(value: bool) -> void:
	enabled = value
	for material in materials:
		material.set_shader_parameter("green_enabled", enabled)


func green_at(position: Vector2) -> bool:
	return enabled and (whole_exterior or position.distance_to(CENTER) < RADIUS - BLEND * 0.5)
