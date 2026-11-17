extends SceneTree
## 固定seed・仮の行動規則による比較。人間の面白さを測るものではない。
const Battle = preload("res://scripts/battle.gd")
func _initialize() -> void:
	var data := {}
	for name in ["balance","mitama","oni","missions","effects","questions"]:
		data[name]=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name+".json"))
	var rng := RandomNumberGenerator.new()
	rng.seed=991122
	for mission_index in [0,1,2,4]:
		for accuracy in [0.65,0.85]:
			var won:=0
			var total_turns:=0
			for sample in range(200):
				var battle=Battle.new()
				battle.setup(data.mitama.slice(0,4),data.missions[mission_index],data.oni,data.balance,sample,data.effects.definitions)
				var turn:=0
				while battle.status=="scrolls" and turn<60:
					if battle.can_tamafuri(1) and battle.hp<battle.max_hp*0.65: battle.use_tamafuri(1)
					if battle.can_tamafuri(0): battle.use_tamafuri(0)
					if battle.status!="scrolls": break
					if battle.enemies[battle.target_index].get("large",false):
						for part in battle.enemies[battle.target_index].get("parts",[]):
							if part.id=="horn" and part.hp>0: battle.choose_target(battle.target_index,"horn")
					var q: Dictionary=data.questions[0].duplicate(true)
					q.difficulty=1
					battle.begin_question(q,0)
					var answer: int=q.answer if rng.randf()<accuracy else -1
					battle.resolve_answer(answer,3500 if rng.randf()<0.45 else 7000)
					turn+=1
				if battle.status=="won": won+=1
				total_turns+=turn
			print("%s accuracy=%.2f wins=%d/200 avg_turns=%.1f" % [data.missions[mission_index].id,accuracy,won,total_turns/200.0])
	quit()
