extends Control

var painel: PanelContainer
var label_conteudo: Label
var btn_comer_refeicao: Button
var btn_comer_fruta: Button
var btn_beber_agua: Button
var btn_machado: Button
var btn_mochila: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(480, 470)
	painel.position = Vector2(-240, -235)
	painel.visible = false
	add_child(painel)
	
	var margem = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 20)
	margem.add_theme_constant_override("margin_top", 20)
	margem.add_theme_constant_override("margin_bottom", 20)
	painel.add_child(margem)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margem.add_child(vbox)
	
	label_conteudo = Label.new()
	label_conteudo.add_theme_font_size_override("font_size", 15)
	vbox.add_child(label_conteudo)
	
	btn_comer_refeicao = Button.new()
	btn_comer_refeicao.add_theme_font_size_override("font_size", 14)
	btn_comer_refeicao.focus_mode = Control.FOCUS_ALL
	btn_comer_refeicao.pressed.connect(func(): Global.comer_jogador(true))
	vbox.add_child(btn_comer_refeicao)

	btn_comer_fruta = Button.new()
	btn_comer_fruta.add_theme_font_size_override("font_size", 14)
	btn_comer_fruta.focus_mode = Control.FOCUS_ALL
	btn_comer_fruta.pressed.connect(func(): Global.comer_jogador(false))
	vbox.add_child(btn_comer_fruta)

	btn_beber_agua = Button.new()
	btn_beber_agua.add_theme_font_size_override("font_size", 14)
	btn_beber_agua.focus_mode = Control.FOCUS_ALL
	btn_beber_agua.pressed.connect(func(): Global.beber_agua_jogador())
	vbox.add_child(btn_beber_agua)
	
	btn_machado = Button.new()
	btn_machado.add_theme_font_size_override("font_size", 14)
	btn_machado.focus_mode = Control.FOCUS_ALL
	btn_machado.pressed.connect(func(): Global.craftar_machado_pedra())
	vbox.add_child(btn_machado)
	
	btn_mochila = Button.new()
	btn_mochila.add_theme_font_size_override("font_size", 14)
	btn_mochila.focus_mode = Control.FOCUS_ALL
	btn_mochila.pressed.connect(func(): Global.craftar_mochila_couro())
	vbox.add_child(btn_mochila)

func _pode_beber_agora() -> bool:
	if Global.esta_chovendo():
		return true
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	if is_instance_valid(jogador):
		# Perto da borda da ilha/ï¿½gua (raio > 115m)
		if abs(jogador.global_position.x) >= 115.0 or abs(jogador.global_position.z) >= 115.0:
			return true
	return false

func atualizar(deve_mostrar: bool):
	var estava_aberto = painel.visible
	painel.visible = deve_mostrar
	if not deve_mostrar:
		return
		
	var colonos = get_tree().get_nodes_in_group("colonos").size()
	var camas = get_tree().get_nodes_in_group("camas").size()
	var projetos = get_tree().get_nodes_in_group("projetos").size()
	var status_machado = "Machado de Pedra (2x Dano)" if Global.tem_machado_pedra else "Machado Improvisado (1x Dano)"
	var status_mochila = "Mochila de Couro (+25% Vel / +1 Coleta)" if Global.tem_mochila_couro else "Sem Mochila"
	var status_cura = "ATIVA (+2 HP/s)" if (Global.saciedade_jogador >= 70.0 and Global.hidratacao_jogador >= 70.0 and Global.tempo_sem_combate >= 6.0) else "Inativa (Requer >=70% Fome/Sede e paz)"
	var dica = "[D-Pad ? / Start] Fechar  |  [D-Pad ? + A] Usar/Fabricar" if Global.usando_joystick else "[I / ESC] Fechar  |  [Clique] Usar/Fabricar"
	
	label_conteudo.text = (
		"=== INVENTï¿½RIO & SOBREVIVï¿½NCIA ===\n" +
		". Regeneraï¿½ï¿½o Natural: " + status_cura + "\n" +
		". Ferramenta: " + status_machado + " | " + status_mochila + "\n" +
		". Madeira: " + str(Global.madeira) + " | Pedra: " + str(Global.pedra) + " | Pedrinhas: " + str(Global.pedrinhas) + " | Gravetos: " + str(Global.gravetos) + "\n" +
		". Couro: " + str(Global.couro) + " | Carne Crua: " + str(Global.carne_crua) + " | Frutas: " + str(Global.frutas) + " | Comida: " + str(Global.comida) + "\n" +
		". Colonos / Camas: " + str(colonos) + " / " + str(camas) + " | Projetos: " + str(projetos) + "\n" +
		dica
	)
	
	btn_comer_refeicao.text = "?? Comer Refeiï¿½ï¿½o Pronta (+35% Fome) [Disp: " + str(Global.comida) + "]"
	btn_comer_refeicao.disabled = Global.comida < 1 or Global.saciedade_jogador >= 98.0

	btn_comer_fruta.text = "?? Comer Fruta (+12% Fome, +10% Sede) [Disp: " + str(Global.frutas) + "]"
	btn_comer_fruta.disabled = Global.frutas < 1 or (Global.saciedade_jogador >= 98.0 and Global.hidratacao_jogador >= 98.0)

	var pode_beber = _pode_beber_agora()
	btn_beber_agua.text = "?? Beber ï¿½gua (+45% Sede)" if pode_beber else "?? Beber ï¿½gua (Vï¿½ atï¿½ a ï¿½gua na borda da ilha ou espere chuva)"
	btn_beber_agua.disabled = not pode_beber or Global.hidratacao_jogador >= 98.0
	
	btn_machado.text = "? Machado de Pedra Jï¿½ Equipado" if Global.tem_machado_pedra else "?? Fabricar Machado de Pedra (3 Gravetos + 2 Pedrinhas)"
	btn_machado.disabled = Global.tem_machado_pedra or Global.gravetos < 3 or Global.pedrinhas < 2

	btn_mochila.text = "? Mochila de Couro Jï¿½ Equipada" if Global.tem_mochila_couro else "?? Fabricar Mochila de Couro (4 Couros + 3 Gravetos)"
	btn_mochila.disabled = Global.tem_mochila_couro or Global.couro < 4 or Global.gravetos < 3
		
	if not estava_aberto:
		btn_comer_refeicao.grab_focus()

func _unhandled_input(event):
	if painel.visible and not get_tree().paused and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		if not btn_machado.disabled: Global.craftar_machado_pedra()
		elif not btn_mochila.disabled: Global.craftar_mochila_couro()
