extends CanvasLayer

var label_madeira: Label
var label_modo: Label
var label_atalhos: Label
var _ultimo_texto_topo: String = ""
var _ultimo_texto_colonos: String = ""
var _ultimo_texto_atalhos: String = ""
var painel_baixo: PanelContainer
var mira: ColorRect
var flash_dano: ColorRect
var label_dica_mira: Label

var painel_colonos: PanelContainer
var label_lista_colonos: Label
var botao_contratar: Button
var painel_objetivos: PanelContainer
var label_objetivos: Label

@onready var inventario_ui = $InventarioUI
@onready var construcao_menu_ui = $ConstrucaoMenuUI
@onready var dock_ui = get_node_or_null("DockUI") if has_node("DockUI") else get_node_or_null("DockTimberbornUI")
@onready var pausa_ui = $PausaUI

var jogador: Node3D
var camera_aerea: Camera3D

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_hud_base()
	jogador = get_tree().current_scene.get_node_or_null("Jogador")
	camera_aerea = get_tree().get_first_node_in_group("camera_aerea")
	if is_instance_valid(dock_ui):
		dock_ui.camera_aerea = camera_aerea
	
	if Global.carregar_ao_iniciar:
		Global.carregar_ao_iniciar = false
		Global.carregar_jogo.call_deferred()

func _montar_hud_base():
	# 1. BARRA SUPERIOR DE RECURSOS
	var painel_topo = PanelContainer.new()
	painel_topo.position = Vector2(20, 20)
	painel_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel_topo)
	
	var margem_topo = MarginContainer.new()
	margem_topo.add_theme_constant_override("margin_left", 15)
	margem_topo.add_theme_constant_override("margin_right", 15)
	margem_topo.add_theme_constant_override("margin_top", 8)
	margem_topo.add_theme_constant_override("margin_bottom", 8)
	margem_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_topo.add_child(margem_topo)
	
	var hbox_topo = HBoxContainer.new()
	hbox_topo.add_theme_constant_override("separation", 20)
	margem_topo.add_child(hbox_topo)
	
	label_madeira = Label.new()
	label_madeira.add_theme_font_size_override("font_size", 16)
	hbox_topo.add_child(label_madeira)
	
	label_modo = Label.new()
	label_modo.add_theme_font_size_override("font_size", 16)
	label_modo.modulate = Color(1.0, 0.85, 0.3)
	hbox_topo.add_child(label_modo)

	# 2. PAINEL DE COLONOS (VisÃ­vel apenas no Planejador AÃ©reo)
	painel_colonos = PanelContainer.new()
	painel_colonos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	painel_colonos.offset_left = -280; painel_colonos.offset_top = 20
	painel_colonos.offset_right = -20; painel_colonos.offset_bottom = 220
	painel_colonos.visible = false
	add_child(painel_colonos)
	
	var margem_col = MarginContainer.new()
	margem_col.add_theme_constant_override("margin_left", 12)
	margem_col.add_theme_constant_override("margin_right", 12)
	margem_col.add_theme_constant_override("margin_top", 10)
	margem_col.add_theme_constant_override("margin_bottom", 10)
	painel_colonos.add_child(margem_col)
	
	var vbox_col = VBoxContainer.new()
	vbox_col.add_theme_constant_override("separation", 8)
	margem_col.add_child(vbox_col)
	
	botao_contratar = Button.new()
	botao_contratar.pressed.connect(func(): Global.contratar_colono())
	vbox_col.add_child(botao_contratar)
	
	label_lista_colonos = Label.new()
	label_lista_colonos.add_theme_font_size_override("font_size", 13)
	vbox_col.add_child(label_lista_colonos)

	flash_dano = ColorRect.new()
	flash_dano.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_dano.color = Color(0.85, 0.05, 0.05, 0.0)
	flash_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_dano)

	painel_objetivos = PanelContainer.new()
	painel_objetivos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	painel_objetivos.offset_left = -290; painel_objetivos.offset_top = 20
	painel_objetivos.offset_right = -20; painel_objetivos.offset_bottom = 145
	painel_objetivos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel_objetivos)
	var m_obj = MarginContainer.new()
	m_obj.add_theme_constant_override("margin_left", 12); m_obj.add_theme_constant_override("margin_right", 12)
	m_obj.add_theme_constant_override("margin_top", 8); m_obj.add_theme_constant_override("margin_bottom", 8)
	m_obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_objetivos.add_child(m_obj)
	label_objetivos = Label.new()
	label_objetivos.add_theme_font_size_override("font_size", 13)
	label_objetivos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_obj.add_child(label_objetivos)

	# 3. MIRA INTELIGENTE
	mira = ColorRect.new()
	mira.size = Vector2(6, 6); mira.color = Color(1, 1, 1, 0.85)
	mira.set_anchors_preset(Control.PRESET_CENTER); mira.position = Vector2(-3, -3)
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mira)

	label_dica_mira = Label.new()
	label_dica_mira.set_anchors_preset(Control.PRESET_CENTER)
	label_dica_mira.custom_minimum_size = Vector2(460, 32); label_dica_mira.position = Vector2(-230, 18)
	label_dica_mira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_dica_mira.add_theme_font_size_override("font_size", 16)
	label_dica_mira.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_dica_mira.add_theme_constant_override("outline_size", 4)
	label_dica_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label_dica_mira)

	# 4. BARRA INFERIOR DE ATALHOS (1Âª Pessoa)
	painel_baixo = PanelContainer.new()
	painel_baixo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	painel_baixo.offset_top = -50; painel_baixo.offset_bottom = -15
	painel_baixo.offset_left = 50; painel_baixo.offset_right = -50
	painel_baixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel_baixo)
	
	label_atalhos = Label.new()
	label_atalhos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_atalhos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_atalhos.add_theme_font_size_override("font_size", 15)
	painel_baixo.add_child(label_atalhos)

func alternar_pausa():
	var vai_pausar = not get_tree().paused
	get_tree().paused = vai_pausar
	pausa_ui.definir_visivel(vai_pausar)
	
	if vai_pausar:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mira.visible = false; label_dica_mira.text = ""
	elif is_instance_valid(jogador) and not jogador.no_modo_construcao and not jogador.inventario_aberto and not jogador.menu_construcao_aberto:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	var apertou_esc = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	var apertou_start = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if apertou_esc or apertou_start:
		if is_instance_valid(construcao_menu_ui) and construcao_menu_ui.painel.visible:
			construcao_menu_ui.definir_visivel(false)
			if is_instance_valid(jogador):
				jogador.menu_construcao_aberto = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif is_instance_valid(jogador) and jogador.inventario_aberto:
			jogador._alternar_inventario()
		else:
			alternar_pausa()
		get_viewport().set_input_as_handled()

func _process(_delta):
	var _novo_topo = (
		"â¤ï¸ " + str(Global.vida_jogador) +
		"  |  ðŸ– " + str(int(Global.saciedade_jogador)) + "%" +
		"  |  ðŸ’§ " + str(int(Global.hidratacao_jogador)) + "%" +
		"  |  ðŸªµ " + str(Global.madeira) +
		"  |  ðŸª¨ " + str(Global.pedra) +
		"  |  âšª " + str(Global.pedrinhas) +
		"  |  ðŸŒ¿ " + str(Global.gravetos) +
		"  |  ðŸ« " + str(Global.frutas) +
		"  |  ðŸ¥© " + str(Global.carne_crua) +
		"  |  ðŸ² " + str(Global.comida) +
		"  |  ðŸ•’ " + Global.obter_hora_formatada() +
		"  |  " + Global.obter_texto_clima()
	)
	if _novo_topo != _ultimo_texto_topo:
		_ultimo_texto_topo = _novo_topo
		label_madeira.text = _novo_topo
	
	if get_tree().paused: return
	if not is_instance_valid(jogador):
		jogador = get_tree().current_scene.get_node_or_null("Jogador")
		return
	if not is_instance_valid(camera_aerea):
		camera_aerea = get_tree().get_first_node_in_group("camera_aerea")
		if is_instance_valid(dock_ui):
			dock_ui.camera_aerea = camera_aerea

	var joy = Global.usando_joystick
	var menu_construcao_aberto = is_instance_valid(construcao_menu_ui) and construcao_menu_ui.painel.visible

	botao_contratar.visible = jogador.no_modo_construcao
	painel_colonos.visible = jogador.no_modo_construcao
	_atualizar_objetivos_iniciais(jogador.no_modo_construcao)
	painel_baixo.visible = not jogador.no_modo_construcao
	if is_instance_valid(dock_ui):
		dock_ui.definir_visivel(jogador.no_modo_construcao)

	if jogador.no_modo_construcao:
		botao_contratar.text = "ðŸ¤ Contratar Colono (" + str(Global.CUSTO_CONTRATAR_COLONO) + " Comida)" + (" [Y]" if joy else "")
		botao_contratar.disabled = Global.comida < Global.CUSTO_CONTRATAR_COLONO
		var colonos = get_tree().get_nodes_in_group("colonos")
		if colonos.is_empty():
			label_lista_colonos.text = "ðŸ‘¥ EQUIPE (0)\nNenhum colono contratado."
		else:
			var linhas = ["ðŸ‘¥ EQUIPE (" + str(colonos.size()) + ")"]
			for i in range(colonos.size()):
				if is_instance_valid(colonos[i]) and colonos[i].has_method("obter_status_texto"):
					linhas.append("â€¢ Colono " + str(i + 1) + ": " + colonos[i].obter_status_texto())
			var _novo_col = "\n".join(linhas)
			if _novo_col != _ultimo_texto_colonos:
				_ultimo_texto_colonos = _novo_col
				label_lista_colonos.text = _novo_col

	inventario_ui.atualizar(jogador.inventario_aberto)
	if jogador.inventario_aberto or menu_construcao_aberto:
		mira.visible = false; label_dica_mira.text = ""
		return

	if jogador.no_modo_construcao:
		label_dica_mira.text = ""
		if is_instance_valid(camera_aerea) and camera_aerea.modo_marcacao:
			label_modo.text = "|  PINCEL DE CORTE"
		else:
			label_modo.text = "|  PLANEJADOR (" + _obter_nome_peca_aerea() + ")"
		mira.visible = joy
	elif jogador.construindo_1p:
		label_dica_mira.text = ""; label_modo.text = "|  CONSTRUINDO"
		var nome_mob = _obter_nome_mobilia_1p()
		label_atalhos.text = ("PeÃ§a: " + nome_mob + " | [L1/R1] Girar | [B] Guia | [R2] Colocar | [L2] Guardar") if joy else ("PeÃ§a: " + nome_mob + " | [Q/R] Girar | [B] Guia | [Esq] Colocar | [Dir] Guardar")
		mira.visible = true
	else:
		label_modo.text = "|  1Âª PESSOA"
		label_atalhos.text = "[R2] Cortar/CaÃ§ar | [X] Interagir | [D-Pad â–¼] Guia [B] | [D-Pad â–²] InventÃ¡rio | [Start] Pausa" if joy else "[Esq] Cortar/CaÃ§ar | [E] Interagir | [B] Guia de ConstruÃ§Ã£o | [I] InventÃ¡rio | [ESC] Pausa"
		mira.visible = true
		label_dica_mira.text = jogador.obter_dica_mira()

func _formatar_custo(est: EstruturaConstruivel) -> String:
	var partes = []
	if est.custo_madeira > 0: partes.append(str(est.custo_madeira) + " mad")
	if est.custo_pedra > 0: partes.append(str(est.custo_pedra) + " ped")
	if est.custo_gravetos > 0: partes.append(str(est.custo_gravetos) + " grav")
	if est.custo_pedrinhas > 0: partes.append(str(est.custo_pedrinhas) + " pedr")
	return "GrÃ¡tis" if partes.is_empty() else ", ".join(partes)

func _obter_nome_peca_aerea() -> String:
	if is_instance_valid(camera_aerea) and is_instance_valid(camera_aerea.fantasma):
		var cena = camera_aerea.opcoes_construcao[camera_aerea.indice_atual]
		return cena.resource_path.get_file().get_basename() + " (" + _formatar_custo(camera_aerea.fantasma) + ")"
	return "Nenhum"

func _obter_nome_mobilia_1p() -> String:
	if is_instance_valid(jogador.fantasma_1p):
		var cena = jogador.opcoes_mobilia[jogador.indice_mobilia]
		return cena.resource_path.get_file().get_basename() + " (" + _formatar_custo(jogador.fantasma_1p) + ")"
	return "Nenhum"

func mostrar_flash_dano():
if not is_instance_valid(flash_dano): return
flash_dano.color.a = 0.35
var tween = create_tween()
tween.tween_property(flash_dano, "color:a", 0.0, 0.35)
func _atualizar_objetivos_iniciais(em_planejador: bool):
	if not is_instance_valid(painel_objetivos): return
	if em_planejador:
		painel_objetivos.visible = false
		return
	var tem_fogueira = false
	for est in get_tree().get_nodes_in_group("construidos"):
		if is_instance_valid(est) and "is_fogueira" in est and est.is_fogueira:
			tem_fogueira = true; break
	var tem_cama = get_tree().get_nodes_in_group("camas").size() > 0
	var tem_colono = get_tree().get_nodes_in_group("colonos").size() > 0
	var ok1 = Global.tem_machado_pedra
	if ok1 and tem_fogueira and tem_cama and tem_colono:
		painel_objetivos.visible = false
		return
	painel_objetivos.visible = true
	label_objetivos.text = (
		"PRIMEIROS PASSOS:\n" +
		("[OK] " if ok1 else "[  ] ") + "Machado de Pedra [I]\n" +
		("[OK] " if tem_fogueira else "[  ] ") + "Construir Fogueira [B]\n" +
		("[OK] " if tem_cama else "[  ] ") + "Construir Cama [B]\n" +
		("[OK] " if tem_colono else "[  ] ") + "Contratar Colono (Bancada)"
	)
