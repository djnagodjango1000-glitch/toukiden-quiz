extends SceneTree
const Progression=preload("res://scripts/progression.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var members: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/mitama.json"))
	var progression=Progression.new(rules,members)
	var store=Store.new()
	store.base_path="user://rarity_test_%d.json" % Time.get_ticks_usec()
	var old: Dictionary=store.initial()
	old.schema_version=1
	old.haku=5000
	old["material"]=40
	old["levels"]={"m01":9}
	old["evolutions"]={"m01":2}
	old["deck"]=["m01","m02"]
	old.cleared=["trial01"]
	var file:=FileAccess.open(store.base_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var restored: Dictionary=store.load_save()
	check(restored.schema_version==2 and store._read(store.base_path).schema_version==1,"旧データは読み込み時に書き換えない")
	check(restored.haku==5000 and restored.material==40 and restored.deck==old.deck and int(restored.levels.m01)==9 and int(restored.evolutions.m01)==2 and restored.cleared==old.cleared,"所持・編成・育成・進行を保持")
	check(progression.rarity("m01",2)==3,"旧進化2段階を★3に対応")
	check(store.persist(restored),"新形式を保存")
	check(store._read(store.base_path).schema_version==2 and store._read(store.base_path+".bak").schema_version==1,"旧データのバックアップを維持")
	check(progression.valid_backup(restored),"移行データの妥当性")
	var state:=restored.duplicate(true)
	var expected_haku:=5000
	var expected_material:=40
	for stage in range(2,6):
		var requirement: Dictionary=progression.evolution_requirements("m01",stage)
		expected_haku-=int(requirement.haku)
		expected_material-=int(requirement.material)
		var next: Dictionary=progression.evolve(state,"m01")
		check(not next.is_empty() and int(next.evolutions.m01)==stage+1,"各段階の進化")
		check(int(next.haku)==expected_haku and int(next.material)==expected_material,"段階別コスト")
		state=next
	check(progression.rarity("m01",6)==7 and progression.evolution_requirements("m01",6).is_empty(),"★7で上限")
	check(progression.evolve(state,"m01").is_empty(),"★8への進化を拒否")
	check(progression.valid_backup(state),"★7のバックアップを検証")
	check(store.persist(state),"★7の保存")
	var reloaded: Dictionary=store.load_save()
	check(int(reloaded.evolutions.m01)==6 and progression.rarity("m01",int(reloaded.evolutions.m01))==7,"★7を再起動後に復元")
	var interrupted:=FileAccess.open(store.base_path+".tmp",FileAccess.WRITE)
	interrupted.store_string("{broken")
	interrupted.close()
	check(int(store.load_save().evolutions.m01)==6,"中断した一時ファイルは有効なセーブを壊さない")
	var denied:=restored.duplicate(true)
	denied.levels.m01=5
	check(progression.evolve(denied,"m01").is_empty(),"段階別レベル条件を検証")
	denied=restored.duplicate(true)
	denied.haku=0
	check(progression.evolve(denied,"m01").is_empty(),"費用不足で消費しない")
	state.evolutions.m01=7
	check(not progression.valid_backup(state),"★7を超える不正データを拒否")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(store.base_path+suffix)
	print("RARITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
