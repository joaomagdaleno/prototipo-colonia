extends Node

## Gerenciador e Avaliador de Tarefas do Colono
## Prioriza sobrevivÃªncia, entrega fÃ­sica nos BaÃºs e coleta/construÃ§Ã£o marcadas.

@onready var colono: CharacterBody3D = get_parent()

var alvo_atual: Node3D = null
var tipo_alvo: String = ""

var alvos_ignorados: Dictionary = {}
const TEMPO_IGNORAR_SEGUNDOS := 10.0

func tem_alvo() -> bool:
	return is_instance_valid(alvo_atual)

func obter_alvo_atual() -> Node3D:
	return alvo_atual if is_instance_valid(alvo_atual) else null

var alvo: Node3D:
	get: return alvo_atual if tipo_alvo == "projeto" else null
var alvo_arvore: Node3D:
	get: return alvo_atual if tipo_alvo == "arvore" else null
var alvo_cama: Node3D:
	get: return alvo_atual if tipo_alvo == "cama" else null
var alvo_arbusto: Node3D:
	get: return alvo_atual if tipo_alvo == "arbusto" else null
var alvo_pedra: Node3D:
	get: return alvo_atual if tipo_alvo == "pedra" else null
var alvo_coletavel: Node3D:
	get: return alvo_atual if tipo_alvo == "coletavel" else null

func limpar_alvos():
	alvo_atual = null
	tipo_alvo = ""

func escolher_proxima_tarefa() -> Vector3:
	_limpar_cache_ignorados()

	# 1. Prioridade mÃ¡xima: SobrevivÃªncia (Sono / Noite)
	if colono.energia <= 25.0 or Global.esta_de_noite():
		var cama_livre = _procurar_cama_livre()
		if cama_livre:
			_definir_alvo(cama_livre, "cama")
			cama_livre.ocupada = true
			return cama_livre.global_position
		else:
			colono.dormindo = true
			return Vector3.INF

	# 2. Entrega LogÃ­stica: Se tem carga na mochila, leva para o BaÃº mais prÃ³ximo
	if colono.obter_carga_mochila() > 0:
		var bau_livre = _buscar_mais_proximo("baus", func(b):
			return b.construida and b.obter_total_itens_bau() < b.CAPACIDADE_MAXIMA_BAU
		)
		if bau_livre:
			_definir_alvo(bau_livre, "bau")
			return bau_livre.global_position
		else:
			# Fallback: se nÃ£o hÃ¡ baÃºs construÃ­dos ou todos estÃ£o cheios, entrega no estoque global
			_descarregar_mochila_no_global()

	# 3. Comida e Frutas (arbustos marcados)
	var arbusto = _buscar_mais_proximo("recursos_marcados", func(a): return a.is_in_group("arbustos") and a.tem_frutas and not a.reservado)
	if arbusto:
		_definir_alvo(arbusto, "arbusto")
		arbusto.reservado = true
		return arbusto.global_position

	# 4. Itens soltos no chÃ£o marcados
	var item = _buscar_mais_proximo("recursos_marcados", func(c): return c.is_in_group("coletaveis_chao") and not c.reservado)
	if item:
		_definir_alvo(item, "coletavel")
		item.reservado = true
		return item.global_position

	# 5. Projetos de ConstruÃ§Ã£o que podem ser pagos
	var projeto = _buscar_mais_proximo("projetos", func(p): return not p.construida and not p.reservado and p.pode_pagar())
	if projeto:
		_definir_alvo(projeto, "projeto")
		projeto.reservado = true
		return projeto.global_position

	# 6. Madeira (Ãrvores Marcadas)
	var arvore = _buscar_mais_proximo("recursos_marcados", func(a): return a.is_in_group("arvores") and not a.cortada and not a.reservado)
	if arvore:
		_definir_alvo(arvore, "arvore")
		arvore.reservado = true
		return arvore.global_position

	# 7. MineraÃ§Ã£o (Pedras Grandes Marcadas)
	var pedra = _buscar_mais_proximo("recursos_marcados", func(r): return r.is_in_group("pedras") and not r.quebrada and not r.reservado)
	if pedra:
		_definir_alvo(pedra, "pedra")
		pedra.reservado = true
		return pedra.global_position

	return Vector3.INF

func _definir_alvo(novo_alvo: Node3D, tipo: String):
	alvo_atual = novo_alvo
	tipo_alvo = tipo

func concluir_trabalho(fator_distancia: float):
	var mult_chuva = 1.4 if Global.esta_chovendo() else 1.0

	if is_instance_valid(alvo_atual):
		match tipo_alvo:
			"bau":
				_depositar_no_bau(alvo_atual)
			"projeto":
				if alvo_atual.construir():
					colono.energia -= 5.0 * fator_distancia * mult_chuva
				else:
					alvo_atual.reservado = false
			"arvore":
				var antes = Global.madeira
				alvo_atual.cortar()
				var ganho = max(0, Global.madeira - antes)
				Global.madeira = antes
				colono.mochila["madeira"] += ganho
				colono.energia -= 8.0 * fator_distancia * mult_chuva
			"pedra":
				var antes = Global.pedra
				alvo_atual.quebrar()
				var ganho = max(0, Global.pedra - antes)
				Global.pedra = antes
				colono.mochila["pedra"] += ganho
				colono.energia -= 10.0 * fator_distancia * mult_chuva
			"arbusto":
				var antes = Global.frutas
				alvo_atual.colher()
				var ganho = max(0, Global.frutas - antes)
				Global.frutas = antes
				colono.mochila["frutas"] += ganho
				colono.energia -= 3.0 * fator_distancia * mult_chuva
			"coletavel":
				var tipo_item = alvo_atual.tipo_item if "tipo_item" in alvo_atual else "graveto"
				var chave = "gravetos" if tipo_item == "graveto" else "pedrinhas"
				var antes = Global.get(chave)
				alvo_atual.colher()
				var ganho = max(0, Global.get(chave) - antes)
				Global.set(chave, antes)
				colono.mochila[chave] += ganho
				colono.energia -= 2.0 * fator_distancia * mult_chuva

	limpar_alvos()

func _depositar_no_bau(bau: Node3D):
	var depositou = false
	for chave in colono.mochila.keys():
		var qtd = int(colono.mochila[chave])
		while qtd > 0 and bau.guardar_item_no_bau(chave, 1):
			qtd -= 1
			depositou = true
		colono.mochila[chave] = qtd
	if depositou:
		print("ðŸ“¦ Colono depositou recursos no BaÃº! Estoque do BaÃº: ", bau.obter_total_itens_bau(), "/", bau.CAPACIDADE_MAXIMA_BAU)
	# Se sobrou algo porque o baÃº encheu no meio da entrega, o prÃ³ximo ciclo procura outro baÃº ou descarrega no Global

func _descarregar_mochila_no_global():
	for chave in colono.mochila.keys():
		var qtd = int(colono.mochila[chave])
		if qtd > 0:
			Global.set(chave, Global.get(chave) + qtd)
			colono.mochila[chave] = 0

func cancelar_e_ignorar_atual():
	if is_instance_valid(alvo_atual):
		if "reservado" in alvo_atual:
			alvo_atual.reservado = false
		if tipo_alvo == "cama" and "ocupada" in alvo_atual:
			alvo_atual.ocupada = false
			colono.dormindo = true
		alvos_ignorados[alvo_atual] = Time.get_ticks_msec() + int(TEMPO_IGNORAR_SEGUNDOS * 1000)

	if not colono.dormindo:
		limpar_alvos()

func _limpar_cache_ignorados():
	var agora = Time.get_ticks_msec()
	var expirados = []
	for obj in alvos_ignorados:
		if not is_instance_valid(obj) or agora >= alvos_ignorados[obj]:
			expirados.append(obj)
	for item_exp in expirados:
		alvos_ignorados.erase(item_exp)

func _buscar_mais_proximo(grupo: String, filtro: Callable) -> Node3D:
	var mais_perto: Node3D = null
	var menor_dist_sq := INF
	var pos_colono := colono.global_position

	for item in get_tree().get_nodes_in_group(grupo):
		if not is_instance_valid(item) or item in alvos_ignorados or not filtro.call(item):
			continue
		var dist_sq = pos_colono.distance_squared_to(item.global_position)
		if dist_sq < menor_dist_sq:
			menor_dist_sq = dist_sq
			mais_perto = item

	return mais_perto

func _procurar_cama_livre() -> Node3D:
	var mais_perto: Node3D = null
	var menor_dist_sq := INF
	var pos_colono := colono.global_position

	for c in get_tree().get_nodes_in_group("camas"):
		if is_instance_valid(c) and c.construida and not c.ocupada and c not in alvos_ignorados:
			var d_sq = pos_colono.distance_squared_to(c.global_position)
			if d_sq < menor_dist_sq:
				menor_dist_sq = d_sq
				mais_perto = c
	return mais_perto
