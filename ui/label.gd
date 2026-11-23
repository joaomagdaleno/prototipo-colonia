extends Label

func _process(_delta):
	text = "Madeira: " + str(Global.madeira)
	
	# Se tiver menos de 5 madeiras, o texto fica vermelho!
	if Global.madeira < 5:
		add_theme_color_override("font_color", Color.RED)
	else:
		add_theme_color_override("font_color", Color.WHITE)
