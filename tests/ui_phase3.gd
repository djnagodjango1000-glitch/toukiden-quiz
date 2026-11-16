extends SceneTree
var app
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	call_deferred("run")
func buttons(node: Node, text: String) -> Array:
	var result: Array = []
	if node is Button and text in node.text: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child,text))
	return result
func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.store.base_path = "user://phase3_test_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.haku = 500
	app.show_party()
	check(app.members_for_deck().size()==4,"初期編成")
	buttons(app,"強化")[0].pressed.emit()
	check(app.save.haku==400 and int(app.save.levels.m01)==2,"強化の消費とレベル")
	check(app.members_for_deck()[0].attack==103,"戦闘能力へ強化を反映")
	buttons(app,"編成中")[0].pressed.emit()
	check(app.deck_ids().size()==3,"編成解除")
	app.show_gacha()
	buttons(app,"召喚する")[0].pressed.emit()
	check(app.save.haku==200 and app.save.owned.size()==5,"召喚と消費")
	check(app.store.load_save().owned.size()==5 and app.store.load_save().haku==200,"変更の再読込")
	app.show_party()
	buttons(app,"編成する")[0].pressed.emit()
	check(app.deck_ids().size()==4,"編成追加")
	app.show_details(app.data.missions[0])
	app.start_battle()
	check(app.model.party.size()==4 and app.model.party[0].level==2,"変更後編成で出陣")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	print("PHASE 3 UI: 8 checks, %d failures" % failed)
	quit(1 if failed else 0)
