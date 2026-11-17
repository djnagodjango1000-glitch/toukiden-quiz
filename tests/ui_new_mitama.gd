extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.store.base_path = "user://new_mitama_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	for id in ["m09","m10","m11","m12"]:
		var image = app.portrait(id)
		check(image.texture != null and image.texture.atlas != null,"新肖像: "+id)
		check(image.texture.region.size.x > 0 and image.texture.region.size.y > 0,"肖像の範囲: "+id)
		image.free()
		app.save.owned.append(id)
	app.show_party()
	check(app.screen=="party","追加ミタマの編成画面")
	app.show_gacha()
	check(app.screen=="gacha","追加ミタマの召喚画面")
	print("NEW MITAMA UI: %d failures" % failures)
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
