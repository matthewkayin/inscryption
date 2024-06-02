shader_type canvas_item;

uniform int offset: hint_range(0, 5) = 0;
uniform vec4 border_color: source_color;

void fragment() {
	vec2 coords = UV * (1.0 / TEXTURE_PIXEL_SIZE);
    float counting_backwards = float(UV.x < (1.0 - TEXTURE_PIXEL_SIZE.x) && int(coords.y) > int(coords.x));
    coords = (counting_backwards * (vec2(1.0) - coords)) + ((1.0 - counting_backwards) * coords);
    int index = int(coords.x) + int(coords.y) - offset;
    float hidden = min(float(index % 4), 1.0);
    hidden = min(float((index + 1) % 4), hidden);
    vec4 sampled = texture(TEXTURE, UV);
    COLOR = mix(vec4(border_color.r, border_color.g, border_color.b, sampled.a), vec4(0.0, 0.0, 0.0, 0.0), 1.0 - hidden);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
