extends CharacterBody3D

const VELOCIDADE_ANDAR := 5.0
const VELOCIDADE_CORRER := 8.5
const VELOCIDADE_AGACHADO := 2.5
const FORCA_PULO := 5.2

const ALTURA_EM_PE := 1.8
const ALTURA_AGACHADO := 1.0
const CAM_Y_EM_PE := 1.6
const CAM_Y_AGACHADO := 0.85

const SENSIBILIDADE_MOUSE := 0.003
const SENSIBILIDADE_CONTROLE := 2.5
const GRAVIDADE := 12.0

@onready var camera: Camera3D = $Camera3D
@onready var colisor: CollisionShape3D = $CollisionShape3D
@onready var camera_aerea: Camera3D = get_parent().get_node("CameraAerea")
@onready var interacao_comp = $Interacao
@onready var mobilia_comp = $Mobilia

var opcoes_mobilia: Array[PackedScene]:
	get: return mobilia_comp.opcoes_mobilia
var indice_mobilia: int:
	get: return mobilia_comp.indice_mobilia
var fantasma_1p: Node3D:
	get: return mobilia_comp.fantasma_1p

var agachado: bool = false
var correndo_toggle_joy: bool = false
var construindo_1p: bool = false
var inventario_aberto: bool = false
var menu_construcao_aberto: bool = false
var no_modo_construcao: bool = false
var tempo_recarga_golpe: float = 0.0

func _ready():
	Input.set_mouse_mode.call_deferred(Input.MOUSE_MODE_CAPTURED)
	set_physics_process(false)

func nascer_no_mundo(posicao_segura: Vector3 = Vector3(0, 1.2, 3)):
	if not SaveManager.carregar_ao_iniciar:
		global_position = posicao_segura
	velocity = Vector3.ZERO
	set_physics_process(true)
	print("🧍 Jogador posicionado e pronto em: ", global_position)

func _input(event):
	if get_tree().paused: return

	if not no_modo_construcao and not inventario_aberto and not menu_construcao_aberto and event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * SENSIBILIDADE_MOUSE)
			camera.rotate_x(-event.relative.y * SENSIBILIDADE_MOUSE)
			camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

	if construindo_1p and not no_modo_construcao and not inventario_aberto and not menu_construcao_aberto:
		if event.is_action_pressed("acao_principal"):
			if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mobilia_comp.colocar_peca()
		elif event.is_action_pressed("acao_secundaria"):
			mobilia_comp.alternar_modo()

func _unhandled_input(event):
	if get_tree().paused: return
		
	if not no_modo_construcao and not menu_construcao_aberto and event.is_action_pressed("abrir_inventario"):
		_alternar_inventario()
		return

	if inventario_aberto: return

	if not no_modo_construcao and event.is_action_pressed("modo_mobilia"):
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud and hud.has_node("ConstrucaoMenuUI"):
			var menu = hud.get_node("ConstrucaoMenuUI")
			menu_construcao_aberto = not menu.painel.visible
			menu.definir_visivel(menu_construcao_aberto)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_construcao_aberto else Input.MOUSE_MODE_CAPTURED
		else:
			mobilia_comp.alternar_modo()

	if menu_construcao_aberto: return

	if not no_modo_construcao:
		if event.is_action_pressed("agachar"):
			if agachado and _pode_levantar(): agachado = false
			elif not agachado: agachado = true; correndo_toggle_joy = false
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_STICK and not agachado:
			correndo_toggle_joy = not correndo_toggle_joy

	mobilia_comp.processar_inputs_mobilia(event)
		
	if event.is_action_pressed("interagir"):
		if no_modo_construcao: alternar_modo_construcao()
		else: interacao_comp.executar_interacao()

func alternar_modo_construcao():
	no_modo_construcao = not no_modo_construcao
	camera_aerea.current = no_modo_construcao
	camera.current = not no_modo_construcao
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if no_modo_construcao else Input.MOUSE_MODE_CAPTURED
	if no_modo_construcao: velocity = Vector3.ZERO

func _alternar_inventario():
	inventario_aberto = not inventario_aberto
	if inventario_aberto and construindo_1p:
		mobilia_comp.alternar_modo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventario_aberto else Input.MOUSE_MODE_CAPTURED

func obter_dica_mira() -> String:
	return interacao_comp.obter_dica_mira()

func _physics_process(delta):
	if get_tree().paused or no_modo_construcao or inventario_aberto or menu_construcao_aberto: return
		
	var olhar_joy = Input.get_vector("olhar_esquerda", "olhar_direita", "olhar_cima", "olhar_baixo")
	if olhar_joy.length() > 0:
		rotate_y(-olhar_joy.x * SENSIBILIDADE_CONTROLE * delta)
		camera.rotate_x(-olhar_joy.y * SENSIBILIDADE_CONTROLE * delta)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

	if tempo_recarga_golpe > 0: tempo_recarga_golpe -= delta

	if construindo_1p:
		mobilia_comp.atualizar_fantasma()
	elif Input.is_action_pressed("acao_principal"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif tempo_recarga_golpe <= 0:
			tempo_recarga_golpe = 0.4
			interacao_comp.executar_golpe()

	camera.position.y = lerp(camera.position.y, CAM_Y_AGACHADO if agachado else CAM_Y_EM_PE, 12.0 * delta)
	if colisor and colisor.shape is CapsuleShape3D:
		colisor.shape.height = lerp(colisor.shape.height, ALTURA_AGACHADO if agachado else ALTURA_EM_PE, 12.0 * delta)
		colisor.position.y = colisor.shape.height * 0.5
		
	if not is_on_floor(): velocity.y -= GRAVIDADE * delta
	elif Input.is_action_just_pressed("pular"):
		if agachado and _pode_levantar(): agachado = false
		velocity.y = FORCA_PULO
	
	var input_dir = Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
	var direcao = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direcao.length() == 0: correndo_toggle_joy = false
		
	var quer_correr = (Input.is_action_pressed("correr") or correndo_toggle_joy) and not agachado and input_dir.y < -0.1
	var vel_atual = VELOCIDADE_AGACHADO if agachado else (VELOCIDADE_CORRER if quer_correr else VELOCIDADE_ANDAR)
	if Global.tem_mochila_couro: vel_atual *= 1.25
	
	velocity.x = direcao.x * vel_atual if direcao.length() > 0 else move_toward(velocity.x, 0, vel_atual)
	velocity.z = direcao.z * vel_atual if direcao.length() > 0 else move_toward(velocity.z, 0, vel_atual)
	move_and_slide()

func _pode_levantar() -> bool:
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, ALTURA_EM_PE, 0))
	query.exclude = [self]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
