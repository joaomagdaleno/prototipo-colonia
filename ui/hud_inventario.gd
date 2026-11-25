extends Control

var painel: PanelContainer
var label_conteudo: Label
var btn_comer_refeicao: Button
var btn_comer_fruta: Button
var btn_beber_agua: Button
var btn_machado: Button
var btn_picareta: Button
var btn_lanca: Button
var btn_mochila: Button
var btn_balde: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(540, 560)
	painel.position = Vector2(-270, -280)
	painel.visible = false
	add_child(painel)

	var margem = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 20)
	margem.add_theme_constant_override("margin_top", 18)
	margem.add_theme_constant_override("margin_bottom", 18)
	painel.add_child(margem)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margem.add_child(vbox)

	label_conteudo = Label.new()
	label_conteudo.add_theme_font_size_override("font_size", 14)
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
	btn_machado.pressed.connect(func(): Global.melhorar_machado())
	vbox.add_child(btn_machado)

	btn_picareta = Button.new()
	btn_picareta.add_theme_font_size_override("font_size", 14)
	btn_picareta.focus_mode = Control.FOCUS_ALL
	btn_picareta.pressed.connect(func(): Global.melhorar_picareta())
	vbox.add_child(btn_picareta)

	btn_lanca = Button.new()
	btn_lanca.add_theme_font_size_override("font_size", 14)
	btn_lanca.focus_mode = Control.FOCUS_ALL
	btn_lanca.pressed.connect(func(): Global.melhorar_lanca())
	vbox.add_child(btn_lanca)

	btn_mochila = Button.new()
	btn_mochila.add_theme_font_size_override("font_size", 14)
	btn_mochila.focus_mode = Control.FOCUS_ALL
	btn_mochila.pressed.connect(func(): Global.craftar_mochila_couro())
	vbox.add_child(btn_mochila)
	btn_balde = Button.new()
	btn_balde.add_theme_font_size_override("font_size", 14)
	btn_balde.focus_mode = Control.FOCUS_ALL
	btn_balde.pressed.connect(func():
		if not Global.tem_balde:
			Global.craftar_balde()
		else:
			Global.encher_balde()
	)
	vbox.add_child(btn_balde)

func _pode_beber_agora() -> bool:
	if Global.esta_chovendo():
		return true
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	if is_instance_valid(jogador):
		if abs(jogador.global_position.x) >= 115.0 or abs(jogador.global_position.z) >= 115.0:
			return true
		for p in Global.pocos_ativos:
			if is_instance_valid(p) and p.construida and p.baldes_agua_poco >= 3 and jogador.global_position.distance_squared_to(p.global_position) <= 16.0:
				return true
	return false

func atualizar(deve_mostrar: bool):
	var estava_aberto = painel.visible
	painel.visible = deve_mostrar
	if not deve_mostrar:
		return

	var colonos = get_tree().get_nodes_in_group("colonos").size()
	var camas = Global.camas_ativas.size()
	var projetos = get_tree().get_nodes_in_group("projetos").size()
	var status_equip = "Machado T" + str(Global.tier_machado) + " | Picareta T" + str(Global.tier_picareta) + " | Lança T" + str(Global.tier_lanca)
	var status_mochila = ("Mochila Couro (+15 Cap / +25% Vel)" if Global.tem_mochila_couro else "Sem Mochila") + " | Peso: " + str(snapped(Global.obter_peso_atual(), 0.1)) + "/" + str(int(Global.obter_capacidade_peso()))
	var status_cura = "ATIVA (+2 HP/s)" if (Global.saciedade_jogador >= 70.0 and Global.hidratacao_jogador >= 70.0 and Global.tempo_sem_combate >= 6.0) else "Inativa (Requer >=70% Fome/Sede e paz)"
	var dica = "[B / Círculo / Start] Fechar  |  [D-Pad] Navegar  |  [Y] Melhorar" if Global.usando_joystick else "[I / ESC] Fechar  |  [Clique] Usar/Fabricar"

	label_conteudo.text = (
		"=== INVENTÁRIO & FORJA DE TIERS ===\n" +
		"• Regeneração Natural: " + status_cura + "\n" +
		"• Arsenal: " + status_equip + " | " + status_mochila + "\n" +
		"• Madeira: " + str(Global.madeira) + " | Pedra: " + str(Global.pedra) + " | Pedrinhas: " + str(Global.pedrinhas) + " | Gravetos: " + str(Global.gravetos) + "\n" +
		"• Couro: " + str(Global.couro) + " | Carne Crua: " + str(Global.carne_crua) + " | Frutas: " + str(Global.frutas) + " | Comida: " + str(Global.comida) + "\n" +
		"• Colonos / Camas: " + str(colonos) + " / " + str(camas) + " | Projetos: " + str(projetos) + "\n" +
		dica
	)

	btn_comer_refeicao.text = "🍲 Comer Refeição Pronta (+35% Fome) [Disp: " + str(Global.comida) + "]"
	btn_comer_refeicao.disabled = Global.comida < 1 or Global.saciedade_jogador >= 98.0

	btn_comer_fruta.text = "🫐 Comer Fruta (+12% Fome, +10% Sede) [Disp: " + str(Global.frutas) + "]"
	btn_comer_fruta.disabled = Global.frutas < 1 or (Global.saciedade_jogador >= 98.0 and Global.hidratacao_jogador >= 98.0)

	var pode_beber = _pode_beber_agora()
	btn_beber_agua.text = "💧 Beber Água (+45% Sede)" if pode_beber else "💧 Beber Água (Vá até a borda da ilha, um Poço ou espere chuva)"
	btn_beber_agua.disabled = not pode_beber or Global.hidratacao_jogador >= 98.0

	if Global.tier_machado == 0:
		btn_machado.text = "🪓 Fabricar Machado de Pedra T1 (3 Grav + 2 Pedr)"
		btn_machado.disabled = Global.gravetos < 3 or Global.pedrinhas < 2
	elif Global.tier_machado == 1:
		btn_machado.text = "🪓 Melhorar Machado Reforçado T2 (6 Mad + 4 Ped + 2 Couro)"
		btn_machado.disabled = Global.madeira < 6 or Global.pedra < 4 or Global.couro < 2
	else:
		btn_machado.text = "✅ Machado Reforçado T2 Máximo (4x Dano em Árvores)"
		btn_machado.disabled = true

	if Global.tier_picareta == 0:
		btn_picareta.text = "⛏ Fabricar Picareta de Pedra T1 (3 Grav + 3 Pedr)"
		btn_picareta.disabled = Global.gravetos < 3 or Global.pedrinhas < 3
	elif Global.tier_picareta == 1:
		btn_picareta.text = "⛏ Melhorar Picareta Reforçada T2 (6 Mad + 6 Ped + 2 Couro)"
		btn_picareta.disabled = Global.madeira < 6 or Global.pedra < 6 or Global.couro < 2
	else:
		btn_picareta.text = "✅ Picareta Reforçada T2 Máxima (4x Dano em Rochas)"
		btn_picareta.disabled = true

	if Global.tier_lanca == 0:
		btn_lanca.text = "🗡 Fabricar Lança de Madeira T1 (4 Grav + 1 Couro)"
		btn_lanca.disabled = Global.gravetos < 4 or Global.couro < 1
	elif Global.tier_lanca == 1:
		btn_lanca.text = "🗡 Melhorar Lança Ponta de Pedra T2 (4 Mad + 3 Pedr + 2 Couro)"
		btn_lanca.disabled = Global.madeira < 4 or Global.pedrinhas < 3 or Global.couro < 2
	else:
		btn_lanca.text = "✅ Lança Ponta de Pedra T2 Máxima (4x Dano em Caça/Combate)"
		btn_lanca.disabled = true

	btn_mochila.text = "✅ Mochila de Couro Equipada (+15 Cap)" if Global.tem_mochila_couro else "🎒 Fabricar Mochila de Couro (+15 Cap | 4 Couros + 3 Gravetos)"
	btn_mochila.disabled = Global.tem_mochila_couro or Global.couro < 4 or Global.gravetos < 3
	var pa = Global.esta_chovendo()
	var jr = get_tree().current_scene.get_node_or_null("Jogador")
	if is_instance_valid(jr) and (abs(jr.global_position.x) >= 115.0 or abs(jr.global_position.z) >= 115.0): pa = true
	btn_balde.text = "Fabricar Balde (3 Mad + 2 Grav)" if not Global.tem_balde else ("Balde Cheio (Use no Poco)" if Global.balde_cheio else ("Encher Balde" if pa else "Balde Vazio (Va a costa/chuva)"))
	btn_balde.disabled = (Global.madeira < 3 or Global.gravetos < 2) if not Global.tem_balde else (Global.balde_cheio or not pa)

	if not estava_aberto:
		btn_comer_refeicao.grab_focus()

func _input(event):
	if not painel.visible or get_tree().paused:
		return
	var fechou := false
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_I or event.keycode == KEY_ESCAPE):
		fechou = true
	elif event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START):
		fechou = true
	if fechou:
		var jogador = get_tree().current_scene.get_node_or_null("Jogador")
		if is_instance_valid(jogador) and jogador.inventario_aberto:
			jogador._alternar_inventario()
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if painel.visible and not get_tree().paused and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		if not btn_machado.disabled: Global.melhorar_machado()
		elif not btn_picareta.disabled: Global.melhorar_picareta()
		elif not btn_lanca.disabled: Global.melhorar_lanca()
		elif not btn_mochila.disabled: Global.craftar_mochila_couro()
