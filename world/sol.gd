extends DirectionalLight3D

func _process(_delta):
	# Converte a hora (0 a 24) em ï¿½ngulo de rotaï¿½ï¿½o do sol
	# ï¿½s 06:00 o sol nasce (0ï¿½), ao meio-dia estï¿½ no topo (-90ï¿½), ï¿½s 18:00 se pï¿½e (-180ï¿½)
	var progresso_dia = (Global.hora_do_dia - 6.0) / 24.0
	rotation.x = -progresso_dia * TAU
	
	# Apaga a luz direcional ï¿½ noite para nï¿½o iluminar por baixo do chï¿½o
	if Global.esta_de_noite():
		light_energy = lerp(light_energy, 0.05, 0.05)
	else:
		light_energy = lerp(light_energy, 1.0, 0.05)
