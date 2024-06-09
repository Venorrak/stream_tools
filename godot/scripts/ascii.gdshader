shader_type spatial;
render_mode unshaded;

// Screen texture
uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_nearest;

// An image containing ASCII characters, from darkest / emptiest (e.g. ' ') to brightest / fullest (e.g. '@')
uniform sampler2D character_map;

// The number of ASCII characters in the character_map
uniform float number_of_characters = 8.0;

// The pixel size of ASCII characters rendered on the screen
uniform vec2 character_size = vec2(8.0, 16.0);

void vertex() {
	// Cover the viewport with the mesh
	POSITION = vec4(VERTEX, 0.5);
}

void fragment() {
	vec2 character_count = VIEWPORT_SIZE / character_size;
	
	// Clamp the screen UV coordinates to the future ASCII character grid
	vec2 clamped_uv = floor(SCREEN_UV * character_count) / character_count;
	
	// Calculate the coordinates we're at within the current character
	vec2 character_uv = SCREEN_UV * character_count - floor(SCREEN_UV * character_count);
	
	// The pixel color in this grid position
	// We use the clamped_uv here to make sure one character has one color
    vec3 color = textureLod(screen_texture, clamped_uv, 0.0).rgb;
	
	// Get the greyscale value (or brightness) here
	float grey = (color.r + color.g + color.b) / 3.0;
	
	// Using this greyscale value, decide which character in the character_map to use
	// The floor and division is to get integer values from 0 to 7 instead of floating points inbetween
	vec2 offset = vec2(round(grey * (number_of_characters - 1.0)) / number_of_characters, 0.0);
	
	// Stencil out the ASCII character by multiplying the color with its alpha
	color *= texture(character_map, offset + character_uv * vec2(1.0 / number_of_characters, 1.0)).a;
	
	// Assign the result
	ALBEDO = color;
}