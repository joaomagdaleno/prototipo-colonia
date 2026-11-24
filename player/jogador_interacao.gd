extends Node

@onready var jogador: CharacterBody3D = get_parent()
@onready var raycast: RayCast3D = get_parent().get_node("Camera3D/RayCast3D")
var mao_ferramenta: Node3D
var mesh_cabo: MeshInstance3D
var mesh_cabeca: MeshInstance3D
var _tipo_equipado: String = ""

func _ready():
	_criar_visual_ferramenta()

func executar_golpe():
	_animar_golpe_mao()
	if raycast.is_colliding():
		var alvo = raycast.get_collider()
		if alvo.has_method("receber_dano"):
			if alvo.is_in_group("arvores") and Global.tier_machado <= 0:
				AudioManager.tocar("dano")
				print("🪓 Você precisa fabricar um Machado de Pedra no Inventário [I] para cortar árvores!")
				return
			if alvo.is_in_group("pedras") and Global.tier_picareta <= 0:
				AudioManager.tocar("dano")
				print("⛏ Você precisa fabricar uma Picareta de Pedra no Inventário [I] para minerar rochas!")
				return
			var dano = _calcular_dano_contra(alvo)
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
				if Global.esta_de_noite(): Global.hora_do_dia = 6.0; print("Voce dormiu na cama ate 06:00!")
			elif estrutura.is_tenda and estrutura.construida:
				if Global.esta_de_noite(): Global.hora_do_dia = 6.0; Global.salvar_jogo(); print("Dormiu na Tenda e salvou!")
				else: Global.salvar_jogo(); print("Jogo salvo na Tenda!")
			elif estrutura.is_curtume and estrutura.construida:
				estrutura.curtir_material()
			elif estrutura.is_coletor_chuva and estrutura.construida:
				if estrutura.agua_coletor > 0:
					if Global.tem_balde and not Global.balde_cheio: estrutura.agua_coletor -= 1; Global.encher_balde(); AudioManager.tocar("coleta")
					elif Global.hidratacao_jogador < 98.0: estrutura.agua_coletor -= 1; Global.beber_agua_jogador(); AudioManager.tocar("coleta")
			elif estrutura.is_poco and estrutura.construida:
				if estrutura.baldes_agua_poco < 3:
					if Global.tem_balde and Global.balde_cheio: Global.balde_cheio = false; estrutura.baldes_agua_poco += 1; AudioManager.tocar("coleta")
				else: Global.beber_agua_jogador(); AudioManager.tocar("coleta")
			elif estrutura.is_canteiro and estrutura.construida:
				if not estrutura.canteiro_plantado:
					if not estrutura.plantar_canteiro():
						print("Voce precisa de pelo menos 1 Fruta para plantar!")
				elif estrutura.progresso_cultivo >= 100.0:
					var colhidas = estrutura.colher_canteiro(true)
					Global.frutas += colhidas
					print("Colheu +", colhidas, " Frutas do canteiro!")
				else:
					print("Cultivo em andamento: ", int(estrutura.progresso_cultivo), "%")
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
	if _esta_perto_da_agua():
		if Global.tem_balde and not Global.balde_cheio: Global.encher_balde(); AudioManager.tocar("coleta")
		elif Global.hidratacao_jogador < 98.0: Global.beber_agua_jogador()

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
		elif est.is_curtume:
			if Global.carne_crua >= 2: return btn_interagir + " Curtir Couro (2 Carne -> +1 Couro)"
			elif Global.couro >= 1: return btn_interagir + " Cortar Tiras (1 Couro -> +4 Gravetos)"
			return "Mesa de Curtume (Requer 2 Carne Crua ou 1 Couro)"
		elif est.is_tenda: return btn_interagir + (" Dormir e Salvar" if Global.esta_de_noite() else " Salvar na Tenda")
		elif est.is_fazenda: return "Fazenda Central (Canteiros Desbloqueados)"
		elif est.is_coletor_chuva: return "Coletor Vazio" if est.agua_coletor <= 0 else (btn_interagir + " Usar Coletor (" + str(est.agua_coletor) + "/5)")
		elif est.is_poco: return (btn_interagir + " Despejar Balde" if (Global.tem_balde and Global.balde_cheio) else "Poco Seco (" + str(est.baldes_agua_poco) + "/3)") if est.baldes_agua_poco < 3 else (btn_interagir + " Beber Agua do Poco")
		elif est.is_canteiro:
			if not est.canteiro_plantado:
				return btn_interagir + " Plantar Semente (1 Fruta)"
			elif est.progresso_cultivo >= 100.0:
				return btn_interagir + " Colher Cultivo (+4 Frutas)"
			return "🌱 Cultivando... " + str(int(est.progresso_cultivo)) + "%"
		elif est.is_fogueira:
			if (Global.carne_crua + int(Global.estoque_total_baus.get("carne_crua", 0))) >= 1:
				return btn_interagir + " Assar Carne (1 Carne -> +8 Comida)"
			elif (Global.frutas + int(Global.estoque_total_baus.get("frutas", 0))) >= 2:
				return btn_interagir + " Cozinhar Frutas (2 Frutas -> +5 Comida)"
			return "Fogueira (Precisa de 1 Carne Crua ou 2 Frutas)"
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
			
	_atualizar_visual_ferramenta("machado")
	if alvo.is_in_group("arvores"):
		if Global.tier_machado <= 0:
			return "🪓 Requer Machado de Pedra [I]"
		return btn_bater + " Cortar Árvore (Dano " + str(_calcular_dano_contra(alvo)) + ")"
	elif alvo.is_in_group("pedras"):
		_atualizar_visual_ferramenta("picareta")
		if Global.tier_picareta <= 0:
			return "⛏ Requer Picareta de Pedra [I]"
		return btn_bater + " Minerar Rocha (Dano " + str(_calcular_dano_contra(alvo)) + ")"
	elif alvo.is_in_group("animais"):
		_atualizar_visual_ferramenta("lanca")
		return btn_bater + " Caçar " + alvo.especie.capitalize() + " (Dano " + str(_calcular_dano_contra(alvo)) + ")"
	elif alvo.is_in_group("inimigos"):
		_atualizar_visual_ferramenta("lanca")
		return btn_bater + " Atacar Criatura (" + str(alvo.vida) + " HP)"
	elif alvo.is_in_group("arbustos"):
		return btn_interagir + " Colher Frutas" if ("tem_frutas" in alvo and alvo.tem_frutas) else "Arbusto (Sem frutas)"
	elif alvo.is_in_group("coletaveis_chao"):
		var nome_item = "Graveto" if ("tipo_item" in alvo and alvo.tipo_item == "graveto") else "Pedrinha"
		return btn_interagir + " Pegar " + nome_item
	elif _esta_perto_da_agua() and Global.hidratacao_jogador < 98.0:
		return btn_interagir + " Beber Água (+45% Sede)"
		
	return ""

func _calcular_dano_contra(alvo: Node) -> int:
	var tier := 0
	_atualizar_visual_ferramenta("machado")
	if alvo.is_in_group("arvores"):
		tier = Global.tier_machado
	elif alvo.is_in_group("pedras"):
		_atualizar_visual_ferramenta("picareta")
		tier = Global.tier_picareta
	elif alvo.is_in_group("animais") or alvo.is_in_group("inimigos"):
		tier = Global.tier_lanca
	if tier >= 2:
		return 4
	elif tier == 1:
		return 2
	return 1

func _criar_visual_ferramenta():
	var cam = get_parent().get_node_or_null("Camera3D")
	if not is_instance_valid(cam): return
	mao_ferramenta = Node3D.new()
	mao_ferramenta.position = Vector3(0.38, -0.32, -0.58)
	mao_ferramenta.rotation_degrees = Vector3(15, -12, 8)
	cam.add_child(mao_ferramenta)

	mesh_cabo = MeshInstance3D.new()
	var box_cabo = BoxMesh.new()
	box_cabo.size = Vector3(0.04, 0.45, 0.04)
	var mat_cabo = StandardMaterial3D.new()
	mat_cabo.albedo_color = Color(0.45, 0.26, 0.12)
	box_cabo.material = mat_cabo
	mesh_cabo.mesh = box_cabo
	mesh_cabo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mao_ferramenta.add_child(mesh_cabo)

	mesh_cabeca = MeshInstance3D.new()
	var box_cab = BoxMesh.new()
	box_cab.size = Vector3(0.18, 0.12, 0.05)
	var mat_cab = StandardMaterial3D.new()
	mat_cab.albedo_color = Color(0.55, 0.58, 0.62)
	box_cab.material = mat_cab
	mesh_cabeca.mesh = box_cab
	mesh_cabeca.position = Vector3(0, 0.18, -0.04)
	mesh_cabeca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mao_ferramenta.add_child(mesh_cabeca)
	mao_ferramenta.visible = false

func _atualizar_visual_ferramenta(contexto: String):
	if not is_instance_valid(mao_ferramenta): return
	if jogador.construindo_1p or jogador.no_modo_construcao:
		mao_ferramenta.visible = false
		return
	var tier := 0
	if contexto == "machado": tier = Global.tier_machado
	elif contexto == "picareta": tier = Global.tier_picareta
	elif contexto == "lanca": tier = Global.tier_lanca
	if tier <= 0:
		mao_ferramenta.visible = false
		return
	mao_ferramenta.visible = true
	var chave = contexto + "_" + str(tier)
	if chave == _tipo_equipado: return
	_tipo_equipado = chave
	var mat = mesh_cabeca.mesh.material as StandardMaterial3D
	mat.albedo_color = Color(0.78, 0.82, 0.88) if tier >= 2 else Color(0.52, 0.54, 0.58)
	if contexto == "machado":
		mesh_cabo.scale = Vector3(1, 1, 1)
		mesh_cabeca.scale = Vector3(1.0, 1.1, 1.0)
		mesh_cabeca.position = Vector3(0, 0.18, -0.05)
	elif contexto == "picareta":
		mesh_cabo.scale = Vector3(1, 1, 1)
		mesh_cabeca.scale = Vector3(1.8, 0.55, 0.8)
		mesh_cabeca.position = Vector3(0, 0.2, 0)
	elif contexto == "lanca":
		mesh_cabo.scale = Vector3(0.8, 1.7, 0.8)
		mesh_cabeca.scale = Vector3(0.45, 1.4, 0.5)
		mesh_cabeca.position = Vector3(0, 0.36, 0)
		if tier == 1: mat.albedo_color = Color(0.58, 0.36, 0.18)

func _animar_golpe_mao():
	if not is_instance_valid(mao_ferramenta) or not mao_ferramenta.visible: return
	var tw = create_tween()
	tw.tween_property(mao_ferramenta, "rotation_degrees:x", -45.0, 0.07)
	tw.tween_property(mao_ferramenta, "rotation_degrees:x", 15.0, 0.09)
