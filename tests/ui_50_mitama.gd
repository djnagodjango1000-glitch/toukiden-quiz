extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func contains_text(node: Node, phrase: String) -> bool:
	if (node is Label or node is Button) and phrase in node.text: return true
	for child in node.get_children():
		if contains_text(child,phrase): return true
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://main.tscn").instantiate()
	app.store.base_path="user://ui_50_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.save.owned=[]
	for m in app.data.mitama:
		var image=app.portrait(m.id)
		check(image.texture!=null and image.texture.atlas!=null,"肖像または仮絵: "+m.id)
		check(m.art!="generic_placeholder", "仮絵ではない肖像: "+m.id)
		if m.has("portrait_sheet"):
			check(image.texture.atlas.resource_path.ends_with(m.portrait_sheet+".jpg"),"人物に対応する画像シート: "+m.id)
		image.free()
		app.save.owned.append(m.id)
	app.show_party()
	check(contains_text(app,"井伊直弼") and not contains_text(app,"（仮絵）"),"編成画面に60体の創作肖像")
	app.show_encyclopedia()
	check(contains_text(app,"登録 60 / 60") and contains_text(app,"登録50体報酬") and contains_text(app,"登録60体報酬"),"60体図鑑と報酬")
	app.show_gacha()
	check(contains_text(app,"未所持 0体"),"全員入手後の召喚")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("50 MITAMA UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
