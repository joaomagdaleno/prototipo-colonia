class_name GradeOceanoVisual

## Gerador procedural do oceano e da grade do planejador via Shader GPU (1 Quad = 4 vertices).

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
	var plano = PlaneMesh.new()
	var diametro = float(raio * 2)
	plano.size = Vector2(diametro, diametro)

	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (length(world_pos.xz) > 123.0) discard;
	vec2 grid = abs(fract(world_pos.xz + 0.5) - 0.5) / fwidth(world_pos.xz);
	float line = min(grid.x, grid.y);
	float alpha = 1.0 - min(line, 1.0);
	if (alpha <= 0.05) discard;
	ALBEDO = vec3(1.0);
	ALPHA = alpha * 0.14;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	plano.material = mat

	grade.mesh = plano
	grade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grade.position = Vector3(0, 0.03, 0)
	grade.visible = false
	return grade
