extends SceneTree
const Progression = preload("res://scripts/progression.gd")
const Store = preload("res://scripts/save_store.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",msg)
func _initialize() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var members: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/mitama.json"))
	var missions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
	var p = Progression.new(cfg,members)
	var store = Store.new()
	var state: Dictionary = store.initial()
	check(p.team_cost(state.owned)==8,"初期コスト")
	check(p.change_deck(state,"m05").is_empty(),"未所持拒否")
	check(p.change_deck(state,"m01").deck.size()==3 and not state.has("deck"),"編成変更と元データ不変")
	var tmp: Dictionary=state.duplicate(true)
	tmp.owned.append("m05")
	var strict: Dictionary=cfg.duplicate(true)
	strict.team_cost_limit=8
	var limited=Progression.new(strict,members)
	tmp.deck=["m01","m02","m03","m04"]
	check(limited.change_deck(tmp,"m05").is_empty(),"人数上限")
	tmp.deck=["m01","m02","m03"]
	strict.team_cost_limit=6
	check(limited.change_deck(tmp,"m05").is_empty(),"コスト上限")
	check(p.evolve(state,"m01").is_empty(),"進化条件不足")
	tmp=state.duplicate(true)
	tmp["levels"]={"m01":5}
	tmp["haku"]=250
	tmp["material"]=2
	var evolved: Dictionary=p.evolve(tmp,"m01")
	check(evolved.evolutions.m01==1 and evolved.haku==0 and evolved.material==0,"進化と素材消費")
	check(tmp.haku==250 and tmp.material==2,"進化元は変更されない")
	check(p.evolve(evolved,"m01").is_empty(),"素材不足拒否")
	var rewarded: Dictionary=p.claim_collection(state,4)
	check(rewarded.haku==100 and rewarded.collection_claimed.has("4"),"事典報酬")
	check(p.claim_collection(rewarded,4).is_empty(),"事典報酬の二重受取禁止")
	check(p.claim_collection(state,6).is_empty(),"事典登録数不足")
	check(p.energy_state(state,1000).amount==30,"初期行動力")
	var entered: Dictionary=p.enter_mission(state,missions[0],1000)
	check(entered.energy==27 and entered.energy_updated==1000,"任務で消費")
	check(p.energy_state(entered,1299).amount==27,"5分未満回復しない")
	check(p.energy_state(entered,1600).amount==29,"10分で2回復")
	check(p.energy_state(entered,500).amount==27,"時計逆行は回復しない")
	entered.energy=1
	check(p.enter_mission(entered,missions[0],1000).is_empty(),"不足では出陣不可")
	entered.settings.free_play=true
	check(not p.enter_mission(entered,missions[0],1000).is_empty(),"自由プレイでは消費なし")
	check(p.valid_backup(state),"旧形式バックアップ検証")
	tmp=state.duplicate(true)
	tmp["deck"]=["m01","m01"]
	check(not p.valid_backup(tmp),"重複編成拒否")
	tmp=state.duplicate(true)
	tmp["levels"]={"m01":-1}
	check(not p.valid_backup(tmp),"不正レベル拒否")
	tmp=state.duplicate(true)
	tmp.owned.append("unknown")
	check(not p.valid_backup(tmp),"未知ミタマ拒否")
	var s = Store.new()
	s.base_path="user://phase3progress_%d.json" % Time.get_ticks_usec()
	check(s.persist(evolved),"進化結果保存")
	check(s.load_save().evolutions.m01==1,"進化結果復元")
	var first: Dictionary=s.reward(evolved,missions[0],"unique")
	check(first.material==1 and s.reward(first,missions[0],"unique").material==1,"素材報酬重複防止")
	check(first.orbs==1 and s.reward(first,missions[0],"another").orbs==1,"宝玉は初回達成のみ")
	check(not s.reward(evolved,missions[3],"training").has("orbs"),"修練で宝玉を配布しない")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(s.base_path+suffix)
	print("PROGRESSION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
