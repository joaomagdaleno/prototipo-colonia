extends CharacterBody3D

@export_enum("coelho", "cervo") var especie: String = "coelho"
var vida: int = 1
var carne_ao_abater: int = 2
var couro_ao_abater: int = 1

var vel_passeio: float = 1.8
var vel_fuga: float = 6.5
var raio_audicao_em_pe: float = 9.0
var raio_audicao_agachado: float = 2.5

var direcao_atual: Vector3 = Vector3.ZERO
var tempo_mudar_direcao: float = 0.0
var fugindo: bool = false
var tempo_fuga: float = 0.0
var jogador: CharacterBody3D

# Controle de hibernaï¿½ï¿½o para economizar CPU/Fï¿½sica
var hibernando: bool = false
var _timer_hibernacao: float = 0.0
const DISTANCIA_HIBERNACAO := 65.0
const GRAVIDADE := 12.0

func _ready():
	add_to_group("animais")
	if especie == "cervo":
		vida = 2
		carne_ao_abater = 5
		couro_ao_abater = 3
		vel_fuga = 8.0
		raio_audicao_em_pe = 12.0
		raio_audicao_agachado = 3.2
	jogador = get_tree().current_scene.get_node_or_null("Jogador")
	_otimizar_renderizacao_vega8()
	# Espalha o tempo inicial para nem todos checarem no mesmo frame
	_timer_hibernacao = randf_range(0.1, 0.8)

func _otimizar_renderizacao_vega8():
	for filho in get_children():
		if filho is MeshInstance3D:
			# Coelhos sï¿½o muito pequenos para projetar sombra em tempo real
			if especie == "coelho":
				filho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			filho.visibility_range_begin = 0.0
			filho.visibility_range_end = 75.0
			filho.visibility_range_end_margin = 5.0
			filho.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _physics_process(delta):
	if not is_instance_valid(jogador):
		jogador = get_tree().current_scene.get_node_or_null("Jogador")

	# Verifica se estï¿½ longe o suficiente para hibernar (economiza move_and_slide)
	_timer_hibernacao -= delta
	if _timer_hibernacao <= 0.0:
		_timer_hibernacao = 0.8
		var cam_ativa = get_viewport().get_camera_3d()
		if is_instance_valid(cam_ativa):
			var dist_cam = global_position.distance_squared_to(cam_ativa.global_position)
			hibernando = dist_cam > (DISTANCIA_HIBERNACAO * DISTANCIA_HIBERNACAO)

	if hibernando:
		return

	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	else:
		velocity.y = 0

	# 1. Verifica proximidade e furtividade do Jogador
	if is_instance_valid(jogador) and not jogador.no_modo_construcao:
		var dist = global_position.distance_to(jogador.global_position)
		var esta_agachado = "agachado" in jogador and jogador.agachado
		var raio_alerta = raio_audicao_agachado if esta_agachado else raio_audicao_em_pe
		
		# Se o jogador estiver correndo, o raio de audiï¿½ï¿½o aumenta!
		if Input.is_action_pressed("correr") and not esta_agachado:
			raio_alerta *= 1.6
			
		if dist <= raio_alerta:
			fugindo = true
			tempo_fuga = 4.0
			var dir_oposta = (global_position - jogador.global_position)
			dir_oposta.y = 0
			direcao_atual = dir_oposta.normalized()

	# 2. Comportamento de Fuga ou Passeio Aleatï¿½rio
	if fugindo:
		tempo_fuga -= delta
		if tempo_fuga <= 0:
			fugindo = false
		velocity.x = direcao_atual.x * vel_fuga
		velocity.z = direcao_atual.z * vel_fuga
	else:
		tempo_mudar_direcao -= delta
		if tempo_mudar_direcao <= 0:
			tempo_mudar_direcao = randf_range(2.0, 5.0)
			if randf() < 0.35:
				direcao_atual = Vector3.ZERO # Fica parado pastando
			else:
				var ang = randf_range(0, TAU)
				direcao_atual = Vector3(cos(ang), 0, sin(ang))
		velocity.x = direcao_atual.x * vel_passeio
		velocity.z = direcao_atual.z * vel_passeio

	if direcao_atual.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direcao_atual.x, direcao_atual.z), 0.15)

	move_and_slide()

# Chamado pelo Jogador ao golpear com o machado (Clique Esquerdo / R2)
func receber_dano(dano: int):
	hibernando = false
	vida -= dano
	fugindo = true
	tempo_fuga = 5.0
	if is_instance_valid(jogador):
		var dir_oposta = (global_position - jogador.global_position)
		dir_oposta.y = 0
		direcao_atual = dir_oposta.normalized()
		
	if vida <= 0:
		Global.carne_crua += carne_ao_abater
		Global.couro += couro_ao_abater
		print("🦌 Caça abatida (", especie, ")! +", carne_ao_abater, " Carne Crua | +", couro_ao_abater, " Couro")
		queue_free()
