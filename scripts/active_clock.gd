extends RefCounted
## フレームdeltaの丸め・上限に依存しない単調時計。試験時は模擬時計を注入。
var elapsed_ms := 0
var running := false
var anchor := 0
var source: Callable

func _init(provider: Callable = Callable()) -> void:
	source = provider if provider.is_valid() else Time.get_ticks_msec
	anchor = int(source.call())

func read() -> int:
	var now := int(source.call())
	if running: elapsed_ms += maxi(0,now-anchor)
	# 逆行した模擬時計を受けても同じ区間を二重加算しない。
	anchor = maxi(anchor,now)
	return elapsed_ms

func set_running(value: bool) -> void:
	read()
	running = value

func reset() -> void:
	running = false
	elapsed_ms = 0
	anchor = int(source.call())
