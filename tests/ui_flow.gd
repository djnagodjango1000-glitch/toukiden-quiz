extends SceneTree
var app
var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("UI FAIL: ",msg)

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+filename+".png")

func run() -> void:
	root.size = Vector2i(720,1280)
	var scene = load("res://main.tscn")
	app = scene.instantiate()
	app.store.base_path = "user://ui_test_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	check(app.screen=="title","タイトル起動")
	await capture("title")
	app.show_home()
	check(app.screen=="home","里")
	app.show_party()
	check(app.content.get_child_count()>8,"編成表示")
	app.show_regions()
	app.show_missions()
	check(not app.unlocked(app.data.missions[1]),"二つ目の任務は未解放")
	app.show_details(app.data.missions[0])
	app.start_battle()
	check(app.screen=="battle" and app.model.enemies.size()==1,"出陣")
	await capture("battle")
	await app.choose_question(app.data.questions[0])
	check(app.model.status=="question","巻物から四択へ")
	await capture("question")
	# UI回答経路を使い、アニメーションを経て討伐・報酬まで通す。
	var guard := 0
	while app.screen=="battle" and guard<20:
		if app.model.status=="scrolls": await app.choose_question(app.data.questions[0])
		await app.answer(int(app.model.current_question.answer))
		guard+=1
	check(app.screen=="result" and app.model.status=="won","UIで討伐")
	check(app.save.haku==100,"報酬表示と保存")
	check(app.store.load_save().haku==100,"結果画面で保存済み")
	check(app.unlocked(app.data.missions[1]),"任務解放")
	await capture("result")
	# Pixel 6a相当の縦長描画。実機のタッチ・システムバー検証とは別。
	root.size=Vector2i(1080,2400)
	app.show_home()
	await capture("home_tall")
	check(app.size.y>=1280,"縦長ウィンドウ")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(app.store.base_path+suffix)
	print("UI TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
