shader_type spatial;
// PS1-style surface: vertex snapping (jitter), affine texture warping,
// nearest-filtered low-res textures, optional world-space (triplanar-ish)
// UVs for level geometry and vertex colours for baked character clothing.
// Fog comes from the Environment.
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float uv_scale = 1.0;
uniform float snap_res = 160.0;
uniform float emission = 0.0;
uniform bool affine = true;
uniform bool world_uv = false;      // level geometry: UVs from world position
uniform float world_scale = 0.5;    // texture repeats per metre in world_uv mode
uniform bool use_vcolor = false;    // characters: clothing baked into COLOR
uniform float tex_mix = 1.0;        // 0 = flat colour, 1 = full texture detail

varying vec2 aff_uv;
varying float aff_w;
varying vec3 vcol;

void vertex() {
	vec4 p = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_res, snap_res * 0.75);
	p.xy = floor((p.xy / p.w) * grid + 0.5) / grid * p.w;
	POSITION = p;
	vec2 uv = UV * uv_scale;
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		if (wn.y > wn.x && wn.y > wn.z) {
			uv = wp.xz;
		} else if (wn.x > wn.z) {
			uv = vec2(wp.z, -wp.y);
		} else {
			uv = vec2(wp.x, -wp.y);
		}
		uv *= world_scale;
	}
	vcol = use_vcolor ? COLOR.rgb : vec3(1.0);
	if (affine) {
		aff_uv = uv * p.w;
		aff_w = p.w;
	} else {
		aff_uv = uv;
		aff_w = 1.0;
	}
}

void fragment() {
	vec2 uv = aff_uv / aff_w;
	vec3 t = texture(albedo_tex, uv).rgb;
	t = mix(vec3(dot(t, vec3(0.33))), t, 0.85);
	t = mix(vec3(0.6), t, tex_mix) * 1.6;
	vec3 c = t * albedo_color.rgb * vcol;
	ALBEDO = c;
	EMISSION = c * emission;
}
