extends SceneTree
const Challenges = preload("res://scripts/challenges.gd")
const Battle = preload("res://scripts/battle.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",text)
func _initialize() -> void:
	var d: Dictionary = {}
	for n in ["challenges","mitama","missions","oni","balance","effects","questions"]:
		d[n] = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+n+".json"))
	var entries: Array = d.challenges.trial05
	var none := Challenges.evaluate(entries,0,0,0,0)
	check(Challenges.reward(none)==0,"未回答はすべて未達成")
	var exact := Challenges.evaluate(entries,4,5,50000,3)
	check(exact.all(func(x): return x.met),"各条件の境界は達成")
	check(Challenges.reward(exact)==130,"報酬を合算")
	var missed := Challenges.evaluate(entries,3,5,50001,2)
	check(missed.all(func(x): return not x.met),"各条件の境界外は未達成")
	var store := SaveStore.new()
	var original := store.initial()
	var paid := store.reward(original,d.missions[0],"unique",1,3,false,20)
	check(paid.haku==120,"基本報酬と挑戦報酬を加算")
	check(store.reward(paid,d.missions[0],"unique",1,3,false,20).haku==120,"再表示では二重支給しない")
	var b := Battle.new()
	var enemies: Array = d.oni.duplicate(true)
	for enemy in enemies:
		if enemy.id=="boss": enemy.hp=999999
	b.setup(d.mitama.slice(0,4),d.missions[2],enemies,d.balance,1,d.effects.definitions)
	b.begin_question(d.questions[0],1000)
	b.resolve_answer(int(d.questions[0].answer),3000)
	check(b.answered==1 and b.total_answer_ms==2000 and b.max_streak==1,"正解時間と連続正解を計測")
	b.begin_question(d.questions[0],4000)
	b.resolve_answer(-1,29000)
	check(b.total_answer_ms==22000 and b.max_streak==1 and b.streak==0,"時間切れは制限時間まで計測し連続を維持しない")
	b.setup(d.mitama.slice(0,4),d.missions[2],enemies,d.balance,1,d.effects.definitions)
	check(b.total_answer_ms==0 and b.max_streak==0,"再出陣で計測を初期化")
	for mission_id in d.challenges:
		check(d.missions.any(func(m): return m.id==mission_id),"目標の任務IDが存在")
	print("CHALLENGES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
