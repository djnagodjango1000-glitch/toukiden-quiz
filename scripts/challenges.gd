extends RefCounted
## 独自の仮条件。時間は通常4択の回答開始から決定・時間切れまで。
static func evaluate(challenges: Array, correct: int, answered: int, total_ms: int, max_streak: int) -> Array:
	var result: Array = []
	for challenge in challenges:
		var met := false
		if answered > 0:
			match str(challenge.get("type", "")):
				"accuracy": met = correct * 100 >= int(challenge.threshold) * answered
				"average_ms": met = total_ms <= int(challenge.threshold) * answered
				"streak": met = max_streak >= int(challenge.threshold)
		result.append({"id":challenge.id,"label":challenge.label,"met":met,"reward_haku":int(challenge.reward_haku)})
	return result

static func reward(results: Array) -> int:
	var total := 0
	for item in results:
		if item.met: total += maxi(0,int(item.reward_haku))
	return total
