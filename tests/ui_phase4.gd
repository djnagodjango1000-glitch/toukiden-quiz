extends SceneTree
var app
var failed := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("FAIL: ",message)
func count_named(node: Node, name: String) -> int:
	var total := 1 if node.get_script() != null and str(node.get_script().resource_path).ends_with(name) else 0
	for child in node.get_children(): total += count_named(child,name)
	return total
func scroll_button(node: Node) -> Button:
	if node is Button and node.text.contains("級"):
		return node
	for child in node.get_children():
		var found := scroll_button(child)
		if found != null: return found
	return null
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")
func _initialize(): call_deferred("run")
func run() -> void:
	root.size = Vector2i(720,1280)
	app = load("res://main.tscn").instantiate()
	app.store.base_path = "user://phase4_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.show_home()
	await capture("phase4_home")
	check(app.screen=="home","里画面")
	check(app.data.mitama.size()==8,"8体のミタマ")
	var first_portrait=app.portrait("m07")
	var second_portrait=app.portrait("m08")
	check(first_portrait.texture != null and second_portrait.texture != null,"追加肖像の読み込み")
	first_portrait.free()
	second_portrait.free()
	app.show_gacha()
	check(app.content.get_child_count()>4,"無料召喚画面")
	app.save.settings.free_play=true
	app.show_details(app.data.missions[4])
	app.start_battle()
	await capture("phase4_wolf")
	check(app.model.enemies[0].id=="wolf_boss","追加大型鬼")
	check(count_named(app,"scroll_ornament.gd")==4,"巻物4本の装飾")
	check(app.model.choose_target(0,"horn"),"角の選択")
	check(app.model.choose_target(0,"foreleg"),"前脚の選択")
	check(app.model.choose_target(0,"tail"),"尾の選択")
	app.model.enemies[0].parts[0].hp=1
	app.model.choose_target(0,"horn")
	app.model.begin_question(app.data.questions[0],0)
	var result: Dictionary=app.model.resolve_answer(int(app.data.questions[0].answer),5000)
	check(result.events.any(func(e):return e.type=="part_break") and app.model.enemies[0].stun>0,"角破壊で気絶")
	app.show_battle()
	await process_frame
	var scroll := scroll_button(app)
	check(scroll!=null,"巻物の入力対象")
	if scroll != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = scroll.get_global_rect().get_center()
		click.pressed = true
		root.push_input(click)
		await process_frame
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		var limit := Time.get_ticks_msec()+3000
		while app.model.status!="question" and Time.get_ticks_msec()<limit: await process_frame
		check(app.model.status=="question","装飾を通した巻物タップ")
	app.mission = app.data.missions[3]
	app.model.status = "won"
	app.model.correct = 7
	app.model.answered = 10
	app.receipt = "phase4-score"
	app.show_result()
	check(int(app.save.training_best)==70 and int(app.store.load_save().training_best)==70,"修練自己ベストの保存")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	print("PHASE 4 UI: %d checks, %d failures" % [checks,failed])
	quit(1 if failed else 0)
