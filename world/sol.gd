extends DirectionalLight3D

var _timer_sol: float = 0.0

func _ready():
	_atualizar_sol()

func _process(delta):
	_timer_sol -= delta
	if _timer_sol > 0.0:
		return
	_timer_sol = 0.4
	_atualizar_sol()

func _atualizar_sol():
	# Converte a hora (0 a 24) em angulo de rotacao do sol (atualizado a cada 0.4s para poupar shadow maps na Vega 8)
	var progresso_dia = (Global.hora_do_dia - 6.0) / 24.0
	rotation.x = -progresso_dia * TAU

	# Desliga sombras direcionais e reduz energia a noite para nao iluminar por baixo do chao
	var noite = Global.esta_de_noite()
	shadow_enabled = not noite
	if noite:
		light_energy = 0.05
