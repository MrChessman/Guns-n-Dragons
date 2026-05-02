shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Default to black
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0; // Default thickness 1
void fragment() {
    // TEXTURE_PIXEL_SIZE tells us how big one pixel is
    vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
    
    // We check the transparent pixels in an 8-way circle around the current pixel
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
    
    // Cap the outline value at 1.0
    outline = min(outline, 1.0);
    
    vec4 color = texture(TEXTURE, UV);
    // Mix the original sprite color with our outline color!
    COLOR = mix(color, line_color, outline - color.a);
}