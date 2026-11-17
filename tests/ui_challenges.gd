extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func has_label(node: Node, text: String) -> bool:
	if node is Label and text in node.text: return true
	for child in node.get_children():
		if has_label(child,text): return true
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.store.base_path="user://challenges_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.show_details(app.data.missions[0])
	check(has_label(app,"正答率80%以上"),"出陣前に目標表示")
	app.mission=app.data.missions[0]
	app.receipt="ui-challenge"
	app.model.status="won"
	app.model.correct=1
	app.model.answered=1
	app.model.total_answer_ms=3000
	app.model.max_streak=1
	app.show_result()
	check(has_label(app,"達成　正答率80%以上"),"結果に達成を表示")
	check(app.save.haku==170,"報酬を保存")
	check(app.store.load_save().haku==170,"報酬を復元")
	app.show_result()
	check(app.save.haku==170,"結果再表示による二重報酬を防止")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	print("CHALLENGE UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
