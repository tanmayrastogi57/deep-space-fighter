extends RefCounted

# Geometry at layer 1 is common scenery. These two layers belong only to the pilot.
const EXTERIOR := 2
const INTERIOR := 4
const EYE := Vector3(0, 0.62, -0.72)

# A series of flattened octagonal sections gives a blended wing-body without
# a circular end cap. Corners carry broad highlights at actual chase distance.
static func fuselage() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices := [Vector3(0.04,0.04,-4.85), Vector3(0.51,0.35,-2.65), Vector3(0.84,0.56,-0.85), Vector3(1.16,0.49,1.15), Vector3(0.78,0.26,3.05), Vector3(0.34,0.12,3.45)]
	var profile := [Vector2(-0.65,1),Vector2(0.65,1),Vector2(1,0.35),Vector2(1,-0.36),Vector2(0.58,-1),Vector2(-0.58,-1),Vector2(-1,-0.36),Vector2(-1,0.35)]
	for i in slices.size() - 1:
		for j in profile.size():
			var k := (j + 1) % profile.size()
			var a := _point(slices[i], profile[j])
			var b := _point(slices[i], profile[k])
			var c := _point(slices[i+1], profile[k])
			var d := _point(slices[i+1], profile[j])
			for p in [a,b,c,a,c,d]:
				surface.add_vertex(p)
	for end in [0, slices.size()-1]:
		for j in profile.size():
			var a := _point(slices[end], profile[j])
			var b := _point(slices[end], profile[(j+1)%profile.size()])
			for p in [Vector3(0,0,slices[end].z), b if end == 0 else a, a if end == 0 else b]:
				surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()


static func _point(section: Vector3, uv: Vector2) -> Vector3:
	return Vector3(section.x * uv.x, section.y * uv.y, section.z)


static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float, mat: Material, part: String) -> MeshInstance3D:
	var piece := VisualFactory.add_mesh(parent, VisualFactory.box(Vector3(width,depth,a.distance_to(b))), (a+b)*0.5, Vector3.ONE, mat, Vector3.ZERO, part)
	piece.quaternion = Quaternion(Vector3.BACK, (b-a).normalized())
	return piece


static func cockpit(ship: Node3D) -> Dictionary:
	var tub := Node3D.new()
	tub.name = "PilotInterior"
	tub.position = EYE
	ship.add_child(tub)
	var graphite := VisualFactory.material(Color("#262e37"), 0.18, 0.64)
	var trim := VisualFactory.material(Color("#606c73"), 0.25, 0.42)
	var display := VisualFactory.material(Color("#101e26"), 0.1, 0.4, Color("#07141b"))
	for side in [-1.0,1.0]:
		beam(tub, Vector3(side*0.94,-0.6,-0.85), Vector3(side*0.72,0.70,-0.87), 0.035,0.05,trim,"CanopyBow")
		beam(tub, Vector3(side*0.9,-0.56,-0.82), Vector3(side*0.67,-0.49,0.65),0.11,0.12,graphite,"Sill")
	VisualFactory.add_mesh(tub, VisualFactory.box(Vector3(1.8,0.34,0.35)), Vector3(0,-0.71,-0.86),Vector3.ONE,graphite,Vector3(-12,0,0),"Dash")
	VisualFactory.add_mesh(tub,VisualFactory.box(Vector3(1.62,.035,.16)),Vector3(0,-.50,-.79),Vector3.ONE,trim,Vector3(-8,0,0),"GlareShield")
	var readouts: Array[Label3D] = []
	for side in [-1.0,1.0]:
		VisualFactory.add_mesh(tub, VisualFactory.box(Vector3(0.42,0.15,0.028)),Vector3(side*0.45,-0.56,-0.675),Vector3.ONE,display,Vector3(-12,0,0),"Instrument")
		var label := Label3D.new()
		label.pixel_size = 0.001
		label.font_size = 32
		label.outline_size = 0
		label.modulate = Color("#9cdfd5")
		label.position = Vector3(side*0.45,-0.55,-0.651)
		label.rotation.x = deg_to_rad(-12)
		tub.add_child(label)
		readouts.append(label)
	for geom in tub.find_children("*", "GeometryInstance3D", true, false):
		geom.layers = INTERIOR
		geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"root":tub, "readouts":readouts}
