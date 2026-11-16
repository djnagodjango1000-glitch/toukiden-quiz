extends Control
## 新規制作の仮背景と鬼。原作の画像を使わない。
var count := 1
var dead: Array = []
var selected := 0
var enemy_data: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

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
		var enemy: Dictionary = enemy_data[i] if i<enemy_data.size() else {}
		var large: bool = enemy.get("large",false)
		var broken: Array = []
		for part in enemy.get("parts",[]):
			if part.hp<=0: broken.append(part.id)
		var s := minf(1.0, 2.0 / float(count))*(1.12 if large else 0.78)
		var body_color := Color("856049") if large else (Color("514c63") if i%2 == 0 else Color("5d664b"))
		if i < dead.size() and dead[i]: body_color = Color("2c3937")
		draw_circle(c,54*s,body_color)
		draw_circle(c+Vector2(0,-58*s),39*s,body_color.lightened(.12))
		for sign_value in [-1,1]:
			var sig := float(sign_value)
			var arm_id := "left_arm" if sign_value<0 else "right_arm"
			if not arm_id in broken:
				draw_line(c+Vector2(sig*38*s,0),c+Vector2(sig*73*s,35*s),body_color,24*s if large else 19*s)
			else:
				draw_circle(c+Vector2(sig*38*s,0),8*s,Color("cb9f78"))
			draw_line(c+Vector2(sig*24*s,30*s),c+Vector2(sig*38*s,75*s),body_color,22*s)
			if not "horn" in broken:
				draw_colored_polygon(PackedVector2Array([c+Vector2(sig*12*s,-83*s),c+Vector2(sig*34*s,-116*s),c+Vector2(sig*31*s,-72*s)]),Color("d0bc88"))
			draw_line(c+Vector2(sig*9*s,-63*s),c+Vector2(sig*24*s,-58*s),Color("ecb96e"),4*s)
		draw_arc(c+Vector2(0,-52*s),17*s,.2,PI-.2,12,Color("e0cf9d"),3*s)
		if enemy.get("stun",0)>0:
			draw_arc(c+Vector2(0,-95*s),35*s,0,TAU,32,Color("f1d387"),3)
		if i==selected:
			draw_arc(c+Vector2(0,84*s),55*s,0,TAU,40,Color("cfad64"),2)
