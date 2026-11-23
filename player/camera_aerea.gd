extends Camera3D

## Câmera Aérea / Modo Estratégico de Planejamento e Construção

@export var opcoes_construcao: Array[PackedScene]
var indice_atual: int = 0
var rotacao_atual: float = 0.0

var fantasma: Node3D
var grade_visual: MeshInstance3D
var oceano_visual: MeshInstance3D
var velocidade_movimento := 18.0
var usando_controle: bool = false
var ultima_pos_pintada: Vector3 = Vector3(9999, 9999, 9999)
var _forma_demolir: SphereShape3D
var _forma_livre: SphereShape3D
var _ultima_celula_verificada: Vector2i = Vector2i(99999, 99999)
var _ultimo_resultado_livre: bool = true

const LIMITE_MAPA_XZ := 105.0
const ALTURA_MIN_ZOOM := 10.0
const ALTURA_MAX_ZOOM := 48.0

@onready var pincel = $Pincel

var modo_marcacao: bool:
	get: return pincel.ativo if is_instance_valid(pincel) else false

func _ready():
	add_to_group("camera_aerea")
	_forma_demolir = SphereShape3D.new()
	_forma_demolir.radius = 0.45
	_forma_livre = SphereShape3D.new()
	_forma_livre.radius = 0.4
	far = 220.0

	oceano_visual = GradeOceanoVisual.criar_oceano()
	get_tree().current_scene.call_deferred("add_child", oceano_visual)

	grade_visual = GradeOceanoVisual.criar_grade()
	get_tree().current_scene.call_deferred("add_child", grade_visual)

	if opcoes_construcao.is_empty() and ResourceLoader.exists("res://buildings/Estrada.tscn"):
		opcoes_construcao.append(load("res://buildings/Estrada.tscn"))

	_trocar_fantasma(0)

func _trocar_fantasma(novo_indice: int):
	if opcoes_construcao.is_empty():
		return

	indice_atual = clamp(novo_indice, 0, opcoes_construcao.size() - 1)
	if is_instance_valid(fantasma):
		fantasma.queue_free()

	var cena = opcoes_construcao[indice_atual]
	if cena:
		fantasma = cena.instantiate()
		get_tree().current_scene.call_deferred("add_child", fantasma)
		fantasma.visible = false
		fantasma.remove_from_group("projetos")
		if fantasma.has_node("CorpoFisico"):
			fantasma.get_node("CorpoFisico").collision_layer = 0
		if fantasma.has_node("AreaInteracao"):
			fantasma.get_node("AreaInteracao").monitoring = false

func _process(delta):
	if not current:
		if is_instance_valid(fantasma): fantasma.visible = false
		if is_instance_valid(grade_visual): grade_visual.visible = false
		pincel.ocultar()
		return

	if is_instance_valid(grade_visual):
		grade_visual.visible = not pincel.ativo

	# 1. Movimentação e Limites da Câmera
	var input_dir = Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
	if input_dir.length() > 0:
		if Input.get_connected_joypads().size() > 0 and not Input.is_key_pressed(KEY_W) and not Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_D):
			usando_controle = true
		var frente = (-transform.basis.z * Vector3(1, 0, 1)).normalized()
		var direita = (transform.basis.x * Vector3(1, 0, 1)).normalized()
		global_position += (frente * -input_dir.y + direita * input_dir.x).normalized() * velocidade_movimento * delta

	var zoom_joy = Input.get_axis("olhar_cima", "olhar_baixo")
	if abs(zoom_joy) > 0.2:
		usando_controle = true
		global_position += transform.basis.z * zoom_joy * 15.0 * delta

	global_position.x = clamp(global_position.x, -LIMITE_MAPA_XZ, LIMITE_MAPA_XZ)
	global_position.z = clamp(global_position.z, -LIMITE_MAPA_XZ, LIMITE_MAPA_XZ)
	global_position.y = clamp(global_position.y, ALTURA_MIN_ZOOM, ALTURA_MAX_ZOOM)

	# 2. Interseção com o Terreno (Raycast)
	var pos_tela = (get_viewport().get_visible_rect().size / 2.0) if usando_controle else get_viewport().get_mouse_position()
	var origem = project_ray_origin(pos_tela)
	var query = PhysicsRayQueryParameters3D.create(origem, origem + project_ray_normal(pos_tela) * 120.0)
	if is_instance_valid(fantasma):
		query.exclude = [fantasma]
	query.collision_mask = 1
	var resultado = get_world_3d().direct_space_state.intersect_ray(query)

	if resultado:
		var pos_bruta = resultado.position
		if pincel.ativo:
			if is_instance_valid(fantasma): fantasma.visible = false
			pincel.atualizar(pos_bruta)
		elif is_instance_valid(fantasma):
			pincel.ocultar()
			var pos = Vector3(round(pos_bruta.x), pos_bruta.y + 0.5, round(pos_bruta.z))
			fantasma.visible = true
			fantasma.global_position = pos
			fantasma.rotation.y = rotacao_atual
			_atualizar_cor_fantasma(_posicao_esta_livre(pos))

			if Input.is_action_pressed("acao_principal") and pos.distance_to(ultima_pos_pintada) >= 0.9:
				_tentar_colocar_projeto(pos)
			if Input.is_action_pressed("acao_secundaria"):
				_tentar_demolir_na_posicao(pos)
	else:
		if is_instance_valid(fantasma): fantasma.visible = false
		pincel.ocultar()

	if not Input.is_action_pressed("acao_principal"):
		ultima_pos_pintada = Vector3(9999, 9999, 9999)

func _posicao_esta_livre(pos: Vector3) -> bool:
	var celula = Vector2i(int(round(pos.x)), int(round(pos.z)))
	if celula == _ultima_celula_verificada:
		return _ultimo_resultado_livre
	_ultima_celula_verificada = celula

	# 1. Checagem O(1) para estradas (que nao possuem colisor fisico)
	if Global.estradas_pos.has(celula):
		_ultimo_resultado_livre = false
		return false

	# 2. Consulta espacial nativa C++ (BVH) para arvores, projetos e construcoes
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = _forma_livre
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.collision_mask = 3
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var col = hit.get("collider")
		if not is_instance_valid(col): continue
		var alvo = col if (col.is_in_group("projetos") or col.is_in_group("construidos") or col.is_in_group("arvores")) else col.get_parent()
		if is_instance_valid(alvo) and alvo != fantasma and (alvo.is_in_group("projetos") or alvo.is_in_group("construidos") or alvo.is_in_group("arvores")):
			_ultimo_resultado_livre = false
			return false
	_ultimo_resultado_livre = true
	return true

func _atualizar_cor_fantasma(livre: bool):
	if not is_instance_valid(fantasma) or not fantasma.has_node("MeshInstance3D"): return
	var mesh_inst: MeshInstance3D = fantasma.get_node("MeshInstance3D")
	var mat = mesh_inst.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat
	if not livre: mat.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
	elif fantasma.has_method("pode_pagar") and not fantasma.pode_pagar(): mat.albedo_color = Color(1.0, 0.75, 0.15, 0.55)
	else: mat.albedo_color = Color(0.2, 1.0, 0.35, 0.55)

func _tentar_colocar_projeto(pos: Vector3):
	ultima_pos_pintada = pos
	_ultima_celula_verificada = Vector2i(99999, 99999)
	if not _posicao_esta_livre(pos) or opcoes_construcao.is_empty(): return
	var cena = opcoes_construcao[indice_atual]
	var novo = cena.instantiate()
	novo.name = cena.resource_path.get_file().get_basename()
	get_tree().current_scene.add_child(novo)
	novo.global_position = pos
	novo.rotation.y = rotacao_atual
	novo.add_to_group("projetos")

func _tentar_demolir_na_posicao(pos: Vector3):
	# 1. Checagem O(1) instantanea para estradas (que nao possuem colisor fisico)
	var celula = Vector2i(int(round(pos.x)), int(round(pos.z)))
	if Global.estradas_pos.has(celula):
		var est_rua = Global.estradas_pos[celula]
		if is_instance_valid(est_rua) and est_rua is Node3D and est_rua.has_method("demolir"):
			est_rua.demolir()
			_ultima_celula_verificada = Vector2i(99999, 99999)
			return

	# 2. Consulta espacial nativa C++ (BVH) para projetos e construcoes com colisor
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = _forma_demolir
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.collision_mask = 3
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var col = hit.get("collider")
		if not is_instance_valid(col): continue
		var alvo = col if col.has_method("demolir") else col.get_parent()
		if is_instance_valid(alvo) and alvo != fantasma and (alvo.is_in_group("projetos") or alvo.is_in_group("construidos")):
			alvo.demolir()
			_ultima_celula_verificada = Vector2i(99999, 99999)
			return

func _unhandled_input(event):
	if not current: return
	if event is InputEventMouseMotion: usando_controle = false

	var apertou_c = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C
	var apertou_dpad = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_UP
	if apertou_c or apertou_dpad:
		pincel.alternar()
		return

	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		Global.contratar_colono()

	if not pincel.ativo:
		if event.is_action_pressed("girar_esquerda"): rotacao_atual -= PI / 2.0
		elif event.is_action_pressed("girar_direita"): rotacao_atual += PI / 2.0
		elif event.is_action_pressed("peca_anterior") and not opcoes_construcao.is_empty():
			_trocar_fantasma((indice_atual - 1 + opcoes_construcao.size()) % opcoes_construcao.size())
		elif event.is_action_pressed("peca_proxima") and not opcoes_construcao.is_empty():
			_trocar_fantasma((indice_atual + 1) % opcoes_construcao.size())
		elif event is InputEventKey and event.pressed and not event.echo and not opcoes_construcao.is_empty():
			var n = event.keycode - KEY_1
			if n >= 0 and n < opcoes_construcao.size() and n != indice_atual: _trocar_fantasma(n)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and global_position.y > ALTURA_MIN_ZOOM:
			global_position += transform.basis.z * 1.5
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and global_position.y < ALTURA_MAX_ZOOM:
			global_position -= transform.basis.z * 1.5
