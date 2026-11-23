extends CharacterBody3D

## Inimigo Noturno com Navegaï¿½ï¿½o Inteligente (NavMesh) e Mï¿½quina de Estados (FSM)

enum Estado { PERSEGUIR, ATACAR, FUGIR_FOGO }

@export var vida: int = 4
@export var velocidade: float = 3.6
@export var dano_ataque: int = 15

var estado_atual: Estado = Estado.PERSEGUIR
var tempo_recarga_ataque: float = 0.0
var jogador: CharacterBody3D = null

var _timer_fogueira: float = 0.0
var _dir_fuga_fogo: Vector3 = Vector3.ZERO
var _timer_repensar_caminho: float = 0.0
var _movendo_via_rvo: bool = false

const GRAVIDADE := 12.0

@onready var agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

func _ready():
	add_to_group("inimigos")
	jogador = get_tree().current_scene.get_node_or_null("Jogador")
	_timer_fogueira = randf_range(0.05, 0.25)
	if is_instance_valid(agent):
		agent.avoidance_enabled = true
		agent.radius = 0.45
		agent.velocity_computed.connect(_on_velocity_computed)
	_timer_repensar_caminho = randf_range(0.05, 0.35)
	_otimizar_renderizacao_vega8()

func _otimizar_renderizacao_vega8():
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.visibility_range_begin = 0.0
			filho.visibility_range_end = 90.0
			filho.visibility_range_end_margin = 5.0
			filho.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _physics_process(delta):
	# Ao amanhecer, dissolve na floresta
	if not Global.esta_de_noite():
		queue_free()
		return

	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVIDADE * delta
	if tempo_recarga_ataque > 0.0:
		tempo_recarga_ataque -= delta

	if not is_instance_valid(jogador):
		jogador = get_tree().current_scene.get_node_or_null("Jogador")

	# 1. Checagem periï¿½dica de fogueiras acesas (5 vezes por segundo)
	_timer_fogueira -= delta
	if _timer_fogueira <= 0.0:
		_timer_fogueira = 0.2
		_verificar_repulsao_fogo()

	# 2. Execuï¿½ï¿½o da Mï¿½quina de Estados
	_movendo_via_rvo = false
	match estado_atual:
		Estado.FUGIR_FOGO:
			_executar_fuga(delta)
		Estado.PERSEGUIR:
			_executar_perseguicao(delta)
		Estado.ATACAR:
			_executar_ataque(delta)

	if not _movendo_via_rvo:
		move_and_slide()

func _verificar_repulsao_fogo():
	var fugir = false
	for est in Global.fogueiras_ativas:
		if is_instance_valid(est) and "is_fogueira" in est and est.is_fogueira:
			if est.luz and est.luz.visible:
				# 36.0 = 6 metros de raio de proteï¿½ï¿½o da fogueira
				if global_position.distance_squared_to(est.global_position) < 36.0:
					var vet_fuga = global_position - est.global_position
					vet_fuga.y = 0
					_dir_fuga_fogo = vet_fuga.normalized()
					fugir = true
					break

	if fugir:
		estado_atual = Estado.FUGIR_FOGO
	elif estado_atual == Estado.FUGIR_FOGO:
		estado_atual = Estado.PERSEGUIR

func _executar_fuga(_delta: float):
	velocity.x = _dir_fuga_fogo.x * (velocidade * 1.25)
	velocity.z = _dir_fuga_fogo.z * (velocidade * 1.25)
	rotation.y = lerp_angle(rotation.y, atan2(_dir_fuga_fogo.x, _dir_fuga_fogo.z), 0.15)

func _executar_perseguicao(delta: float):
	if not is_instance_valid(jogador) or jogador.no_modo_construcao:
		velocity.x = 0; velocity.z = 0; if is_instance_valid(agent): agent.set_velocity(Vector3.ZERO)
		return

	var dist_jogador = global_position.distance_to(jogador.global_position)
	if dist_jogador > 28.0:
		velocity.x = 0; velocity.z = 0; if is_instance_valid(agent): agent.set_velocity(Vector3.ZERO)
		return

	# Ataque direto ao alcance do jogador
	if dist_jogador <= 1.8:
		estado_atual = Estado.ATACAR
		return

	# Checa se hï¿½ um muro ou portï¿½o fechado diretamente bloqueando o caminho
	var obstaculo = _buscar_muro_a_frente()
	if obstaculo != null:
		estado_atual = Estado.ATACAR
		return

	# Atualiza o destino de navegaï¿½ï¿½o com throttling (3 vezes por seg) para economizar CPU
	_timer_repensar_caminho -= delta
	if _timer_repensar_caminho <= 0.0 and is_instance_valid(agent):
		_timer_repensar_caminho = randf_range(0.32, 0.48)
		agent.target_position = jogador.global_position

	var dir = Vector3.ZERO
	if is_instance_valid(agent) and not agent.is_navigation_finished():
		dir = agent.get_next_path_position() - global_position
		dir.y = 0
	else:
		dir = jogador.global_position - global_position
		dir.y = 0

	if dir.length() > 0.1:
		dir = dir.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.15)
		if is_instance_valid(agent):
			_movendo_via_rvo = true
			agent.set_velocity(Vector3(dir.x * velocidade, velocity.y, dir.z * velocidade))
			return
		velocity.x = dir.x * velocidade
		velocity.z = dir.z * velocidade
	else:
		velocity.x = 0; velocity.z = 0; if is_instance_valid(agent): agent.set_velocity(Vector3.ZERO)

func _executar_ataque(_delta: float):
	velocity.x = 0
	velocity.z = 0
	if is_instance_valid(agent): agent.set_velocity(Vector3.ZERO)

	if tempo_recarga_ataque > 0.0:
		return

	# 1. Prioridade de ataque: Jogador
	if is_instance_valid(jogador) and global_position.distance_to(jogador.global_position) <= 2.0:
		tempo_recarga_ataque = 1.5
		Global.aplicar_dano_jogador(dano_ataque)
		return

	# 2. Ataque a muros / portï¿½es que bloqueiam a passagem
	var muro = _buscar_muro_a_frente()
	if muro != null:
		tempo_recarga_ataque = 1.5
		muro.receber_dano_estrutura(dano_ataque)
		return

	# Se o alvo se afastou ou o muro caiu, volta a perseguir
	estado_atual = Estado.PERSEGUIR

func _buscar_muro_a_frente() -> EstruturaConstruivel:
	var pos := global_position
	for est in Global.fogueiras_ativas:
		if is_instance_valid(est) and est is EstruturaConstruivel:
			if est.is_muro or est.is_parede or (est.is_portao and not est.portao_aberto):
				if pos.distance_squared_to(est.global_position) <= 3.24: # 1.8 metros
					return est
	return null

func receber_dano(dano: int):
	var malhas = get_children().filter(func(n): return n is MeshInstance3D)
	if not malhas.is_empty():
		var tween = create_tween()
		for f in malhas:
			tween.parallel().tween_property(f, "scale", Vector3(1.18, 0.82, 1.18), 0.06)
			tween.tween_property(f, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	print("Golpe na criatura! Vida restante: ", max(0, vida - dano))
	vida -= dano
	if is_instance_valid(jogador):
		var empurrao = (global_position - jogador.global_position).normalized()
		velocity.x = empurrao.x * 6.0
		velocity.z = empurrao.z * 6.0

	if vida <= 0:
		Global.couro += 2
		print("💀 Criatura noturna derrotada! +2 Couro")
		queue_free()

func _on_velocity_computed(safe_velocity: Vector3):
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()
