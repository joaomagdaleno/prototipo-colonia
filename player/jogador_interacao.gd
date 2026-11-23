extends Node

@onready var jogador: CharacterBody3D = get_parent()
@onready var raycast: RayCast3D = get_parent().get_node("Camera3D/RayCast3D")

func executar_golpe():
	if raycast.is_colliding():
		var alvo = raycast.get_collider()
		if alvo.has_method("receber_dano"):
			var dano = 2 if Global.tem_machado_pedra else 1
			AudioManager.tocar("golpe")
			alvo.receber_dano(dano)
			return
			
		var est: EstruturaConstruivel = alvo if alvo is EstruturaConstruivel else (alvo.get_parent() as EstruturaConstruivel)
		if est and est.construida and (est.is_portao or est.is_muro) and est.vida_atual < est.vida_maxima:
			est.reparar()

func _esta_perto_da_agua() -> bool:
	# Borda da ilha de 250x250m (onde encontra o oceano visual)
	return abs(jogador.global_position.x) >= 115.0 or abs(jogador.global_position.z) >= 115.0

func executar_interacao():
	if raycast.is_colliding():
		var alvo = raycast.get_collider()
		var estrutura: EstruturaConstruivel = null
		
		if alvo is EstruturaConstruivel:
			estrutura = alvo
		elif alvo.get_parent() is EstruturaConstruivel:
			estrutura = alvo.get_parent()
		
		if estrutura:
			if estrutura.is_bancada and estrutura.construida:
				if jogador.construindo_1p:
					jogador.mobilia_comp.alternar_modo()
				jogador.alternar_modo_construcao()
			elif estrutura.is_bau and estrutura.construida:
				estrutura.transferir_tudo_do_jogador()
			elif estrutura.is_cama and estrutura.construida:
				if Global.esta_de_noite():
					Global.hora_do_dia = 6.0
					print("Você dormiu na cama até amanhecer (06:00)!")
				else:
					print("Só é possível dormir durante a noite (após 20:00).")
			elif estrutura.is_fogueira and estrutura.construida:
				estrutura.cozinhar()
			elif estrutura.is_portao and estrutura.construida:
				estrutura.alternar_portao()
			elif estrutura.is_muro and estrutura.construida:
				if estrutura.vida_atual < estrutura.vida_maxima:
					estrutura.reparar()
				else:
					print("Muro já está com a vida máxima!")
			else:
				estrutura.construir()
			return
		elif alvo.has_method("colher"):
			AudioManager.tocar("coleta")
			alvo.colher()
			return

	# Se não interagiu com nenhum objeto e está na beira do mar com sede, bebe água
	if _esta_perto_da_agua() and Global.hidratacao_jogador < 98.0:
		Global.beber_agua_jogador()

func obter_dica_mira() -> String:
	if jogador.construindo_1p:
		return ""
		
	var btn_interagir = "[X]" if Global.usando_joystick else "[E]"
	var btn_bater = "[R2]" if Global.usando_joystick else "[Clique Esq]"
	
	if not raycast.is_colliding():
		if _esta_perto_da_agua() and Global.hidratacao_jogador < 98.0:
			return btn_interagir + " Beber Água do Mar/Costa (+45% Sede)"
		return ""
		
	var alvo = raycast.get_collider()
	if not is_instance_valid(alvo):
		return ""
		
	var est: EstruturaConstruivel = null
	if alvo is EstruturaConstruivel:
		est = alvo
	elif alvo.get_parent() is EstruturaConstruivel:
		est = alvo.get_parent()
		
	if est:
		if not est.construida:
			var custos = []
			if est.custo_madeira > 0: custos.append(str(est.custo_madeira) + " Mad")
			if est.custo_pedra > 0: custos.append(str(est.custo_pedra) + " Ped")
			if est.custo_gravetos > 0: custos.append(str(est.custo_gravetos) + " Grav")
			if est.custo_pedrinhas > 0: custos.append(str(est.custo_pedrinhas) + " Pedr")
			var txt_custo = ", ".join(custos) if not custos.is_empty() else "Grátis"
			return btn_interagir + " Construir " + est.name + " (" + txt_custo + ")"
		elif est.is_bancada:
			return btn_interagir + " Abrir Modo Planejador"
		elif est.is_bau:
			var total = est.obter_total_itens_bau()
			return btn_interagir + " Guardar/Pegar (" + str(total) + "/" + str(est.CAPACIDADE_MAXIMA_BAU) + " | " + est.obter_resumo_bau() + ")"
		elif est.is_fogueira:
			return btn_interagir + " Cozinhar (1 Carne -> 8 Comida | 2 Frutas -> 5)"
		elif est.is_cama:
			return btn_interagir + " Dormir até Amanhecer" if Global.esta_de_noite() else "Cama (Disponível à noite)"
		elif est.is_portao:
			var acao_portao = "Fechar" if est.portao_aberto else "Abrir"
			var dica_reparo = " | " + btn_bater + " Reparar (1 Mad)" if est.vida_atual < est.vida_maxima else ""
			return btn_interagir + " " + acao_portao + " Portão (" + str(est.vida_atual) + "/" + str(est.vida_maxima) + " HP)" + dica_reparo
		elif est.is_muro:
			if est.vida_atual < est.vida_maxima:
				return btn_interagir + " Reparar Muro (" + str(est.vida_atual) + "/" + str(est.vida_maxima) + " HP | 1 Ped)"
			return "Muro de Pedra (" + str(est.vida_atual) + "/" + str(est.vida_maxima) + " HP)"
			
	if alvo.is_in_group("arvores"):
		return btn_bater + " Cortar Árvore"
	elif alvo.is_in_group("pedras"):
		return btn_bater + " Minerar Rocha"
	elif alvo.is_in_group("animais"):
		return btn_bater + " Caçar " + alvo.especie.capitalize()
	elif alvo.is_in_group("inimigos"):
		return btn_bater + " Atacar Criatura (" + str(alvo.vida) + " HP)"
	elif alvo.is_in_group("arbustos"):
		return btn_interagir + " Colher Frutas" if ("tem_frutas" in alvo and alvo.tem_frutas) else "Arbusto (Sem frutas)"
	elif alvo.is_in_group("coletaveis_chao"):
		var nome_item = "Graveto" if ("tipo_item" in alvo and alvo.tipo_item == "graveto") else "Pedrinha"
		return btn_interagir + " Pegar " + nome_item
	elif _esta_perto_da_agua() and Global.hidratacao_jogador < 98.0:
		return btn_interagir + " Beber Água (+45% Sede)"
		
	return ""
