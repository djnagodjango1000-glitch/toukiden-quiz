extends SceneTree
## ゲームコード上の購入・通信経路を静的に確認する。Android実機の監査とは別。
func _initialize() -> void:
	var forbidden := ["HTTPRequest.new(","HTTPClient.new(","WebSocketPeer.new(","JavaClassWrapper", "BillingClient", "InAppPurchase", "OS.shell_open("]
	var files := DirAccess.get_files_at("res://scripts")
	var errors := 0
	for file in files:
		if not file.ends_with(".gd"): continue
		var body := FileAccess.get_file_as_string("res://scripts/"+file)
		for term in forbidden:
			if term in body:
				printerr("Offline policy: forbidden runtime entry ",term," in ",file)
				errors+=1
	var project := FileAccess.get_file_as_string("res://project.godot")
	if "permissions/internet=true" in project:
		printerr("Offline policy: internet permission enabled")
		errors+=1
	print("OFFLINE POLICY: %d script files, %d violations" % [files.size(),errors])
	quit(1 if errors else 0)
