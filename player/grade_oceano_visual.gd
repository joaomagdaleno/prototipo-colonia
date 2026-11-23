class_name GradeOceanoVisual

## Gerador procedural da grade do planejador e do plano oceï¿½nico ao redor do mapa.

static func criar_oceano() -> MeshInstance3D:
	var oceano = MeshInstance3D.new()
	var plano = PlaneMesh.new()
	plano.size = Vector2(3000.0, 3000.0)

	var mat_agua = StandardMaterial3D.new()
	mat_agua.albedo_color = Color(0.08, 0.32, 0.48, 1.0)
	mat_agua.roughness = 0.25
	mat_agua.metallic = 0.1
	plano.material = mat_agua

	oceano.mesh = plano
	oceano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oceano.position = Vector3(0, -0.15, 0)
	return oceano

static func criar_grade(raio: int = 125) -> MeshInstance3D:
	var grade = MeshInstance3D.new()
	var imesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(-raio, raio + 1):
		imesh.surface_add_vertex(Vector3(-raio - 0.5, 0, i - 0.5))
		imesh.surface_add_vertex(Vector3(raio + 0.5, 0, i - 0.5))
		imesh.surface_add_vertex(Vector3(i - 0.5, 0, -raio - 0.5))
		imesh.surface_add_vertex(Vector3(i - 0.5, 0, raio + 0.5))
	imesh.surface_end()

	grade.mesh = imesh
	grade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grade.position = Vector3(0, 0.03, 0)
	grade.visible = false
	return grade
