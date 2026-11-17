extends SceneTree
const Battle=preload("res://scripts/battle.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var d:={}
	for name in ["mitama","effects","balance","missions","oni","questions"]:
		d[name]=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name+".json"))
	var actor: Dictionary=d.mitama[3]
	var q: Dictionary=d.questions[0]
	var b=Battle.new()
	b.setup([actor],d.missions[2],d.oni,d.balance,777,d.effects.definitions)
	check(not b.can_tamafuri(0),"ポイント不足")
	b.points[0]=4
	var activation: Dictionary=b.use_tamafuri(0)
	check(activation.accepted and b.points[0]==0 and b.pending_choice_reduction==2,"補助発動と消費")
	b.points[0]=4
	check(not b.use_tamafuri(0).accepted and b.points[0]==4,"使用待ちの重複拒否")
	check(b.begin_question(q,1000),"出題開始")
	check(b.visible_answer_indices.size()==2 and int(q.answer) in b.visible_answer_indices,"正答を残し2択にする")
	check(b.pending_choice_reduction==0,"問題開始時に補助を消費")
	var hidden:=-1
	for i in range(4):
		if not i in b.visible_answer_indices: hidden=i
	check(not b.resolve_answer(hidden,1100).accepted and b.status=="question","非表示の選択肢を拒否")
	check(b.resolve_answer(int(q.answer),1500).correct,"正答の元インデックスを維持")
	check(b.begin_question(q,3000) and b.visible_answer_indices.size()==4,"次の問題は通常の四択")
	var t=b.resolve_answer(-1,23000)
	check(t.accepted and not t.correct,"時間切れでも安全に処理")
	b.setup([actor],d.missions[2],d.oni,d.balance,777,d.effects.definitions)
	b.points[0]=4
	b.use_tamafuri(0)
	b.begin_question(q,1000)
	var first: Array=b.visible_answer_indices.duplicate()
	var b2=Battle.new()
	b2.setup([actor],d.missions[2],d.oni,d.balance,777,d.effects.definitions)
	b2.points[0]=4
	b2.use_tamafuri(0)
	b2.begin_question(q,1000)
	check(b2.visible_answer_indices==first,"固定乱数で再現")
	b2.setup([actor],d.missions[2],d.oni,d.balance,1,d.effects.definitions)
	check(b2.pending_choice_reduction==0 and b2.visible_answer_indices.is_empty(),"再出陣で補助状態を初期化")
	print("QUIZ ASSIST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
