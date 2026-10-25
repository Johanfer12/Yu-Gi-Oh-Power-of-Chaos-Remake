extends SceneTree
## Engine-only staged/exported project smoke; no original game data is needed.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	await process_frame
	var paths := root.get_node("Paths")
	var game := root.get_node("Game")
	var report_path: String = paths.cmdline_value("report")
	var import_pack: String = paths.cmdline_value("boot-import-pack")
	var cache_check: bool = paths.cmdline_value("boot-cache-check") == "true"
	check(not paths.cmdline_value("storage").is_empty(), "Engine-only smoke requires isolated --storage")
	check(not FileAccess.file_exists("res://bundled_data.pck"), "engine-only project has no bundled original resources")
	if not cache_check:
		check(not FileAccess.file_exists("res://data/inventory.json"), "engine-only project has no mounted original inventory")
		check(not paths.has_data(), "fresh engine-only install requests its user resource pack")
	# Exercise the configured production entry point, not an importer constructed by
	# the test. A missing boot->launcher route must fail this build smoke.
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(main_scene) == OK, "configured main scene starts")
	for frame: int in range(8):
		await process_frame
	var actual: Node = game._screen
	var expected := "launcher_android.gd" if cache_check else "android_content_setup.gd"
	check(is_instance_valid(actual) and actual.get_script().resource_path.get_file() == expected,
		"actual boot reaches " + expected)
	if not cache_check and is_instance_valid(actual) and actual.get_script().resource_path.get_file() == expected:
		check(actual._picker.use_native_dialog and actual._picker.access == FileDialog.ACCESS_FILESYSTEM,
			"actual first-run screen exposes native Android file selection")
		actual._selection_cancelled()
		check(not actual._choose.disabled, "actual first-run cancellation keeps import available")
		if not import_pack.is_empty():
			await actual._import_selected(import_pack)
			for frame: int in range(4):
				await process_frame
			check(paths.has_data() and paths.content_pack_persistent, "real selected PCK persists and mounts")
			check(game._screen.get_script().resource_path.get_file() == "launcher_android.gd", "real first-run import reaches game launcher")
			check(root.get_node("CardDB").cards.size() >= 771, "real first-run import loads card database")
	if cache_check:
		check(paths.has_data() and paths.content_pack_persistent, "second boot reuses persisted PCK without importing")
		check(root.get_node("CardDB").cards.size() >= 771, "second boot has card database")
	var setup: Script = load("res://scenes/launcher/android_content_setup.gd")
	check(setup != null, "first-run importer is available in the public engine bundle")
	if setup != null:
		for spanish: bool in [true, false]:
			var screen: Control = setup.new()
			screen._spanish = spanish
			root.add_child(screen)
			await process_frame
			check(screen._choose.text == ("Seleccionar paquete .pck" if spanish else "Select .pck resource pack"), "import action is localized")
			check(screen._choose.custom_minimum_size.y >= 60, "import action has a touch-sized target")
			check(screen._picker.use_native_dialog and screen._picker.access == FileDialog.ACCESS_FILESYSTEM, "Android uses the native system file picker")
			check(screen._picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE and not screen._picker.filters.is_empty(), "picker selects a single resource pack")
			var before := FileAccess.file_exists(paths.user_content_pack_path())
			screen._selection_cancelled()
			check(not screen._status.text.is_empty() and not screen._choose.disabled, "cancel selection leaves import available")
			check(FileAccess.file_exists(paths.user_content_pack_path()) == before, "cancel never creates or changes content")
			screen.free()
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			check(false, "engine-only smoke report is writable")
		else:
			file.store_string(JSON.stringify({"ok": failures.is_empty(), "message": "Production boot and engine-only import screen", "failures": failures, "data_dir": paths.data_dir, "main_scene": main_scene, "real_import": not import_pack.is_empty(), "second_boot": cache_check, "physical_device_tested": false}, "  "))
			file.close()
	root.get_node("Audio").stop_all()
	print("android_engine_bundle_test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
