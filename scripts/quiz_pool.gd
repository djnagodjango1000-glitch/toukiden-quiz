extends RefCounted
## ジャンル数の差で巻物が偏らないよう、最初に異なるジャンルを選ぶ。
static func scrolls(questions: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var buckets := {}
	for q in questions:
		if q.get("type") != "choice": continue
		var genre: String = q.get("genre", "")
		if not buckets.has(genre): buckets[genre] = []
		buckets[genre].append(q)
	var names := buckets.keys()
	var chosen: Array = []
	var used: Array = []
	while chosen.size()<count and not names.is_empty():
		var position := rng.randi_range(0,names.size()-1)
		var genre: String = names.pop_at(position)
		var pool: Array = buckets[genre]
		var q: Dictionary = pool[rng.randi_range(0,pool.size()-1)]
		chosen.append(q)
		used.append(q.id)
	if chosen.size()<count:
		var remaining: Array = []
		for q in questions:
			if q.get("type")=="choice" and not q.id in used: remaining.append(q)
		while chosen.size()<count and not remaining.is_empty():
			chosen.append(remaining.pop_at(rng.randi_range(0,remaining.size()-1)))
	return chosen
