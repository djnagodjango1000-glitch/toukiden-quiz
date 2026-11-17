shader_type canvas_item;

uniform float richness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 pixel = COLOR;
	vec3 gold = clamp(pixel.rgb * vec3(1.16, 1.06, 0.79) + vec3(0.06, 0.035, 0.0), vec3(0.0), vec3(1.0));
	pixel.rgb = mix(pixel.rgb, gold, richness);
	COLOR = pixel;
}
