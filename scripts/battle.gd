extends RefCounted
## UI非依存の戦闘状態機械。時間は呼出側からmsで注入する。
var config: Dictionary
var effects: Dictionary = {}
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
var target_part := "body"
var current_question: Dictionary = {}
var question_started_ms := 0
var pending_choice_reduction := 0
var visible_answer_indices: Array = []
var rng := RandomNumberGenerator.new()
var points: Array = []
var gauge := 0
var streak := 0
var guard_multiplier := 1.0
var rally_multiplier := 1.0
var rally_hits := 0
var musuhi_pool: Array = []
var musuhi_start_ms := 0
var musuhi_correct := 0
var musuhi_mistakes := 0
var musuhi_question_index := 0
var last_musuhi_index := -1

func setup(members: Array, mission: Dictionary, oni: Array, balance: Dictionary, seed_value: int, skill_definitions: Dictionary = {}) -> void:
	config = balance.duplicate(true)
	effects = skill_definitions.duplicate(true)
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
	points = []
	for member in party:
		hp += int(member.hp)
		points.append(0)
	max_hp = hp
	wave_index = 0
	actor_index = 0
	correct = 0
	answered = 0
	gauge = 0
	streak = 0
	pending_choice_reduction = 0
	visible_answer_indices = []
	guard_multiplier = 1.0
	rally_multiplier = 1.0
	rally_hits = 0
	musuhi_pool = []
	last_musuhi_index = -1
	rng.seed = seed_value
	_load_wave()

func _load_wave() -> void:
	enemies = waves[wave_index].duplicate(true)
	for enemy in enemies:
		enemy["stun"] = 0
		enemy["attack_scale"] = 1.0
		for part in enemy.get("parts", []): part["max_hp"] = int(part.hp)
	target_index = 0
	target_part = "body"
	status = "scrolls"

func choose_target(index: int, part_id: String = "body") -> bool:
	if status != "scrolls" or index < 0 or index >= enemies.size() or enemies[index].hp <= 0: return false
	if part_id != "body":
		var found := false
		for part in enemies[index].get("parts", []):
			if part.id == part_id and part.hp > 0: found = true
		if not found: return false
	target_index = index
	target_part = part_id
	return true

func _has_alive() -> bool:
	for enemy in enemies:
		if enemy.hp > 0: return true
	return false

func _ensure_target() -> bool:
	if not _has_alive(): return false
	if enemies[target_index].hp <= 0:
		for i in range(enemies.size()):
			if enemies[i].hp > 0:
				target_index = i
				target_part = "body"
				break
	if target_part != "body":
		for part in enemies[target_index].get("parts", []):
			if part.id == target_part and part.hp <= 0: target_part = "body"
	return true

func begin_question(question: Dictionary, now_ms: int) -> bool:
	if status != "scrolls" or question.get("type", "choice") != "choice": return false
	current_question = question.duplicate(true)
	visible_answer_indices = []
	var wrong: Array = []
	for i in range(current_question.options.size()):
		visible_answer_indices.append(i)
		if i != int(current_question.answer): wrong.append(i)
	var remove_count := mini(pending_choice_reduction, maxi(0,wrong.size()-1))
	for _i in range(remove_count):
		var chosen: int = rng.randi_range(0,wrong.size()-1)
		visible_answer_indices.erase(wrong[chosen])
		wrong.remove_at(chosen)
	pending_choice_reduction = 0
	question_started_ms = now_ms
	status = "question"
	return true

func remaining_ms(now_ms: int) -> int:
	return maxi(0, int(config.question_time_ms) - maxi(0, now_ms - question_started_ms))

func target_attribute() -> String:
	var enemy: Dictionary = enemies[target_index]
	if target_part != "body":
		for part in enemy.get("parts", []):
			if part.id == target_part and int(part.hp) > 0:
				return str(part.get("attribute", enemy.attribute))
	return str(enemy.attribute)

# 巻物選択前に最初の通常攻撃だけを予測。追撃・技・敵の反撃は含めない。
func preview_strike(member: Dictionary, power: float, source: String = "attack") -> Dictionary:
	if enemies.is_empty() or target_index < 0 or target_index >= enemies.size(): return {}
	var enemy: Dictionary = enemies[target_index]
	if int(enemy.hp) <= 0: return {}
	var attribute := target_attribute()
	var affinity := float(config.attributes[member.attribute][attribute])
	var multiplier := rally_multiplier if source in ["attack", "followup"] and rally_hits > 0 else 1.0
	var damage := maxi(1, int(floor(float(member.attack) * power * affinity * multiplier)))
	var part_damage := 0
	var body_damage := damage
	if target_part != "body":
		for part in enemy.get("parts", []):
			if part.id == target_part and int(part.hp) > 0:
				part_damage = mini(int(part.hp), damage)
				body_damage = int(floor(damage * float(config.get("parts", {}).get("body_transfer", 0.25))))
				break
	return {"attribute": attribute, "affinity": affinity, "damage": damage,
		"part_damage": part_damage, "body_damage": mini(int(enemy.hp), body_damage)}

func _strike(member: Dictionary, power: float, events: Array, source: String) -> int:
	if not _ensure_target(): return 0
	var prediction := preview_strike(member, power, source)
	if source in ["attack", "followup"] and rally_hits > 0:
		rally_hits -= 1
	return _apply_damage(int(prediction.damage), events, source, member.name)

func _apply_damage(damage: int, events: Array, source: String, actor: String) -> int:
	if not _ensure_target(): return 0
	var enemy: Dictionary = enemies[target_index]
	var body_damage := damage
	if target_part != "body":
		for part in enemy.get("parts", []):
			if part.id != target_part: continue
			part.hp = maxi(0, int(part.hp) - damage)
			body_damage = int(floor(damage * float(config.get("parts", {}).get("body_transfer", 0.25))))
			events.append({"type": "part_hit", "text": "%s → %s %d" % [actor, part.label, damage], "damage": damage, "part": part.id})
			if part.hp == 0:
				events.append({"type": "part_break", "text": "%s 破壊！" % part.label, "part": part.id})
				enemy.stun = maxi(int(enemy.stun), int(part.get("stun_turns", 0)))
				enemy.attack_scale *= float(part.get("attack_multiplier", 1.0))
				target_part = "body"
			break
	var actual := mini(int(enemy.hp), body_damage)
	enemy.hp = maxi(0, int(enemy.hp) - body_damage)
	events.append({"type": source, "text": "%s → %s %d" % [actor, enemy.name, body_damage], "damage": actual})
	if enemy.hp == 0: events.append({"type": "kill", "text": "鬼を討伐！"})
	return actual

func _effect(skill_id: Variant, member: Dictionary, events: Array) -> int:
	if skill_id == null or not effects.has(skill_id): return 0
	var effect: Dictionary = effects[skill_id]
	match effect.kind:
		"reduce_choices":
			pending_choice_reduction = clampi(int(effect.get("remove_count",2)),1,2)
			events.append({"type":"quiz_help", "text":"次の四択で誤答を%d個減らす" % pending_choice_reduction})
		"attack":
			return _strike(member, float(effect.power), events, "skill_attack")
		"multi_attack":
			var total := 0
			for _i in range(int(effect.hits)):
				if not _has_alive(): break
				total += _strike(member, float(effect.power), events, "skill_attack")
			return total
		"attack_heal":
			var damage := _strike(member, float(effect.power), events, "skill_attack")
			var amount := mini(max_hp-hp, roundi(max_hp*float(effect.fraction)))
			hp += amount
			events.append({"type": "heal", "text": "体力 +%d" % amount, "amount": amount})
			return damage
		"attack_guard":
			var damage := _strike(member, float(effect.power), events, "skill_attack")
			guard_multiplier = minf(guard_multiplier, float(effect.multiplier))
			events.append({"type": "guard", "text": "次の敵行動で被ダメージ軽減"})
			return damage
		"heal_guard":
			var amount := mini(max_hp-hp, roundi(max_hp*float(effect.fraction)))
			hp += amount
			guard_multiplier = minf(guard_multiplier, float(effect.multiplier))
			events.append({"type": "heal", "text": "体力 +%d" % amount, "amount": amount})
			events.append({"type": "guard", "text": "次の敵行動で被ダメージ軽減"})
		"attack_rally":
			var damage := _strike(member, float(effect.power), events, "skill_attack")
			rally_multiplier = float(effect.multiplier)
			rally_hits = int(effect.hits)
			events.append({"type": "rally", "text": "攻撃強化 残り%d撃" % rally_hits})
			return damage
		"heal":
			var amount := mini(max_hp-hp, roundi(max_hp*float(effect.fraction)))
			hp += amount
			events.append({"type": "heal", "text": "体力 +%d" % amount, "amount": amount})
		"guard":
			guard_multiplier = minf(guard_multiplier, float(effect.multiplier))
			events.append({"type": "guard", "text": "次の敵行動で被ダメージ軽減"})
		"rally":
			rally_multiplier = float(effect.multiplier)
			rally_hits = int(effect.hits)
			events.append({"type": "rally", "text": "攻撃強化 残り%d撃" % rally_hits})
	return 0

func _settle(events: Array, retaliate: bool) -> int:
	if not _has_alive():
		wave_index += 1
		if wave_index >= waves.size(): status = "won"
		else: _load_wave()
		return 0
	var retaliation := 0
	if retaliate:
		for enemy in enemies:
			if enemy.hp <= 0: continue
			if enemy.stun > 0:
				enemy.stun -= 1
				events.append({"type": "stun", "text": "%sは気絶中" % enemy.name})
				continue
			var hit := maxi(1, int(floor(float(enemy.attack)*float(enemy.attack_scale)*guard_multiplier)))
			retaliation += hit
			events.append({"type": "enemy_attack", "text": "%sの攻撃 %d" % [enemy.name,hit], "damage": hit})
		hp = maxi(0, hp - retaliation)
		guard_multiplier = 1.0
	status = "lost" if hp == 0 else "scrolls"
	_ensure_target()
	return retaliation

func resolve_answer(selection: int, now_ms: int) -> Dictionary:
	if status != "question": return {"accepted": false}
	if selection != -1 and not selection in visible_answer_indices: return {"accepted": false}
	var elapsed := maxi(0, now_ms - question_started_ms)
	var success: bool = elapsed < int(config.question_time_ms) and selection == int(current_question.answer)
	answered += 1
	var damage := 0
	var events: Array = []
	var actor: Dictionary = party[actor_index]
	var consumed := 1
	var fast: bool = success and config.hayafuri.enabled and elapsed <= int(config.hayafuri.threshold_ms)
	if success:
		correct += 1
		streak += 1
		gauge = mini(int(config.musuhi.gauge_required), gauge+1)
		if config.tamafuri.enabled:
			for i in range(points.size()): points[i] = mini(int(config.tamafuri.get("max_points",15)), int(points[i])+int(config.tamafuri.points_per_correct))
		var power := float(config.difficulty_multipliers[str(int(current_question.difficulty))])
		damage += _strike(actor, power, events, "attack")
		if fast and _has_alive():
			var id: Variant = actor.get("hayafuri")
			if id != null and effects.has(id):
				events.append({"type": "hayafuri", "text": effects[id].label, "actor": actor.name})
				damage += _effect(id, actor, events)
			# 後続一体という人数は暫定。追撃から固有技は再帰発動しない。
			var followups := mini(int(config.hayafuri.get("followup_count",1)), party.size()-1)
			for offset in range(1,followups+1):
				if not _has_alive(): break
				consumed += 1
				damage += _strike(party[(actor_index+offset)%party.size()],power,events,"followup")
	else:
		streak = 0
		gauge = 0
	var retaliation := _settle(events, true)
	actor_index = (actor_index+consumed)%party.size()
	return {"accepted": true, "correct": success, "damage": damage, "retaliation": retaliation,
		"actor": actor.name, "elapsed_ms": elapsed, "status": status, "hayafuri": fast,
		"events": events, "answer": current_question.options[int(current_question.answer)], "explanation": current_question.explanation}

func can_tamafuri(index: int) -> bool:
	if status != "scrolls" or not config.tamafuri.enabled or index < 0 or index >= party.size(): return false
	var id: Variant = party[index].get("tamafuri")
	if id != null and effects.has(id) and effects[id].kind == "reduce_choices" and pending_choice_reduction > 0: return false
	return id != null and effects.has(id) and int(points[index]) >= int(effects[id].cost)

func use_tamafuri(index: int) -> Dictionary:
	if not can_tamafuri(index): return {"accepted": false}
	var member: Dictionary = party[index]
	var id: String = member.tamafuri
	points[index] -= int(effects[id].cost)
	var events: Array = [{"type": "tamafuri", "text": effects[id].label, "actor": member.name}]
	var damage := _effect(id,member,events)
	_settle(events,false)
	return {"accepted": true, "events": events, "damage": damage, "status": status}

func can_musuhi() -> bool:
	return status == "scrolls" and config.musuhi.enabled and gauge >= int(config.musuhi.gauge_required)

func start_musuhi(pool: Array, now_ms: int) -> bool:
	if not can_musuhi() or pool.is_empty(): return false
	for q in pool:
		if q.get("type") != "boolean" or q.options.size() != 2: return false
	musuhi_pool = pool.duplicate(true)
	musuhi_start_ms = now_ms
	musuhi_correct = 0
	musuhi_mistakes = 0
	gauge = 0
	status = "musuhi_feedback"
	return next_musuhi(now_ms)

func musuhi_remaining_ms(now_ms: int) -> int:
	return maxi(0, int(config.musuhi.time_ms)-maxi(0,now_ms-musuhi_start_ms))

func next_musuhi(now_ms: int) -> bool:
	if status != "musuhi_feedback" or musuhi_remaining_ms(now_ms) == 0: return false
	musuhi_question_index = rng.randi_range(0,musuhi_pool.size()-1)
	if musuhi_pool.size()>1 and musuhi_question_index==last_musuhi_index:
		musuhi_question_index = (musuhi_question_index+1)%musuhi_pool.size()
	last_musuhi_index = musuhi_question_index
	current_question = musuhi_pool[musuhi_question_index]
	status = "musuhi"
	return true

func answer_musuhi(selection: int, now_ms: int) -> Dictionary:
	if status != "musuhi": return {"accepted": false}
	if musuhi_remaining_ms(now_ms) == 0: return finish_musuhi(now_ms)
	if selection < 0 or selection > 1: return {"accepted": false}
	var success: bool = selection == int(current_question.answer)
	if success: musuhi_correct += 1
	else: musuhi_mistakes += 1
	status = "musuhi_feedback"
	if musuhi_mistakes >= int(config.musuhi.max_mistakes):
		var finished := finish_musuhi(now_ms)
		finished["correct"] = success
		return finished
	return {"accepted": true, "finished": false, "correct": success}

func finish_musuhi(now_ms: int) -> Dictionary:
	if not status in ["musuhi","musuhi_feedback"]: return {"accepted": false}
	if musuhi_remaining_ms(now_ms)>0 and musuhi_mistakes < int(config.musuhi.max_mistakes): return {"accepted": false}
	var events: Array = [{"type": "musuhi", "text": "ムスヒノ刻 %d問正解" % musuhi_correct}]
	var total_attack := 0
	for member in party: total_attack += int(member.attack)
	var damage := 0
	if musuhi_correct > 0:
		damage = _apply_damage(int(floor(total_attack*musuhi_correct*float(config.musuhi.damage_per_correct))),events,"musuhi_attack","四魂の力")
	# 刻の終了では敵の追加行動を入れず通常の巻物選択へ戻す（仮仕様）。
	_settle(events,false)
	return {"accepted": true, "finished": true, "events": events, "damage": damage, "status": status}
