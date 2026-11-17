extends Control

const Battle = preload("res://scripts/battle.gd")
const Challenges = preload("res://scripts/challenges.gd")
const QuizPool = preload("res://scripts/quiz_pool.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const StageArt = preload("res://scripts/stage_art.gd")
const ScrollOrnament = preload("res://scripts/scroll_ornament.gd")
const Sound = preload("res://scripts/sound.gd")
const Music = preload("res://scripts/music.gd")
const Progression = preload("res://scripts/progression.gd")
const RarityFrame = preload("res://scripts/rarity_frame.gd")
const RarityTint = preload("res://scripts/rarity_tint.gdshader")
var progression
var sound = Sound.new()
var music = Music.new()
var store = SaveStore.new()
var save: Dictionary
var model = Battle.new()
var data: Dictionary = {}
var content: VBoxContainer
var footer: Label
var clock_label: Label
var screen := "title"
var battle_clock := 0.0
var active_clock = preload("res://scripts/active_clock.gd").new()
var paused := false
var busy := false
var mission: Dictionary
var receipt := ""
var question_serial := 0
var notice := ""
var event_history: Array = []
var offered_scrolls: Array = []
var recent_question_ids: Array = []
var mistakes: Array = []
var skip_effects := false
var stage_art: Control
var encyclopedia_owned_filter := 0
var encyclopedia_attribute_filter := 0
var palette := {"paper": Color("dfd0ad"), "ink": Color("30251e"), "gold": Color("95713d"), "dark": Color("263f3c")}

func _ready() -> void:
	var theme_data := Theme.new()
	theme_data.default_font = load("res://assets/japanese.ttc")
	theme_data.default_font_size = 25
	theme_data.set_stylebox("normal","Button",style(Color("f2e8cc"),palette.gold,4))
	theme_data.set_stylebox("disabled","Button",style(Color("d2c8ad"),Color("aa9d7d"),4))
	theme_data.set_stylebox("hover","Button",style(Color("fff1c9"),palette.gold,4))
	theme_data.set_stylebox("pressed","Button",style(Color("c7b482"),palette.ink,4))
	for state in ["font_color","font_hover_color","font_pressed_color"]:
		theme_data.set_color(state,"Button",palette.ink)
	theme_data.set_color("font_disabled_color","Button",Color("77705f"))
	theme = theme_data
	for filename in ["balance", "mitama", "oni", "missions", "questions", "effects", "boolean_questions", "progression", "story", "challenges"]:
		data[filename] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + filename + ".json"))
	progression = Progression.new(data.progression,data.mitama)
	add_child(sound)
	add_child(music)
	save = store.load_save()
	if not save.is_empty(): music.configure(save.get("settings",{}))
	notice = store.error
	show_title()

func sync_clock() -> void:
	battle_clock = float(active_clock.read())

func update_clock_state() -> void:
	var timing: bool = (screen=="battle" and model.status=="question") or (screen=="musuhi" and model.status in ["musuhi","musuhi_feedback"])
	active_clock.set_running(timing and not paused)
	sync_clock()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		active_clock.set_running(false)
		paused = true
		music.set_paused(true)
	if what == NOTIFICATION_APPLICATION_RESUMED:
		paused = false
		music.set_paused(false)
		update_clock_state()

func _process(_delta: float) -> void:
	if paused: return
	sync_clock()
	if screen == "musuhi" and model.status in ["musuhi","musuhi_feedback"]:
		if is_instance_valid(clock_label): clock_label.text = "残り %.1f 秒" % (model.musuhi_remaining_ms(int(battle_clock))/1000.0)
		if not busy and model.musuhi_remaining_ms(int(battle_clock)) == 0: end_musuhi()
	elif not busy and screen == "battle" and model.status == "question":
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
	if screen in ["musuhi","musuhi_intro","musuhi_result"]: music.play_track("musuhi")
	elif screen == "battle":
		var is_boss: bool = model.enemies.any(func(enemy): return enemy.get("large",false))
		music.play_track("boss" if is_boss else "battle")
	elif screen in ["result","review"]: music.play_track("result" if model.status=="won" else "defeat")
	else: music.play_track("village")
	for child in get_children():
		if child == sound or child == music: continue
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
	b.custom_minimum_size.y = 66
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
	label("開発版  0.16.0\n特殊戦闘の動作検証用です。\n能力値・任務・戦闘順は暫定仕様です。",23)
	label("原作の画像・音楽・問題文は使用していません。",20)
	space(50)
	button("里へ",show_home,store.blocked)
	if not notice.is_empty(): label(notice,23,Color("8a332d"))
	if store.blocked: label("既存セーブは削除していません。保存ファイルの確認が必要です。",22)

func show_home() -> void:
	active_clock.set_running(false)
	screen = "home"
	clear_page("里 ── 鬼問戦記")
	label("ハク  %d    経験値  %d" % [save.haku,save.xp],26)
	var hero_banner := HBoxContainer.new()
	hero_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_banner.add_theme_constant_override("separation",8)
	content.add_child(hero_banner)
	for id in deck_ids(): hero_banner.add_child(portrait(id,92))
	space(12)
	var village := TextureRect.new()
	village.texture = load("res://assets/art/village.png")
	village.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	village.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	village.custom_minimum_size.y = 200
	content.add_child(village)
	label("試作の里",36,palette.dark)
	label("山の向こうで鬼が動き始めた。\n巻物の問いを解き、ミタマとともに出陣しよう。",25)
	space(40)
	button("物語 ── 帰る場所への旅",show_story_menu)
	button("任務 ── 領域を選ぶ",show_regions)
	button("遊び方",show_how_to_play)
	button("ミタマ ── 編成・強化",show_party)
	button("召喚 ── ミタマを迎える",show_gacha)
	button("ミタマ事典",show_encyclopedia)
	button("修練 ── 問いの稽古",show_training,not "trial01" in save.cleared)
	button("設定・セーブ情報",show_settings)
	button("タイトルに戻る",show_title)
	label("編成・強化・召喚は開発中の仮仕様です。",20)

func story_unlocked(chapter: Dictionary) -> bool:
	var requirement := str(chapter.get("unlock_after", ""))
	return requirement.is_empty() or requirement in save.cleared

func show_story_menu() -> void:
	screen = "story_menu"
	clear_page("物語 ── 帰る場所への旅")
	label("原作の資料を参考に、新たな人物と文章で描いた物語です。",22)
	label("任務を進めると続きを読めます。開いた場面は何度でも読み返せます。",22)
	for item in data.story.chapters:
		var chapter: Dictionary = item
		var is_open := story_unlocked(chapter)
		button(str(chapter.title) if is_open else "？？？　任務を進めると解放",func(): show_story_page(chapter,0),not is_open)
	button("里に戻る",show_home)

func show_story_page(chapter: Dictionary, index: int) -> void:
	if not story_unlocked(chapter) or index < 0 or index >= chapter.pages.size():
		show_story_menu()
		return
	screen = "story"
	clear_page(str(chapter.title))
	var illustration := TextureRect.new()
	illustration.texture = load("res://assets/art/village.png")
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.custom_minimum_size.y = 200
	content.add_child(illustration)
	var page: Dictionary = chapter.pages[index]
	label(str(page.speaker),28,palette.dark)
	label(str(page.text),27)
	space(20)
	label("%d / %d" % [index+1,chapter.pages.size()],20)
	if index+1 < chapter.pages.size():
		button("次へ",func(): show_story_page(chapter,index+1))
	else:
		button("物語一覧へ",show_story_menu)
	if index>0: button("前へ",func(): show_story_page(chapter,index-1))
	button("里に戻る",show_home)

func show_how_to_play() -> void:
	screen = "guide"
	clear_page("遊び方")
	label("一、巻物を選ぶ",30,palette.dark)
	label("ジャンルと難易度を見て選択。難しい問いほど与える攻撃が大きくなります。",23)
	label("二、素早く答える",30,palette.dark)
	label("4秒以内の正解でハヤフリが発動。ミタマの力と後続の追撃が出ます。",23)
	label("三、力を使い分ける",30,palette.dark)
	label("正解でタマフリのポイントが貯まります。攻撃・回復・守りなど、ミタマごとに異なる力を使えます。",23)
	label("四、大型鬼を狙う",30,palette.dark)
	label("角を壊すと気絶、腕や脚を壊すと反撃が弱まります。部位にはそれぞれ仮の属性があります。狙う場所を選び、巻物の通常攻撃予想を参考にしましょう。",23)
	label("五、ムスヒノ刻",30,palette.dark)
	label("正解を重ねてゲージを満たし、発動。○×に続けて答えると追加攻撃できます。",23)
	label("技の値や相性は調査中の暫定仕様です。行動力を使わない自由プレイも設定で選べます。",20)
	button("里に戻る",show_home)

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
		if m.get("training",false): continue
		var suffix := "  達成" if m.id in save.cleared else ""
		button(m.label+suffix,func(): show_details(m),not unlocked(m))
		label("報酬 %dハク / %d経験値" % [m.rewards.haku,m.rewards.xp],21)
	label("任務達成で次の任務が解放されます。",22)
	button("領域選択に戻る",show_regions)

func show_training() -> void:
	for item in data.missions:
		if item.get("training",false):
			show_details(item)
			return

func show_details(m: Dictionary) -> void:
	screen = "detail"
	mission = m
	clear_page(m.label)
	var energy: Dictionary = progression.energy_state(save,int(Time.get_unix_time_from_system()))
	var free: bool = save.settings.get("free_play",false)
	label("独自の仮任務 / 行動力 %d（所持 %d）%s" % [m.energy,energy.amount," 自由プレイ" if free else ""],24)
	label("戦闘数 %d / 最大出現数 %d" % [m.waves.size(),m.waves[0].size()],26)
	label("報酬 %dハク / %d経験値" % [m.rewards.haku,m.rewards.xp],26)
	if int(m.get("perfect_bonus_haku",0))>0:
		label("挑戦：通常クイズ全問正解で追加 %dハク" % int(m.perfect_bonus_haku),22)
	if m.get("training",false):
		label("自己ベスト：正解率 %d%%　%d回達成ごとに宝玉1個（無料）" % [save.get("training_best",0),data.progression.training_orb_interval],22)
	var objectives: Array = data.challenges.get(m.id,[])
	if not objectives.is_empty():
		label("挑戦目標（本作の仮条件・達成ごとにハク）",23,palette.dark)
		for objective in objectives: label("・%s　%dハク" % [objective.label,objective.reward_haku],21)
	space(20)
	label("編成したミタマを速さ順で使用します。\n巻物を選び、20秒以内に四択へ解答。正解で攻撃し、残った鬼が反撃します。\n敵をタップして攻撃対象を変更できます。",24)
	label("仮仕様：4秒以内の正解で固有効果と後続1体の追撃。\n正解でタマフリとムスヒを蓄積。角を壊すと気絶、腕を壊すと攻撃低下。",22)
	space(30)
	button("出陣",start_battle,not free and int(energy.amount)<int(m.energy))
	button("任務一覧へ",show_missions)

func portrait(id: String, width: float = 112.0, preview_stage: int = -1) -> TextureRect:
	var positions := {"m01":4,"m02":0,"m03":2,"m04":3,"m05":1,"m06":5}
	var index: int = positions.get(id,0)
	var stage: int = preview_stage if preview_stage>=0 else int(save.get("evolutions",{}).get(id,0))
	var stars: int = maxi(1,progression.rarity(id,stage))
	var atlas := AtlasTexture.new()
	var entry: Dictionary = {}
	for member in data.mitama:
		if member.id == id:
			entry = member
			break
	if stars>=7 and id in ["m01","m03","m04","m05","m06"]:
		atlas.atlas=load("res://assets/art/portraits_rare7.jpg")
		var cell:=Vector2(atlas.atlas.get_width()/3.0,atlas.atlas.get_height()/2.0)
		atlas.region=Rect2(Vector2((index%3)*cell.x,(index/3)*cell.y),cell)
	elif entry.has("portrait_sheet"):
		var sheet_index: int = int(entry.portrait_index)
		atlas.atlas = load("res://assets/art/"+str(entry.portrait_sheet)+".jpg")
		var half := atlas.atlas.get_size() / 2.0
		atlas.region = Rect2(Vector2((sheet_index%2)*half.x,(sheet_index/2)*half.y),half)
	elif id in ["m13","m14","m02","m16"]:
		var historical_index: int = ["m13","m14","m02","m16"].find(id)
		atlas.atlas = load("res://assets/art/mitama_historical.png")
		var half := atlas.atlas.get_size() / 2.0
		atlas.region = Rect2(Vector2((historical_index%2)*half.x,(historical_index/2)*half.y),half)
	elif id in ["m09","m10","m11","m12"]:
		var extra_index: int = ["m09","m10","m11","m12"].find(id)
		atlas.atlas = load("res://assets/art/mitama_more.png")
		var half := atlas.atlas.get_size() / 2.0
		atlas.region = Rect2(Vector2((extra_index%2)*half.x,(extra_index/2)*half.y),half)
	elif id in ["m07","m08"]:
		atlas.atlas = load("res://assets/art/mitama_extra.png")
		atlas.region = Rect2(0 if id=="m07" else 887,0,887,887)
	elif positions.has(id):
		atlas.atlas = load("res://assets/art/portraits.png")
		atlas.region = Rect2((index%3)*512,(index/3)*512,512,512)
	else:
		atlas.atlas = load("res://assets/art/mitama_placeholder.svg")
		atlas.region = Rect2(0,0,512,512)
	var image := TextureRect.new()
	image.texture = atlas
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.custom_minimum_size = Vector2(width,width)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if stars>=5:
		var tint:=ShaderMaterial.new()
		tint.shader=RarityTint
		tint.set_shader_parameter("richness",[0.16,0.28,0.45][stars-5])
		image.material=tint
	var frame=RarityFrame.new()
	frame.rarity=stars
	image.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return image

func deck_ids() -> Array:
	return save.get("deck",save.owned.slice(0,4))

func members_for_deck() -> Array:
	var members: Array = []
	for id in deck_ids():
		for original in data.mitama:
			if original.id == id:
				var member: Dictionary = original.duplicate(true)
				var level: int = int(save.get("levels",{}).get(id,1))
				member.level = level
				member.hp += (level-1)*int(data.progression.health_per_level)
				member.attack += (level-1)*int(data.progression.attack_per_level)
				var evolution: int = int(save.get("evolutions",{}).get(id,0))
				member.evolution = evolution
				member.hp += evolution*int(data.progression.evolve_health)
				member.attack += evolution*int(data.progression.evolve_attack)
				members.append(member)
	return members

func save_change(updated: Dictionary) -> bool:
	if not store.persist(updated):
		label("保存に失敗しました："+store.error,22,Color("8a332d"))
		return false
	save = store.upgraded(updated)
	return true

func skill_description(effect: Dictionary) -> String:
	match effect.kind:
		"reduce_choices": return "次の四択で誤答を%d個減らす" % int(effect.remove_count)
		"attack": return "攻撃力の%d%%で攻撃" % roundi(float(effect.power)*100)
		"multi_attack": return "攻撃力の%d%%で%d回攻撃" % [roundi(float(effect.power)*100),int(effect.hits)]
		"attack_heal": return "攻撃%d%%＋最大体力の%d%%回復" % [roundi(float(effect.power)*100),roundi(float(effect.fraction)*100)]
		"attack_guard": return "攻撃%d%%＋次の敵行動の被害を%d%%に" % [roundi(float(effect.power)*100),roundi(float(effect.multiplier)*100)]
		"heal_guard": return "最大体力%d%%回復＋次の敵行動の被害を%d%%に" % [roundi(float(effect.fraction)*100),roundi(float(effect.multiplier)*100)]
		"attack_rally": return "攻撃%d%%＋次の%d撃を%d%%に強化" % [roundi(float(effect.power)*100),int(effect.hits),roundi(float(effect.multiplier)*100)]
		"heal": return "最大体力の%d%%回復" % roundi(float(effect.fraction)*100)
		"guard": return "次の敵行動の被害を%d%%に" % roundi(float(effect.multiplier)*100)
		"rally": return "次の%d撃を%d%%に強化" % [int(effect.hits),roundi(float(effect.multiplier)*100)]
	return "効果未設定"

func show_party() -> void:
	screen = "party"
	clear_page("ミタマ ── 編成と強化")
	label("編成 %d/4　コスト %d/%d　ハク %d　素材 %d" % [deck_ids().size(),progression.team_cost(deck_ids()),data.progression.team_cost_limit,save.haku,save.get("material",0)],22)
	for original in data.mitama:
		var m: Dictionary = original
		if not m.id in save.owned: continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		content.add_child(row)
		row.add_child(portrait(m.id,108))
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var level: int = int(save.get("levels",{}).get(m.id,1))
		var info := Label.new()
		var stage: int = int(save.get("evolutions",{}).get(m.id,0))
		info.text = "%s%s  [%s] ★%d Lv.%d\n体力 %d / 攻撃 %d" % [m.name,"（仮絵）" if m.art=="generic_placeholder" else "",m.attribute,progression.rarity(m.id,stage),level,int(m.hp)+(level-1)*int(data.progression.health_per_level)+stage*int(data.progression.evolve_health),int(m.attack)+(level-1)*int(data.progression.attack_per_level)+stage*int(data.progression.evolve_attack)]
		info.add_theme_color_override("font_color",palette.ink)
		info.add_theme_font_size_override("font_size",21)
		panel.add_child(info)
		var history := Label.new()
		history.text = m.get("historical_fact","")
		history.add_theme_color_override("font_color",palette.ink)
		history.add_theme_font_size_override("font_size",17)
		history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(history)
		var skills_info := Label.new()
		var hay: Dictionary = data.effects.definitions[m.hayafuri]
		var tama: Dictionary = data.effects.definitions[m.tamafuri]
		skills_info.text = "ハヤフリ：%s\n%s\nタマフリ：%s（%d pt）\n%s" % [hay.label,skill_description(hay),tama.label,int(tama.cost),skill_description(tama)]
		skills_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skills_info.add_theme_color_override("font_color",palette.ink)
		skills_info.add_theme_font_size_override("font_size",18)
		panel.add_child(skills_info)
		var controls := HBoxContainer.new()
		panel.add_child(controls)
		var toggle := Button.new()
		toggle.text = "編成中" if m.id in deck_ids() else "編成する"
		toggle.disabled = m.id in deck_ids() and deck_ids().size()<=1
		toggle.pressed.connect(func():
			var updated: Dictionary = progression.change_deck(save,m.id)
			if updated.is_empty(): return
			if save_change(updated): show_party())
		controls.add_child(toggle)
		var upgrade := Button.new()
		upgrade.text = "強化 %dハク" % data.progression.upgrade_cost_haku
		upgrade.disabled = save.haku<int(data.progression.upgrade_cost_haku) or level>=int(data.progression.upgrade_max_level)
		upgrade.pressed.connect(func():
			var updated: Dictionary = save.duplicate(true)
			updated.haku -= int(data.progression.upgrade_cost_haku)
			if not updated.has("levels"): updated["levels"] = {}
			updated.levels[m.id] = level+1
			if save_change(updated): show_party())
		controls.add_child(upgrade)
		var fusion := Button.new()
		fusion.text = "素材合成"
		fusion.disabled = int(save.get("material",0))<int(data.progression.fusion_material) or int(save.haku)<int(data.progression.fusion_haku) or level>=int(data.progression.upgrade_max_level)
		fusion.pressed.connect(func(): show_fusion(m))
		panel.add_child(fusion)
		var evolve_button := Button.new()
		var stars: int = progression.rarity(m.id,stage)
		evolve_button.text = "進化 %d→%d　★%d→★%d" % [stage,stage+1,stars,stars+1] if stars<7 else "★7 最高レアリティ"
		evolve_button.disabled = progression.evolve(save,m.id).is_empty()
		evolve_button.pressed.connect(func(): show_evolve(m))
		panel.add_child(evolve_button)
	label("編成は最大4体。満員の場合は先に1体外してください。\n強化：%dハクで体力+%d・攻撃+%d（仮値、最大Lv.%d）。" % [data.progression.upgrade_cost_haku,data.progression.health_per_level,data.progression.attack_per_level,data.progression.upgrade_max_level],20)
	label("肖像は新規の象徴画です。史実や原作の容姿を再現したものではありません。",19)
	button("里に戻る",show_home)

func show_fusion(m: Dictionary) -> void:
	screen = "fusion"
	clear_page("素材合成による強化")
	content.add_child(portrait(m.id,180))
	var level: int = int(save.get("levels",{}).get(m.id,1))
	var stage: int = int(save.get("evolutions",{}).get(m.id,0))
	var hp: int = int(m.hp)+(level-1)*int(data.progression.health_per_level)+stage*int(data.progression.evolve_health)
	var attack: int = int(m.attack)+(level-1)*int(data.progression.attack_per_level)+stage*int(data.progression.evolve_attack)
	label("%s　Lv.%d → %d" % [m.name,level,level+1],30)
	label("体力 %d → %d　攻撃 %d → %d" % [hp,hp+int(data.progression.health_per_level),attack,attack+int(data.progression.attack_per_level)],23)
	label("必要：%dハク・素材%d / 現在：%dハク・素材%d（仮仕様）" % [data.progression.fusion_haku,data.progression.fusion_material,save.haku,save.get("material",0)],22)
	var unavailable: bool = level>=int(data.progression.upgrade_max_level) or save.haku<int(data.progression.fusion_haku) or int(save.get("material",0))<int(data.progression.fusion_material)
	button("合成を確定",func():
		var updated: Dictionary = save.duplicate(true)
		if int(updated.haku)<int(data.progression.fusion_haku) or int(updated.get("material",0))<int(data.progression.fusion_material): return
		updated.haku -= int(data.progression.fusion_haku)
		updated["material"] = int(updated.get("material",0))-int(data.progression.fusion_material)
		if not updated.has("levels"): updated["levels"] = {}
		updated.levels[m.id] = level+1
		if save_change(updated): show_party(),unavailable)
	button("戻る",show_party)

func show_evolve(m: Dictionary) -> void:
	screen = "evolve"
	clear_page("ミタマ進化")
	var stage: int = int(save.get("evolutions",{}).get(m.id,0))
	var stars: int = progression.rarity(m.id,stage)
	var needed: Dictionary = progression.evolution_requirements(m.id,stage)
	if needed.is_empty():
		content.add_child(portrait(m.id,180))
		label("★7に到達しています。",26)
		button("戻る",show_party)
		return
	var preview:=HBoxContainer.new()
	preview.add_theme_constant_override("separation",24)
	content.add_child(preview)
	preview.add_child(portrait(m.id,180,stage))
	preview.add_child(portrait(m.id,180,stage+1))
	var level: int = int(save.get("levels",{}).get(m.id,1))
	var before_hp: int = int(m.hp)+(level-1)*int(data.progression.health_per_level)+stage*int(data.progression.evolve_health)
	var before_attack: int = int(m.attack)+(level-1)*int(data.progression.attack_per_level)+stage*int(data.progression.evolve_attack)
	label("%s　★%d → ★%d" % [m.name,stars,stars+1],30)
	label("体力 %d → %d　攻撃 %d → %d" % [before_hp,before_hp+int(data.progression.evolve_health),before_attack,before_attack+int(data.progression.evolve_attack)],23)
	label("必要：%dハク・素材%d / 現在：%dハク・素材%d\n条件：Lv.%d以上。すべて仮仕様。" % [int(needed.haku),int(needed.material),save.haku,save.get("material",0),int(needed.level)],22)
	button("進化を確定",func():
		var updated: Dictionary = progression.evolve(save,m.id)
		if not updated.is_empty() and save_change(updated): show_party(),progression.evolve(save,m.id).is_empty())
	button("戻る",show_party)

func show_encyclopedia() -> void:
	screen = "encyclopedia"
	clear_page("ミタマ事典")
	label("登録 %d / %d" % [save.owned.size(),data.mitama.size()],27)
	var owned_labels := ["すべて","取得済み","未取得"]
	var attribute_labels := ["すべて","斬","砕","突"]
	button("所持："+owned_labels[encyclopedia_owned_filter],func():
		encyclopedia_owned_filter=(encyclopedia_owned_filter+1)%owned_labels.size()
		show_encyclopedia())
	button("属性："+attribute_labels[encyclopedia_attribute_filter],func():
		encyclopedia_attribute_filter=(encyclopedia_attribute_filter+1)%attribute_labels.size()
		show_encyclopedia())
	for m in data.mitama:
		var owned: bool = m.id in save.owned
		if encyclopedia_owned_filter==1 and not owned: continue
		if encyclopedia_owned_filter==2 and owned: continue
		if encyclopedia_attribute_filter>0 and m.attribute!=attribute_labels[encyclopedia_attribute_filter]: continue
		if owned:
			var member: Dictionary=m
			var stage: int=int(save.get("evolutions",{}).get(member.id,0))
			button("◆ %s　%s　★%d" % [member.name,member.attribute,progression.rarity(member.id,stage)],func(): show_mitama_detail(member))
		else: label("◇ 未取得",23)
	for key in data.progression.encyclopedia_rewards:
		var threshold := int(key)
		var claimed: bool = key in save.get("collection_claimed",[])
		button("登録%d体報酬：%dハク%s" % [threshold,data.progression.encyclopedia_rewards[key],"（受取済）" if claimed else ""],func():
			var updated: Dictionary = progression.claim_collection(save,threshold)
			if not updated.is_empty() and save_change(updated): show_encyclopedia(),claimed or save.owned.size()<threshold)
	button("里に戻る",show_home)

func show_mitama_detail(m: Dictionary) -> void:
	if not m.id in save.owned: return
	screen="mitama_detail"
	clear_page("ミタマ事典 ── "+str(m.name))
	content.add_child(portrait(m.id,180))
	var level: int=int(save.get("levels",{}).get(m.id,1))
	var stage: int=int(save.get("evolutions",{}).get(m.id,0))
	var hp: int=int(m.hp)+(level-1)*int(data.progression.health_per_level)+stage*int(data.progression.evolve_health)
	var attack: int=int(m.attack)+(level-1)*int(data.progression.attack_per_level)+stage*int(data.progression.evolve_attack)
	label("%s　★%d　%s　Lv.%d　進化%d" % [m.name,progression.rarity(m.id,stage),m.attribute,level,stage],25)
	label("体力 %d　攻撃 %d　速さ %d　コスト %d" % [hp,attack,int(m.speed),int(m.cost)],21)
	label(str(m.get("historical_fact","")),21)
	var hay: Dictionary=data.effects.definitions[m.hayafuri]
	var tama: Dictionary=data.effects.definitions[m.tamafuri]
	label("ハヤフリ：%s\n%s" % [hay.label,skill_description(hay)],21)
	label("タマフリ：%s（%d pt）\n%s" % [tama.label,int(tama.cost),skill_description(tama)],21)
	if m.has("reference_versions"):
		label("非公式Wikiの掲載例（本作の能力ではありません）",18)
		for reference in m.reference_versions:
			label("★%d %s　%s属性　コスト%s" % [int(reference.rarity),reference.get("variant",""),reference.attribute,str(reference.get("cost","不明"))],18)
	label("能力・技・進化条件は本作の暫定設定。",18)
	button("事典に戻る",show_encyclopedia)

func show_gacha() -> void:
	screen = "gacha"
	clear_page("召喚 ── ミタマを迎える")
	label("所持ハク %d　宝玉 %d" % [save.haku,save.get("orbs",0)],28)
	label("%dハクで未所持のミタマから等確率で1体を迎えます。\n確率と費用はオフライン用の仮仕様です。" % data.progression.summon_cost_haku,23)
	var missing: Array = []
	for m in data.mitama:
		if not m.id in save.owned: missing.append(m)
	label("未所持 %d体" % missing.size(),24)
	button("召喚する（%dハク）" % data.progression.summon_cost_haku,func():
		if save.haku<int(data.progression.summon_cost_haku) or missing.is_empty(): return
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var selected: Dictionary = missing[rng.randi_range(0,missing.size()-1)]
		var updated: Dictionary = save.duplicate(true)
		updated.haku -= int(data.progression.summon_cost_haku)
		updated.owned.append(selected.id)
		if save_change(updated):
			show_gacha()
			content.add_child(portrait(selected.id,180))
			label("%s を迎えました！%s" % [selected.name,"（仮絵）" if selected.art=="generic_placeholder" else ""],30),save.haku<int(data.progression.summon_cost_haku) or missing.is_empty())
	button("宝玉で召喚（%d個）" % data.progression.orb_summon_cost,func():
		var cost: int = int(data.progression.orb_summon_cost)
		if int(save.get("orbs",0))<cost or missing.is_empty(): return
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var selected: Dictionary = missing[rng.randi_range(0,missing.size()-1)]
		var updated: Dictionary = save.duplicate(true)
		updated["orbs"] = int(updated.get("orbs",0))-cost
		updated.owned.append(selected.id)
		if save_change(updated):
			show_gacha()
			content.add_child(portrait(selected.id,180))
			label("%s を迎えました！%s" % [selected.name,"（仮絵）" if selected.art=="generic_placeholder" else ""],30),int(save.get("orbs",0))<int(data.progression.orb_summon_cost) or missing.is_empty())
	label("宝玉は任務の初回達成、または修練%d回で無料入手。課金・広告なし。召喚対象は未所持から等確率。" % data.progression.training_orb_interval,20)
	button("里に戻る",show_home)

func show_settings() -> void:
	screen = "settings"
	clear_page("設定・セーブ情報")
	label("完全オフライン / 広告・課金なし",25)
	button("行動力："+("自由プレイ" if save.settings.get("free_play",false) else "通常"),func():
		var updated: Dictionary = save.duplicate(true)
		updated.settings["free_play"] = not updated.settings.get("free_play",false)
		if save_change(updated): show_settings())
	label("任務報酬は帰還前に自動保存されます。\n保存先：user://save.json\n世代バックアップ：save.json.bak\n読み込み時は現在の進行を上書きする前に確認します。",23)
	button("演出の速さ："+("じっくり" if save.settings.get("relaxed_effects",false) else "テンポ優先"),func():
		var updated: Dictionary = save.duplicate(true)
		updated.settings["relaxed_effects"] = not updated.settings.get("relaxed_effects",false)
		if save_change(updated): show_settings())
	button("効果音："+("OFF" if save.settings.get("muted",false) else "ON"),func():
		var updated: Dictionary = save.duplicate(true)
		updated.settings["muted"] = not updated.settings.get("muted",false)
		if store.persist(updated):
			save = updated
			show_settings()
		else: label(store.error,24,Color("8a332d")))
	button("BGM："+("OFF" if save.settings.get("bgm_muted",false) else "ON"),func():
		var updated: Dictionary=save.duplicate(true)
		updated.settings["bgm_muted"]=not updated.settings.get("bgm_muted",false)
		if save_change(updated):
			music.configure(save.settings)
			show_settings())
	button("BGM音量：%d%%" % int(save.settings.get("bgm_volume",60)),func():
		var levels: Array=[20,40,60,80,100]
		var current: int=levels.find(int(save.settings.get("bgm_volume",60)))
		var updated: Dictionary=save.duplicate(true)
		updated.settings["bgm_volume"]=levels[(current+1)%levels.size()]
		if save_change(updated):
			music.configure(save.settings)
			show_settings())
	button("バックアップを書き出す",func(): backup_dialog(false))
	button("バックアップを読み込む",func(): backup_dialog(true))
	button("現在の進行を保存",func():
		if store.persist(save): label("保存しました。",24)
		else: label(store.error,24,Color("8a332d")))
	button("里に戻る",show_home)

func backup_dialog(importing: bool) -> void:
	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	picker.filters = PackedStringArray(["*.json ; 鬼問戦記セーブ"])
	picker.current_file = "kimon-backup.json"
	add_child(picker)
	picker.file_selected.connect(func(path: String):
		picker.hide()
		if importing:
			var file := FileAccess.open(path,FileAccess.READ)
			if file == null or file.get_length()>2*1024*1024:
				label("ファイルを読み込めません。",22,Color("8a332d"))
				return
			var parser := JSON.new()
			if parser.parse(file.get_as_text()) != OK or not store.valid(parser.data) or not progression.valid_backup(parser.data):
				label("対応していないか、破損したバックアップです。",22,Color("8a332d"))
				return
			var incoming: Dictionary = parser.data
			var confirm := ConfirmationDialog.new()
			confirm.title = "バックアップの読み込み"
			confirm.dialog_text = "現在の進行を読み込んだ内容で上書きします。\nハク：%d → %d / 所持ミタマ：%d → %d\n現在のデータは前世代のバックアップにも保存します。" % [save.haku,incoming.haku,save.owned.size(),incoming.owned.size()]
			confirm.ok_button_text = "上書きして読み込む"
			add_child(confirm)
			confirm.confirmed.connect(func():
				if save_change(incoming):
					show_settings()
					label("バックアップを読み込みました。",22))
			confirm.popup_centered()
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file == null:
				label("書き出せませんでした。",22,Color("8a332d"))
				return
			file.store_string(JSON.stringify(save,"  "))
			file.flush()
			if file.get_error() != OK:
				label("書き出し中にエラーが発生しました。",22,Color("8a332d"))
				file.close()
				return
			file.close()
			label("バックアップを書き出しました。",22))
	picker.popup_centered_ratio(0.9)

func start_battle() -> void:
	var updated: Dictionary = progression.enter_mission(save,mission,int(Time.get_unix_time_from_system()))
	if updated.is_empty():
		show_details(mission)
		label("行動力が不足しています。",23,Color("8a332d"))
		return
	if not save_change(updated): return
	var party: Array = members_for_deck()
	model.setup(party,mission,data.oni,data.balance,Time.get_ticks_msec(),data.effects.definitions)
	event_history.clear()
	offered_scrolls.clear()
	recent_question_ids.clear()
	mistakes.clear()
	receipt = "%s-%s-%s" % [mission.id,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	question_serial = 0
	active_clock.reset()
	battle_clock = 0.0
	notice = "巻物を選んでください。"
	show_battle()

func show_battle() -> void:
	screen = "battle"
	clear_page("%s  %d/%d" % [mission.label,mini(model.wave_index+1,model.waves.size()),model.waves.size()])
	var art = StageArt.new()
	stage_art = art
	art.enemy_data = model.enemies.duplicate(true)
	art.count = model.enemies.size()
	art.selected = model.target_index
	for e in model.enemies: art.dead.append(e.hp <= 0)
	art.custom_minimum_size.y = 190
	content.add_child(art)
	var targets := HBoxContainer.new()
	content.add_child(targets)
	for i in range(model.enemies.size()):
		var enemy: Dictionary = model.enemies[i]
		var b := Button.new()
		b.text = "%s %s  HP %d" % ["◎" if i==model.target_index else "", "大鬼" if enemy.get("large",false) else "鬼%d" % (i+1),enemy.hp]
		b.custom_minimum_size.y = 50
		b.add_theme_font_size_override("font_size",21)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = enemy.hp <= 0 or model.status != "scrolls" or busy
		b.pressed.connect(func():
			if model.choose_target(i): show_battle())
		targets.add_child(b)
	if model.status == "scrolls" and not busy and model.enemies[model.target_index].get("large",false):
		var parts_row := HBoxContainer.new()
		content.add_child(parts_row)
		var part_options: Array = [{"id":"body","label":"本体","hp":model.enemies[model.target_index].hp,"attribute":model.enemies[model.target_index].attribute}]
		part_options.append_array(model.enemies[model.target_index].parts)
		for part in part_options:
			var p := Button.new()
			p.text = ("◎" if model.target_part==part.id else "")+part.label+"・"+str(part.get("attribute",model.enemies[model.target_index].attribute))+"\n"+(str(int(part.hp)) if part.hp>0 else "破壊済")
			p.custom_minimum_size.y = 60
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.add_theme_font_size_override("font_size",20)
			p.disabled = part.hp<=0
			p.pressed.connect(func():
				if model.choose_target(model.target_index,part.id): show_battle())
			parts_row.add_child(p)
	var order_text := ""
	for j in range(model.party.size()):
		var m: Dictionary = model.party[(model.actor_index+j)%model.party.size()]
		order_text += ("▶ " if j==0 else " → ")+m.name
	label(order_text,20,palette.dark)
	var portraits_row := HBoxContainer.new()
	portraits_row.add_theme_constant_override("separation",4)
	content.add_child(portraits_row)
	for j in range(model.party.size()):
		var member: Dictionary = model.party[(model.actor_index+j)%model.party.size()]
		portraits_row.add_child(portrait(member.id,68 if j==0 else 54))
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = model.max_hp
	hp_bar.value = model.hp
	hp_bar.custom_minimum_size.y = 28
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill",style(Color("468780"),palette.gold))
	content.add_child(hp_bar)
	label("体力 %d / %d" % [model.hp,model.max_hp],20)
	var display_notice := notice
	if model.status == "scrolls" and model.target_part != "body":
		for part in model.enemies[model.target_index].get("parts",[]):
			if part.id == model.target_part:
				if int(part.get("stun_turns",0))>0: display_notice += "　角破壊で気絶"
				elif float(part.get("attack_multiplier",1.0))<1.0: display_notice += "　破壊で反撃減少"
	label(display_notice,20)
	if model.status == "scrolls" and not busy:
		var actor: Dictionary = model.party[model.actor_index]
		var target_attr: String = model.target_attribute()
		var multiplier: float = float(data.balance.attributes[actor.attribute][target_attr])
		var matchup := "有利" if multiplier>1.0 else ("不利" if multiplier<1.0 else "互角")
		label("ムスヒ %d/%d　連続%d　%s→%s %s×%.2f" % [model.gauge,data.balance.musuhi.gauge_required,model.streak,actor.attribute,target_attr,matchup,multiplier],18)
		var skills := HBoxContainer.new()
		content.add_child(skills)
		for index in range(model.party.size()):
			var m: Dictionary = model.party[index]
			var cost: int = int(data.effects.definitions[m.tamafuri].cost)
			var skill_button := Button.new()
			var kind: String = data.effects.definitions[m.tamafuri].kind
			var role: String = {"attack":"攻","multi_attack":"連","attack_heal":"攻癒","attack_guard":"攻守","heal_guard":"癒守","attack_rally":"攻援","heal":"癒","guard":"守","rally":"援","reduce_choices":"知"}.get(kind,"技")
			skill_button.text = "%s・%s\n%d/%d pt" % [m.name,role,model.points[index],cost]
			skill_button.add_theme_font_size_override("font_size",18)
			skill_button.custom_minimum_size.y = 56
			skill_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_button.disabled = not model.can_tamafuri(index)
			skill_button.pressed.connect(func(): use_tamafuri(index))
			skills.add_child(skill_button)
		var musuhi_button := Button.new()
		musuhi_button.text = "ムスヒ\n発動"
		musuhi_button.custom_minimum_size.y = 56
		musuhi_button.add_theme_font_size_override("font_size",18)
		musuhi_button.disabled = not model.can_musuhi()
		musuhi_button.pressed.connect(begin_musuhi)
		skills.add_child(musuhi_button)
	if busy: return
	if model.status == "scrolls":
		if model.pending_choice_reduction>0:
			label("次の四択は誤答が%d個減ります" % model.pending_choice_reduction,19)
		if offered_scrolls.is_empty():
			offered_scrolls = QuizPool.scrolls(data.questions,4,model.rng,recent_question_ids)
		label("正解時の通常攻撃予想（追撃・技は含まず）",16)
		for q in offered_scrolls:
			var rank: String = ["初級","中級","上級"][int(q.difficulty)-1]
			var estimate: Dictionary = model.preview_strike(model.party[model.actor_index],float(data.balance.difficulty_multipliers[str(int(q.difficulty))]))
			var estimate_text := "本体%d" % int(estimate.body_damage)
			if model.target_part != "body": estimate_text = "部位%d / 本体%d" % [int(estimate.part_damage),int(estimate.body_damage)]
			var scroll_button := button("%s　%s　予想 %s" % [rank,q.genre,estimate_text],func(): choose_question(q))
			var parchment := style(Color("f2e3bc"),Color("694626"),5)
			parchment.shadow_color = Color(0.17,0.11,0.05,0.55)
			parchment.shadow_size = 3
			parchment.shadow_offset = Vector2(0,3)
			scroll_button.add_theme_stylebox_override("normal",parchment)
			var ornament = ScrollOrnament.new()
			ornament.tier = int(q.difficulty)
			scroll_button.add_child(ornament)
		button("撤退して里へ（報酬なし）",show_home)
	elif model.status == "question":
		var q: Dictionary = model.current_question
		label(q.text,27)
		clock_label = label("残り 20.0 秒",22)
		for i in range(q.options.size()):
			if i in model.visible_answer_indices:
				button("%d．%s" % [i+1,q.options[i]],func(): answer(i))

func choose_question(q: Dictionary) -> void:
	if busy or model.status != "scrolls": return
	busy = true
	await animate_events([{"type":"scroll_open","text":"%s の問いをひらく" % q.genre}])
	busy = false
	sync_clock()
	if model.begin_question(q,int(battle_clock)):
		offered_scrolls.clear()
		recent_question_ids.append(q.id)
		while recent_question_ids.size()>int(data.balance.get("quiz_recent_limit",30)):
			recent_question_ids.pop_front()
		notice = "落ち着いて問いを解こう。"
		show_battle()
		update_clock_state()

func answer(selection: int) -> void:
	if busy: return
	sync_clock()
	var question: Dictionary = model.current_question.duplicate(true)
	var outcome: Dictionary = model.resolve_answer(selection,int(battle_clock))
	if not outcome.accepted: return
	if not outcome.correct: mistakes.append(question)
	update_clock_state()
	busy = true
	notice = "正解！" if outcome.correct else "不正解・時間切れ　正答：%s" % outcome.answer
	show_battle()
	label(outcome.explanation,22)
	await animate_events(outcome.events)
	var answer_delay: float = float(data.balance.presentation.answer_seconds) if save.settings.get("relaxed_effects",false) else float(data.balance.presentation.get("answer_seconds_fast",0.3))
	await get_tree().create_timer(answer_delay).timeout
	busy = false
	resume_battle()

func animate_events(events: Array) -> void:
	skip_effects = false
	for event in events:
		event_history.append(event.duplicate(true))
		if skip_effects: continue
		if not save.get("settings",{}).get("muted",false): sound.play_event(event.type)
		var overlay := PanelContainer.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.gui_input.connect(func(input: InputEvent):
			if (input is InputEventScreenTouch and input.pressed) or (input is InputEventMouseButton and input.pressed and input.button_index==MOUSE_BUTTON_LEFT):
				skip_effects = true)
		overlay.add_theme_stylebox_override("panel",style(Color(0.07,0.12,0.13,0.56),palette.gold,0))
		add_child(overlay)
		if event.type in ["attack","followup","skill_attack","musuhi_attack","part_break"]:
			var slash := TextureRect.new()
			slash.texture = load("res://assets/art/slash.png")
			slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slash.modulate.a = 0.72
			overlay.add_child(slash)
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(center)
		var strip := VBoxContainer.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.custom_minimum_size.x = 600
		center.add_child(strip)
		var headline := Label.new()
		headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var headings := {"scroll_open":"巻物開封", "hayafuri":"ハヤフリ", "tamafuri":"タマフリ", "musuhi":"ムスヒノ刻", "quiz_help":"解答補助", "part_break":"部位破壊", "followup":"追撃", "attack":"一閃", "enemy_attack":"鬼の反撃", "stun":"気絶", "kill":"討伐", "heal":"回復", "guard":"守護", "rally":"奮起", "part_hit":"部位攻撃", "skill_attack":"霊技", "musuhi_attack":"四魂の一撃"}
		headline.text = headings.get(event.type,"霊技")
		headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		headline.add_theme_font_size_override("font_size",52)
		headline.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
		headline.add_theme_constant_override("shadow_offset_x",3)
		headline.add_theme_constant_override("shadow_offset_y",3)
		headline.add_theme_color_override("font_color",Color("efd28d") if event.type != "enemy_attack" else Color("ed8972"))
		strip.add_child(headline)
		var detail := Label.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.text = event.get("actor","")+"\n"+event.text
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size",25)
		detail.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
		detail.add_theme_constant_override("shadow_offset_x",2)
		detail.add_theme_constant_override("shadow_offset_y",2)
		detail.add_theme_color_override("font_color",Color("fff3d5"))
		strip.add_child(detail)
		var hint := Label.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.text = "タップで演出を早送り"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size",18)
		hint.add_theme_color_override("font_color",Color("d7c9ae"))
		strip.add_child(hint)
		if event.has("damage"):
			var number := Label.new()
			number.mouse_filter = Control.MOUSE_FILTER_IGNORE
			number.text = "−%d" % int(event.damage)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number.add_theme_font_size_override("font_size",64)
			number.add_theme_color_override("font_color",Color("ffe6a9"))
			strip.add_child(number)
		if event.type=="scroll_open":
			strip.scale.x=0.15
			create_tween().tween_property(strip,"scale:x",1.0,0.25)
		strip.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(strip,"modulate:a",1.0,0.1)
		tween.parallel().tween_property(headline,"scale",Vector2(1.06,1.06),0.16)
		var event_delay: float = float(data.balance.presentation.event_seconds) if save.settings.get("relaxed_effects",false) else float(data.balance.presentation.get("event_seconds_fast",0.18))
		await get_tree().create_timer(event_delay).timeout
		overlay.queue_free()

func resume_battle() -> void:
	if model.status in ["won","lost"]: show_result()
	else: show_battle()

func use_tamafuri(index: int) -> void:
	if busy: return
	var result: Dictionary = model.use_tamafuri(index)
	if not result.accepted: return
	busy = true
	notice = "タマフリ発動"
	show_battle()
	await animate_events(result.events)
	busy = false
	resume_battle()

func begin_musuhi() -> void:
	if busy: return
	if not model.start_musuhi(data.boolean_questions,int(battle_clock)): return
	busy = true
	screen = "musuhi_intro"
	music.play_track("musuhi")
	await animate_events([{"type":"musuhi","text":"○×の連問に挑め！"}])
	# 発動カットインは回答時間に含めない。
	busy = false
	show_musuhi()

func show_musuhi() -> void:
	screen = "musuhi"
	update_clock_state()
	clear_page("ムスヒノ刻")
	label("四魂を結び、知恵を刃に",34,palette.dark)
	clock_label = label("残り %.1f 秒" % (model.musuhi_remaining_ms(int(battle_clock))/1000.0),32)
	label("正解 %d問　誤答 %d/%d" % [model.musuhi_correct,model.musuhi_mistakes,data.balance.musuhi.max_mistakes],26)
	label("仮ルール：制限20秒／2回目の誤答で終了",21)
	space(50)
	label(model.current_question.text,32)
	space(50)
	var circles := HBoxContainer.new()
	content.add_child(circles)
	for i in range(2):
		var b := Button.new()
		b.text = ["○","×"][i]
		b.custom_minimum_size = Vector2(0,180)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",80)
		b.add_theme_stylebox_override("normal",style(Color("f2e8cc"),palette.gold,40))
		b.add_theme_color_override("font_color",palette.dark)
		b.pressed.connect(func(): answer_musuhi(i))
		circles.add_child(b)
	label("正解数に応じて追加攻撃。終了後は通常戦闘へ戻ります。",22)

func answer_musuhi(selection: int) -> void:
	if busy: return
	sync_clock()
	var question: Dictionary = model.current_question.duplicate(true)
	var outcome: Dictionary = model.answer_musuhi(selection,int(battle_clock))
	if not outcome.accepted: return
	if outcome.has("correct") and not outcome.correct: mistakes.append(question)
	update_clock_state()
	busy = true
	if outcome.get("finished",false):
		await complete_musuhi(outcome)
		return
	label("正解！" if outcome.correct else "不正解",38)
	await get_tree().create_timer(float(data.balance.presentation.musuhi_feedback_seconds)).timeout
	busy = false
	if model.musuhi_remaining_ms(int(battle_clock)) == 0:
		end_musuhi()
	elif model.next_musuhi(int(battle_clock)): show_musuhi()

func end_musuhi() -> void:
	if busy: return
	sync_clock()
	var outcome: Dictionary = model.finish_musuhi(int(battle_clock))
	if not outcome.accepted: return
	update_clock_state()
	busy = true
	await complete_musuhi(outcome)

func complete_musuhi(outcome: Dictionary) -> void:
	screen = "musuhi_result"
	update_clock_state()
	await animate_events(outcome.events)
	busy = false
	notice = "ムスヒノ刻 %d問正解 / 追加ダメージ %d" % [model.musuhi_correct,outcome.damage]
	resume_battle()

func show_result() -> void:
	screen = "result"
	clear_page("任務達成" if model.status == "won" else "敗北")
	label("%s\n正解 %d / %d問" % [mission.label,model.correct,model.answered],30)
	if model.status == "won":
		var perfect: bool = model.answered>0 and model.correct==model.answered
		var results: Array = Challenges.evaluate(data.challenges.get(mission.id,[]),model.correct,model.answered,model.total_answer_ms,model.max_streak)
		var bonus: int = Challenges.reward(results)
		var updated: Dictionary = store.reward(save,mission,receipt,int(data.progression.orb_first_clear),int(data.progression.training_orb_interval),perfect,bonus)
		if mission.get("training",false) and model.answered>0:
			var score := int(floor(100.0*model.correct/model.answered))
			updated["training_best"] = maxi(int(updated.get("training_best",0)),score)
		if not store.persist(updated):
			label("保存できませんでした。報酬は未確定です。\n"+store.error,24,Color("8a332d"))
			button("保存を再試行",show_result)
			return
		save = updated
		label("%dハク / %d経験値 / 素材%dを獲得\n進行を保存しました。" % [mission.rewards.haku,mission.rewards.xp,mission.rewards.get("material",0)],28)
		if not results.is_empty():
			label("挑戦目標（仮）",25,palette.dark)
			for result in results:
				label("%s　%s%s" % ["達成" if result.met else "未達成",result.label,"　+%dハク" % result.reward_haku if result.met else ""],21)
		if perfect and int(mission.get("perfect_bonus_haku",0))>0:
			label("通常クイズ全問正解！ 追加 %dハク" % int(mission.perfect_bonus_haku),26,palette.dark)
	else: label("報酬はありません。里で準備を整えましょう。",26)
	if model.status == "won":
		for item in data.story.chapters:
			var chapter: Dictionary = item
			if chapter.get("unlock_after", "") == mission.id:
				button("物語の続きを見る",func(): show_story_page(chapter,0))
	if not mistakes.is_empty(): button("間違えた問題を復習（%d問）" % mistakes.size(),show_review)
	space(30)
	button("里へ帰還",show_home)

func show_review() -> void:
	screen = "review"
	clear_page("今回の問題を復習")
	for q in mistakes:
		label(q.text,25,palette.dark)
		label("正解：%s\n%s" % [q.options[int(q.answer)],q.explanation],21)
		var separator := HSeparator.new()
		content.add_child(separator)
	button("結果に戻る",show_result)
