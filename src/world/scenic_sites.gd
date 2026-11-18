extends RefCounted

const Frame := preload("res://src/world/airframe.gd")

static func _glass_slab() -> ArrayMesh:
	# Broken sheets have two broad faces and chipped, offset ends rather than
	# a pointed cone. Keep the fracture field in one instanced draw.
	var bottom := [Vector3(-.72,-.37,-.26),Vector3(.57,-.52,-.27),Vector3(.92,-.41,.12),Vector3(.38,-.61,.28),Vector3(-.84,-.50,.18)]
	var top := [Vector3(-.48,.43,-.24),Vector3(.16,.57,-.21),Vector3(.72,.31,.10),Vector3(.26,.51,.24),Vector3(-.59,.39,.18)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in bottom.size():
		var j := (i+1)%bottom.size()
		for vertex in [bottom[i],top[i],top[j],bottom[i],top[j],bottom[j],bottom[j],bottom[i],Vector3(0,-.53,0),top[i],top[j],Vector3(0,.46,0)]:
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()

static func add_site(area: Area3D, site_name: String, planet: Node3D) -> void:
	var art := Node3D.new()
	art.name = "Landmark"
	area.add_child(art)
	var metal := VisualFactory.material(Color("#657780"),0.27,0.50)
	var amber := VisualFactory.material(Color("#b88c4c"),0.18,0.50,Color("#ab733a"))
	match site_name:
		"The Glass Horizon":
			var rng := RandomNumberGenerator.new()
			rng.seed = 19438
			var splinter := _glass_slab()
			var shards := MultiMesh.new()
			shards.transform_format = MultiMesh.TRANSFORM_3D
			shards.mesh = splinter
			shards.instance_count = 23
			for i in shards.instance_count:
				var flank := -1.0 if i % 2 == 0 else 1.0
				var pos := Vector3(flank*rng.randf_range(16,56), rng.randf_range(-12,7),rng.randf_range(-51,45))
				var axes := Basis.from_euler(Vector3(rng.randf_range(-.5,.6), rng.randf_range(-2,2),flank*rng.randf_range(.25,.9)))
				shards.set_instance_transform(i,Transform3D(axes.scaled_local(Vector3(rng.randf_range(2.5,6.3),rng.randf_range(9,28),rng.randf_range(3.5,6.5))),pos))
			var ice := MultiMeshInstance3D.new()
			ice.name = "FractureField"
			ice.multimesh = shards
			var mirror := ShaderMaterial.new()
			mirror.shader = preload("res://assets/shaders/fracture_glass.gdshader")
			ice.material_override = mirror
			art.add_child(ice)
		"Silent Relay":
			art.rotation_degrees = Vector3(-9,18,-16)
			Frame.beam(art,Vector3(0,-17,0),Vector3(0,12,0),2.0,2.0,metal,"BentMast")
			VisualFactory.add_mesh(art,VisualFactory.box(Vector3(8,7,7)),Vector3(0,-6,0),Vector3.ONE,metal,Vector3.ZERO,"Avionics")
			var solar := VisualFactory.material(Color("#294669"),.34,.33,Color("#0b182b"))
			Frame.beam(art,Vector3(-21,-6,0),Vector3(20,-6,0),0.9,0.9,metal,"Boom")
			for i in [-2,-1,1]:
				var array := VisualFactory.add_mesh(art,VisualFactory.box(Vector3(8,.45,10)),Vector3(i*9,-6,0),Vector3.ONE,solar,Vector3(36,0,14 if i<0 else -28),"SolarWing")
				for rib in [-3.2,0.0,3.2]:
					VisualFactory.add_mesh(array,VisualFactory.box(Vector3(8.1,.06,.11)),Vector3(0,.25,rib),Vector3.ONE,metal,Vector3.ZERO,"CellDivider")
			# Tapered open dish with a feed suspended above its concave face.
			var bowl := VisualFactory.cylinder(9.0,1.7,3.2,24)
			bowl.cap_top = false
			var dish := Node3D.new()
			dish.position = Vector3(0,12,0)
			dish.rotation_degrees.x = 56
			art.add_child(dish)
			var skin := VisualFactory.material(Color("#bcc0b4"),.3,.48)
			skin.cull_mode = BaseMaterial3D.CULL_DISABLED
			VisualFactory.add_mesh(dish,bowl,Vector3.ZERO,Vector3.ONE,skin,Vector3.ZERO,"Receiver")
			for i in 3:
				var a := TAU*i/3.
				Frame.beam(dish,Vector3(8*cos(a),1.6,8*sin(a)),Vector3(0,6,0),.32,.32,metal,"FeedSupport")
			VisualFactory.add_mesh(dish,VisualFactory.sphere(.9,10,5),Vector3.UP*6,Vector3.ONE,amber,Vector3.ZERO,"Beacon")
		"Caligo Overlook":
			art.look_at(planet.global_position,Vector3.UP)
			for flank in [-1.0,1.0]:
				var foot := Vector3(flank*18,-14,-4)
				var elbow := Vector3(flank*23,3,-4)
				var tip := Vector3(flank*16,12,-4)
				Frame.beam(art,foot,elbow,1.6,1.8,metal,"SurveyPylon")
				Frame.beam(art,elbow,tip,1.3,1.5,metal,"ViewingArm")
				VisualFactory.add_mesh(art,VisualFactory.box(Vector3(1.5,.55,1.6)),tip,Vector3.ONE,amber,Vector3.ZERO,"SightLight")
			Frame.beam(art,Vector3(-19,-14,-4),Vector3(19,-14,-4),1.5,2.4,metal,"ObservationDeck")


static func launch_lane(parent: Node3D) -> void:
	var lane := Node3D.new()
	lane.name = "DepartureLights"
	parent.add_child(lane)
	var shell := VisualFactory.material(Color("#454e57"),0.30,0.67)
	var lamp := VisualFactory.material(Color("#d6af74"),0.06,0.48,Color("#d19d59"))
	var nav := VisualFactory.material(Color("#99d4d2"),0.06,0.48,Color("#65b8c0"))
	var housing := VisualFactory.box(Vector3(1.7,.70,3.5))
	var strip := VisualFactory.box(Vector3(1.3,.22,2.7))
	for i in 5:
		for side in [-1,1]:
			var p := Vector3(side*(10+i*2.0), -2.8-i*.7, 8.0-i*34.0)
			VisualFactory.add_mesh(lane,housing,p,Vector3.ONE,shell,Vector3.ZERO,"Housing")
			var light := VisualFactory.add_mesh(lane,strip,p+Vector3.UP*.43,Vector3.ONE,lamp if side < 0 else nav,Vector3.ZERO,"Guidelight")
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
