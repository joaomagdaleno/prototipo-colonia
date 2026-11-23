extends Node

@export var opcoes_mobilia: Array[PackedScene]
var indice_mobilia: int = 0
var rotacao_mobilia: float = 0.0
var fantasma_1p: Node3D = null
var _forma_snap: SphereShape3D = null
var _ultima_celula_snap: Vector3i = Vector3i(999999, 999999, 999999)
var _cache_vizinhos_snap: Array[Node3D] = []

@onready var jogador: CharacterBody3D = get_parent()
@onready var camera: Camera3D = get_parent().get_node("Camera3D")

func alternar_modo():
	if opcoes_mobilia.is_empty():
		print("AVISO: Adicione as cenas em 'Opcoes Mobilia' no Inspetor do nó Mobilia!")
		return
		
	jogador.construindo_1p = not jogador.construindo_1p
	if jogador.construindo_1p:
		selecionar_peca(indice_mobilia)
	else:
		if is_instance_valid(fantasma_1p):
			fantasma_1p.queue_free()
			fantasma_1p = null

func selecionar_peca(novo_indice: int):
	indice_mobilia = clamp(novo_indice, 0, opcoes_mobilia.size() - 1)
	if is_instance_valid(fantasma_1p):
		fantasma_1p.queue_free()
		
	var cena = opcoes_mobilia[indice_mobilia]
	if cena:
		fantasma_1p = cena.instantiate()
		get_tree().current_scene.add_child(fantasma_1p)
		fantasma_1p.visible = true
		fantasma_1p.remove_from_group("projetos")
		
		if fantasma_1p.has_node("CorpoFisico"):
			fantasma_1p.get_node("CorpoFisico").collision_layer = 0
		if fantasma_1p.has_node("AreaInteracao"):
			fantasma_1p.get_node("AreaInteracao").monitoring = false

func processar_inputs_mobilia(event: InputEvent):
	if not jogador.construindo_1p or opcoes_mobilia.is_empty():
		return
		
	if event.is_action_pressed("girar_esquerda"):
		rotacao_mobilia -= PI / 2.0
	elif event.is_action_pressed("girar_direita"):
		rotacao_mobilia += PI / 2.0
	elif event.is_action_pressed("peca_anterior"):
		selecionar_peca((indice_mobilia - 1 + opcoes_mobilia.size()) % opcoes_mobilia.size())
	elif event.is_action_pressed("peca_proxima"):
		selecionar_peca((indice_mobilia + 1) % opcoes_mobilia.size())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selecionar_peca((indice_mobilia - 1 + opcoes_mobilia.size()) % opcoes_mobilia.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selecionar_peca((indice_mobilia + 1) % opcoes_mobilia.size())
	elif event is InputEventKey and event.pressed and not event.echo:
		var num_tecla = event.keycode - KEY_1
		if num_tecla >= 0 and num_tecla < opcoes_mobilia.size() and num_tecla != indice_mobilia:
			selecionar_peca(num_tecla)

func atualizar_fantasma():
	if not is_instance_valid(fantasma_1p):
		return
		
	var origem = camera.global_position
	var destino = origem - camera.global_transform.basis.z * 6.0
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [jogador, fantasma_1p]
	query.collision_mask = 1
	var resultado = jogador.get_world_3d().direct_space_state.intersect_ray(query)
	
	var pos_alvo: Vector3
	if resultado:
		pos_alvo = resultado.position
	else:
		var frente_plana = -jogador.transform.basis.z
		frente_plana.y = 0
		pos_alvo = jogador.global_position + frente_plana.normalized() * 3.0
		pos_alvo.y = 0.0
	
	# SISTEMA DE SNAP MODULAR INTELIGENTE (Pisos, Paredes e Tetos)
	pos_alvo = _calcular_snap_modular(pos_alvo)
	
	fantasma_1p.global_position = fantasma_1p.global_position.lerp(pos_alvo, 0.35)
	fantasma_1p.rotation.y = lerp_angle(fantasma_1p.rotation.y, rotacao_mobilia, 0.35)
	_atualizar_cor(_posicao_livre(fantasma_1p.global_position))

func _obter_estruturas_proximas(pos_alvo: Vector3) -> Array[Node3D]:
var celula_atual = Vector3i(roundi(pos_alvo.x), roundi(pos_alvo.y), roundi(pos_alvo.z))
if celula_atual == _ultima_celula_snap:
return _cache_vizinhos_snap

_ultima_celula_snap = celula_atual
_cache_vizinhos_snap.clear()

if _forma_snap == null:
_forma_snap = SphereShape3D.new()
_forma_snap.radius = 3.5

var query = PhysicsShapeQueryParameters3D.new()
query.shape = _forma_snap
query.transform = Transform3D(Basis(), pos_alvo)
query.collision_mask = 1
query.collide_with_bodies = true
query.collide_with_areas = false

var resultados = jogador.get_world_3d().direct_space_state.intersect_shape(query, 64)
var vistos: Dictionary = {}
for hit in resultados:
var col = hit.get("collider")
if not is_instance_valid(col):
continue
var est = col.get_parent()
if not is_instance_valid(est) or est == fantasma_1p or vistos.has(est):
continue
vistos[est] = true
if est is Node3D:
_cache_vizinhos_snap.append(est)

return _cache_vizinhos_snap

func _calcular_snap_modular(pos_alvo: Vector3) -> Vector3:
var vizinhos = _obter_estruturas_proximas(pos_alvo)

# 1. Snap para Pisos (grade de 1x1)
if fantasma_1p.is_in_group("pisos"):
var melhor_encaixe = pos_alvo
var menor_dist = 1.3
for piso in vizinhos:
if not is_instance_valid(piso) or not piso.is_in_group("pisos"): continue
for dir in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]:
var ponto = piso.global_position + dir.rotated(Vector3.UP, piso.rotation.y)
var d = Vector2(pos_alvo.x, pos_alvo.z).distance_to(Vector2(ponto.x, ponto.z))
if d < menor_dist:
menor_dist = d
melhor_encaixe = ponto
rotacao_mobilia = piso.rotation.y
return melhor_encaixe

# 2. Snap para Portao dentro de Batente de Porta
if "is_portao" in fantasma_1p and fantasma_1p.is_portao:
var menor_dist = 1.5
var melhor_encaixe = pos_alvo
for batente in vizinhos:
if not is_instance_valid(batente) or not batente.is_in_group("batentes"): continue
var d = pos_alvo.distance_to(batente.global_position)
if d < menor_dist:
menor_dist = d
melhor_encaixe = batente.global_position
rotacao_mobilia = batente.rotation.y
return melhor_encaixe

# 3. Snap para Paredes, Paredes com Janela e Batentes de Porta
if fantasma_1p.is_in_group("paredes") or ("is_parede" in fantasma_1p and fantasma_1p.is_parede):
var menor_dist = 1.6
var melhor_encaixe = pos_alvo

for est in vizinhos:
if not is_instance_valid(est): continue
if est.is_in_group("pisos"):
for borda in [Vector3(0, 0, 0.5), Vector3(0, 0, -0.5), Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0)]:
var ponto = est.global_position + borda.rotated(Vector3.UP, est.rotation.y)
var d = Vector2(pos_alvo.x, pos_alvo.z).distance_to(Vector2(ponto.x, ponto.z))
if d < menor_dist:
menor_dist = d
melhor_encaixe = Vector3(ponto.x, est.global_position.y, ponto.z)
rotacao_mobilia = est.rotation.y + (PI/2.0 if abs(borda.x) > 0.0 else 0.0)
elif est.is_in_group("paredes") or ("is_parede" in est and est.is_parede):
for dir in [Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0)]:
var ponto = est.global_position + dir.rotated(Vector3.UP, est.rotation.y)
var d = pos_alvo.distance_to(ponto)
if d < menor_dist:
menor_dist = d
melhor_encaixe = ponto
rotacao_mobilia = est.rotation.y
return melhor_encaixe

# 4. Snap para Tetos (encaixa no topo de Paredes a 2.4m de altura)
if fantasma_1p.is_in_group("tetos") or ("is_teto" in fantasma_1p and fantasma_1p.is_teto):
var menor_dist = 1.6
var melhor_encaixe = pos_alvo
for est in vizinhos:
if not is_instance_valid(est): continue
if est.is_in_group("pisos"):
var topo_piso = est.global_position + Vector3(0, 2.4, 0)
var d = Vector2(pos_alvo.x, pos_alvo.z).distance_to(Vector2(topo_piso.x, topo_piso.z))
if d < menor_dist:
menor_dist = d
melhor_encaixe = topo_piso
rotacao_mobilia = est.rotation.y
elif est.is_in_group("tetos") or ("is_teto" in est and est.is_teto):
for dir in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]:
var ponto = est.global_position + dir.rotated(Vector3.UP, est.rotation.y)
var d = Vector2(pos_alvo.x, pos_alvo.z).distance_to(Vector2(ponto.x, ponto.z))
if d < menor_dist:
menor_dist = d
melhor_encaixe = ponto
rotacao_mobilia = est.rotation.y
return melhor_encaixe

# 5. Snap lateral para Muros de Pedra (1.0m)
if "is_muro" in fantasma_1p and fantasma_1p.is_muro:
var menor_dist = 1.4
var melhor_encaixe = pos_alvo
for m in vizinhos:
if not is_instance_valid(m) or not ("is_muro" in m and m.is_muro): continue
for dir in [Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0)]:
var ponto = m.global_position + dir.rotated(Vector3.UP, m.rotation.y)
var d = pos_alvo.distance_to(ponto)
if d < menor_dist:
menor_dist = d
melhor_encaixe = ponto
rotacao_mobilia = m.rotation.y
return melhor_encaixe

# 6. Apoiar moveis/estruturas sobre Pisos sem afundar
for piso in vizinhos:
if is_instance_valid(piso) and piso.is_in_group("pisos") and abs(pos_alvo.x - piso.global_position.x) <= 0.55 and abs(pos_alvo.z - piso.global_position.z) <= 0.55:
pos_alvo.y = max(pos_alvo.y, piso.global_position.y + 0.1)
break

return pos_alvo

func _posicao_livre(pos: Vector3) -> bool:
	var segurando_piso = fantasma_1p.is_in_group("pisos")
	var segurando_teto = fantasma_1p.is_in_group("tetos") or ("is_teto" in fantasma_1p and fantasma_1p.is_teto)
	var segurando_parede = fantasma_1p.is_in_group("paredes") or ("is_parede" in fantasma_1p and fantasma_1p.is_parede)
	var segurando_portao = "is_portao" in fantasma_1p and fantasma_1p.is_portao

	for p in _obter_estruturas_proximas(pos):
		if p == fantasma_1p or not is_instance_valid(p):
			continue
		if not (p.is_in_group("projetos") or p.is_in_group("construidos")):
			continue
		# Permite encaixar o Portao exatamente dentro do Batente de Porta
		if segurando_portao and p.is_in_group("batentes"):
			continue
		# Pecas de tipos verticais diferentes podem sobrepor o plano horizontal
		if (segurando_piso and p.is_in_group("tetos")) or (segurando_teto and p.is_in_group("pisos")):
			continue
		if segurando_parede and (p.is_in_group("pisos") or p.is_in_group("tetos")):
			continue

		var dx = p.global_position.x - pos.x
		var dz = p.global_position.z - pos.z
		if (dx * dx + dz * dz) < 0.16 and abs(p.global_position.y - pos.y) < 0.5:
			return false
	return true


func _atualizar_cor(livre: bool):
	if not fantasma_1p.has_node("MeshInstance3D"): return
	var mesh_inst: MeshInstance3D = fantasma_1p.get_node("MeshInstance3D")
	var mat = mesh_inst.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat
	if not livre:
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
	elif fantasma_1p.has_method("pode_pagar") and not fantasma_1p.pode_pagar():
		mat.albedo_color = Color(1.0, 0.75, 0.15, 0.55)
	else:
		mat.albedo_color = Color(0.2, 1.0, 0.35, 0.55)

func colocar_peca():
	if not is_instance_valid(fantasma_1p) or not _posicao_livre(fantasma_1p.global_position):
		return
	var cena_atual = opcoes_mobilia[indice_mobilia]
	var novo_item = cena_atual.instantiate()
	novo_item.name = cena_atual.resource_path.get_file().get_basename()
	get_tree().current_scene.add_child(novo_item)
	novo_item.global_position = fantasma_1p.global_position
	novo_item.rotation.y = rotacao_mobilia
	novo_item.add_to_group("projetos")
	_ultima_celula_snap = Vector3i(999999, 999999, 999999)
	print("Projeto colocado: ", novo_item.name)