shader_type spatial;
render_mode unshaded, cull_front;

uniform float weight = 0.1;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	VERTEX += NORMAL * weight * COLOR.r;
}

void fragment() {
	ALBEDO = color.rgb;
}