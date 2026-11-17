extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
var data: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func fresh():
	var b = Battle.new()
	var baseline: Dictionary = data.balance.duplicate(true)
	baseline.hayafuri.enabled = false
	for row in baseline.attributes.values():
		for attr in row: row[attr] = 1.0
	b.setup(data.mitama.slice(0,4),data.missions[0],data.oni,baseline,12345)
	return b

func _initialize() -> void:
	for file in ["mitama","missions","oni","balance","questions"]:
		data[file] = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+file+".json"))
	var ids: Array = []
	for q in data.questions:
		check(not q.id in ids,"一意な問題ID")
		ids.append(q.id)
		check(q.options.size()==4 and q.answer>=0 and q.answer<4,"四択の構造")
		check(q.has("source") and q.has("checked_at"),"出典と確認日フィールド")
	var q: Dictionary = data.questions[0]
	var b = fresh()
	check(b.party[0].id=="m01","速さ降順")
	check(b.begin_question(q,1000),"出題開始")
	check(not b.begin_question(q,1000),"二重出題禁止")
	var hit: Dictionary = b.resolve_answer(q.answer,20999)
	check(hit.correct and hit.damage==95,"期限直前の正答と仮ダメージ")
	check(b.hp==b.max_hp-45,"反撃")
	check(not b.resolve_answer(q.answer,20999).accepted,"二重回答禁止")
	b=fresh()
	b.begin_question(q,1000)
	var timeout: Dictionary = b.resolve_answer(q.answer,21000)
	check(not timeout.correct and timeout.damage==0,"締切ちょうどは時間切れ")
	b=fresh()
	b.begin_question(q,1000)
	check(not b.resolve_answer((int(q.answer)+1)%4,1100).correct,"誤答")
	b=fresh()
	b.begin_question(q,3000)
	check(b.remaining_ms(2999)==20000,"時計逆行で残り時間を増やさない")
	check(b.remaining_ms(23001)==0,"時間切れ残り0")
	b=fresh()
	var other = fresh()
	check(b.rng.randi()==other.rng.randi(),"固定seedの再現性")
	# 独立した相性行列が計算に反映されること（本番値は中立）。
	b.config.attributes["斬"]["砕"]=2.0
	b.begin_question(q,0)
	check(b.resolve_answer(q.answer,1).damage==190,"相性係数の注入")
	b=fresh()
	var guard := 0
	while b.status=="scrolls" and guard<20:
		b.begin_question(q,0)
		b.resolve_answer(q.answer,10)
		guard+=1
	check(b.status=="won","討伐まで到達")
	b=fresh()
	guard=0
	while b.status=="scrolls" and guard<100:
		b.begin_question(q,0)
		b.resolve_answer(-1,20000)
		guard+=1
	check(b.status=="lost" and b.hp==0,"敗北まで到達")
	b=Battle.new()
	b.setup(data.mitama.slice(0,4),data.missions[1],data.oni,data.balance,12)
	check(b.choose_target(1) and b.target_index==1,"複数敵の対象変更")
	check(not b.choose_target(-1),"不正対象拒否")
	guard=0
	while b.status=="scrolls" and guard<50:
		b.begin_question(q,0)
		b.resolve_answer(q.answer,10)
		guard+=1
	check(b.status=="won" and b.wave_index==2,"連続戦闘を討伐")
	# テスト専用ファイルのみ使用し、実セーブは変更しない。
	var s = Store.new()
	s.base_path="user://test_save_%d.json" % Time.get_ticks_usec()
	var initial: Dictionary = s.load_save()
	check(s.persist(initial),"新規保存")
	var rewarded: Dictionary = s.reward(initial,data.missions[0],"test-receipt")
	check(rewarded.haku==100 and rewarded.cleared.has("trial01"),"報酬と任務解放")
	check(s.reward(rewarded,data.missions[0],"test-receipt").haku==100,"報酬重複防止")
	check(s.persist(rewarded),"更新保存")
	check(s.load_save().haku==100,"再読込")
	var f := FileAccess.open(s.base_path,FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(s.load_save().haku==0 and not s.blocked,"破損主ファイルから前世代復元")
	check(s.persist(rewarded),"復元後の保存")
	check(s._read(s.base_path+".bak").haku==0,"有効バックアップを破損主で上書きしない")
	f=FileAccess.open(s.base_path,FileAccess.WRITE)
	f.store_string('{"schema_version":3}')
	f.close()
	check(s.load_save().is_empty() and s.blocked,"将来版を上書きしない")
	check(not s.persist(initial),"書込保護")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(s.base_path+suffix)
	print("TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
