extends AudioStreamPlayer
## 独自生成の短い効果音。原作音源・外部ファイル不使用。
var sounds: Dictionary = {}

func play_event(kind: String) -> void:
	var freq := 660.0
	if kind in ["enemy_attack","part_break"]: freq = 180.0
	elif kind in ["heal","guard","rally"]: freq = 880.0
	elif kind in ["hayafuri","tamafuri","musuhi"]: freq = 1046.5
	elif kind == "kill": freq = 1320.0
	if not sounds.has(freq):
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var samples := PackedByteArray()
		var length := 3307
		samples.resize(length*2)
		for i in range(length):
			var envelope := sin(PI*float(i)/length)*exp(-4.0*float(i)/length)
			var sample := int(6000.0*envelope*sin(TAU*freq*float(i)/22050.0))
			samples.encode_s16(i*2,sample)
		wav.data = samples
		sounds[freq] = wav
	stream = sounds[freq]
	play()
