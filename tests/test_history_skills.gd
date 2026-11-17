extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var d := {}
	for name in ["mitama","effects","balance","missions","oni"]:
		d[name]=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name+".json"))
	var seen_hay := []
	var seen_tama := []
	var drawn := 0
	for m in d.mitama:
		check(not m.hayafuri in seen_hay and not m.tamafuri in seen_tama,"技IDは人物ごと")
		seen_hay.append(m.hayafuri)
		seen_tama.append(m.tamafuri)
		check(not m.historical_fact.is_empty() and m.historical_source.begins_with("https://"),"人物の紹介と出典")
		check(d.effects.definitions.has(m.hayafuri) and d.effects.definitions.has(m.tamafuri),"技の参照")
		if m.art!="generic_placeholder": drawn += 1
		var trial=Battle.new()
		trial.setup([m],d.missions[2],d.oni,d.balance,44,d.effects.definitions)
		trial.hp=int(trial.max_hp/2)
		var cost: int=int(d.effects.definitions[m.tamafuri].cost)
		trial.points[0]=cost
		var used: Dictionary=trial.use_tamafuri(0)
		check(used.accepted and trial.points[0]==0 and trial.hp<=trial.max_hp,"人物別タマフリが発動: "+m.name)
	check(drawn==27,"27体に創作肖像")
	var musashi: Dictionary=d.mitama[42]
	check(musashi.name=="宮本武蔵" and "二刀" in musashi.historical_fact,"二天一流の紹介")
	check(d.effects.definitions[musashi.tamafuri].kind=="multi_attack","武蔵の二回攻撃")
	var battle=Battle.new()
	battle.setup([musashi],d.missions[2],d.oni,d.balance,44,d.effects.definitions)
	battle.points[0]=4
	var before: int=battle.enemies[0].hp
	var result: Dictionary=battle.use_tamafuri(0)
	var hits:=0
	for event in result.events:
		if event.type=="skill_attack": hits+=1
	check(result.accepted and battle.points[0]==0 and hits==2,"二回攻撃の発動・消費・表示")
	check(before-battle.enemies[0].hp==result.damage and result.damage>0,"二回攻撃の合計ダメージ")
	check(d.effects.definitions[d.mitama[11].tamafuri].kind=="heal","蘭学医は回復技")
	check(d.effects.definitions[d.mitama[49].tamafuri].kind=="heal","微生物学者は回復技")
	print("HISTORY SKILLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
