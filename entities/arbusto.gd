extends StaticBody3D

var tem_frutas: bool = true
var reservado: bool = false
var marcado_para_coleta: bool = false

@export var comida_por_colheita: int = 5
@export var tempo_regeneracao: float = 30.0

@onready var copa_mesh: MeshInstance3D = $Copa
@onready var tronco_mesh: MeshInstance3D = $Tronco

var grupo_frutas: Node3D = null
var _timer_regenerar: Timer

func _ready():
	add_to_group("arbustos")
	_configurar_copa_e_frutas()
	
	_timer_regenerar = Timer.new()
	_timer_regenerar.one_shot = true
	_timer_regenerar.wait_time = tempo_regeneracao
	_timer_regenerar.timeout.connect(_regenerar_frutas)
	add_child(_timer_regenerar)

func _configurar_copa_e_frutas():
	# Desativa sombras e aplica limite de visão leve para a Radeon Vega 8
	for mesh in [tronco_mesh, copa_mesh]:
		if is_instance_valid(mesh):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = 65.0
			mesh.visibility_range_end_margin = 5.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	if not is_instance_valid(copa_mesh):
		return

	# Cria um nó agrupador na altura da Copa com 5 frutinhas vermelhas
	grupo_frutas = Node3D.new()
	grupo_frutas.position = copa_mesh.position
	add_child(grupo_frutas)

	var mesh_fruta = SphereMesh.new()
	mesh_fruta.radius = 0.08
	mesh_fruta.height = 0.16
	mesh_fruta.radial_segments = 6
	mesh_fruta.rings = 4

	var mat_fruta = StandardMaterial3D.new()
	mat_fruta.albedo_color = Color(0.9, 0.15, 0.2)
	mesh_fruta.material = mat_fruta

	var raio_copa = max(0.35, copa_mesh.get_aabb().size.x * copa_mesh.scale.x * 0.45)
	for i in range(5):
		var ang = (float(i) / 5.0) * TAU
		var fruta = MeshInstance3D.new()
		fruta.mesh = mesh_fruta
		fruta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fruta.visibility_range_end = 45.0
		fruta.position = Vector3(cos(ang) * raio_copa, sin(i * 1.7) * 0.12, sin(ang) * raio_copa)
		grupo_frutas.add_child(fruta)

func alternar_marcacao(ativar: bool):
	if marcado_para_coleta == ativar:
		return
	marcado_para_coleta = ativar
	if ativar: add_to_group("recursos_marcados")
	else: remove_from_group("recursos_marcados")
	if is_instance_valid(copa_mesh):
		copa_mesh.transparency = 0.35 if ativar else 0.0
		copa_mesh.visibility_range_end = 150.0 if ativar else 65.0

# Chamado pelo Jogador (apertando E/X) ou pelo Colono
func colher():
	if not tem_frutas:
		print("Este arbusto ainda não tem frutas!")
		return
		
	tem_frutas = false
	reservado = false
	marcado_para_coleta = false
	Global.frutas += comida_por_colheita
	print("Frutas colhidas! +", comida_por_colheita, " frutas cruas | Total frutas: ", Global.frutas)
	
	# Esconde apenas as frutinhas na Copa (o Tronco fica intacto)
	if is_instance_valid(grupo_frutas):
		grupo_frutas.visible = false
	if is_instance_valid(copa_mesh):
		copa_mesh.transparency = 0.0
		var escala_original = copa_mesh.scale
		var tween = create_tween()
		tween.tween_property(copa_mesh, "scale", escala_original * 0.92, 0.08)
		tween.tween_property(copa_mesh, "scale", escala_original, 0.12)
		
	_timer_regenerar.start()

func _regenerar_frutas():
	tem_frutas = true
	if is_instance_valid(grupo_frutas):
		grupo_frutas.visible = true
	print("Um arbusto regenerou frutas!")
