extends SceneTree
var app
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func find(node: Node, classname: String, text: String = "") -> Node:
	if node.is_class(classname) and (text.is_empty() or (node is Button and text in node.text)): return node
	for child in node.get_children():
		var r = find(child,classname,text)
		if r != null: return r
	return null
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1280)
	app=load("res://main.tscn").instantiate()
	app.store.base_path="user://phase3extra_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.haku=1000
	app.save["material"]=4
	app.save["levels"]={"m01":5}
	app.show_party()
	var evolve=find(app,"Button","進化 0→1")
	check(evolve!=null and not evolve.disabled,"進化可能を表示")
	evolve.pressed.emit()
	check(app.screen=="evolve" and app.save.haku==1000,"確認前に消費しない")
	find(app,"Button","進化を確定").pressed.emit()
	check(app.save.haku==750 and app.save.material==2 and app.save.evolutions.m01==1,"進化結果")
	check(app.members_for_deck()[0].hp==590 and app.members_for_deck()[0].attack==167,"進化能力を編成へ反映")
	find(app,"Button","素材合成").pressed.emit()
	check(app.screen=="fusion" and app.save.haku==750,"合成の事前確認")
	find(app,"Button","合成を確定").pressed.emit()
	check(app.save.haku==700 and app.save.material==1 and app.save.levels.m01==6,"合成で素材を消費して強化")
	app.show_encyclopedia()
	find(app,"Button","登録4体報酬").pressed.emit()
	check(app.save.haku==800 and "4" in app.save.collection_claimed,"事典報酬")
	check(find(app,"Button","登録4体報酬").disabled,"事典報酬は再受取不可")
	app.save["orbs"]=1
	app.show_gacha()
	find(app,"Button","宝玉で召喚").pressed.emit()
	check(app.save.orbs==0 and app.save.owned.size()==5,"無料宝玉による召喚")
	app.show_settings()
	var mode=find(app,"Button","行動力：")
	check("通常" in mode.text,"新規セーブ通常モード")
	mode.pressed.emit()
	check(app.save.settings.free_play,"自由プレイを保存")
	var before: Dictionary=app.save.duplicate(true)
	var target=ProjectSettings.globalize_path("user://phase3export_%d.json" % Time.get_ticks_usec())
	app.backup_dialog(false)
	var picker=find(app,"FileDialog")
	picker.file_selected.emit(target)
	check(FileAccess.file_exists(target),"バックアップ出力")
	app.save.haku=0
	app.backup_dialog(true)
	var pickers: Array=[]
	for child in app.get_children():
		if child is FileDialog: pickers.append(child)
	pickers.back().file_selected.emit(target)
	var confirm: Node = null
	for child in app.get_children():
		if child is ConfirmationDialog and not child is FileDialog: confirm=child
	check(confirm!=null and app.save.haku==0,"読込前の確認と上書き待機")
	confirm.confirmed.emit()
	check(app.save.haku==before.haku and app.store.load_save().haku==before.haku,"明示確認後の読込保存")
	app.show_details(app.data.missions[0])
	app.start_battle()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/phase3_small_oni.png")
	check(app.model.enemies.size()==1,"小型鬼戦闘表示")
	app.save.cleared.append("trial01")
	app.show_home()
	var training=find(app,"Button","修練")
	check(training!=null and not training.disabled,"初回達成で修練解放")
	training.pressed.emit()
	check(app.screen=="detail" and app.mission.id=="training01","オフライン修練を選択")
	app.start_battle()
	check(app.screen=="battle" and app.model.enemies.size()==1,"修練に出陣")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	DirAccess.remove_absolute(target)
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("PHASE 3 EXTRA UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
