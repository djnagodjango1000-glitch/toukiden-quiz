extends SceneTree
const Store = preload("res://scripts/save_store.gd")
const Progression = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var members: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/mitama.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var effects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/effects.json"))
	var expected := ["新島八重","清少納言","世阿弥","聖徳太子","足利尊氏","土方歳三","北条政子","菅原道真","紫式部","源義経","推古天皇","杉田玄白","織田信長","伊達政宗","和泉式部","坂本龍馬","卑弥呼","天智天皇","天武天皇","持統天皇","小野妹子","柿本人麻呂","藤原道長","藤原定家","平清盛","源頼朝","木曽義仲","足利義満","雪舟","豊臣秀吉","徳川家康","真田幸村","上杉謙信","武田信玄","毛利元就","明智光秀","石田三成","前田利家","直江兼続","加藤清正","お市の方","千利休","宮本武蔵","葛飾北斎","伊能忠敬","松尾芭蕉","西郷隆盛","吉田松陰","勝海舟","北里柴三郎"]
	expected.append_array(["沖田総司","中野竹子","藤堂高虎","新田義貞","平将門","源頼光","北条早雲","中岡慎太郎","本居宣長","井伊直弼"])
	check(members.size()==60 and expected.size()==60,"歴史人物60体")
	var seen := []
	for i in range(members.size()):
		var m: Dictionary = members[i]
		check(m.name==expected[i] and m.id=="m%02d" % (i+1),"人物とIDの対応")
		check(not m.name in seen,"人物名の重複なし")
		seen.append(m.name)
		check(effects.definitions.has(m.hayafuri) and effects.definitions.has(m.tamafuri),"技が存在")
	var store=Store.new()
	store.base_path="user://legacy_50_%d.json" % Time.get_ticks_usec()
	var old: Dictionary=store.initial()
	old.owned=["m01","m11","m12"]
	old["deck"]=["m11","m12"]
	old["levels"]={"m11":7,"m12":6}
	old["evolutions"]={"m11":1,"m12":2}
	old["haku"]=999
	check(store.persist(old),"旧ミタマを含むセーブ保存")
	var loaded: Dictionary=store.load_save()
	var progression=Progression.new(rules,members)
	check(progression.valid_backup(loaded),"旧セーブを新カタログで検証")
	check(loaded.owned==old.owned and loaded.deck==old.deck and int(loaded.levels.m11)==7 and int(loaded.levels.m12)==6 and int(loaded.evolutions.m11)==1 and int(loaded.evolutions.m12)==2 and int(loaded.haku)==999,"所持・編成・育成・通貨を保持")
	check(progression.find_member("m11").name=="推古天皇" and progression.find_member("m12").name=="杉田玄白","同じIDで歴史人物に置換")
	var all_state: Dictionary=store.initial()
	all_state.owned=[]
	for m in members: all_state.owned.append(m.id)
	check(progression.valid_backup(all_state),"60体所持のバックアップ")
	var rewarded: Dictionary=progression.claim_collection(all_state,50)
	check(rewarded.haku==3000 and progression.claim_collection(rewarded,50).is_empty(),"50体の事典報酬と重複防止")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(store.base_path+suffix)
	print("50 MITAMA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
