extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var checks := 0
var failures := 0
var d: Dictionary = {}
var mock_now := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func fresh():
	var b = Battle.new()
	var fixture: Array = d.oni.duplicate(true)
	for enemy in fixture:
		if enemy.id == "boss":
			enemy.hp = 3800
			enemy.attack = 190
	b.setup(d.mitama.slice(0,4),d.missions[2],fixture,d.balance,12345,d.effects.definitions)
	return b

func count_event(events: Array, kind: String) -> int:
	var n := 0
	for e in events:
		if e.type==kind: n+=1
	return n

func hit(b, elapsed: int = 5000) -> Dictionary:
	b.begin_question(d.questions[0],1000)
	return b.resolve_answer(d.questions[0].answer,1000+elapsed)

func _initialize() -> void:
	for name in ["balance","mitama","missions","oni","effects","questions","boolean_questions"]:
		d[name]=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name+".json"))
	var clock = preload("res://scripts/active_clock.gd").new(func():return mock_now)
	clock.set_running(true)
	mock_now=4000
	check(clock.read()==4000,"単調時計・フレーム停止後も実時間")
	clock.set_running(false)
	mock_now=500000
	check(clock.read()==4000,"休止時間を除外")
	clock.set_running(true)
	mock_now=500001
	check(clock.read()==4001,"復帰後の計時")
	mock_now=499999
	check(clock.read()==4001,"時計逆行拒否")
	clock.reset()
	check(clock.read()==0 and not clock.running,"時計リセット")
	# 個別スキル参照・データ整合性。
	for m in d.mitama:
		check(d.effects.definitions.has(m.hayafuri) and d.effects.definitions.has(m.tamafuri),"スキル参照")
	for q in d.boolean_questions:
		check(q.type=="boolean" and q.options==["○","×"] and int(q.answer) in [0,1],"○×構造")
	var b=fresh()
	var fast: Dictionary=hit(b,4000)
	check(fast.hayafuri and count_event(fast.events,"hayafuri")==1,"4秒ちょうど発動")
	check(count_event(fast.events,"followup")==1 and b.actor_index==2,"後続一体が攻撃・行動者進行")
	b=fresh()
	check(not hit(b,4001).hayafuri,"4秒超では非発動")
	b=fresh()
	check(hit(b,3999).hayafuri,"4秒未満で発動")
	b=fresh()
	b.begin_question(d.questions[0],0)
	var wrong: Dictionary=b.resolve_answer(-1,100)
	check(not wrong.hayafuri and count_event(wrong.events,"hayafuri")==0,"誤答は速答不可")
	check(b.points==[0,0,0,0] and b.gauge==0,"誤答は蓄積しない")
	b=fresh()
	hit(b)
	check(b.points==[1,1,1,1] and b.gauge==1,"正解蓄積")
	check(not b.use_tamafuri(0).accepted and b.points[0]==1,"不足時は非消費")
	b=fresh()
	b.points=[3,3,3,4]
	b.hp=500
	check(b.use_tamafuri(1).accepted and b.hp==990 and b.points[1]==0,"回復タマフリ・消費")
	check(not b.use_tamafuri(1).accepted and b.points[1]==0,"再発動拒否")
	check(b.use_tamafuri(2).accepted and b.guard_multiplier==0.3,"防御技")
	var guard_result: Dictionary=hit(b)
	check(guard_result.retaliation==57 and b.guard_multiplier==1.0,"防御は次の敵行動で消費")
	check(b.use_tamafuri(3).accepted and b.rally_hits==4,"攻撃支援技")
	hit(b)
	check(b.rally_hits==3,"支援の残り攻撃回数")
	check(b.use_tamafuri(0).accepted and b.points[0]==2,"攻撃タマフリのコスト")
	# 攻撃と回復を併せ持つ追加タマフリ。効果とコストを同時に検証。
	b=fresh()
	b.party[0]=d.mitama[8].duplicate(true)
	b.hp=500
	b.points[0]=3
	check(not b.use_tamafuri(0).accepted and b.points[0]==3,"複合技は不足時に消費しない")
	b.points[0]=4
	var before_enemy: int=b.enemies[0].hp
	var before_hp: int=b.hp
	var mixed: Dictionary=b.use_tamafuri(0)
	check(mixed.accepted and b.points[0]==0,"複合技のポイント消費")
	check(b.enemies[0].hp<before_enemy and b.hp>before_hp,"複合技の攻撃と回復")
	check(count_event(mixed.events,"skill_attack")==1 and count_event(mixed.events,"heal")==1,"複合技の演出イベント")
	b=fresh()
	b.actor_index=1
	b.hp=500
	var healed: Dictionary=hit(b,100)
	check(count_event(healed.events,"heal")==1 and b.hp>500-190,"ハヤフリ回復")
	b=fresh()
	b.actor_index=2
	check(count_event(hit(b,100).events,"guard")==1,"ハヤフリ防御")
	b=fresh()
	b.actor_index=3
	check(count_event(hit(b,100).events,"rally")==1,"ハヤフリ支援")
	# 部位は本体と分離。角気絶・腕弱体・破壊一度のみ。
	b=fresh()
	check(not b.choose_target(0,"unknown"),"未知部位拒否")
	check(b.choose_target(0,"horn"),"角選択")
	var before: int=b.enemies[0].hp
	var part_hit: Dictionary=hit(b)
	check(b.enemies[0].parts[0].hp==118 and b.enemies[0].hp==before-35,"本体と部位耐久を分離")
	var broken: Dictionary=hit(b)
	# 二人目砕→砕104点、三人目突→砕は84点。
	if b.enemies[0].parts[0].hp>0: broken=hit(b)
	check(count_event(broken.events,"part_break")==1,"角破壊イベント")
	check(b.enemies[0].stun==1 and broken.retaliation==0,"角破壊時に気絶・反撃中止")
	check(not b.choose_target(0,"horn"),"破壊済み選択拒否")
	check(hit(b).retaliation==0 and b.enemies[0].stun==0,"次行動まで気絶")
	check(hit(b).retaliation==190,"気絶終了")
	b=fresh()
	b.enemies[0].parts[1].hp=1
	b.choose_target(0,"left_arm")
	var arm: Dictionary=hit(b)
	check(arm.retaliation==123 and is_equal_approx(b.enemies[0].attack_scale,0.65),"腕破壊で反撃弱体化")
	check(count_event(hit(b).events,"part_break")==0,"破壊重複なし")
	# 相性3すくみ。方向は仮値だが行列が有効。
	for attr in ["斬","砕","突"]:
		check(d.balance.attributes[attr][attr]==1.0,"同属性中立")
	b=fresh()
	check(hit(b).damage==142,"有利1.5倍を適用")
	b=fresh()
	b.actor_index=2
	check(hit(b).damage==84,"不利0.75倍を適用")
	# ムスヒ：条件、タイマー、誤答上限、戻り、再発動・二重入力。
	b=fresh()
	check(not b.start_musuhi(d.boolean_questions,0),"ゲージ不足")
	b.gauge=5
	check(not b.start_musuhi([],0) and b.gauge==5,"空問題は開始せずゲージ保持")
	check(b.start_musuhi(d.boolean_questions,1000) and b.gauge==0,"ムスヒ開始と消費")
	check(not b.begin_question(d.questions[0],1001) and not b.choose_target(0),"専用モード中は通常入力拒否")
	var correct_index: int=b.current_question.answer
	check(b.answer_musuhi(correct_index,1100).correct,"○×正答")
	check(not b.answer_musuhi(correct_index,1100).accepted,"フィードバック中の二重入力拒否")
	check(b.next_musuhi(1200),"次問へ")
	var first_wrong: Dictionary=b.answer_musuhi(1-int(b.current_question.answer),1300)
	check(not first_wrong.finished and b.musuhi_mistakes==1,"誤答1回継続")
	b.next_musuhi(1400)
	var second_wrong: Dictionary=b.answer_musuhi(1-int(b.current_question.answer),1500)
	check(second_wrong.finished and b.status=="scrolls","2回目誤答終了・通常へ")
	check(second_wrong.damage==282,"正答数に応じた追加攻撃")
	check(not b.finish_musuhi(22000).accepted,"終了攻撃の重複防止")
	check(not b.start_musuhi(d.boolean_questions,22000),"ゲージ消費済み")
	b=fresh()
	b.gauge=5
	b.start_musuhi(d.boolean_questions,1000)
	check(not b.finish_musuhi(20999).accepted,"期限直前に勝手に終了できない")
	var expired: Dictionary=b.answer_musuhi(b.current_question.answer,21000)
	check(expired.finished and expired.damage==0 and b.musuhi_correct==0,"期限ちょうど回答不可・0正解0ダメージ")
	b=fresh()
	b.gauge=5
	b.start_musuhi(d.boolean_questions,0)
	b.answer_musuhi(b.current_question.answer,100)
	var end: Dictionary=b.finish_musuhi(20000)
	check(end.finished and end.damage>0 and b.status=="scrolls","フィードバック中でも時間切れ終了")
	# 最終敵撃破後、追撃やタマフリ・ムスヒを発動しない。
	b=fresh()
	b.enemies[0].hp=1
	var killed: Dictionary=hit(b,10)
	check(b.status=="won" and count_event(killed.events,"followup")==0,"撃破後追撃なし")
	check(not b.use_tamafuri(0).accepted and not b.can_musuhi(),"勝利後の技入力拒否")
	# setupで一時バフ、ゲージ、ポイントをすべて初期化する。
	b.setup(d.mitama.slice(0,4),d.missions[2],d.oni,d.balance,1,d.effects.definitions)
	check(b.gauge==0 and b.points==[0,0,0,0] and b.guard_multiplier==1.0 and b.rally_hits==0,"再出陣の初期化")
	print("PHASE 2 TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
