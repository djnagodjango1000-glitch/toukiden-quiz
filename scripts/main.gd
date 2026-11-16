extends Control

const Battle = preload("res://scripts/battle.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const StageArt = preload("res://scripts/stage_art.gd")
var store = SaveStore.new()
var save: Dictionary
var model = Battle.new()
var data: Dictionary = {}
var content: VBoxContainer
var footer: Label
var clock_label: Label
var screen := "title"
var battle_clock := 0.0
var paused := false
var busy := false
var mission: Dictionary
var receipt := ""
var question_serial := 0
var notice := ""
var palette := {"paper": Color("e4d8b8"), "ink": Color("302c27"), "gold": Color("9c763c"), "dark": Color("253e3b")}

func _ready() -> void:
	var theme_data := Theme.new()
	theme_data.default_font = load("res://assets/japanese.ttc")
	theme_data.default_font_size = 25
	theme = theme_data
	for filename in ["balance", "mitama", "oni", "missions", "questions"]:
		data[filename] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + filename + ".json"))
	save = store.load_save()
	notice = store.error
	show_title()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: paused = true
	if what == NOTIFICATION_APPLICATION_RESUMED: paused = false

func _process(delta: float) -> void:
	if paused or busy or screen != "battle" or model.status != "question": return
	battle_clock += delta * 1000.0
	if is_instance_valid(clock_label): clock_label.text = "残り %.1f 秒" % (model.remaining_ms(int(battle_clock))/1000.0)
	if model.remaining_ms(int(battle_clock)) <= 0: answer(-1)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),palette.paper)
	for i in range(90):
		var y := float(i)*size.y/90.0
		draw_line(Vector2(0,y),Vector2(size.x,y+8),Color(0.4,0.3,0.15,0.035),1)
	draw_rect(Rect2(10,10,size.x-20,size.y-20),palette.gold,false,2)

func style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func clear_page(title: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",28)
	margin.add_theme_constant_override("margin_right",28)
	margin.add_theme_constant_override("margin_top",34)
	margin.add_theme_constant_override("margin_bottom",30)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	label(title,34)
	var line := HSeparator.new()
	content.add_child(line)

func label(text_value: String, font_size: int = 24, color: Color = Color("302c27")) -> Label:
	var l := Label.new()
	l.text = text_value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	content.add_child(l)
	return l

func button(text_value: String, action: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size.y = 78
	b.add_theme_stylebox_override("normal",style(Color("f2e8cc"),palette.gold,12))
	b.add_theme_stylebox_override("hover",style(Color("fff1c9"),palette.gold,12))
	b.add_theme_stylebox_override("pressed",style(Color("c7b482"),palette.ink,12))
	b.add_theme_stylebox_override("disabled",style(Color("ccc5b2"),Color("99907d"),12))
	for state in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(state,palette.ink)
	b.disabled = disabled
	b.pressed.connect(action)
	content.add_child(b)
	return b

func space(height: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = height
	content.add_child(c)

func show_title() -> void:
	screen = "title"
	clear_page("非公式・独立制作プロジェクト")
	space(80)
	label("鬼 問 戦 記",64,palette.dark)
	label("巻物をひらき、知恵で鬼を討つ。",28)
	space(40)
	label("Phase 1 開発版  0.1.0\n基本戦闘の動作検証用です。\n能力値・任務・戦闘順は暫定仕様です。",23)
	label("原作の画像・音楽・問題文は使用していません。",20)
	space(50)
	button("里へ",show_home,store.blocked)
	if not notice.is_empty(): label(notice,23,Color("8a332d"))
	if store.blocked: label("既存セーブは削除していません。保存ファイルの確認が必要です。",22)

func show_home() -> void:
	screen = "home"
	clear_page("里 ── 鬼問戦記")
	label("ハク  %d    経験値  %d" % [save.haku,save.xp],26)
	space(30)
	label("試作の里",44,palette.dark)
	label("山の向こうで鬼が動き始めた。\n巻物の問いを解き、ミタマとともに出陣しよう。",25)
	space(40)
	button("任務 ── 領域を選ぶ",show_regions)
	button("ミタマ ── 編成を確認",show_party)
	button("設定・セーブ情報",show_settings)
	button("タイトルに戻る",show_title)
	label("特殊技・大型鬼・育成・ガチャは後続フェーズで実装します。",20)

func show_regions() -> void:
	screen = "regions"
	clear_page("領域選択")
	space(40)
	label("仮の領域 ── 問いの山道",36,palette.dark)
	label("原作の任務や章を復元した領域ではありません。\n基本戦闘の検証用です。",24)
	space(50)
	button("仮の領域へ",show_missions)
	button("里に戻る",show_home)

func unlocked(m: Dictionary) -> bool:
	if m.id == "trial01" or m.id in save.cleared: return true
	for earlier in data.missions:
		if earlier.id in save.cleared and m.id in earlier.unlocks: return true
	return false

func show_missions() -> void:
	screen = "missions"
	clear_page("任務選択 ── 仮の領域")
	for item in data.missions:
		var m: Dictionary = item
		var suffix := "  達成" if m.id in save.cleared else ""
		button(m.label+suffix,func(): show_details(m),not unlocked(m))
		label("報酬 %dハク / %d経験値" % [m.rewards.haku,m.rewards.xp],21)
	label("二つ目の任務は初陣達成で解放されます。\n大型鬼の第三任務はPhase 2で追加します。",22)
	button("領域選択に戻る",show_regions)

func show_details(m: Dictionary) -> void:
	screen = "detail"
	mission = m
	clear_page(m.label)
	label("独自の仮任務 / 消費行動力 0",24)
	label("戦闘数 %d / 最大出現数 %d" % [m.waves.size(),m.waves[0].size()],26)
	label("報酬 %dハク / %d経験値" % [m.rewards.haku,m.rewards.xp],26)
	space(20)
	label("4体のミタマを速さ順で使用します。\n巻物を選び、20秒以内に四択へ解答。正解で攻撃し、残った鬼が反撃します。\n敵をタップして攻撃対象を変更できます。",24)
	label("仮仕様：一問一行動者。速答追撃は未実装です。",22)
	space(30)
	button("出陣",start_battle)
	button("任務一覧へ",show_missions)

func show_party() -> void:
	screen = "party"
	clear_page("ミタマ編成 ── 固定4体")
	var total_hp := 0
	for i in range(4): total_hp += int(data.mitama[i].hp)
	label("合計コスト 8 / 仮上限 10　合計体力 %d" % total_hp,23)
	for i in range(4):
		var m: Dictionary = data.mitama[i]
		label("%d  %s  [%s]  Lv.%d" % [i+1,m.name,m.attribute,m.level],29,palette.dark)
		label("体力 %d / 攻撃 %d / 速さ %d\n固有技は調査・実装待ち" % [m.hp,m.attack,m.speed],23)
	label("人物名以外の能力・属性は新規の仮値です。原作の個別能力を再現したものではありません。",21)
	button("里に戻る",show_home)

func show_settings() -> void:
	screen = "settings"
	clear_page("設定・セーブ情報")
	label("完全オフライン / 広告・課金なし\nPhase 1は行動力を消費しません。",25)
	label("任務報酬は帰還前に自動保存されます。\n保存先：user://save.json\n世代バックアップ：save.json.bak\n手動入出力・音量設定は後続フェーズです。",23)
	button("現在の進行を保存",func():
		if store.persist(save): label("保存しました。",24)
		else: label(store.error,24,Color("8a332d")))
	button("里に戻る",show_home)

func start_battle() -> void:
	var party: Array = data.mitama.slice(0,4)
	model.setup(party,mission,data.oni,data.balance,Time.get_ticks_msec())
	receipt = "%s-%s-%s" % [mission.id,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	question_serial = 0
	battle_clock = 0.0
	notice = "巻物を選んでください。"
	show_battle()

func show_battle() -> void:
	screen = "battle"
	clear_page("%s  %d/%d" % [mission.label,mini(model.wave_index+1,model.waves.size()),model.waves.size()])
	var art = StageArt.new()
	art.count = model.enemies.size()
	art.selected = model.target_index
	for e in model.enemies: art.dead.append(e.hp <= 0)
	art.custom_minimum_size.y = 300
	content.add_child(art)
	var targets := HBoxContainer.new()
	content.add_child(targets)
	for i in range(model.enemies.size()):
		var enemy: Dictionary = model.enemies[i]
		var b := Button.new()
		b.text = "%s 鬼%d\nHP %d" % ["◎" if i==model.target_index else "",i+1,enemy.hp]
		b.custom_minimum_size.y = 62
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = enemy.hp <= 0 or model.status != "scrolls" or busy
		b.pressed.connect(func():
			if model.choose_target(i): show_battle())
		targets.add_child(b)
	var order_text := ""
	for j in range(model.party.size()):
		var m: Dictionary = model.party[(model.actor_index+j)%model.party.size()]
		order_text += ("▶ " if j==0 else " → ")+m.name
	label(order_text,20,palette.dark)
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = model.max_hp
	hp_bar.value = model.hp
	hp_bar.custom_minimum_size.y = 28
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill",style(Color("468780"),palette.gold))
	content.add_child(hp_bar)
	label("体力 %d / %d" % [model.hp,model.max_hp],20)
	label(notice,21)
	if busy: return
	if model.status == "scrolls":
		var available: Array = data.questions.duplicate()
		# seedを指定したモデル乱数で巻物を選ぶ。
		for k in range(4):
			var pos: int = model.rng.randi_range(0,available.size()-1)
			var q: Dictionary = available.pop_at(pos)
			var rank: String = ["初級","中級","上級"][int(q.difficulty)-1]
			button("┃  %s　　%s  ┃" % [rank,q.genre],func(): choose_question(q))
		button("撤退して里へ（報酬なし）",show_home)
	elif model.status == "question":
		var q: Dictionary = model.current_question
		label(q.text,27)
		clock_label = label("残り 20.0 秒",22)
		for i in range(q.options.size()):
			button("%d．%s" % [i+1,q.options[i]],func(): answer(i))

func choose_question(q: Dictionary) -> void:
	if busy: return
	if model.begin_question(q,int(battle_clock)):
		notice = "落ち着いて問いを解こう。"
		show_battle()

func answer(selection: int) -> void:
	if busy: return
	var outcome: Dictionary = model.resolve_answer(selection,int(battle_clock))
	if not outcome.accepted: return
	busy = true
	notice = ("正解！ %sの攻撃 %d" % [outcome.actor,outcome.damage]) if outcome.correct else ("不正解・時間切れ　正答：%s" % outcome.answer)
	if outcome.retaliation > 0: notice += " / 鬼の反撃 %d" % outcome.retaliation
	show_battle()
	var flash := label("正 解" if outcome.correct else "不 正 解",46,Color("8b382c"))
	label(outcome.explanation,22)
	flash.modulate.a = 0.0
	create_tween().tween_property(flash,"modulate:a",1.0,.18)
	await get_tree().create_timer(1.2).timeout
	busy = false
	if model.status in ["won","lost"]: show_result()
	else: show_battle()

func show_result() -> void:
	screen = "result"
	clear_page("任務達成" if model.status == "won" else "敗北")
	label("%s\n正解 %d / %d問" % [mission.label,model.correct,model.answered],30)
	if model.status == "won":
		var updated: Dictionary = store.reward(save,mission,receipt)
		if not store.persist(updated):
			label("保存できませんでした。報酬は未確定です。\n"+store.error,24,Color("8a332d"))
			button("保存を再試行",show_result)
			return
		save = updated
		label("%dハク / %d経験値を獲得\n進行を保存しました。" % [mission.rewards.haku,mission.rewards.xp],28)
	else: label("報酬はありません。里で準備を整えましょう。",26)
	space(30)
	button("里へ帰還",show_home)
