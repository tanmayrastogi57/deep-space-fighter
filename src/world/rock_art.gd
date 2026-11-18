extends RefCounted

enum { CARBON, FRACTURED, ICE }
const STONE := ["#41434a", "#9a8e7e", "#759ba9"]
const SEAM := ["#746957", "#5b554e", "#b1c8cd"]
static var palette: Array[ShaderMaterial] = []


static func rock(kind: int) -> ShaderMaterial:
	if palette.is_empty():
		for i in 3:
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/geology.gdshader")
			mat.set_shader_parameter("stone",Color(STONE[i]))
			mat.set_shader_parameter("seam",Color(SEAM[i]))
			mat.set_shader_parameter("ice",float(i == ICE))
			palette.append(mat)
	return palette[kind]
