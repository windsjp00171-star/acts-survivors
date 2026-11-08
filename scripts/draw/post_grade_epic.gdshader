// post_grade_epic.gdshader — 史詩感全螢幕調色
// 用途：風格提案 docs/refactor/02-style-direction.md 的實作。輕微壓暗、暗部偏夜靛、亮部偏帝金、
//       提高飽和、保護膚色、暈邊。參數與 tools/style_proposal.py 的 grade() 對應。
// 目標：GL Compatibility（桌面、手機、網頁）。成本：每像素 1 次貼圖取樣、無迴圈、無動態分支。
// 低階裝置備案：把 strength 設 0 即等於關閉（scripts/grade.gd 也可整層停用）。
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms look;
uniform float strength : hint_range(0.0, 1.0) = 1.0;       // 0 = 原圖，1 = 完整調色
uniform float darken : hint_range(1.0, 2.0) = 1.4;         // 壓暗指數（1 不壓，越大越暗）
uniform float saturation : hint_range(0.5, 2.0) = 1.4;     // 飽和倍率
uniform float vignette : hint_range(0.0, 1.0) = 0.42;      // 暈邊強度
group_uniforms;

// 色偏（配色板：夜靛、帝金）與強度
const vec3 SHADOW_TINT = vec3(0.165, 0.165, 0.416);        // #2a2a6a 暗部偏色
const vec3 LIGHT_TINT = vec3(0.91, 0.69, 0.376);           // #e8b060 亮部偏色
const float SHADOW_TINT_AMOUNT = 0.16;
const float LIGHT_TINT_AMOUNT = 0.08;
// 膚色保護：色相（0..1）、飽和、明度的範圍；橘紅色相在 0.095 以下，沙色牆（偏黃）在其上
const float SKIN_HUE_MIN = 0.02;
const float SKIN_HUE_MAX = 0.095;
const float SKIN_SAT_MIN = 0.25;
const float SKIN_SAT_MAX = 0.8;
const float SKIN_VAL_MIN = 0.45;
const float SKIN_KEEP = 0.9;        // 膚色像素回混原色的比例
const float SKIN_ORIGINAL_GAIN = 0.97;
// 暈邊從離中心多遠開始、曲線
const float VIGNETTE_START = 0.4;
const float VIGNETTE_CURVE = 1.3;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec3 a = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(a, vec3(0.299, 0.587, 0.114));        // Rec.601 亮度
	vec3 hsv = rgb2hsv(a);
	float skin = step(SKIN_HUE_MIN, hsv.x) * step(hsv.x, SKIN_HUE_MAX)
			* step(SKIN_SAT_MIN, hsv.y) * step(hsv.y, SKIN_SAT_MAX) * step(SKIN_VAL_MIN, hsv.z);
	float l = max(lum, 1.0e-4);
	vec3 o = a * (pow(l, darken) / l);                      // 保留色相與飽和的壓暗
	o += pow(1.0 - lum, 2.0) * SHADOW_TINT * SHADOW_TINT_AMOUNT;
	o += pow(lum, 3.0) * LIGHT_TINT * LIGHT_TINT_AMOUNT;
	float g = (o.r + o.g + o.b) / 3.0;
	o = clamp(vec3(g) + (o - vec3(g)) * saturation, 0.0, 1.0);
	o = mix(o, a * SKIN_ORIGINAL_GAIN, skin * SKIN_KEEP);
	float r = length((SCREEN_UV - 0.5) * 2.0);
	o *= 1.0 - vignette * pow(clamp(r - VIGNETTE_START, 0.0, 1.0), VIGNETTE_CURVE);
	COLOR = vec4(mix(a, o, strength), 1.0);
}
