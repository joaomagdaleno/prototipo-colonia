extends Node3D

var particulas: GPUParticles3D
var sol: DirectionalLight3D

func _ready():
	sol = get_parent().get_node_or_null("DirectionalLight3D")
	_otimizar_sol_vega8()
	_criar_particulas_chuva()

func _otimizar_sol_vega8():
	if not is_instance_valid(sol):
		return
	# Reduz de 4 renderizaï¿½ï¿½es de sombra por frame para apenas 2 (ganho enorme na Vega 8)
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Limita sombras dinï¿½micas a 55m ao redor da cï¿½mera (alï¿½m disso o Low Poly nï¿½o precisa)
	sol.directional_shadow_max_distance = 55.0
	# Suaviza a transiï¿½ï¿½o de sombra sem pesar na GPU
	sol.directional_shadow_blend_splits = false

func _criar_particulas_chuva():
	particulas = GPUParticles3D.new()
	particulas.amount = 220 # Leve para manter 60 FPS na Vega 8
	particulas.lifetime = 1.1
	particulas.visibility_aabb = AABB(Vector3(-15, -15, -15), Vector3(30, 30, 30))
	# Evita que as gotas de chuva tentem projetar sombra no mapa
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat_proc = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(14, 1, 14)
	mat_proc.direction = Vector3(0, -1, 0)
	mat_proc.spread = 3.0
	mat_proc.initial_velocity_min = 14.0
	mat_proc.initial_velocity_max = 18.0
	particulas.process_material = mat_proc
	
	var mesh_gota = BoxMesh.new()
	mesh_gota.size = Vector3(0.03, 0.45, 0.03)
	
	var mat_gota = StandardMaterial3D.new()
	mat_gota.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_gota.albedo_color = Color(0.7, 0.85, 1.0, 0.45)
	mat_gota.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_gota.material = mat_gota
	
	particulas.draw_pass_1 = mesh_gota
	particulas.emitting = false
	add_child(particulas)

func _process(delta):
	var chovendo = Global.esta_chovendo()
	particulas.emitting = chovendo
	
	# Sï¿½ atualiza a posiï¿½ï¿½o das partï¿½culas quando realmente estiver chovendo
	if chovendo:
		var cam_ativa = get_viewport().get_camera_3d()
		if is_instance_valid(cam_ativa):
			global_position = cam_ativa.global_position + Vector3(0, 10, 0)
	
	# Escurece suavemente a luz do sol durante tempo nublado ou chuva
	if is_instance_valid(sol):
		var energia_alvo = 1.0
		if Global.clima_atual == Global.Clima.NUBLADO:
			energia_alvo = 0.65
		elif chovendo:
			energia_alvo = 0.45
		
		# Sï¿½ interpola se ainda nï¿½o chegou no valor alvo
		if not is_equal_approx(sol.light_energy, energia_alvo):
			sol.light_energy = lerp(sol.light_energy, energia_alvo, 2.0 * delta)
