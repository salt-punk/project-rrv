shader_type sky;

// Comment this if you don't want to use star twinke. However, if you do want to keep it,
// I suggest you to set the sky process mode to High-Quality Incremental or Real-Time,
// as star twinkling may greatly impact performance.
#define USE_TWINKLE

group_uniforms sky;
uniform vec3 sky_color: source_color = vec3(0.03, 0.05, 0.11);

group_uniforms stars;
uniform vec3 star_base_color: source_color = vec3(0.8, 1.0, 0.3);
uniform float star_hue_offset: hint_range(0., 1.) = 0.6;
uniform float star_intensity: hint_range(0., 0.2) = 0.08;
#ifdef USE_TWINKLE
uniform float star_twinkle_speed: hint_range(0.0, 2.0) = 0.8;
uniform float star_twinkle_intensity: hint_range(0.0, 1.0) = 0.2;
#endif

group_uniforms layers;
uniform float layer_scale: hint_range(0., 60.) = 20.;
uniform float layer_scale_step: hint_range(0., 40.) = 10.;
uniform int layers_count: hint_range(0, 12) = 3;

group_uniforms moon;
uniform vec3 moon_color: source_color = vec3(0.9, 0.92, 0.85);
uniform float moon_size: hint_range(0.0, 0.05) = 0.004;
uniform float moon_edge_softness: hint_range(0.0, 0.02) = 0.0015;
uniform float moon_glow_size: hint_range(0.0, 0.5) = 0.15;
uniform float moon_glow_intensity: hint_range(0.0, 2.0) = 0.4;

group_uniforms clouds;
uniform bool use_clouds = true;
uniform vec3 cloud_color: source_color = vec3(0.5, 0.55, 0.65);
uniform float cloud_coverage: hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness: hint_range(0.0, 1.0) = 0.35;
uniform float cloud_scale: hint_range(0.1, 20.0) = 3.0;
uniform vec2 cloud_speed = vec2(0.015, 0.006);
uniform float cloud_opacity: hint_range(0.0, 1.0) = 0.85;
uniform float cloud_shading: hint_range(0.0, 1.0) = 0.6;

// Hue credit:
// The MIT License
// Copyright © 2024 DigvijaysinhGohil
// https://github.com/DigvijaysinhGohil/Godot-Shader-Lib

vec3 hue(vec3 input, float offset, int range_index) {
	// RGB to HSV
	vec4 k = vec4(0., -1./3., 2./3., -1.);
	vec4 p = mix(vec4(input.bg, k.wz), vec4(input.gb, k.xy), step(input.b, input.g));
	vec4 q = mix(vec4(p.xyw, input.r), vec4(input.r, p.yzx), step(p.x, input.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.e-10;
	vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6. * d + e)), d / (q.x + e), q.x);

	offset = (range_index == 0) ? offset / 360. : offset;
	float hue = hsv.x + offset;
	if (hue < 0.) {
		hsv.x = hue + 1.;
	} else if (hue > 1.) {
		hsv.x = hue - 1.;
	} else {
		hsv.x = hue;
	}

	// HSV to RGB
	vec4 k2 = vec4(1., 2./3., 1./3., 3.);
	vec3 p2 = abs(fract(hsv.xxx + k2.xyz) * 6. - k2.www);
	vec3 rgb = hsv.z * mix(k2.xxx, clamp(p2 - k2.xxx, 0., 1.), hsv.y);
	return rgb;
}

// Voronoi method credit:
// The MIT License
// Copyright © 2013 Inigo Quilez
// https://www.shadertoy.com/view/ldl3Dl

vec3 hash(vec3 x) {
	x = vec3(dot(x, vec3(127.1,311.7, 74.7)),
			 dot(x, vec3(269.5,183.3,246.1)),
			 dot(x, vec3(113.5,271.9,124.6)));
	return fract(sin(x) * 43758.5453123);
}

vec2 voronoi(in vec3 x){
	vec3 p = floor(x);
	vec3 f = fract(x);
	
	float res = 100.;
	float id = 0.;
	
	for (float k = -1.; k <= 1.; k += 1.) {
		for (float j = -1.; j <= 1.; j += 1.) {
			for (float i = -1.; i <= 1.; i += 1.) {
				vec3 b = vec3(i, j, k);
				vec3 r = vec3(b) - f + hash(p + b);
				float d = dot(r, r);
				if (d < res) {
					res = d;
					id = dot(p + b, vec3(0., 57., 113.));
				}
		    }
		}
	}
	
	return vec2(sqrt(res), id);
}

// Value noise + fbm, used for clouds
float hash1(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(
			mix(hash1(i + vec3(0., 0., 0.)), hash1(i + vec3(1., 0., 0.)), f.x),
			mix(hash1(i + vec3(0., 1., 0.)), hash1(i + vec3(1., 1., 0.)), f.x),
			f.y
		),
		mix(
			mix(hash1(i + vec3(0., 0., 1.)), hash1(i + vec3(1., 0., 1.)), f.x),
			mix(hash1(i + vec3(0., 1., 1.)), hash1(i + vec3(1., 1., 1.)), f.x),
			f.y
		),
		f.z
	);
}

float cloud_fbm(vec3 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return value;
}

void sky() {
	COLOR = sky_color;

	for (int i = 0; i < layers_count; i++) {
		vec3 pos = EYEDIR * (layer_scale + float(i) * layer_scale_step);
		vec2 layer = voronoi(pos);

		vec3 rand = hash(vec3(layer.y));

		#ifdef USE_TWINKLE
			float twinkle = sin(TIME * PI * star_twinkle_speed + rand.x * TAU);
			twinkle *= star_twinkle_intensity;
			float star = smoothstep(star_intensity + star_intensity * twinkle, 0., layer.x);
		#else
			float star = smoothstep(star_intensity, 0., layer.x);
		#endif

		vec3 star_color = star * hue((COLOR + star_base_color), rand.y * star_hue_offset, 1);

		COLOR += star_color;
	}

	// Moon: positioned wherever the DirectionalLight3D is coming from
	bool has_light = dot(LIGHT0_DIRECTION, LIGHT0_DIRECTION) > 0.0001;
	vec3 moon_dir = has_light ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);
	float moon_dot = dot(EYEDIR, moon_dir);

	float moon_glow = smoothstep(1.0 - moon_glow_size, 1.0, moon_dot) * moon_glow_intensity;
	COLOR += moon_color * moon_glow;

	float moon_disc = smoothstep(1.0 - moon_size - moon_edge_softness, 1.0 - moon_size, moon_dot);
	COLOR = mix(COLOR, moon_color, moon_disc);

	// Clouds: dome-projected fbm noise, brighter on the side facing the moon
	if (use_clouds) {
		float horizon = smoothstep(0.0, 0.15, EYEDIR.y);
		if (horizon > 0.0) {
			vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y, 0.05) * cloud_scale * 0.1;
			cloud_uv += TIME * cloud_speed;

			float n = cloud_fbm(vec3(cloud_uv, 0.0));
			float edge = 0.02 + cloud_softness * 0.5;
			float clouds = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + edge, n);

			float moon_facing = clamp(moon_dot * 0.5 + 0.5, 0.0, 1.0);
			vec3 lit_cloud_color = mix(cloud_color * (1.0 - cloud_shading), cloud_color, moon_facing);

			COLOR = mix(COLOR, lit_cloud_color, clouds * cloud_opacity * horizon);
		}
	}
}