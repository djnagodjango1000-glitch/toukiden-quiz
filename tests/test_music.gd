extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func find_button(node: Node, text: String) -> Button:
	if node is Button and text in node.text: return node
	for child in node.get_children():
		var found:=find_button(child,text)
		if found!=null: return found
	return null
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://main.tscn").instantiate()
	app.store.base_path="user://music_test_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	check(app.music.playing_track=="village", "タイトルで里の曲")
	check(app.music.players[app.music.active].stream.loop, "曲をループ")
	app.screen="battle"
	app.clear_page("test")
	check(app.music.playing_track=="battle", "戦闘曲へ切替")
	var active: int=app.music.active
	var stream: AudioStream=app.music.players[active].stream
	app.clear_page("refresh")
	check(app.music.active==active and app.music.players[active].stream==stream, "同じ画面の再描画で曲を最初に戻さない")
	app.model.enemies=[{"large":true}]
	app.clear_page("boss")
	check(app.music.playing_track=="boss", "大型鬼戦で専用曲")
	app.model.enemies=[]
	app.screen="musuhi"
	app.clear_page("test")
	check(app.music.playing_track=="musuhi", "ムスヒ曲へ切替")
	app.model.status="won"
	app.screen="result"
	app.clear_page("test")
	check(app.music.playing_track=="result", "勝利曲へ切替")
	app.model.status="lost"
	app.clear_page("test")
	check(app.music.playing_track=="defeat", "敗北曲へ切替")
	app.music.set_paused(true)
	check(app.music.players[app.music.active].stream_paused, "休止時に停止")
	app.music.set_paused(false)
	check(not app.music.players[app.music.active].stream_paused, "復帰時に再開")
	app.show_settings()
	var mute:=find_button(app,"BGM：ON")
	check(mute!=null, "BGM切替を表示")
	if mute!=null: mute.pressed.emit()
	check(app.save.settings.get("bgm_muted",false) and app.music.active==-1, "BGMのみ停止")
	check(app.store.load_save().settings.get("bgm_muted",false), "BGM設定を保存")
	var volume:=find_button(app,"BGM音量：60%")
	check(volume!=null, "音量設定を表示")
	if volume!=null: volume.pressed.emit()
	check(int(app.store.load_save().settings.bgm_volume)==80, "音量を保存")
	var unmute:=find_button(app,"BGM：OFF")
	if unmute!=null: unmute.pressed.emit()
	check(not app.save.settings.bgm_muted and app.music.playing_track=="village", "BGMを再開")
	var invalid: Dictionary=app.save.duplicate(true)
	invalid.settings["bgm_volume"]=101
	check(not app.progression.valid_backup(invalid), "不正な音量のバックアップを拒否")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(app.store.base_path+suffix)
	stream=null
	app.music.configure({"bgm_muted":true})
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("MUSIC: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
