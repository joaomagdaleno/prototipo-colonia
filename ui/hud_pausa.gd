extends Control

## Menu de Pausa

var painel: PanelContainer
var btn_continuar: Button
var btn_carregar: Button
var label_feedback: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(340, 320)
	painel.position = Vector2(-170, -160)
	painel.visible = false
	add_child(painel)
	
	var margem = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 25)
	margem.add_theme_constant_override("margin_right", 25)
	margem.add_theme_constant_override("margin_top", 20)
	margem.add_theme_constant_override("margin_bottom", 20)
	painel.add_child(margem)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margem.add_child(vbox)
	
	var titulo = Label.new()
	titulo.text = "⏸️ JOGO PAUSADO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	vbox.add_child(titulo)
	
	btn_continuar = Button.new()
	btn_continuar.text = "▶️ Continuar"
	btn_continuar.add_theme_font_size_override("font_size", 16)
	btn_continuar.pressed.connect(func(): get_parent().alternar_pausa())
	vbox.add_child(btn_continuar)
	
	var btn_salvar = Button.new()
	btn_salvar.text = "💾 Salvar Jogo"
	btn_salvar.add_theme_font_size_override("font_size", 16)
	btn_salvar.pressed.connect(func():
		label_feedback.text = "✅ Jogo salvo com sucesso!" if Global.salvar_jogo() else "❌ Erro ao salvar!"
	)
	vbox.add_child(btn_salvar)
	
	btn_carregar = Button.new()
	btn_carregar.text = "📂 Carregar Jogo Salvo"
	btn_carregar.add_theme_font_size_override("font_size", 16)
	btn_carregar.pressed.connect(func():
		if Global.carregar_jogo():
			label_feedback.text = "✅ Save carregado!"
			get_parent().alternar_pausa()
	)
	vbox.add_child(btn_carregar)
	
	var btn_menu = Button.new()
	btn_menu.text = "🏠 Voltar ao Menu Principal"
	btn_menu.add_theme_font_size_override("font_size", 16)
	btn_menu.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://ui/MenuPrincipal.tscn")
	)
	vbox.add_child(btn_menu)
	
	label_feedback = Label.new()
	label_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_feedback.add_theme_font_size_override("font_size", 14)
	label_feedback.modulate = Color(0.5, 1.0, 0.5)
	vbox.add_child(label_feedback)

func definir_visivel(mostrar: bool):
	painel.visible = mostrar
	if mostrar:
		label_feedback.text = ""
		btn_carregar.disabled = not Global.tem_save()
		btn_continuar.grab_focus()
