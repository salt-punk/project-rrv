shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D input_tex : hint_default_black, filter_linear_mipmap;

uniform bool overlay = true;

uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float scanlines_width : hint_range(0.0, 0.5) = 0.25;
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.3;
uniform vec2 resolution = vec2(640.0, 480.0);

uniform bool pixelate = true;

// pixelate intensity + grid size
uniform float pixelate_strength : hint_range(0.0, 1.0) = 1.0; // 0=smooth, 1=full pixelate
uniform vec2 pixelate_resolution = vec2(640.0, 480.0);        // grid used for pixelation

uniform bool roll = true;
uniform float roll_speed = 8.0;
uniform float roll_size : hint_range(0.0, 100.0) = 15.0;
uniform float roll_variation : hint_range(0.1, 5.0) = 1.8;
uniform float distort_intensity : hint_range(0.0, 0.2) = 0.05;

uniform float noise_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float noise_speed = 5.0;

uniform float static_noise_intensity : hint_range(0.0, 1.0) = 0.06;

uniform float aberration : hint_range(-1.0, 1.0) = 0.03;
uniform float brightness = 1.4;
uniform bool discolor = true;

uniform float warp_amount : hint_range(0.0, 5.0) = 1.0;
uniform bool clip_warp = false;

uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;

// Noise Helpers 
vec2 random2(vec2 uv){
	uv = vec2(
		dot(uv, vec2(127.1, 311.7)),
		dot(uv, vec2(269.5, 183.3))
	);
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float pnoise(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);

	return mix(
		mix(
			dot(random2(uv_index + vec2(0.0, 0.0)), uv_fract - vec2(0.0, 0.0)),
			dot(random2(uv_index + vec2(1.0, 0.0)), uv_fract - vec2(1.0, 0.0)),
			blur.x
		),
		mix(
			dot(random2(uv_index + vec2(0.0, 1.0)), uv_fract - vec2(0.0, 1.0)),
			dot(random2(uv_index + vec2(1.0, 1.0)), uv_fract - vec2(1.0, 1.0)),
			blur.x
		),
		blur.y
	) * 0.5 + 0.5;
}

// CRT Helpers
vec2 warp(vec2 uv){
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta, delta);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;
	return uv + delta * delta_offset;
}

float border(vec2 uv){
	float radius = min(warp_amount, 0.08);
	radius = max(min(min(abs(radius * 2.0), 1.0), 1.0), 1e-5);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	float square = smoothstep(0.96, 1.0, dist);
	return clamp(1.0 - square, 0.0, 1.0);
}

float vignette(vec2 uv){
	uv *= 1.0 - uv.xy;
	float v = uv.x * uv.y * 15.0;
	return pow(v, vignette_intensity * vignette_opacity);
}

// Pixelate Helper
vec2 pixelate_uv(vec2 uv) {
	// Avoid divide-by-zero
	vec2 pr = max(pixelate_resolution, vec2(1.0));
	vec2 snapped = ceil(uv * pr) / pr;

	// If pixelate is off, keep uv. If on, blend by strength.
	float s = pixelate ? clamp(pixelate_strength, 0.0, 1.0) : 0.0;
	return mix(uv, snapped, s);
}

// Sample helpers
float samp_r(vec2 uv) {
	return overlay ? texture(SCREEN_TEXTURE, uv).r : texture(input_tex, uv).r;
}
float samp_g(vec2 uv) {
	return overlay ? texture(SCREEN_TEXTURE, uv).g : texture(input_tex, uv).g;
}
float samp_b(vec2 uv) {
	return overlay ? texture(SCREEN_TEXTURE, uv).b : texture(input_tex, uv).b;
}

void fragment() {
	// Use SCREEN_UV for overlay; UV for local sampling
	vec2 base_uv = overlay ? SCREEN_UV : UV;

	// Warp coordinates
	vec2 uv = warp(base_uv);

	// Pixelate with adjustable strength
	vec2 text_uv = pixelate_uv(uv);

	float time = roll ? TIME : 0.0;

	// Rolling distortion
	float roll_line = 0.0;
	vec2 roll_uv = vec2(0.0);

	if (roll || noise_opacity > 0.0) {
		roll_line = smoothstep(0.3, 0.9, sin(uv.y * roll_size - (time * roll_speed)));
		roll_line *= roll_line * smoothstep(
			0.3, 0.9,
			sin(uv.y * roll_size * roll_variation - (time * roll_speed * roll_variation))
		);

		float xfade = 1.0 - base_uv.x;
		roll_uv = vec2(roll_line * distort_intensity * xfade, 0.0);
	}

	vec2 ab = vec2(aberration, 0.0) * 0.1;

	// Sample RGB with aberration (+ roll distortion)
	vec4 text = vec4(0.0);
	if (roll) {
		text.r = samp_r(text_uv + roll_uv * 0.8 + ab);
		text.g = samp_g(text_uv + roll_uv * 1.2 - ab);
		text.b = samp_b(text_uv + roll_uv);
		text.a = 1.0;
	} else {
		text.r = samp_r(text_uv + ab);
		text.g = samp_g(text_uv - ab);
		text.b = samp_b(text_uv);
		text.a = 1.0;
	}

	float r = text.r;
	float g = text.g;
	float b = text.b;

	// Keep mask effects stable in the same space
	vec2 fx_uv = warp(base_uv);

	// Grille
	if (grille_opacity > 0.0) {
		float gr = smoothstep(0.85, 0.95, abs(sin(fx_uv.x * (resolution.x * 3.14159265))));
		r = mix(r, r * gr, grille_opacity);

		float gg = smoothstep(0.85, 0.95, abs(sin(1.05 + fx_uv.x * (resolution.x * 3.14159265))));
		g = mix(g, g * gg, grille_opacity);

		float bb = smoothstep(0.85, 0.95, abs(sin(2.1 + fx_uv.x * (resolution.x * 3.14159265))));
		b = mix(b, b * bb, grille_opacity);
	}

	// Brightness compensation
	text.r = clamp(r * brightness, 0.0, 1.0);
	text.g = clamp(g * brightness, 0.0, 1.0);
	text.b = clamp(b * brightness, 0.0, 1.0);

	// Scanlines
	float scan = 0.5;
	if (scanlines_opacity > 0.0) {
		scan = smoothstep(
			scanlines_width, scanlines_width + 0.5,
			abs(sin(fx_uv.y * (resolution.y * 3.14159265)))
		);
		text.rgb = mix(text.rgb, text.rgb * vec3(scan), scanlines_opacity);
	}

	// Banded noise
	if (noise_opacity > 0.0) {
		float n = smoothstep(
			0.4, 0.5,
			pnoise(fx_uv * vec2(2.0, 200.0) + vec2(10.0, TIME * noise_speed))
		);

		// Use same pixelation feel for noise sampling
		vec2 pix_uv = pixelate ? (ceil(fx_uv * max(pixelate_resolution, vec2(1.0))) / max(pixelate_resolution, vec2(1.0))) : fx_uv;
		roll_line *= n * scan * clamp(random2(pix_uv + vec2(TIME * 0.8, 0.0)).x + 0.8, 0.0, 1.0);

		text.rgb = clamp(mix(text.rgb, text.rgb + roll_line, noise_opacity), vec3(0.0), vec3(1.0));
	}

	// Static noise
	if (static_noise_intensity > 0.0) {
		vec2 pix_uv = pixelate ? (ceil(fx_uv * max(pixelate_resolution, vec2(1.0))) / max(pixelate_resolution, vec2(1.0))) : fx_uv;
		text.rgb += clamp(random2(pix_uv + fract(TIME)).x, 0.0, 1.0) * static_noise_intensity;
	}

	// Border + vignette
	text.rgb *= border(fx_uv);
	text.rgb *= vignette(fx_uv);

	// Optional alpha clip for warped corners
	if (clip_warp) {
		text.a = border(fx_uv);
	}

	// VHS discolor
	if (discolor) {
		float saturation = 0.5;
		float contrast = 1.2;

		vec3 greyscale = vec3(text.r + text.g + text.b) / 3.0;
		text.rgb = mix(text.rgb, greyscale, saturation);

		float midpoint = pow(0.5, 2.2);
		text.rgb = (text.rgb - vec3(midpoint)) * contrast + midpoint;
	}

	COLOR = text;
}
