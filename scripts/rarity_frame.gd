extends Control
## 肖像の上に重ねる装飾。サイズに応じて描き、タッチ入力は通す。
var rarity := 1
var gold_frame: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity>=6: gold_frame=load("res://assets/art/rarity_gold.png")
	queue_redraw()

func _star(center: Vector2, radius: float, color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(10):
		var angle: float=-PI/2+float(i)*PI/5
		var distance: float=radius if i%2==0 else radius*0.45
		points.append(center+Vector2(cos(angle),sin(angle))*distance)
	draw_colored_polygon(points,color)

func _draw() -> void:
	var r:=clampi(rarity,1,7)
	var colors: Array=[Color("8e8170"),Color("ae7646"),Color("bdc4bf"),Color("7394b3"),Color("c47273"),Color("e7b949"),Color("ffe69a")]
	var c: Color=colors[r-1]
	var bounds:=Rect2(Vector2.ZERO,size)
	if gold_frame!=null:
		draw_texture_rect(gold_frame,bounds,false,Color(1,1,1,1.0 if r==7 else 0.62))
	else:
		draw_rect(bounds,c,false,maxf(2.0,size.x*0.024))
		if r>=3:
			var inset:=size.x*0.04
			draw_rect(bounds.grow(-inset),c,false,maxf(1.0,size.x*0.008))
		if r>=4:
			var edge:=size.x*0.12
			for x in [0.0,size.x]:
				for y in [0.0,size.y]:
					var sx:=1.0 if x==0.0 else -1.0
					var sy:=1.0 if y==0.0 else -1.0
					draw_line(Vector2(x,y+sy*edge),Vector2(x+sx*edge,y),c,maxf(2.0,size.x*0.014))
	var radius:=minf(size.x*0.035, size.x/(float(r)*2.8+3.0))
	var spacing:=radius*2.45
	var start:=(size.x-float(r-1)*spacing)*0.5
	for i in range(r): _star(Vector2(start+float(i)*spacing,size.y-radius*1.6),radius,c)
