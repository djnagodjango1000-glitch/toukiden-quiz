extends RefCounted
## temp検証後に置換。破損・将来版を勝手に初期化しない。
var base_path := "user://save.json"
var blocked := false
var error := ""

func initial() -> Dictionary:
	return {"schema_version": 1, "haku": 0, "xp": 0, "cleared": [], "reward_ids": [], "settings": {"free_play": false}, "owned": ["m01", "m02", "m03", "m04"]}

func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("schema_version") != 1: return false
	for field in ["haku", "xp"]:
		if not (data.get(field) is float or data.get(field) is int) or data[field] < 0: return false
	for field in ["cleared", "reward_ids", "owned"]:
		if not data.get(field) is Array: return false
	return data.get("settings") is Dictionary

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return null
	return parser.data

func load_save() -> Dictionary:
	blocked = false
	error = ""
	var data: Variant = _read(base_path)
	# 新しいschemaの主セーブは旧backupで巻き戻さない。
	if data is Dictionary and data.get("schema_version", 0) > 1:
		blocked = true
		error = "新しい版のセーブです。上書きを停止しました。"
		return {}
	if valid(data): return data
	var backup: Variant = _read(base_path + ".bak")
	if valid(backup):
		# 復元元は残す。次の保存でも破損主ファイルをbackupへ移さない。
		error = "主セーブを読めないため、前回のバックアップから復元しました。"
		return backup
	if FileAccess.file_exists(base_path) or FileAccess.file_exists(base_path + ".bak"):
		blocked = true
		error = "セーブが破損しています。元ファイルを保護し、自動初期化を停止しました。"
		return {}
	return initial()

func persist(data: Dictionary) -> bool:
	if blocked or not valid(data):
		error = "セーブ形式が不正か、書き込み保護中です。"
		return false
	var temp := base_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		error = "一時セーブを作成できません。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if not valid(_read(temp)):
		error = "保存内容の再検証に失敗しました。"
		return false
	if valid(_read(base_path)):
		var copy_error := DirAccess.copy_absolute(base_path, base_path + ".bak")
		if copy_error != OK:
			error = "旧セーブの保護に失敗しました。"
			return false
	var replace_error := DirAccess.rename_absolute(temp, base_path)
	if replace_error != OK:
		error = "セーブの置換に失敗しました。"
		return false
	error = ""
	return true

func reward(data: Dictionary, mission: Dictionary, receipt: String, orb_per_first_clear: int = 1) -> Dictionary:
	var updated := data.duplicate(true)
	if receipt in updated.reward_ids: return updated
	updated.haku += int(mission.rewards.haku)
	updated.xp += int(mission.rewards.xp)
	updated["material"] = int(updated.get("material",0))+int(mission.rewards.get("material",0))
	if not mission.id in updated.cleared:
		updated.cleared.append(mission.id)
		if not mission.get("training",false): updated["orbs"] = int(updated.get("orbs",0))+orb_per_first_clear
	updated.reward_ids.append(receipt)
	return updated
