extends SceneTree
var app
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func button_named(node: Node, name: String) -> Button:
	if node is Button and name in node.text: return node
	for child in node.get_children():
		var found := button_named(child,name)
		if found != null: return found
	return null
func run() -> void:
	root.size=Vector2i(720,1280)
	app=load("res://main.tscn").instantiate()
	app.store.base_path="user://experience_test_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.settings.free_play=true
	app.show_home()
	check(button_named(app,"遊び方")!=null,"遊び方への入口")
	app.show_how_to_play()
	check(app.screen=="guide","遊び方画面")
	app.show_details(app.data.missions[1])
	app.start_battle()
	var offered: Array=app.offered_scrolls.duplicate(true)
	app.model.choose_target(1)
	app.show_battle()
	check(app.offered_scrolls==offered,"対象変更で巻物が変わらない")
	app.model.points[2]=3
	await app.use_tamafuri(2)
	check(app.offered_scrolls==offered,"タマフリ使用でも巻物が変わらない")
	var q: Dictionary=offered[0]
	await app.choose_question(q)
	await app.answer(-1)
	check(app.mistakes.size()==1 and app.mistakes[0].id==q.id,"誤答記録")
	check(q.id in app.recent_question_ids,"直近問題の記録")
	check(not app.offered_scrolls.any(func(x):return x.id==q.id),"未出題がある場合の再出題回避")
	app.model.status="lost"
	app.show_result()
	check(button_named(app,"復習")!=null,"結果から復習")
	app.show_review()
	check(app.screen=="review","復習画面")
	app.show_result()
	check(app.screen=="result","復習から結果に戻る")
	app.model.status="won"
	app.show_result()
	var paid: int=app.save.haku
	app.show_review()
	app.show_result()
	check(paid==180 and app.save.haku==paid,"復習から戻っても報酬は重複しない")
	# オーバーレイは入力を受け、残りの演出だけを省略する。
	var events: Array=[]
	for i in range(12): events.append({"type":"attack","text":"一撃"})
	app.animate_events(events)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/experience_slash.png")
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=Vector2(360,640)
	press.pressed=true
	root.push_input(press)
	await process_frame
	check(app.skip_effects,"タップで早送り")
	await create_timer(0.5).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	print("EXPERIENCE UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
