extends SceneTree
const Pool = preload("res://scripts/quiz_pool.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
func check(condition: bool, description: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",description)
func _initialize() -> void:
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
	var random := RandomNumberGenerator.new()
	random.seed=1919
	var recent: Array=[]
	for i in range(25):
		var offered: Array=Pool.scrolls(all,4,random,recent)
		check(offered.size()==4,"巻物数")
		var genres: Array=[]
		for q in offered:
			check(not q.genre in genres,"違うジャンルを優先")
			genres.append(q.genre)
			var choices_in_genre: Array=all.filter(func(x):return x.genre==q.genre)
			var fresh: Array=choices_in_genre.filter(func(x):return not x.id in recent)
			if not fresh.is_empty(): check(not q.id in recent,"未出題があるジャンルは直近を回避")
		var selected: Dictionary=offered[0]
		recent.append(selected.id)
		if recent.size()>30: recent.pop_front()
	var subset: Array = all.slice(0,3)
	var exhausted: Array=[]
	for q in subset: exhausted.append(q.id)
	check(Pool.scrolls(subset,4,random,exhausted).size()==3,"候補が尽きた時は再出題")
	var store=Store.new()
	var state: Dictionary=store.initial()
	var missions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
	var clean: Dictionary=store.reward(state,missions[0],"one",1,3,true)
	check(clean.haku==150,"全問正解ボーナス")
	check(store.reward(clean,missions[0],"one",1,3,true).haku==150,"報酬二重付与防止")
	check(store.reward(state,missions[0],"miss",1,3,false).haku==100,"誤答ありでは通常報酬")
	print("EXPERIENCE TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
