extends Node

## Estado Global do Jogo
## Centraliza recursos, tempo de mundo, metabolismo do jogador e eventos globais.

# Recursos Globais
var madeira: int = 0
var pedra: int = 0
var pedrinhas: int = 0
var gravetos: int = 0
var comida: int = 5
var frutas: int = 0
var carne_crua: int = 0
var couro: int = 0
var estradas_pos: Dictionary = {}
var baus_ativos: Array[Node3D] = []
var fogueiras_ativas: Array[Node3D] = []
var camas_ativas: Array[Node3D] = []
var canteiros_ativos: Array[Node3D] = []
var pocos_ativos: Array[Node3D] = []
var estoque_total_baus: Dictionary = {"madeira": 0, "pedra": 0, "gravetos": 0, "pedrinhas": 0, "comida": 0, "frutas": 0}

# Sobrevivência do Jogador
var vida_jogador: int = 100
const VIDA_MAX_JOGADOR: int = 100
var saciedade_jogador: float = 85.0
var hidratacao_jogador: float = 85.0
var tempo_sem_combate: float = 10.0
var _timer_metabolismo: float = 0.0

# Ferramentas e Equipamentos
var tem_machado_pedra: bool = false
var tier_machado: int = 0
var tier_picareta: int = 0
var tier_lanca: int = 0
var equipe_ferramentas: bool = false
var equipe_mochilas: bool = false
var tem_mochila_couro: bool = false
var usando_joystick: bool = false

# Tempo e Clima
var hora_do_dia: float = 8.0
var dia_atual: int = 1
const VELOCIDADE_TEMPO: float = 0.04
enum Clima { ENSOLARADO, NUBLADO, CHUVA, TEMPESTADE }
var clima_atual: Clima = Clima.ENSOLARADO
var _tempo_proximo_clima: float = 45.0

# Colonos
var cena_colono: PackedScene = preload("res://entities/Colono.tscn")
const CUSTO_CONTRATAR_COLONO: int = 10

var _timer_nav: Timer

# Atalhos para o SaveManager
var carregar_ao_iniciar: bool:
	get: return SaveManager.carregar_ao_iniciar
	set(v): SaveManager.carregar_ao_iniciar = v

func tem_save() -> bool: return SaveManager.tem_save()
func salvar_jogo() -> bool: return SaveManager.salvar_jogo()
func carregar_jogo() -> bool: return SaveManager.carregar_jogo()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.configurar_acoes()

	_timer_nav = Timer.new()
	_timer_nav.one_shot = true
	_timer_nav.wait_time = 0.4
	_timer_nav.timeout.connect(_atualizar_navmesh)
	add_child(_timer_nav)

func _input(event):
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if event is InputEventMouseMotion and event.relative.length() < 1.0:
			return
		usando_joystick = false
	elif event is InputEventJoypadButton:
		usando_joystick = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.25:
		usando_joystick = true

func _process(delta):
	if get_tree().paused:
		return

	# 1. Ciclo Dia e Noite
	hora_do_dia += VELOCIDADE_TEMPO * delta
	if hora_do_dia >= 24.0:
		hora_do_dia -= 24.0
		dia_atual += 1

	# 2. Variação Climática
	_tempo_proximo_clima -= delta
	if _tempo_proximo_clima <= 0:
		_tempo_proximo_clima = randf_range(40.0, 75.0)
		var sorteio = randf()
		if sorteio < 0.55:
			clima_atual = Clima.ENSOLARADO
		elif sorteio < 0.80:
			clima_atual = Clima.NUBLADO
		else:
			clima_atual = Clima.CHUVA
		print("🌦️ Clima mudou para: ", obter_texto_clima())

	# 3. Metabolismo e Regeneração (executa 1 vez por segundo)
	tempo_sem_combate += delta
	_timer_metabolismo += delta
	if _timer_metabolismo >= 1.0:
		_timer_metabolismo = 0.0
		_processar_metabolismo()

func _processar_metabolismo():
	saciedade_jogador = max(0.0, saciedade_jogador - 0.10)
	hidratacao_jogador = max(0.0, hidratacao_jogador - 0.14)

	# Cura passiva se bem alimentado, hidratado e fora de perigo
	if saciedade_jogador >= 70.0 and hidratacao_jogador >= 70.0 and tempo_sem_combate >= 6.0:
		if vida_jogador > 0 and vida_jogador < VIDA_MAX_JOGADOR:
			curar_jogador(2)

func esta_de_noite() -> bool:
	return hora_do_dia >= 20.0 or hora_do_dia < 6.0

func esta_chovendo() -> bool:
	return clima_atual == Clima.CHUVA or clima_atual == Clima.TEMPESTADE

func obter_texto_clima() -> String:
	match clima_atual:
		Clima.ENSOLARADO: return "☀️ Sol"
		Clima.NUBLADO: return "⛅ Nublado"
		Clima.TEMPESTADE: return "? Tempestade"
		Clima.CHUVA: return "🌧️ Chuva"
	return "☀️ Sol"

func obter_hora_formatada() -> String:
	var horas = int(hora_do_dia)
	var minutos = int((hora_do_dia - horas) * 60)
	return "%02d:%02d" % [horas, minutos]

func atualizar_navmesh_otimizado():
	_timer_nav.start()

func _atualizar_navmesh():
	pass

func obter_fator_logistica(pos_alvo: Vector3) -> float:
	var bancada = get_tree().current_scene.get_node_or_null("Bancada")
	if not bancada:
		for c in get_tree().get_nodes_in_group("construidos"):
			if "is_bancada" in c and c.is_bancada:
				bancada = c
				break

	if not bancada:
		return 1.0

	var distancia = Vector2(bancada.global_position.x, bancada.global_position.z).distance_to(Vector2(pos_alvo.x, pos_alvo.z))
	if distancia <= 15.0:
		return 1.0

	var tem_estrada_perto = false
	var cx = int(round(pos_alvo.x))
	var cz = int(round(pos_alvo.z))
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			if (dx * dx + dz * dz) <= 36 and estradas_pos.has(Vector2i(cx + dx, cz + dz)):
				tem_estrada_perto = true
				break
		if tem_estrada_perto:
			break

	var distancia_extra = distancia - 15.0
	if tem_estrada_perto:
		distancia_extra *= 0.5

	return 1.0 + (distancia_extra / 30.0)

func craftar_machado_pedra() -> bool:
	if tem_machado_pedra or gravetos < 3 or pedrinhas < 2:
		return false
	gravetos -= 3
	pedrinhas -= 2
	tem_machado_pedra = true
	print("🪓 Machado de Pedra fabricado!")
	return true

const CAPACIDADE_PESO_BASE := 15.0
const BONUS_PESO_MOCHILA := 15.0

func obter_peso_atual() -> float:
return (
pedra * 2.5 +
madeira * 1.5 +
carne_crua * 1.0 +
(comida + couro) * 0.8 +
(gravetos + pedrinhas + frutas) * 0.5
)

func obter_capacidade_peso() -> float:
return CAPACIDADE_PESO_BASE + (BONUS_PESO_MOCHILA if tem_mochila_couro else 0.0)

func esta_sobrecarregado() -> bool:
return obter_peso_atual() > obter_capacidade_peso()

func craftar_mochila_couro() -> bool:
	if tem_mochila_couro or couro < 4 or gravetos < 3:
		return false
	couro -= 4
	gravetos -= 3
	tem_mochila_couro = true
	print("🎒 Mochila de Couro fabricada!")
	return true

func contratar_colono() -> bool:
	var total_camas := 0
	for c in camas_ativas:
		if is_instance_valid(c) and c.construida:
			total_camas += 1
	if comida < CUSTO_CONTRATAR_COLONO or get_tree().get_nodes_in_group("colonos").size() >= total_camas:
		return false

	var bancada = get_tree().current_scene.get_node_or_null("Bancada")
	if not bancada:
		for c in get_tree().get_nodes_in_group("construidos"):
			if "is_bancada" in c and c.is_bancada:
				bancada = c
				break

	if not bancada:
		return false

	comida -= CUSTO_CONTRATAR_COLONO
	var novo_colono = cena_colono.instantiate()
	get_tree().current_scene.add_child(novo_colono)
	var offset = Vector3(randf_range(1.5, 3.0), 0.5, randf_range(-1.5, 1.5))
	novo_colono.global_position = bancada.global_position + offset
	return true

func iniciar_novo_jogo():
	madeira = 0; pedra = 0; pedrinhas = 0; gravetos = 0
	comida = 5; frutas = 0; carne_crua = 0; couro = 0
	estradas_pos.clear()
	baus_ativos.clear()
	fogueiras_ativas.clear()
	camas_ativas.clear()
	canteiros_ativos.clear()
	pocos_ativos.clear()
	estoque_total_baus = {"madeira": 0, "pedra": 0, "gravetos": 0, "pedrinhas": 0, "comida": 0, "frutas": 0}
	hora_do_dia = 8.0; dia_atual = 1
	clima_atual = Clima.ENSOLARADO
	tem_machado_pedra = false
	tem_mochila_couro = false
	vida_jogador = VIDA_MAX_JOGADOR
	saciedade_jogador = 85.0
	hidratacao_jogador = 85.0
	tempo_sem_combate = 10.0
	SaveManager.carregar_ao_iniciar = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world/Mundo.tscn")

func aplicar_dano_jogador(qtd: int):
	tempo_sem_combate = 0.0
	AudioManager.tocar("dano")
	vida_jogador = clamp(vida_jogador - qtd, 0, VIDA_MAX_JOGADOR)
	var hud = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
	if is_instance_valid(hud) and hud.has_method("mostrar_flash_dano"):
		hud.mostrar_flash_dano()
	print("🩸 Sofreu ", qtd, " de dano! Vida: ", vida_jogador, "/", VIDA_MAX_JOGADOR)
	if vida_jogador <= 0:
		print("💫 Desmaiou! Retornando à Bancada...")
		vida_jogador = 50
		saciedade_jogador = 50.0
		hidratacao_jogador = 50.0
		madeira = int(madeira * 0.5)
		comida = max(2, int(comida * 0.5))
		var jogador = get_tree().current_scene.get_node_or_null("Jogador")
		var bancada = get_tree().current_scene.get_node_or_null("Bancada")
		if jogador and bancada:
			jogador.global_position = bancada.global_position + Vector3(0, 1.0, 2.0)

func curar_jogador(qtd: int):
	vida_jogador = clamp(vida_jogador + qtd, 0, VIDA_MAX_JOGADOR)

func comer_jogador(usar_comida_pronta: bool) -> bool:
	if saciedade_jogador >= 98.0:
		return false
	if usar_comida_pronta and comida >= 1:
		comida -= 1
		saciedade_jogador = min(100.0, saciedade_jogador + 35.0)
		print("🍲 Refeição consumida! Saciedade: ", int(saciedade_jogador), "%")
		return true
	elif not usar_comida_pronta and frutas >= 1:
		frutas -= 1
		saciedade_jogador = min(100.0, saciedade_jogador + 12.0)
		hidratacao_jogador = min(100.0, hidratacao_jogador + 10.0)
		print("🫐 Frutas consumidas! Saciedade: ", int(saciedade_jogador), "% | Hidratação: ", int(hidratacao_jogador), "%")
		return true
	return false

func beber_agua_jogador() -> bool:
	if hidratacao_jogador >= 98.0:
		return false
	hidratacao_jogador = min(100.0, hidratacao_jogador + 45.0)
	print("💧 Água consumida! Hidratação: ", int(hidratacao_jogador), "%")
	return true

func melhorar_machado() -> bool:
	if tier_machado == 0 and gravetos >= 3 and pedrinhas >= 2:
		gravetos -= 3; pedrinhas -= 2
		tier_machado = 1; tem_machado_pedra = true
		return true
	elif tier_machado == 1 and madeira >= 6 and pedra >= 4 and couro >= 2:
		madeira -= 6; pedra -= 4; couro -= 2
		tier_machado = 2; tem_machado_pedra = true
		return true
	return false

func melhorar_picareta() -> bool:
	if tier_picareta == 0 and gravetos >= 3 and pedrinhas >= 3:
		gravetos -= 3; pedrinhas -= 3
		tier_picareta = 1
		return true
	elif tier_picareta == 1 and madeira >= 6 and pedra >= 6 and couro >= 2:
		madeira -= 6; pedra -= 6; couro -= 2
		tier_picareta = 2
		return true
	return false

func melhorar_lanca() -> bool:
	if tier_lanca == 0 and gravetos >= 4 and couro >= 1:
		gravetos -= 4; couro -= 1
		tier_lanca = 1
		return true
	elif tier_lanca == 1 and madeira >= 4 and pedrinhas >= 3 and couro >= 2:
		madeira -= 4; pedrinhas -= 3; couro -= 2
		tier_lanca = 2
		return true
	return false

func forjar_ferramentas_equipe() -> bool:
	if not equipe_ferramentas and madeira >= 8 and pedra >= 6 and couro >= 2:
		madeira -= 8; pedra -= 6; couro -= 2
		equipe_ferramentas = true
		AudioManager.tocar("construir")
		return true
	return false

func forjar_mochilas_equipe() -> bool:
	if not equipe_mochilas and couro >= 6 and gravetos >= 6:
		couro -= 6; gravetos -= 6
		equipe_mochilas = true
		AudioManager.tocar("construir")
		return true
	return false

func is_noite_de_horda() -> bool:
	return esta_de_noite() and dia_atual >= 3 and (dia_atual % 3 == 0)

func semear_todos_canteiros() -> int:
	var plantados := 0
	for c in canteiros_ativos:
		if is_instance_valid(c) and c.construida and not c.canteiro_plantado:
			if c.plantar_canteiro():
				plantados += 1
			else:
				break
	return plantados

func colher_todos_canteiros() -> int:
	var total_frutas := 0
	for c in canteiros_ativos:
		if is_instance_valid(c) and c.construida and c.canteiro_plantado and c.progresso_cultivo >= 100.0:
			var qtd = c.colher_canteiro(true)
			if qtd > 0:
				frutas += qtd
				total_frutas += qtd
	return total_frutas
