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
	check(drawn==50,"50体に創作肖像")
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
	check(d.effects.definitions[d.mitama[49].tamafuri].kind=="heal_guard","微生物学者は回復と防御")
	for index in [0,29,49]:
		var member: Dictionary=d.mitama[index]
		battle.setup([member],d.missions[2],d.oni,d.balance,44,d.effects.definitions)
		battle.hp=int(battle.max_hp/2)
		var original_hp: int=battle.hp
		var original_enemy: int=battle.enemies[0].hp
		var cost: int=int(d.effects.definitions[member.tamafuri].cost)
		battle.points[0]=cost-1
		check(not battle.use_tamafuri(0).accepted and battle.points[0]==cost-1,"複合技のポイント不足: "+member.name)
		battle.points[0]=cost
		var used: Dictionary=battle.use_tamafuri(0)
		check(used.accepted and battle.points[0]==0,"複合技の消費: "+member.name)
		if index==0:
			check(battle.enemies[0].hp<original_enemy and is_equal_approx(battle.guard_multiplier,0.6),"八重の攻撃と守り")
		elif index==29:
			check(battle.enemies[0].hp<original_enemy and battle.rally_hits==3 and is_equal_approx(battle.rally_multiplier,1.4),"秀吉の攻撃と支援")
		else:
			check(battle.hp>original_hp and is_equal_approx(battle.guard_multiplier,0.65),"北里の回復と守り")
	print("HISTORY SKILLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
