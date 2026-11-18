extends StaticBody3D
class_name OrbitalStation

var station_name := "Asteria Station"
var carrier := false
var dock_marker: Marker3D


func setup(display_name: String, is_carrier: bool = false) -> void:
	station_name = display_name
	carrier = is_carrier


func _ready() -> void:
	name = station_name
	add_to_group("dockable")
	collision_layer = 1
	collision_mask = 1
	if carrier:
		_build_carrier()
	else:
		_build_station()
	dock_marker = Marker3D.new()
	dock_marker.name = "DockMarker"
	dock_marker.position = Vector3(0, 5.2, -2.0) if carrier else Vector3(0, -18, 28)
	dock_marker.rotation_degrees = Vector3.ZERO
	add_child(dock_marker)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color("#52dcff")
	beacon.light_energy = 2.0
	beacon.omni_range = 35.0
	beacon.position = dock_marker.position
	add_child(beacon)


func can_dock(fighter: PlayerFighter) -> bool:
	return (
		fighter.landing_gear
		and fighter.velocity.length() < 28.0
		and fighter.global_position.distance_to(dock_marker.global_position) < 48.0
	)


func dock_transform() -> Transform3D:
	return dock_marker.global_transform


func distance_to_dock(fighter: PlayerFighter) -> float:
	return fighter.global_position.distance_to(dock_marker.global_position)


func _build_station() -> void:
	var metal := VisualFactory.material(Color("#5c6871"), 0.84, 0.3)
	var dark := VisualFactory.material(Color("#17222b"), 0.9, 0.25)
	var window := VisualFactory.material(Color("#82dcff"), 0.15, 0.18, Color("#30aee5"))
	var torus := TorusMesh.new()
	torus.inner_radius = 12.0
	torus.outer_radius = 16.5
	torus.rings = 32
	torus.ring_segments = 18
	VisualFactory.add_mesh(self, torus, Vector3.ZERO, Vector3.ONE, metal, Vector3(90, 0, 0), "HabitatRing")
	VisualFactory.add_mesh(self, VisualFactory.cylinder(2.7, 2.7, 29.0, 28), Vector3.ZERO, Vector3.ONE, dark, Vector3.ZERO, "CentralSpine")
	for angle_index in 8:
		var angle := float(angle_index) / 8.0 * TAU
		var panel_position := Vector3(cos(angle) * 14.4, sin(angle) * 14.4, 0)
		VisualFactory.add_mesh(self, VisualFactory.box(Vector3(2.6, 1.1, 1.8)), panel_position, Vector3.ONE, window, Vector3(0, 0, rad_to_deg(angle)), "WindowBank")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 17.0
	collision.shape = shape
	add_child(collision)


func _build_carrier() -> void:
	var hull := VisualFactory.material(Color("#46545f"), 0.88, 0.31)
	var dark := VisualFactory.material(Color("#101a22"), 0.92, 0.23)
	var deck := VisualFactory.material(Color("#2d3b43"), 0.76, 0.44)
	var emissive := VisualFactory.material(Color("#7be6ff"), 0.1, 0.18, Color("#2ec6f0"))
	VisualFactory.add_mesh(self, VisualFactory.box(Vector3(18.0, 4.2, 46.0)), Vector3(0, 0, 0), Vector3.ONE, hull, Vector3.ZERO, "CarrierHull")
	VisualFactory.add_mesh(self, VisualFactory.box(Vector3(25.0, 0.45, 30.0)), Vector3(0, 3.5, -3.0), Vector3.ONE, deck, Vector3.ZERO, "FlightDeck")
	VisualFactory.add_mesh(self, VisualFactory.box(Vector3(5.0, 5.8, 8.0)), Vector3(-6.5, 4.3, 5.0), Vector3.ONE, dark, Vector3.ZERO, "Bridge")
	for side in [-1.0, 1.0]:
		for z_value in [-11.0, 5.0, 17.0]:
			VisualFactory.add_mesh(self, VisualFactory.cylinder(0.55, 0.75, 2.6, 16), Vector3(side * 7.1, 0, z_value), Vector3.ONE, emissive, Vector3(90, 0, 0), "Thruster")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24.0, 7.0, 46.0)
	collision.shape = shape
	add_child(collision)

