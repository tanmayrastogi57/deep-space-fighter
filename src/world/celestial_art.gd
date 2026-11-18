extends RefCounted

static func surface(kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/planet.gdshader")
	mat.set_shader_parameter("kind",kind)
	return mat


static func ring_mesh(inner: float, outer: float, wedges: int = 96) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in wedges+1:
		var u := float(i)/wedges
		var ray := Vector3(cos(TAU*u),0,sin(TAU*u))
		for band in 2:
			st.set_uv(Vector2(u,band))
			st.set_normal(Vector3.UP)
			st.add_vertex(ray*(inner if band == 0 else outer))
		if i < wedges:
			var k := i*2
			for j in [k,k+1,k+2,k+1,k+3,k+2]:
				st.add_index(j)
	return st.commit()


static func rings(parent: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/rings.gdshader")
	var ring := VisualFactory.add_mesh(parent,ring_mesh(162,257),Vector3.ZERO,Vector3.ONE,mat,Vector3(20,0,-18),"PlanetaryRings")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func corona(parent: Node3D, radius: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*radius*2.84
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/corona.gdshader")
	var halo := VisualFactory.add_mesh(parent,quad,Vector3.ZERO,Vector3.ONE,mat,Vector3.ZERO,"Corona")
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
