extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func find_text(node: Node, phrase: String) -> Node:
	if (node is Label or node is Button) and phrase in node.text: return node
	for child in node.get_children():
		var result := find_text(child,phrase)
		if result != null: return result
	return null
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.store.base_path = "user://preview_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.settings.free_play = true
	var new_mission: Dictionary = app.data.missions[5]
	check(not app.unlocked(new_mission),"未達成時の任務制限")
	app.save.cleared.append("trial04")
	check(app.unlocked(new_mission),"既存の第四任務達成セーブで解放")
	app.show_details(app.data.missions[2])
	app.start_battle()
	var offered: Array = app.offered_scrolls.duplicate(true)
	check(find_text(app,"本体・砕") != null and find_text(app,"左腕・突") != null,"本体・部位の属性表示")
	check(find_text(app,"正解時の通常攻撃予想") != null and find_text(app,"予想 本体") != null,"通常攻撃の予想表示")
	var left = find_text(app,"左腕・突")
	if left != null: left.pressed.emit()
	check(app.model.target_part=="left_arm" and app.offered_scrolls==offered,"部位を変えても巻物を維持")
	check(find_text(app,"斬→突 不利") != null and find_text(app,"予想 部位") != null,"部位選択後の相性と予想")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("TARGET UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
