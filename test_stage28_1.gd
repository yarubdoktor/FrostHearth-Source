extends Node
## Regression: orphan visual templates must be released when leaving the city.
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_stage28_1.json"
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	for cycle in 3:
		var city: Node3D = load("res://city.tscn").instantiate()
		add_child(city)
		await get_tree().process_frame
		await get_tree().process_frame
		var templates: Array = city.citizen_meshes + city.soldier_meshes.values()
		templates.append(city.crystal_scene)
		templates.append(city.wolf_scene)
		check(templates.size() == 7, "cycle %d: seven visual templates" % cycle)
		var refs: Array = []
		for template in templates:
			check(is_instance_valid(template), "template is available before deletion")
			refs.append(weakref(template))
		# Actual citizens are duplicates, not the shared template objects.
		check(city.citizens.size() > 0, "citizen duplicates were spawned")
		city.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		for ref in refs:
			check(ref.get_ref() == null, "orphan template released after city deletion")
	# Also cover deletion before _ready: no templates have been created.
	var unopened: Node3D = load("res://city.tscn").instantiate()
	unopened.free()
	check(not is_instance_valid(unopened), "unopened city can be freed safely")
	print("RESULT: %d/%d" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
