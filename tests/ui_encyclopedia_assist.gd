extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",text)
func find_text(node: Node, phrase: String) -> Node:
	if (node is Button or node is Label) and phrase in node.text: return node
	for child in node.get_children():
		var found:=find_text(child,phrase)
		if found!=null: return found
	return null
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://main.tscn").instantiate()
	app.store.base_path="user://wiki_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.show_encyclopedia()
	check(find_text(app,"登録 4 / 60")!=null,"登録人数")
	find_text(app,"◆ 新島八重").pressed.emit()
	check(app.screen=="mitama_detail" and find_text(app,"会津籠城戦")!=null,"人物詳細と由来")
	check(find_text(app,"非公式Wikiの掲載例")!=null and find_text(app,"★5 通常")!=null,"Wiki掲載値を別表示")
	app.show_encyclopedia()
	find_text(app,"属性：すべて").pressed.emit()
	check(find_text(app,"属性：斬")!=null and find_text(app,"◆ 清少納言")==null,"属性フィルター")
	app.encyclopedia_attribute_filter=0
	app.show_encyclopedia()
	find_text(app,"所持：すべて").pressed.emit()
	check(find_text(app,"所持：取得済み")!=null and find_text(app,"◇ 未取得")==null,"所持フィルター")
	app.save.settings.free_play=true
	app.show_details(app.data.missions[2])
	app.start_battle()
	var index:=-1
	for i in range(app.model.party.size()):
		if app.model.party[i].id=="m04": index=i
	check(index>=0,"聖徳太子を編成")
	if index>=0:
		app.model.points[index]=4
		check(app.model.use_tamafuri(index).accepted,"解答補助を発動")
		app.show_battle()
		check(find_text(app,"誤答が2個減ります")!=null,"補助待ちを表示")
		var q: Dictionary=app.data.questions[0]
		app.model.begin_question(q,1000)
		app.show_battle()
		var visible:=0
		for i in range(q.options.size()):
			if find_text(app,"%d．%s" % [i+1,q.options[i]])!=null: visible+=1
		check(visible==2 and int(q.answer) in app.model.visible_answer_indices,"正答を含む2択の画面")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("ENCYCLOPEDIA AND ASSIST UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
