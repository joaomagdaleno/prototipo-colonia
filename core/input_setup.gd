class_name InputSetup

## Utilitï¿½rio de configuraï¿½ï¿½o e mapeamento de controles (Teclado, Mouse e Gamepad)

static func configurar_acoes():
	_registrar("mover_frente", [KEY_W], [], JOY_AXIS_LEFT_Y, -1.0)
	_registrar("mover_tras", [KEY_S], [], JOY_AXIS_LEFT_Y, 1.0)
	_registrar("mover_esquerda", [KEY_A], [], JOY_AXIS_LEFT_X, -1.0)
	_registrar("mover_direita", [KEY_D], [], JOY_AXIS_LEFT_X, 1.0)

	_registrar("olhar_cima", [], [], JOY_AXIS_RIGHT_Y, -1.0)
	_registrar("olhar_baixo", [], [], JOY_AXIS_RIGHT_Y, 1.0)
	_registrar("olhar_esquerda", [], [], JOY_AXIS_RIGHT_X, -1.0)
	_registrar("olhar_direita", [], [], JOY_AXIS_RIGHT_X, 1.0)

	_registrar("interagir", [KEY_E], [JOY_BUTTON_X])
	_registrar("modo_mobilia", [KEY_B], [JOY_BUTTON_DPAD_DOWN])
	_registrar("abrir_inventario", [KEY_I], [JOY_BUTTON_DPAD_UP])

	_registrar("girar_esquerda", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER])
	_registrar("girar_direita", [KEY_R], [JOY_BUTTON_RIGHT_SHOULDER])

	_registrar("peca_anterior", [], [JOY_BUTTON_DPAD_LEFT])
	_registrar("peca_proxima", [KEY_TAB], [JOY_BUTTON_DPAD_RIGHT])

	_registrar("acao_principal", [], [], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var clique_esq = InputEventMouseButton.new()
	clique_esq.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("acao_principal", clique_esq)

	_registrar("acao_secundaria", [], [], JOY_AXIS_TRIGGER_LEFT, 1.0)
	var clique_dir = InputEventMouseButton.new()
	clique_dir.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("acao_secundaria", clique_dir)

	_registrar("pular", [KEY_SPACE], [JOY_BUTTON_A])
	_registrar("correr", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_registrar("agachar", [KEY_CTRL], [JOY_BUTTON_B])

	var confirmar_joy = InputEventJoypadButton.new()
	confirmar_joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept", confirmar_joy)

static func _registrar(nome: String, teclas: Array, botoes_joy: Array, eixo: JoyAxis = JOY_AXIS_INVALID, direcao_eixo: float = 0.0):
	if InputMap.has_action(nome):
		InputMap.action_erase_events(nome)
	else:
		InputMap.add_action(nome, 0.2)

	for tecla in teclas:
		var ev = InputEventKey.new()
		ev.keycode = tecla
		ev.physical_keycode = tecla
		InputMap.action_add_event(nome, ev)

	for botao in botoes_joy:
		var ev = InputEventJoypadButton.new()
		ev.button_index = botao
		InputMap.action_add_event(nome, ev)

	if eixo != JOY_AXIS_INVALID:
		var ev = InputEventJoypadMotion.new()
		ev.axis = eixo
		ev.axis_value = direcao_eixo
		InputMap.action_add_event(nome, ev)
