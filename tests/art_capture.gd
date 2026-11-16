extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(720,1280)
	var app=load("res://main.tscn").instantiate()
	app.store.base_path="user://art_preview_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.show_details(app.data.missions[2])
	app.start_battle()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/phase3_boss.png")
	app.show_party()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/phase3_party.png")
	quit()
