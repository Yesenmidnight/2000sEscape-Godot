shader_type spatial;
// 全亮渲染（PS1 原机不做动态光照；暗角/氛围交给 CRT 滤镜与配色）
// 注：diffuse_lambert 光照路径对本项目 GLB 网格有掉面问题（4.7 实测），
//     MODEL_NORMAL_MATRIX 亦有兼容性问题——锁定本版本，勿改回光照路径。
render_mode shades_disabled, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.8, 0.8, 0.8);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform bool use_tex = false;
// 顶点吸附网格数（越小抖动越明显）
uniform float snap_res = 220.0;
// 颜色量化级数（每通道），配合抖动产生渐变色带
uniform float color_steps = 20.0;
uniform float dither_strength = 0.45;

varying vec2 v_uv_aff;
varying float v_w;

void vertex() {
	// PS1 标志性顶点抖动：视空间量化 VERTEX（不写 POSITION，规避引擎兼容问题）
	vec4 cp = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (cp.w > 0.0001) {
		vec2 grid = vec2(snap_res * 0.5);
		vec2 ndc = cp.xy / cp.w;
		ndc = floor(ndc * grid + vec2(0.5)) / grid;
		cp = vec4(ndc * cp.w, cp.z, cp.w);
		VERTEX = (inverse(PROJECTION_MATRIX) * cp).xyz;
	}
	// 仿射贴图：顶点阶段把 UV 乘 w，像素阶段除回（消除透视校正）
	v_w = max(cp.w, 0.0001);
	v_uv_aff = UV * v_w;
}

void fragment() {
	vec3 col = base_color;
	if (use_tex) {
		col *= texture(tex, v_uv_aff / v_w).rgb;
	}
	// 抖动 + 每通道量化（PS1 的 15bit 色深观感）
	float d = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col = floor(col * color_steps + 0.5 + d * dither_strength) / color_steps;
	ALBEDO = col;
}
