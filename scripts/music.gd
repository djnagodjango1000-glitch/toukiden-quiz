extends Node
## 独自制作のオフラインBGM。画面切替時は2つのプレイヤーで短くクロスフェード。
const TRACKS := {
	"village":"res://assets/music/village.ogg",
	"battle":"res://assets/music/battle.ogg",
	"boss":"res://assets/music/boss.ogg",
	"musuhi":"res://assets/music/musuhi.ogg",
	"result":"res://assets/music/result.ogg",
	"defeat":"res://assets/music/defeat.ogg"
}
var players: Array[AudioStreamPlayer] = []
var active := -1
var requested := ""
var playing_track := ""
var muted := false
var percent := 60
var paused := false
var transition: Tween

func _ready() -> void:
	for i in range(2):
		var player:=AudioStreamPlayer.new()
		player.volume_db=-80.0
		add_child(player)
		players.append(player)

func _exit_tree() -> void:
	if transition!=null and transition.is_running(): transition.kill()
	for player in players: player.stop()

func _volume_db() -> float:
	return -4.0+linear_to_db(clampf(float(percent)/100.0,0.01,1.0))

func configure(settings: Dictionary) -> void:
	muted=bool(settings.get("bgm_muted",false))
	percent=clampi(int(settings.get("bgm_volume",60)),1,100)
	if muted:
		if transition!=null and transition.is_running(): transition.kill()
		for player in players: player.stop()
		playing_track=""
		active=-1
	elif not requested.is_empty() and playing_track!=requested:
		play_track(requested)
	elif active>=0:
		if transition!=null and transition.is_running(): transition.kill()
		players[active].volume_db=_volume_db()
		var other:=1-active
		players[other].stop()

func set_paused(value: bool) -> void:
	paused=value
	for player in players: player.stream_paused=value

func play_track(track: String) -> void:
	if not TRACKS.has(track): return
	requested=track
	if muted or players.is_empty(): return
	if playing_track==track and active>=0 and players[active].playing: return
	if transition!=null and transition.is_running(): transition.kill()
	var previous:=active
	var next:=0 if active!=0 else 1
	var stream: AudioStreamOggVorbis=load(TRACKS[track]).duplicate()
	stream.loop=true
	players[next].stop()
	players[next].stream=stream
	players[next].volume_db=-60.0
	players[next].play()
	players[next].stream_paused=paused
	active=next
	playing_track=track
	transition=create_tween()
	transition.set_parallel(true)
	transition.tween_property(players[next],"volume_db",_volume_db(),0.4)
	if previous>=0 and players[previous].playing:
		transition.tween_property(players[previous],"volume_db",-60.0,0.4)
		transition.chain().tween_callback(players[previous].stop)
