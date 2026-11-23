extends Node

@export var raio_pincel: float = 2.5
var ativo: bool = false
var anel_visual: MeshInstance3D
var _ultima_pos_pintada: Vector3 = Vector3.INF

func _ready():
	_criar_anel_visual()

func _criar_anel_visual():
	anel_visual = MeshInstance3D.new()
	var imesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	imesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var segmentos = 32
	for i in range(segmentos + 1):
		var angulo = (float(i) / segmentos) * TAU
		imesh.surface_add_vertex(Vector3(cos(angulo) * raio_pincel, 0, sin(angulo) * raio_pincel))
	imesh.surface_end()
	
	anel_visual.mesh = imesh
	anel_visual.visible = false
	get_tree().current_scene.call_deferred("add_child", anel_visual)

func alternar():
	ativo = not ativo
	if not ativo and is_instance_valid(anel_visual):
		anel_visual.visible = false
	print("Modo Pincel de Corte/Colheita: ", "ATIVADO" if ativo else "DESATIVADO")

func desativar():
	ativo = false
	if is_instance_valid(anel_visual):
		anel_visual.visible = false

func ocultar():
	if is_instance_valid(anel_visual):
		anel_visual.visible = false

func atualizar(pos_chao: Vector3):
	if is_instance_valid(anel_visual):
		anel_visual.visible = true
		anel_visual.global_position = Vector3(pos_chao.x, pos_chao.y + 0.15, pos_chao.z)
		
	var clicou_agora = Input.is_action_just_pressed("acao_principal") or Input.is_action_just_pressed("acao_secundaria")
	var moveu_suficiente = pos_chao.distance_squared_to(_ultima_pos_pintada) >= 0.36
	if Input.is_action_pressed("acao_principal"):
		if clicou_agora or moveu_suficiente:
			_ultima_pos_pintada = pos_chao
			_pintar_recursos(pos_chao, true)
	elif Input.is_action_pressed("acao_secundaria"):
		if clicou_agora or moveu_suficiente:
			_ultima_pos_pintada = pos_chao
			_pintar_recursos(pos_chao, false)
	else:
		_ultima_pos_pintada = Vector3.INF

func _pintar_recursos(centro: Vector3, marcar: bool):
	var raio_sq = raio_pincel * raio_pincel
	for grupo in ["arvores", "arbustos", "pedras", "coletaveis_chao"]:
		for item in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(item) and item.has_method("alternar_marcacao"):
				var dx = item.global_position.x - centro.x
				var dz = item.global_position.z - centro.z
				if (dx * dx + dz * dz) <= raio_sq:
					item.alternar_marcacao(marcar)
