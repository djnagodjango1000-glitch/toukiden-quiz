extends Control
## 新規制作の仮背景と鬼。原作の画像を使わない。
var count := 1
var dead: Array = []
var selected := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("283d3c"))
	draw_circle(Vector2(w * 0.8, h * 0.22), 47, Color("b4ad83"))
	for i in range(7):
		var x := float(i) * w / 5.0 - 50.0
		draw_colored_polygon(PackedVector2Array([Vector2(x-140,h),Vector2(x,h*.2 + (i%3)*30),Vector2(x+180,h)]),Color("354e49") if i%2 else Color("3f5750"))
	for i in range(15):
		var x := i * w / 14.0
		draw_line(Vector2(x,h),Vector2(x+20,h*.72),Color("63715a"),2)
	for i in range(count):
		var c := Vector2(w * float(i+1)/float(count+1), h*.64)
		var s := minf(1.0, 2.0 / float(count))
		var body_color := Color("514c63") if i%2 == 0 else Color("5d664b")
		if i < dead.size() and dead[i]: body_color = Color("2c3937")
		draw_circle(c,54*s,body_color)
		draw_circle(c+Vector2(0,-58*s),39*s,body_color.lightened(.12))
		for sign_value in [-1,1]:
			var sig := float(sign_value)
			draw_line(c+Vector2(sig*38*s,0),c+Vector2(sig*73*s,35*s),body_color,19*s)
			draw_line(c+Vector2(sig*24*s,30*s),c+Vector2(sig*38*s,75*s),body_color,22*s)
			draw_colored_polygon(PackedVector2Array([c+Vector2(sig*12*s,-83*s),c+Vector2(sig*34*s,-116*s),c+Vector2(sig*31*s,-72*s)]),Color("d0bc88"))
			draw_line(c+Vector2(sig*9*s,-63*s),c+Vector2(sig*24*s,-58*s),Color("ecb96e"),4*s)
		draw_arc(c+Vector2(0,-52*s),17*s,.2,PI-.2,12,Color("e0cf9d"),3*s)
		if i==selected:
			draw_arc(c+Vector2(0,84*s),55*s,0,TAU,40,Color("cfad64"),2)
