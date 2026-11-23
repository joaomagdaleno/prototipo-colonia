extends CharacterBody3D

const VELOCIDADE := 3.0
const GRAVIDADE := 9.8

var energia: float = 100.0
var fome: float = 0.0
var dormindo: bool = false

var mochila: Dictionary = {
	"madeira": 0,
	"pedra": 0,
	"gravetos": 0,
	"pedrinhas": 0,
	"frutas": 0
}
const CAPACIDADE_MOCHILA := 15

func obter_capacidade_maxima() -> int:
	return 30 if Global.equipe_mochilas else CAPACIDADE_MOCHILA

func obter_carga_mochila() -> int:
	var total = 0
	for qtd in mochila.values():
		total += int(qtd)
	return total


var profissao: String = "Geral"
const PROFISSOES := ["Geral", "Agricultor", "Construtor", "Coletor"]

func alternar_profissao():
	var idx = (PROFISSOES.find(profissao) + 1) % PROFISSOES.size()
	profissao = PROFISSOES[idx]
	tarefas.limpar_alvos()

func obter_bonus_profissao(tipo_tarefa: String) -> float:
	if profissao == "Agricultor" and tipo_tarefa in ["colher_canteiro", "plantar_canteiro", "arbusto"]: return 0.75
	if profissao == "Construtor" and tipo_tarefa == "projeto": return 0.75
	if profissao == "Coletor" and tipo_tarefa in ["arvore", "pedra", "coletavel"]: return 0.75
	return 1.0

var esta_trabalhando: bool = false
var tempo_trabalhando: float = 0.0
var tempo_tentando: float = 0.0
var tempo_espera: float = 1.5

var posicao_anterior: Vector3 = Vector3.ZERO
var tempo_preso: float = 0.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var tarefas = $Tarefas

func _ready():
	add_to_group("colonos")
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.5
	agent.avoidance_enabled = true
	agent.radius = 0.4
	agent.velocity_computed.connect(_on_velocity_computed)
	_otimizar_renderizacao_vega8()
	posicao_anterior = global_position

func _physics_process(delta):
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVIDADE * delta

	# 1. Necessidade de Fome (Consome do Global ou dos Baus construidos)
	fome = clamp(fome + 1.2 * delta, 0.0, 100.0)
	if fome >= 70.0:
		_tentar_alimentar_colono()

	# 2. Estado Dormindo
	if dormindo:
		agent.set_velocity(Vector3.ZERO)
		velocity.x = 0; velocity.z = 0; move_and_slide()
		var taxa = 15.0 if is_instance_valid(tarefas.alvo_cama) else 5.0
		energia = clamp(energia + taxa * delta, 0.0, 100.0)
		if energia >= 95.0 and not Global.esta_de_noite():
			dormindo = false
			if is_instance_valid(tarefas.alvo_cama):
				tarefas.alvo_cama.ocupada = false
			tarefas.limpar_alvos()
		return

	if tempo_espera > 0:
		tempo_espera -= delta
		velocity.x = 0; velocity.z = 0; move_and_slide()
		return

	# 3. Executando Tarefa no Local
	if esta_trabalhando:
		agent.set_velocity(Vector3.ZERO)
		tempo_trabalhando += delta
		velocity.x = 0; velocity.z = 0; move_and_slide()
		var alvo_atual = tarefas.obter_alvo_atual()
		var fator = Global.obter_fator_logistica(alvo_atual.global_position) if is_instance_valid(alvo_atual) else 1.0
		
		var mult_ferr = 0.5 if Global.equipe_ferramentas else 1.0
		var mult_prof = obter_bonus_profissao(tarefas.tipo_alvo)
		if tempo_trabalhando > 0.5 * fator * mult_ferr * mult_prof:
			tarefas.concluir_trabalho(fator)
			esta_trabalhando = false
			tempo_trabalhando = 0.0
			tempo_tentando = 0.0
			tempo_espera = 0.8
		return

	# 4. Escolher Próxima Tarefa
	if not tarefas.tem_alvo():
		var destino = tarefas.escolher_proxima_tarefa()
		if destino != Vector3.INF:
			tempo_tentando = 0.0
			agent.target_position = destino
		else:
			tempo_espera = 0.5
			velocity.x = 0; velocity.z = 0; move_and_slide()
		return

	# 5. Navegar até o Alvo
	var alvo = tarefas.obter_alvo_atual()
	if not is_instance_valid(alvo):
		tarefas.limpar_alvos()
		return

	tempo_tentando += delta
	if tempo_tentando > 12.0:
		tarefas.cancelar_e_ignorar_atual()
		tempo_tentando = 0.0
		return

	var dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(alvo.global_position.x, alvo.global_position.z))
	if dist < 1.8:
		if tarefas.alvo_cama != null:
			dormindo = true
		elif tarefas.alvo != null and not tarefas.alvo.pode_pagar():
			tarefas.alvo.reservado = false; tarefas.limpar_alvos(); tempo_espera = 1.0
		else:
			esta_trabalhando = true
		return

	var direcao = Vector3.ZERO
	if not agent.is_navigation_finished():
		direcao = agent.get_next_path_position() - global_position
	direcao.y = 0
	if direcao.length() < 0.1:
		direcao = agent.target_position - global_position
		direcao.y = 0

	if direcao.length() > 0.1:
		direcao = direcao.normalized()
		var vel = _calcular_velocidade_atual()
		rotation.y = lerp_angle(rotation.y, atan2(direcao.x, direcao.z), 0.1)
		agent.set_velocity(Vector3(direcao.x * vel, velocity.y, direcao.z * vel))
	else:
		velocity.x = 0; velocity.z = 0
		agent.set_velocity(Vector3.ZERO)
		move_and_slide()

	if global_position.distance_to(posicao_anterior) < 0.05 and dist > 1.8:
		tempo_preso += delta
		if tempo_preso > 1.5:
			tarefas.cancelar_e_ignorar_atual()
			tempo_tentando = 0.0; tempo_preso = 0.0
	else:
		tempo_preso = 0.0
	posicao_anterior = global_position

func _tentar_alimentar_colono():
	if Global.comida > 0:
		Global.comida -= 1
		fome = 0.0
		return
	for bau in Global.baus_ativos:
		if is_instance_valid(bau) and bau.construida and bau.has_method("retirar_item_do_bau"):
			if bau.retirar_item_do_bau("comida", 1) > 0:
				fome = 0.0
				print("Colono pegou comida pronta do Bau!")
				return

	if Global.frutas > 0:
		Global.frutas -= 1
		fome = 30.0
		return
	for bau in Global.baus_ativos:
		if is_instance_valid(bau) and bau.construida and bau.has_method("retirar_item_do_bau"):
			if bau.retirar_item_do_bau("frutas", 1) > 0:
				fome = 30.0
				print("Colono pegou frutas do Bau!")
				return

func _calcular_velocidade_atual() -> float:
	var mult_moch = 1.2 if Global.equipe_mochilas else 1.0
	var cx = int(round(global_position.x))
	var cz = int(round(global_position.z))
	for ox in [-1, 0, 1]:
		for oz in [-1, 0, 1]:
			if Global.estradas_pos.has(Vector2i(cx + ox, cz + oz)):
				return 4.5 * mult_moch
	return VELOCIDADE * mult_moch

func obter_status_texto() -> String:
	var est = "[" + profissao + "] " + str(int(energia)) + "%"
	var carga = obter_carga_mochila()
	if dormindo:
		agent.set_velocity(Vector3.ZERO)
		return "💤 Dormindo (" + est + ")"
	if esta_trabalhando:
		agent.set_velocity(Vector3.ZERO)
		if is_instance_valid(tarefas.alvo): return "🔨 Construindo (" + est + ")"
		if is_instance_valid(tarefas.alvo_arvore): return "🪓 Cortando (" + est + ")"
		if is_instance_valid(tarefas.alvo_pedra): return "⛏ Minerando (" + est + ")"
		if tarefas.tipo_alvo == "colher_canteiro": return "🌾 Colhendo canteiro (" + est + ")" 
		if tarefas.tipo_alvo == "plantar_canteiro": return "🌱 Plantando canteiro (" + est + ")" 
		if tarefas.tipo_alvo == "bau": return "📦 Guardando (" + est + ")"
		return "🌿 Coletando (" + est + ")"
	if tarefas.tem_alvo():
		if tarefas.tipo_alvo == "colher_canteiro": return "🌾 Colhendo canteiro (" + est + ")" 
		if tarefas.tipo_alvo == "plantar_canteiro": return "🌱 Plantando canteiro (" + est + ")" 
		if tarefas.tipo_alvo == "bau":
			return "📦 Levando ao Baú [" + str(carga) + "/" + str(obter_capacidade_maxima()) + "] (" + est + ")"
		return "🚶 Indo trabalhar (" + est + ")"
	return "⏳ Sem ordens (" + est + ")"

func _otimizar_renderizacao_vega8():
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			filho.visibility_range_begin = 0.0
			filho.visibility_range_end = 95.0
			filho.visibility_range_end_margin = 5.0
			filho.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _on_velocity_computed(safe_velocity: Vector3):
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()
