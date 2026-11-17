extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func find_button(node: Node, text: String) -> Button:
	if node is Button and text in node.text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.store.base_path = "user://story_test_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	var chapters: Array = app.data.story.chapters
	check(chapters.size()==4,"4つの物語を読み込む")
	check(app.story_unlocked(chapters[0]),"序章を初期解放")
	check(not app.story_unlocked(chapters[1]),"未達成の続きを閉じる")
	app.show_home()
	var entry := find_button(app,"物語 ──")
	check(entry != null,"里から物語を開ける")
	if entry: entry.pressed.emit()
	var intro := find_button(app,"序　消え残る灯")
	check(intro != null and not intro.disabled,"序章を選択可能")
	var locked := find_button(app,"？？？")
	check(locked != null and locked.disabled,"未解放の場面を選べない")
	if intro: intro.pressed.emit()
	check(app.screen=="story","序章を表示")
	var next := find_button(app,"次へ")
	check(next != null,"次へ進める")
	if next: next.pressed.emit()
	check(find_button(app,"前へ")!=null,"前に戻れる")
	app.save.cleared.append("trial01")
	check(app.story_unlocked(chapters[1]),"初任務達成で続きを解放")
	check(not app.story_unlocked(chapters[2]),"次の任務までは後続を閉じる")
	app.show_story_page(chapters[2],0)
	check(app.screen=="story_menu","未解放の場面は直接表示できない")
	var ids := []
	for chapter in chapters:
		check(not chapter.id in ids and chapter.pages.size()>0,"重複しない章と空でないページ")
		ids.append(chapter.id)
		if not chapter.unlock_after.is_empty():
			check(app.data.missions.any(func(m): return m.id==chapter.unlock_after),"解放条件の任務が存在")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	print("STORY UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
