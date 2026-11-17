extends SceneTree
var app
var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PHASE 2 UI FAIL: ",msg)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")

func find_button(node: Node, text: String) -> Button:
	if node is Button and text in node.text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null

func click(text: String) -> void:
	await process_frame
	var b := find_button(app,text)
	check(b != null and not b.disabled,"ボタン有効: "+text)
	if b == null or b.disabled: return
	var rect := b.get_global_rect()
	check(rect.position.y>=0 and rect.end.y<=root.size.y,"ボタン画面内: "+text)
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=rect.get_center()
	press.pressed=true
	root.push_input(press)
	await process_frame
	var release := press.duplicate()
	release.pressed=false
	root.push_input(release)
	await process_frame

func wait_idle() -> void:
	var deadline := Time.get_ticks_msec()+15000
	while app.busy and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.busy,"演出終了")

func run() -> void:
	root.size=Vector2i(720,1280)
	app=load("res://main.tscn").instantiate()
	app.store.base_path="user://ui_phase2_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.cleared=["trial01","trial02"]
	app.show_missions()
	await click("山門の角砕き")
	await click("出陣")
	check(app.model.enemies[0].id=="boss","大型鬼出陣")
	await capture("boss")
	await click("角")
	check(app.model.target_part=="horn","実入力配送で角選択")
	await app.choose_question(app.data.questions[0])
	await app.answer(int(app.model.current_question.answer))
	check(app.model.enemies[0].parts[0].hp==0,"角破壊")
	check(app.model.enemies[0].stun==1,"気絶中")
	check(app.event_history.any(func(e): return e.type=="part_break"),"破壊演出経路")
	await capture("boss_broken")
	await click("左腕")
	for i in range(4):
		await app.choose_question(app.data.questions[0])
		await app.answer(int(app.model.current_question.answer))
	check(app.model.can_musuhi() and app.model.can_tamafuri(1),"特殊技蓄積")
	var before: int=app.model.points[1]
	await click("清少納言")
	await wait_idle()
	check(app.model.points[1]==before-3,"UIタマフリ消費")
	await click("ムスヒ\n発動")
	await wait_idle()
	check(app.screen=="musuhi","専用画面へ遷移")
	await capture("musuhi")
	app._notification(app.NOTIFICATION_APPLICATION_PAUSED)
	app.sync_clock()
	var old_clock: float=app.battle_clock
	app._process(1.0)
	check(app.battle_clock==old_clock,"サスペンド中の時計停止")
	app._notification(app.NOTIFICATION_APPLICATION_RESUMED)
	await click(app.model.current_question.options[int(app.model.current_question.answer)])
	await wait_idle()
	check(app.model.musuhi_correct==1,"○×入力経路")
	await app.answer_musuhi(1-int(app.model.current_question.answer))
	await app.answer_musuhi(1-int(app.model.current_question.answer))
	check(app.screen=="battle" and app.model.status=="scrolls","ムスヒ終了後の復帰")
	check(app.event_history.any(func(e):return e.type=="musuhi_attack"),"ムスヒ追加攻撃演出")
	# 時間切れ終了のUI経路も検証。
	app.model.gauge=int(app.data.balance.musuhi.gauge_required)
	await app.begin_musuhi()
	app.model.musuhi_start_ms=int(app.battle_clock)-int(app.data.balance.musuhi.time_ms)
	await app.end_musuhi()
	check(app.screen=="battle" and app.model.musuhi_correct==0,"0問正解時間切れ復帰")
	# 本体を選び、最後まで通常戦闘を通す。
	app.model.choose_target(0,"body")
	var guard := 0
	while app.screen=="battle" and guard<30:
		await app.choose_question(app.data.questions[0])
		await app.answer(int(app.model.current_question.answer))
		guard+=1
	check(app.screen=="result" and app.model.status=="won","大型鬼討伐まで到達")
	check(app.save.haku==420 and app.store.load_save().haku==420,"大型鬼報酬の保存")
	await capture("boss_result")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	print("PHASE 2 UI TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
