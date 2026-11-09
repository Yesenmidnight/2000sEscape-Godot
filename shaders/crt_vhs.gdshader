shader_type canvas_item;
// 逃离千禧年 —— CRT/VHS 合并滤镜（迁移自 ESC_VisualEffects.js）
// 桶形畸变公式与各效果参数与原版保持一致，全部由 uniform 控制。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float curvature : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.2;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float flicker_intensity : hint_range(0.0, 0.2) = 0.0;
uniform float chroma_amount : hint_range(0.0, 4.0) = 0.0;
uniform float beam_speed = 0.35; // 滚动扫描光束速度，0 关闭

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// CRT 桶形畸变：centered *= 1 + dist^2 * curvature（原版公式）
	vec2 centered = uv * 2.0 - 1.0;
	float dist = length(centered);
	centered *= 1.0 + dist * dist * curvature;
	uv = centered * 0.5 + 0.5;

	// 越界画黑边（CRT 边框），否则正常采样后处理
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 色差：RGB 三通道分离采样
		vec3 col;
		if (chroma_amount > 0.001) {
			float off = sin(TIME * 1.7) * 0.0015 * chroma_amount;
			col.r = texture(screen_tex, uv + vec2(off, 0.0)).r;
			col.g = texture(screen_tex, uv).g;
			col.b = texture(screen_tex, uv - vec2(off, 0.0)).b;
		} else {
			col = texture(screen_tex, uv).rgb;
		}

		// VHS 扫描线：每 2px 一条暗线（原版 drawScanlines）
		float scan = 1.0 - scanline_opacity * step(0.5, fract(FRAGCOORD.y * 0.5));
		col *= scan;

		// 滚动扫描光束（约 60px 渐变带缓慢下移）
		if (beam_speed > 0.001) {
			float beam_y = fract(TIME * beam_speed) * 1.1 - 0.05;
			float d = uv.y - beam_y;
			col += vec3(exp(-abs(d) * 90.0) * 0.05);
		}

		// 噪点/颗粒（阈值化随机像素，对应原版 drawNoise）
		float n = hash21(floor(FRAGCOORD.xy / 2.0) + vec2(TIME * 91.0, TIME * 77.0));
		if (n > 1.0 - noise_intensity) {
			col += vec3(0.10 * (n * 2.0 - (1.0 - noise_intensity)));
		}

		// 暗角（径向渐变，对应原版 drawVignette）
		float vig = smoothstep(0.35, 0.95, length(uv - vec2(0.5)) * 1.3);
		col = mix(col, vec3(0.0), vig * vignette_intensity);

		// 闪烁
		if (flicker_intensity > 0.001) {
			float fl = (hash21(vec2(TIME * 7.0, 3.7)) - 0.5) * flicker_intensity;
			col += vec3(fl);
		}

		COLOR = vec4(col, 1.0);
	}
}
