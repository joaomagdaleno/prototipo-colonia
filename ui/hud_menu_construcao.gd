extends Control

## Menu de ConstruÃ§Ã£o em 1Âª Pessoa
## Apresenta os projetos organizados por abas temÃ¡ticas, com cards descritivos,
## custos em tempo real e seleÃ§Ã£o direta para o fantasma 1P.

var painel: PanelContainer
var container_abas: HBoxContainer
var grid_itens: GridContainer
var label_custos: Label
var label_titulo_aba: Label

var catalogo := [
	{
		"categoria": "Estruturas",
		"icone": "ðŸªµ",
		"itens": [
			{"nome": "Piso de Madeira", "cena_path": "res://buildings/Piso.tscn", "icone": "ðŸŸ«", "desc": "FundaÃ§Ã£o plana para suportar construÃ§Ãµes."},
			{"nome": "Parede de Madeira", "cena_path": "res://buildings/ParedeMadeira.tscn", "icone": "ðŸ§±", "desc": "Parede modular com snap em pisos e paredes."},
			{"nome": "Teto de Madeira", "cena_path": "res://buildings/TetoMadeira.tscn", "icone": "â›º", "desc": "Telhado protetor contra chuvas intensas."},
		]
	},
	{
		"categoria": "SobrevivÃªncia",
		"icone": "ðŸ”¥",
		"itens": [
			{"nome": "Fogueira", "cena_path": "res://buildings/Fogueira.tscn", "icone": "ðŸ”¥", "desc": "Aquece, ilumina Ã  noite e cozinha alimentos."},
			{"nome": "BaÃº de Estoque", "cena_path": "res://buildings/Bau.tscn", "icone": "ðŸ“¦", "desc": "Armazena atÃ© 150 recursos com descarga rÃ¡pida."},
			{"nome": "Cama de Madeira", "cena_path": "res://buildings/Cama.tscn", "icone": "ðŸ›ï¸", "desc": "Permite dormir durante a noite atÃ© amanhecer."},
			{"nome": "Bancada Central", "cena_path": "res://buildings/Bancada.tscn", "icone": "ðŸ› ï¸", "desc": "Mesa de trabalho e acesso ao Planejador AÃ©reo."},
		]
	},
	{
		"categoria": "Defesa & Cerco",
		"icone": "ðŸ›¡ï¸",
		"itens": [
			{"nome": "Muro de Pedra", "cena_path": "res://buildings/MuroPedra.tscn", "icone": "ðŸª¨", "desc": "Barreira robusta contra criaturas noturnas."},
			{"nome": "PortÃ£o de Madeira", "cena_path": "res://buildings/Portao.tscn", "icone": "ðŸšª", "desc": "Abre e fecha com [E] permitindo passagem livre."},
		]
	}
]

var aba_atual: int = 0
var botoes_abas: Array[Button] = []
var cache_cenas: Dictionary = {}
var cache_custos: Dictionary = {}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carregar_cenas()
	_montar_interface()

func _carregar_cenas():
	for cat in catalogo:
		for item in cat["itens"]:
			var path: String = item["cena_path"]
			if ResourceLoader.exists(path):
				var cena: PackedScene = load(path)
				cache_cenas[path] = cena
				var inst = cena.instantiate()
				cache_custos[path] = {
					"mad": inst.custo_madeira if "custo_madeira" in inst else 0,
					"ped": inst.custo_pedra if "custo_pedra" in inst else 0,
					"grav": inst.custo_gravetos if "custo_gravetos" in inst else 0,
					"pedr": inst.custo_pedrinhas if "custo_pedrinhas" in inst else 0
				}
				inst.queue_free()

func _montar_interface():
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(680, 480)
	painel.position = Vector2(-340, -240)
	painel.visible = false
	add_child(painel)

	var margem = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 24)
	margem.add_theme_constant_override("margin_right", 24)
	margem.add_theme_constant_override("margin_top", 18)
	margem.add_theme_constant_override("margin_bottom", 18)
	painel.add_child(margem)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margem.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var titulo = Label.new()
	titulo.text = "ðŸ“– GUIA DE CONSTRUÃ‡ÃƒO DO SOBREVIVENTE"
	titulo.add_theme_font_size_override("font_size", 20)
	header.add_child(titulo)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var dica_sair = Label.new()
	dica_sair.text = "[B / ESC] Fechar"
	dica_sair.add_theme_font_size_override("font_size", 14)
	dica_sair.modulate = Color(0.7, 0.7, 0.7)
	header.add_child(dica_sair)

	container_abas = HBoxContainer.new()
	container_abas.add_theme_constant_override("separation", 10)
	vbox.add_child(container_abas)

	for i in range(catalogo.size()):
		var cat = catalogo[i]
		var btn = Button.new()
		btn.text = cat["icone"] + " " + cat["categoria"]
		btn.add_theme_font_size_override("font_size", 15)
		btn.focus_mode = Control.FOCUS_ALL
		var indice = i
		btn.pressed.connect(func(): _trocar_aba(indice))
		container_abas.add_child(btn)
		botoes_abas.append(btn)

	label_titulo_aba = Label.new()
	label_titulo_aba.add_theme_font_size_override("font_size", 14)
	label_titulo_aba.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(label_titulo_aba)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(630, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	grid_itens = GridContainer.new()
	grid_itens.columns = 3
	grid_itens.add_theme_constant_override("h_separation", 12)
	grid_itens.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid_itens)

	var rodape = HBoxContainer.new()
	vbox.add_child(rodape)

	label_custos = Label.new()
	label_custos.add_theme_font_size_override("font_size", 14)
	label_custos.text = "Selecione uma peÃ§a para posicionar o fantasma no mundo."
	rodape.add_child(label_custos)

func _trocar_aba(indice: int):
	aba_atual = indice
	for i in range(botoes_abas.size()):
		botoes_abas[i].modulate = Color(1.3, 1.3, 1.3) if i == aba_atual else Color(0.75, 0.75, 0.75)
	
	label_titulo_aba.text = "Categoria: " + catalogo[aba_atual]["categoria"]
	_renderizar_cards()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _renderizar_cards():
	for child in grid_itens.get_children():
		child.queue_free()

	var cat = catalogo[aba_atual]
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")

	for item in cat["itens"]:
		var path = item["cena_path"]
		var cena: PackedScene = cache_cenas.get(path, null)
		if not cena: continue

		var custos = cache_custos.get(path, {"mad": 0, "ped": 0, "grav": 0, "pedr": 0})
		var pode_construir = (
			Global.madeira >= custos["mad"] and
			Global.pedra >= custos["ped"] and
			Global.gravetos >= custos["grav"] and
			Global.pedrinhas >= custos["pedr"]
		)

		var card_btn = Button.new()
		card_btn.custom_minimum_size = Vector2(200, 115)
		card_btn.focus_mode = Control.FOCUS_ALL

		var card_margin = MarginContainer.new()
		card_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_top", 6)
		card_margin.add_theme_constant_override("margin_bottom", 6)
		card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(card_margin)

		var card_box = VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 3)
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_margin.add_child(card_box)

		var card_header = Label.new()
		card_header.text = item["icone"] + " " + item["nome"]
		card_header.add_theme_font_size_override("font_size", 14)
		card_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(card_header)

		var card_desc = Label.new()
		card_desc.text = item["desc"]
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_desc.add_theme_font_size_override("font_size", 11)
		card_desc.modulate = Color(0.8, 0.8, 0.8)
		card_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(card_desc)

		var card_custo = Label.new()
		var custos_arr = []
		if custos["mad"] > 0: custos_arr.append(str(custos["mad"]) + "ðŸªµ")
		if custos["ped"] > 0: custos_arr.append(str(custos["ped"]) + "ðŸª¨")
		if custos["grav"] > 0: custos_arr.append(str(custos["grav"]) + "ðŸŒ¿")
		if custos["pedr"] > 0: custos_arr.append(str(custos["pedr"]) + "âšª")
		var txt_custo = " ".join(custos_arr) if not custos_arr.is_empty() else "GrÃ¡tis"
		
		card_custo.text = "Custo: " + txt_custo
		card_custo.add_theme_font_size_override("font_size", 12)
		card_custo.modulate = Color(0.4, 1.0, 0.4) if pode_construir else Color(1.0, 0.4, 0.4)
		card_custo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(card_custo)

		var cena_selecionada = cena
		card_btn.pressed.connect(func():
			if jogador and jogador.mobilia_comp:
				_selecionar_para_jogador(jogador, cena_selecionada)
		)

		grid_itens.add_child(card_btn)

func _selecionar_para_jogador(jogador: Node, cena: PackedScene):
	var opcoes = jogador.mobilia_comp.opcoes_mobilia
	var idx = opcoes.find(cena)
	if idx == -1:
		opcoes.append(cena)
		idx = opcoes.size() - 1
	jogador.menu_construcao_aberto = false
	definir_visivel(false)
	jogador.construindo_1p = true
	jogador.mobilia_comp.selecionar_peca(idx)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func definir_visivel(mostrar: bool):
	painel.visible = mostrar
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if mostrar else Input.MOUSE_MODE_CAPTURED)
	if mostrar:
		_trocar_aba(aba_atual)
		if not botoes_abas.is_empty():
			botoes_abas[aba_atual].grab_focus()
