shader_type canvas_item;

uniform vec4 border_color: source_color;

void fragment() {
    vec4 sampled = texture(TEXTURE, UV);
    COLOR = sampled.a * border_color;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
