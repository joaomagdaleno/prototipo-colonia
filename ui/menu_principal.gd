extends Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var fundo = ColorRect.new()
	fundo.color = Color(0.08, 0.12, 0.09, 1.0)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(320, 260)
	vbox.position = Vector2(-160, -130)
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)
	
	var titulo = Label.new()
	titulo.text = "SOBREVIVÃŠNCIA & COLÃ”NIA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 26)
	vbox.add_child(titulo)
	
	var btn_novo = Button.new()
	btn_novo.text = "ðŸŒ² Novo Jogo"
	btn_novo.add_theme_font_size_override("font_size", 18)
	btn_novo.pressed.connect(func(): Global.iniciar_novo_jogo())
	vbox.add_child(btn_novo)
	
	var btn_carregar = Button.new()
	btn_carregar.text = "ðŸ“‚ Carregar Jogo Salvo"
	btn_carregar.add_theme_font_size_override("font_size", 18)
	btn_carregar.disabled = not Global.tem_save()
	btn_carregar.pressed.connect(func():
		Global.carregar_ao_iniciar = true
		get_tree().change_scene_to_file("res://world/Mundo.tscn")
	)
	vbox.add_child(btn_carregar)
	
	var btn_sair = Button.new()
	btn_sair.text = "âŒ Sair para o Windows"
	btn_sair.add_theme_font_size_override("font_size", 18)
	btn_sair.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_sair)
	
	btn_novo.grab_focus()
