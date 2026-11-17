extends Control
## 新規作成の巻物の軸と装飾。入力は下のボタンに通す。
var tier := 1
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	var dark := Color("4d321d")
	var gold := Color("a37a36")
	for x in [8.0,size.x-16.0]:
		draw_rect(Rect2(x,3,8,size.y-6),dark)
		draw_line(Vector2(x+3,6),Vector2(x+3,size.y-6),gold,2)
		draw_circle(Vector2(x+4,5),5,gold)
		draw_circle(Vector2(x+4,size.y-5),5,gold)
	var color: Color = [Color("b89355"),Color("a3a7a4"),Color("d4a53d")][clampi(tier-1,0,2)]
	var c := Vector2(32,size.y/2)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-15),c+Vector2(14,0),c+Vector2(0,15),c+Vector2(-14,0)]),dark)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-11),c+Vector2(10,0),c+Vector2(0,11),c+Vector2(-10,0)]),color)
