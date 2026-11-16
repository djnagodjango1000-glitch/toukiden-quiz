extends RefCounted
## UIに依存しないPhase 1戦闘。経過時間と乱数seedを外から渡す。

var config: Dictionary
var party: Array
var enemies: Array = []
var waves: Array
var wave_index := 0
var actor_index := 0
var hp := 0
var max_hp := 0
var correct := 0
var answered := 0
var status := "idle"
var target_index := 0
var current_question: Dictionary = {}
var question_started_ms := 0
var rng := RandomNumberGenerator.new()

func setup(members: Array, mission: Dictionary, oni: Array, balance: Dictionary, seed_value: int) -> void:
	config = balance.duplicate(true)
	party = members.duplicate(true)
	party.sort_custom(func(a, b):
		if a.speed == b.speed: return a.id < b.id
		return a.speed > b.speed)
	waves = []
	for ids in mission.waves:
		var wave: Array = []
		for id in ids:
			for enemy in oni:
				if enemy.id == id: wave.append(enemy.duplicate(true))
		waves.append(wave)
	hp = 0
	for member in party: hp += int(member.hp)
	max_hp = hp
	wave_index = 0
	actor_index = 0
	correct = 0
	answered = 0
	rng.seed = seed_value
	_load_wave()

func _load_wave() -> void:
	enemies = waves[wave_index].duplicate(true)
	target_index = 0
	status = "scrolls"

func choose_target(index: int) -> bool:
	if status != "scrolls" or index < 0 or index >= enemies.size() or enemies[index].hp <= 0: return false
	target_index = index
	return true

func begin_question(question: Dictionary, now_ms: int) -> bool:
	if status != "scrolls": return false
	current_question = question.duplicate(true)
	question_started_ms = now_ms
	status = "question"
	return true

func remaining_ms(now_ms: int) -> int:
	return maxi(0, int(config.question_time_ms) - maxi(0, now_ms - question_started_ms))

func resolve_answer(selection: int, now_ms: int) -> Dictionary:
	if status != "question": return {"accepted": false}
	var elapsed := maxi(0, now_ms - question_started_ms)
	# 締切ちょうどで回答不可。UI・モデルの両方が同じ境界を使う。
	var success: bool = elapsed < int(config.question_time_ms) and selection == int(current_question.answer)
	answered += 1
	var damage := 0
	var retaliation := 0
	var actor: Dictionary = party[actor_index]
	if success:
		correct += 1
		var enemy: Dictionary = enemies[target_index]
		var multiplier: float = float(config.difficulty_multipliers[str(int(current_question.difficulty))])
		var affinity: float = float(config.attributes[actor.attribute][enemy.attribute])
		damage = maxi(1, int(floor(float(actor.attack) * multiplier * affinity)))
		enemy.hp = maxi(0, int(enemy.hp) - damage)
	var alive := false
	for enemy in enemies:
		if enemy.hp > 0: alive = true
	if not alive:
		wave_index += 1
		if wave_index >= waves.size(): status = "won"
		else: _load_wave()
	else:
		for enemy in enemies:
			if enemy.hp > 0: retaliation += int(enemy.attack)
		hp = maxi(0, hp - retaliation)
		status = "lost" if hp == 0 else "scrolls"
		if enemies[target_index].hp <= 0:
			for i in range(enemies.size()):
				if enemies[i].hp > 0:
					target_index = i
					break
	actor_index = (actor_index + 1) % party.size()
	return {"accepted": true, "correct": success, "damage": damage, "retaliation": retaliation,
		"actor": actor.name, "elapsed_ms": elapsed, "status": status,
		"answer": current_question.options[int(current_question.answer)], "explanation": current_question.explanation}
