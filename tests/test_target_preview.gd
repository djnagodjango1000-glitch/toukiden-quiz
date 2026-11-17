extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var data := {}
	for name in ["balance","mitama","oni","missions","effects","questions"]:
		data[name] = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name+".json"))
	var battle = Battle.new()
	battle.setup(data.mitama.slice(0,4),data.missions[2],data.oni,data.balance,77,data.effects.definitions)
	var actor: Dictionary = battle.party[0]
	check(battle.choose_target(0,"left_arm"),"部位の選択")
	check(battle.target_attribute()=="突","部位属性が鬼本体より優先")
	var before_part: int = battle.enemies[0].parts[1].hp
	var before_body: int = battle.enemies[0].hp
	var prediction: Dictionary = battle.preview_strike(actor,1.0)
	check(is_equal_approx(prediction.affinity,0.75),"不利相性を予測に反映")
	check(battle.enemies[0].hp==before_body and battle.enemies[0].parts[1].hp==before_part,"予測は状態を変えない")
	var events := []
	battle._strike(actor,1.0,events,"attack")
	check(before_part-battle.enemies[0].parts[1].hp==prediction.part_damage,"部位予測と実ダメージ")
	check(before_body-battle.enemies[0].hp==prediction.body_damage,"本体予測と実ダメージ")
	check(battle.choose_target(0,"right_arm"),"別属性の部位を選択")
	check(battle.target_attribute()=="斬" and is_equal_approx(battle.preview_strike(actor,1.0).affinity,1.0),"選択変更で相性更新")
	check(battle.choose_target(0,"body") and battle.target_attribute()=="砕","本体属性へ復帰")
	battle.rally_multiplier=1.6
	battle.rally_hits=1
	prediction=battle.preview_strike(actor,1.4)
	check(battle.rally_hits==1,"予測は強化残数を消費しない")
	before_body=battle.enemies[0].hp
	battle._strike(actor,1.4,[],"attack")
	check(before_body-battle.enemies[0].hp==prediction.body_damage and battle.rally_hits==0,"強化と難易度を実ダメージへ反映")
	# 属性省略時は鬼本体の属性を使い、過去のデータも扱う。
	battle.enemies[0].parts[0].erase("attribute")
	check(battle.choose_target(0,"horn") and battle.target_attribute()=="砕","属性省略時の後方互換")
	battle.enemies[0].parts[0].hp=1
	prediction=battle.preview_strike(actor,1.0)
	check(prediction.part_damage==1,"残耐久を超える予測を抑える")
	battle._strike(actor,1.0,[],"attack")
	check(battle.target_part=="body" and battle.target_attribute()=="砕","破壊後は本体を選択")
	# 追加任務は2連戦を終えるまで勝利せず、報酬は同じreceiptで重複しない。
	var mission: Dictionary=data.missions[5]
	battle.setup(data.mitama.slice(0,4),mission,data.oni,data.balance,77,data.effects.definitions)
	check(battle.enemies.size()==2 and battle.wave_index==0,"連戦の初戦")
	for enemy in battle.enemies: enemy.hp=0
	battle._settle([],false)
	check(battle.status=="scrolls" and battle.wave_index==1 and battle.enemies[0].id=="boss","小鬼討伐後に大型鬼へ")
	battle.enemies[0].hp=0
	battle._settle([],false)
	check(battle.status=="won","最終戦討伐で任務達成")
	var store=preload("res://scripts/save_store.gd").new()
	var state: Dictionary=store.initial()
	var paid: Dictionary=store.reward(state,mission,"new-mission")
	check(paid.haku==500 and paid.orbs==1 and paid.material==2,"追加任務の初回報酬")
	var repeated: Dictionary=store.reward(paid,mission,"new-mission")
	check(repeated.haku==500 and repeated.orbs==1 and repeated.material==2,"報酬の二重付与防止")
	print("TARGET PREVIEW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
