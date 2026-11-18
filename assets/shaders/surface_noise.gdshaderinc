float hash3(vec3 p) {
	p = fract(p * vec3(.1031,.11369,.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x+p.y)*p.z);
}
float field(vec3 p) {
	vec3 i = floor(p), t = fract(p);
	t *= t*(3.0-2.0*t);
	vec2 k = vec2(0.,1.);
	return mix(mix(mix(hash3(i),hash3(i+k.yxx),t.x),mix(hash3(i+k.xyx),hash3(i+k.yyx),t.x),t.y),
		mix(mix(hash3(i+k.xxy),hash3(i+k.yxy),t.x),mix(hash3(i+k.xyy),hash3(i+k.yyy),t.x),t.y),t.z);
}
float terrain(vec3 p) {
	return 0.55*field(p) + 0.29*field(p.yzx*2.13+7.1) + 0.16*field(p.zxy*4.47+15.7);
}
