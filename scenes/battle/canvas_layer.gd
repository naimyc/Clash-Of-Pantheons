# Attach to a CanvasLayer (layer = 10).
# Amber-ember vignette — dark fiery edges, bright centre like divine spotlight.
extends CanvasLayer

func _ready():
	layer = 10

	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 uv  = SCREEN_UV * 2.0 - 1.0;
	uv.x    *= 0.8;
	float d  = length(uv);

	// Dark ember-red vignette at edges
	float v  = smoothstep(0.5, 1.35, d);
	vec3 col = mix(vec3(0.18, 0.06, 0.01), vec3(0.0, 0.0, 0.0), v);

	// Subtle golden centre warmth — like light from the heavens
	float centre = 1.0 - smoothstep(0.0, 0.7, d);
	col += vec3(0.06, 0.04, 0.0) * centre;

	COLOR = vec4(col, v * 0.72);
}
"""
	var mat    = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
