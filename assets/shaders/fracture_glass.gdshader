shader_type spatial;
render_mode cull_disabled;
varying vec3 shard;
void vertex() { shard = VERTEX; }
void fragment() {
	float plane = shard.y + .13*shard.x - .12*shard.z;
	float fissure = 1.-smoothstep(.006,.024,abs(plane+.12));
	float sheen = pow(1.-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.,1.),2.5);
	ALBEDO = mix(vec3(.14,.23,.25),vec3(.33,.46,.46),.3+fissure*.65);
	ROUGHNESS = .32; METALLIC = .32;
	EMISSION = vec3(.12,.22,.24)*sheen + vec3(.07,.11,.12)*fissure;
}
