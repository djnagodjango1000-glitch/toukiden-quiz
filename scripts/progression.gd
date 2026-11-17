extends RefCounted
## UIに依存しない仮経済。操作はコピーを返し、呼出側が保存成功後に採用。
var rules: Dictionary
var catalog: Array

func _init(config: Dictionary, mitama: Array) -> void:
	rules = config
	catalog = mitama

func find_member(id: String) -> Dictionary:
	for m in catalog:
		if m.id == id: return m
	return {}

func team_cost(deck: Array) -> int:
	var total := 0
	for id in deck:
		var member := find_member(str(id))
		if member.is_empty(): return -1
		total += int(member.cost)
	return total

func change_deck(state: Dictionary, id: String) -> Dictionary:
	if not id in state.owned or find_member(id).is_empty(): return {}
	var updated := state.duplicate(true)
	var deck: Array = updated.get("deck",updated.owned.slice(0,int(rules.team_limit))).duplicate()
	if id in deck:
		if deck.size()<=1: return {}
		deck.erase(id)
	else:
		if deck.size()>=int(rules.team_limit): return {}
		deck.append(id)
		if team_cost(deck)>int(rules.team_cost_limit): return {}
	updated["deck"] = deck
	return updated

func rarity(id: String, stage: int) -> int:
	var member:=find_member(id)
	if member.is_empty(): return 0
	return clampi(int(member.rarity)+maxi(0,stage),1,7)

func evolution_requirements(id: String, stage: int) -> Dictionary:
	var member:=find_member(id)
	if member.is_empty() or stage<0 or stage>=int(rules.evolve_max) or rarity(id,stage)>=7: return {}
	var steps: Array=rules.get("evolve_steps",[])
	if stage>=steps.size(): return {}
	return steps[stage].duplicate(true)

func evolve(state: Dictionary, id: String) -> Dictionary:
	if not id in state.owned or find_member(id).is_empty(): return {}
	var levels: Dictionary = state.get("levels",{})
	var stages: Dictionary = state.get("evolutions",{})
	var needed:=evolution_requirements(id,int(stages.get(id,0)))
	if needed.is_empty() or int(levels.get(id,1)) < int(needed.level): return {}
	if int(state.haku)<int(needed.haku) or int(state.get("material",0))<int(needed.material): return {}
	var updated := state.duplicate(true)
	updated.haku -= int(needed.haku)
	updated["material"] = int(updated.get("material",0))-int(needed.material)
	if not updated.has("evolutions"): updated["evolutions"] = {}
	updated.evolutions[id] = int(stages.get(id,0))+1
	return updated

func claim_collection(state: Dictionary, threshold: int) -> Dictionary:
	var key := str(threshold)
	if not rules.encyclopedia_rewards.has(key) or state.owned.size()<threshold or key in state.get("collection_claimed",[]): return {}
	var updated := state.duplicate(true)
	if not updated.has("collection_claimed"): updated["collection_claimed"] = []
	updated.collection_claimed.append(key)
	updated.haku += int(rules.encyclopedia_rewards[key])
	return updated

func energy_state(state: Dictionary, now: int) -> Dictionary:
	var maximum := int(rules.energy_max)
	var amount := clampi(int(state.get("energy",maximum)),0,maximum)
	var last := int(state.get("energy_updated",now))
	if now < last: return {"amount":amount,"updated":last}
	if amount>=maximum: return {"amount":maximum,"updated":now}
	var interval := int(rules.energy_recovery_seconds)
	var gained := int((now-last)/interval)
	amount = mini(maximum, amount+gained)
	return {"amount":amount,"updated":now if amount>=maximum else last+gained*interval}

func enter_mission(state: Dictionary, mission: Dictionary, now: int) -> Dictionary:
	var updated := state.duplicate(true)
	if state.settings.get("free_play",false): return updated
	var energy := energy_state(state,now)
	var cost := int(mission.energy)
	if int(energy.amount)<cost: return {}
	updated["energy"] = int(energy.amount)-cost
	updated["energy_updated"] = int(energy.updated)
	return updated

func valid_backup(state: Variant) -> bool:
	if not state is Dictionary or not state.get("owned") is Array or not state.get("settings") is Dictionary: return false
	for key in ["free_play","muted","relaxed_effects","bgm_muted"]:
		if state.settings.has(key) and not state.settings[key] is bool: return false
	if state.settings.has("bgm_volume"):
		var volume: Variant=state.settings.bgm_volume
		if not (volume is int or volume is float) or volume != int(volume) or int(volume)<1 or int(volume)>100: return false
	var owned: Array = state.owned
	if owned.is_empty() or owned.size()>catalog.size(): return false
	var seen: Array = []
	for id in owned:
		if not id is String or id in seen or find_member(id).is_empty(): return false
		seen.append(id)
	var deck: Variant = state.get("deck",owned.slice(0,int(rules.team_limit)))
	if not deck is Array or deck.is_empty() or deck.size()>int(rules.team_limit): return false
	seen = []
	for id in deck:
		if not id in owned or id in seen: return false
		seen.append(id)
	if team_cost(deck)>int(rules.team_cost_limit): return false
	for field in ["levels","evolutions"]:
		var values: Variant = state.get(field,{})
		if not values is Dictionary: return false
		for id in values:
			if not id in owned or not (values[id] is int or values[id] is float): return false
			var value := int(values[id])
			if value != values[id]: return false
			if field=="levels" and (value<1 or value>int(rules.upgrade_max_level)): return false
			if field=="evolutions" and (value<0 or value>mini(int(rules.evolve_max),7-int(find_member(id).rarity))): return false
	for field in ["material","energy","energy_updated","orbs","training_wins","training_best"]:
		if state.has(field) and (not (state[field] is int or state[field] is float) or state[field]<0): return false
	if state.has("collection_claimed"):
		if not state.collection_claimed is Array: return false
		var claimed: Array = []
		for key in state.collection_claimed:
			if not key is String or key in claimed or not rules.encyclopedia_rewards.has(key): return false
			claimed.append(key)
	return true
