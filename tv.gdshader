shader_type canvas_item;

void fragment() {
	vec2 coords = (0.5 * UV) / SCREEN_PIXEL_SIZE;
    float should_dim = float(int(coords.y) % 2);
    COLOR = mix(vec4(0, 0, 0, 0.1), vec4(0, 0, 0, 0), should_dim);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
