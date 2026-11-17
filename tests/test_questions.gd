extends SceneTree
const Pool = preload("res://scripts/quiz_pool.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",msg)
func _initialize() -> void:
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
	var tf: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/boolean_questions.json"))
	var ids: Array=[]
	var categories: Array=[]
	for q in all+tf:
		check(not q.id in ids,"問題ID重複")
		ids.append(q.id)
		var size: int = 4 if q.type=="choice" else 2
		check(q.options.size()==size and int(q.answer)>=0 and int(q.answer)<size,"選択肢の形式")
		check(q.options.duplicate().all(func(x):return x is String and not x.is_empty()),"選択肢の空欄")
		var seen: Array=[]
		for option in q.options:
			check(not option in seen,"選択肢の重複")
			seen.append(option)
		check(not q.text.is_empty() and not q.source.is_empty() and q.has("checked_at"),"出典フィールド")
		if q.type=="choice" and not q.genre in categories: categories.append(q.genre)
	check(all.size()>=100 and tf.size()>=30,"初期収録数")
	check(categories.size()==7,"クイズ7ジャンル")
	var first=RandomNumberGenerator.new()
	first.seed=42
	var second=RandomNumberGenerator.new()
	second.seed=42
	var sample: Array=Pool.scrolls(all,4,first)
	check(sample==Pool.scrolls(all,4,second),"固定乱数での再現")
	var genres: Array=[]
	for q in sample:
		check(not q.genre in genres,"巻物のジャンルが重複しない")
		genres.append(q.genre)
	var small: Array=Pool.scrolls([all[0]],4,first)
	check(small.size()==1,"問題不足時にも例外なし")
	print("QUESTION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
