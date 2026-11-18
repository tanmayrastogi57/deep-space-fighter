shader_type sky;
#include "res://assets/shaders/surface_noise.gdshaderinc"
uniform float chart_seed = 0.0;
float stars(vec2 uv, vec2 grid, float threshold, float spread, float salt) {
	vec2 cell = floor(uv*grid), q = fract(uv*grid);
	vec3 id = vec3(cell,salt+chart_seed);
	float h = hash3(id);
	vec2 center = .2+.6*vec2(hash3(id+6.1),hash3(id+11.7));
	vec2 delta = q-center;
	return step(threshold,h)*exp(-dot(delta,delta)/spread)*(.35+.65*h);
}
void sky() {
	// Only angular coordinates enter this field: no camera translation or clock.
	float equator = dot(EYEDIR,normalize(vec3(.38,.86,.34)));
	float dust = terrain(EYEDIR*4.3+vec3(5.,8.,3.));
	float ribbon = exp(-18.*abs(equator+.065*sin(EYEDIR.x*8.)))*(.2+.8*dust);
	float fine = stars(SKY_COORDS,vec2(640.,320.),.965,.013,8.);
	float bright = stars(SKY_COORDS,vec2(286.,143.),.967,.008,24.);
	COLOR = vec3(.003,.008,.017)+ribbon*vec3(.067,.072,.099)
		+fine*vec3(.40,.50,.60)+bright*vec3(.81,.82,.78);
}
