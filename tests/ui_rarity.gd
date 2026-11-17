extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func find_label(node: Node, text: String) -> bool:
	if node is Label and text in node.text: return true
	for child in node.get_children():
		if find_label(child,text): return true
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1000)
	var app=load("res://main.tscn").instantiate()
	app.store.base_path="user://rarity_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	var backdrop:=ColorRect.new()
	backdrop.color=Color("263f3c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var grid:=GridContainer.new()
	grid.columns=4
	grid.position=Vector2(12,40)
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",14)
	layer.add_child(grid)
	for stage in range(7):
		var box:=VBoxContainer.new()
		grid.add_child(box)
		var img: TextureRect=app.portrait("m01",165,stage)
		box.add_child(img)
		var frame=img.get_child(0)
		check(frame.rarity==stage+1 and frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"各★の画像装飾と入力")
		check((img.material!=null)==(stage>=4),"高レアリティの色調")
		if stage==6: check(img.texture.atlas.resource_path.ends_with("portraits_rare7.jpg"),"★7の新島八重は専用の豪華衣装")
		var text:=Label.new()
		text.text="★%d" % (stage+1)
		text.add_theme_font_size_override("font_size",24)
		box.add_child(text)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rarity_preview.png")
	layer.queue_free()
	app.save["levels"]={"m01":9}
	app.save["evolutions"]={"m01":5}
	app.save["material"]=20
	app.save.haku=3000
	app.show_evolve(app.data.mitama[0])
	check(find_label(app,"★6 → ★7"),"進化前後のレアリティ表示")
	check(find_label(app,"700ハク・素材6"),"次の進化条件を表示")
	app.save.evolutions.m01=6
	app.show_evolve(app.data.mitama[0])
	check(find_label(app,"★7に到達"),"★7の上限表示")
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("RARITY UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
