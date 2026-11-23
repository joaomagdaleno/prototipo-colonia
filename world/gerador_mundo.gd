@tool
extends Node3D

@export_group("Cenas de Natureza")
@export var cena_arvore: PackedScene
@export var cena_rocha: PackedScene
@export var cena_arbusto: PackedScene
@export var cena_graveto: PackedScene
@export var cena_pedrinha: PackedScene

@export_group("Cenas de Vida & Perigos")
@export var cena_animal: PackedScene
@export var cena_inimigo: PackedScene

@export_group("Configuraï¿½ï¿½es de Populaï¿½ï¿½o")
@export var max_animais: int = 12
@export var max_inimigos_noite: int = 6

@export var testar_geracao_editor: bool = false:
	set(valor):
		if valor:
			gerar_mundo_completo()
			testar_geracao_editor = false

var _cache_meshes_vega8: Dictionary = {}
var _timer_fauna: float = 2.0
var _timer_inimigos: float = 5.0

func _ready():
	if Engine.is_editor_hint():
		return
	# Espera 1 frame de fï¿½sica para garantir que o colisor do Chao esteja 100% ativo
	await get_tree().physics_frame
	if not SaveManager.carregar_ao_iniciar and get_child_count() == 0:
		gerar_mundo_completo()
		# Espera mais 1 frame para os colisores das novas ï¿½rvores/rochas registrarem
		await get_tree().physics_frame
	# Etapa final: acorda o jogador em uma posiï¿½ï¿½o segura acima do solo
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	if is_instance_valid(jogador) and jogador.has_method("nascer_no_mundo"):
		var altura_solo = _obter_altura_chao(0.0, 3.0)
		jogador.nascer_no_mundo(Vector3(0.0, altura_solo + 0.5, 3.0))


func _obter_raio_chao() -> float:
	var chao = get_parent().get_node_or_null("Chao") if get_parent() else null
	if chao:
		for filho in chao.get_children():
			if filho is MeshInstance3D and filho.mesh:
				var tamanho = filho.mesh.get_aabb().size * chao.scale * filho.scale
				return max(10.0, (min(tamanho.x, tamanho.z) / 2.0) - 2.0)
	return 123.0

func _obter_altura_chao(pos_x: float, pos_z: float) -> float:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(Vector3(pos_x, 50.0, pos_z), Vector3(pos_x, -50.0, pos_z))
	var resultado = space_state.intersect_ray(query)
	return resultado.position.y if resultado else 0.0

func gerar_mundo_completo():
	for filho in get_children():
		filho.queue_free()
		
	var raio = _obter_raio_chao()
	var area = PI * raio * raio
	var posicoes_ocupadas: Array[Vector2] = []
	
	# Quantidades otimizadas para a Radeon Vega 8 (~250x250m)
	var qtd_arvores = max(10, int(area / 145.0))   # ~320 ï¿½rvores
	var qtd_rochas = max(4, int(area / 380.0))     # ~125 rochas
	var qtd_arbustos = max(5, int(area / 260.0))   # ~180 arbustos
	var qtd_gravetos = max(10, int(area / 180.0))  # ~265 gravetos
	var qtd_pedrinhas = max(10, int(area / 200.0)) # ~240 pedrinhas
	
	print("?? Gerando Mundo Procedural -> ï¿½rvores:", qtd_arvores, " | Rochas:", qtd_rochas, " | Arbustos:", qtd_arbustos)
	
	_espalhar(cena_arvore, qtd_arvores, raio, 4.0, posicoes_ocupadas, true, 145.0, true)
	_espalhar(cena_rocha, qtd_rochas, raio, 3.0, posicoes_ocupadas, true, 95.0, false)
	_espalhar(cena_arbusto, qtd_arbustos, raio, 2.2, posicoes_ocupadas, true, 55.0, false)
	_espalhar(cena_graveto, qtd_gravetos, raio, 1.5, posicoes_ocupadas, false, 28.0, false)
	_espalhar(cena_pedrinha, qtd_pedrinhas, raio, 1.5, posicoes_ocupadas, false, 28.0, false)
	
	if not Engine.is_editor_hint():
		Global.atualizar_navmesh_otimizado()

func aplicar_otimizacao_item(inst: Node3D):
	if not is_instance_valid(inst):
		return
	var dist_visao := 130.0
	var sombra := true
	
	if inst.is_in_group("arvores"):
		dist_visao = 145.0; sombra = true
	elif inst.is_in_group("pedras"):
		dist_visao = 130.0; sombra = true
	elif inst.is_in_group("arbustos"):
		dist_visao = 65.0; sombra = false
	elif inst.is_in_group("coletaveis_chao"):
		dist_visao = 28.0; sombra = false
		
	for sub in inst.get_children():
		if sub is MeshInstance3D:
			if not sombra:
				sub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sub.visibility_range_begin = 0.0
			sub.visibility_range_end = dist_visao
			sub.visibility_range_end_margin = 8.0
			sub.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _espalhar(cena: PackedScene, qtd: int, raio: float, dist_min: float, ocupadas: Array[Vector2], bloquear_nav: bool, dist_visao: float, sombra: bool):
	if not cena:
		return
	var dist_min_sq = dist_min * dist_min
	
	# Pega a posiï¿½ï¿½o exata do Jogador e da Bancada para nunca spawnar nada em cima deles
	var jogador = get_tree().current_scene.get_node_or_null("Jogador") if not Engine.is_editor_hint() else null
	var bancada = get_tree().current_scene.get_node_or_null("Bancada")
	var pos_jogador = Vector2(jogador.global_position.x, jogador.global_position.z) if is_instance_valid(jogador) else Vector2.ZERO
	var pos_bancada = Vector2(bancada.global_position.x, bancada.global_position.z) if is_instance_valid(bancada) else Vector2.ZERO
	
	for i in range(qtd):
		var pos_valida = false
		var px = 0.0
		var pz = 0.0
		
		for tentativa in range(20):
			px = randf_range(-raio, raio)
			pz = randf_range(-raio, raio)
			var candidata = Vector2(px, pz)
			
			# Mantï¿½m uma zona segura de 8m ao redor do Jogador e da Bancada (64.0 = 8m^2)
			if candidata.distance_squared_to(pos_jogador) < 64.0 or candidata.distance_squared_to(pos_bancada) < 64.0:
				continue
				
			pos_valida = true
			for p in ocupadas:
				if candidata.distance_squared_to(p) < dist_min_sq:
					pos_valida = false
					break
			if pos_valida:
				break
				
		if pos_valida:
			if bloquear_nav:
				ocupadas.append(Vector2(px, pz))
			var inst = cena.instantiate()
			inst.position = Vector3(px, _obter_altura_chao(px, pz), pz)
			inst.rotation.y = randf_range(0, TAU)
			add_child(inst)
			
			if Engine.is_editor_hint():
				inst.owner = get_tree().edited_scene_root
			if bloquear_nav:
				inst.add_to_group("navegavel", true)
				
			for sub in inst.get_children():
				if sub is MeshInstance3D:
					var chave_m = cena.resource_path + ":" + sub.name
					if not _cache_meshes_vega8.has(chave_m) and sub.mesh:
						_cache_meshes_vega8[chave_m] = sub.mesh
					elif _cache_meshes_vega8.has(chave_m):
						sub.mesh = _cache_meshes_vega8[chave_m]
					if not sombra:
						sub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					sub.visibility_range_begin = 0.0
					sub.visibility_range_end = dist_visao
					sub.visibility_range_end_margin = 8.0
					sub.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _process(delta):
	if Engine.is_editor_hint():
		return
		
	# 1. Ciclo de Spawn de Fauna (Coelhos e Cervos)
	_timer_fauna -= delta
	if _timer_fauna <= 0.0:
		_timer_fauna = 8.0
		_spawnar_fauna()
		
	# 2. Ciclo de Spawn de Inimigos Noturnos (20:00 ï¿½s 06:00)
	if Global.esta_de_noite():
		_timer_inimigos -= delta
		if _timer_inimigos <= 0.0:
			_timer_inimigos = 14.0
			_spawnar_inimigo_noturno()

func _spawnar_fauna():
	if not cena_animal:
		return
	if get_tree().get_nodes_in_group("animais").size() >= max_animais:
		return
		
	var inst = cena_animal.instantiate()
	inst.especie = "cervo" if randf() < 0.3 else "coelho"
	if inst.especie == "cervo":
		inst.scale = Vector3(1.5, 1.5, 1.5)
	get_tree().current_scene.add_child(inst)
	
	var px = randf_range(-100.0, 100.0)
	var pz = randf_range(-100.0, 100.0)
	inst.global_position = Vector3(px, _obter_altura_chao(px, pz) + 0.5, pz)

func _spawnar_inimigo_noturno():
	if not cena_inimigo:
		return
	if get_tree().get_nodes_in_group("inimigos").size() >= max_inimigos_noite:
		return
		
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	var centro = jogador.global_position if is_instance_valid(jogador) else Vector3.ZERO
	
	# Nasce a uma distï¿½ncia segura (entre 28m e 45m do jogador)
	var ang = randf_range(0, TAU)
	var dist = randf_range(28.0, 45.0)
	var px = clamp(centro.x + cos(ang) * dist, -110.0, 110.0)
	var pz = clamp(centro.z + sin(ang) * dist, -110.0, 110.0)
	
	var inst = cena_inimigo.instantiate()
	get_tree().current_scene.add_child(inst)
	inst.global_position = Vector3(px, _obter_altura_chao(px, pz) + 0.5, pz)
	print("?? Uma criatura surgiu na escuridï¿½o da floresta!")
