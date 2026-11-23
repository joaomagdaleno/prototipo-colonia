extends DirectionalLight3D

var _timer_sol: float = 0.0
var _cam_aerea_cache: Camera3D = null

func _ready():
	directional_shadow_max_distance = 42.0
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

	var noite = Global.esta_de_noite()
	if noite:
		if shadow_enabled:
			shadow_enabled = false
		light_energy = 0.05
		return

	# Na visao aerea com zoom alto (Y > 32m), desliga sombras dinamicas para aliviar a Vega 8
	if not is_instance_valid(_cam_aerea_cache) and get_parent():
		_cam_aerea_cache = get_parent().get_node_or_null("CameraAerea")
	var zoom_aereo_alto = is_instance_valid(_cam_aerea_cache) and _cam_aerea_cache.current and _cam_aerea_cache.global_position.y > 32.0

	var deve_ter_sombra = not zoom_aereo_alto
	if shadow_enabled != deve_ter_sombra:
		shadow_enabled = deve_ter_sombra