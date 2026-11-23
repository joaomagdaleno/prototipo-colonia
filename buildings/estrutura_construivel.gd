extends Node3D
class_name EstruturaConstruivel

@export var custo_madeira: int = 5
@export var custo_pedra: int = 0
@export var custo_gravetos: int = 0
@export var custo_pedrinhas: int = 0

@export var is_bancada: bool = false
@export var is_cama: bool = false
@export var is_fogueira: bool = false
@export var is_bau: bool = false
@export var is_canteiro: bool = false
@export var is_poco: bool = false
@export var is_curtume: bool = false
var canteiro_plantado: bool = false
var progresso_cultivo: float = 0.0
var reservado_colono: bool = false
var mesh_cultivo: MeshInstance3D = null
var _timer_cultivo: float = 1.0
@export var is_parede: bool = false
@export var is_teto: bool = false
@export var modo_macro: bool = true

@export var is_muro: bool = false
@export var is_portao: bool = false
@export var vida_maxima: int = 100

# Armazenamento Físico (Baú)
var estoque_bau: Dictionary = {
	"madeira": 0,
	"pedra": 0,
	"gravetos": 0,
	"pedrinhas": 0,
	"comida": 0,
	"frutas": 0
}
const CAPACIDADE_MAXIMA_BAU: int = 150

var vida_atual: int = 100
var portao_aberto: bool = false
var coordenada_grade: Vector2i = Vector2i.ZERO
var obstaculo_nav: NavigationObstacle3D = null

var construida: bool = false
var reservado: bool = false
var ocupada: bool = false

var _protegida_chuva_cache: bool = false
var _timer_chuva: float = randf_range(0.1, 1.5)

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var corpo_fisico: CollisionObject3D = get_node_or_null("CorpoFisico") if has_node("CorpoFisico") else self
@onready var luz: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready():
	# Desliga _process em todas as estruturas por padrï¿½o (sï¿½ fogueira construï¿½da liga depois)
	set_process(false)
	_aplicar_visual_low_poly()
	
	# Estradas sï¿½o rasas e nï¿½o precisam projetar sombra nem renderizar a 200m
	if is_in_group("estradas"):
		construida = true
		mesh.transparency = 0.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 120.0
		# Remove colisor fisico da estrada para aliviar o servidor de fisica 3D
		if corpo_fisico != self:
			corpo_fisico.queue_free()
		elif has_node("CollisionShape3D"):
			$CollisionShape3D.queue_free()
		add_to_group("construidos")
		coordenada_grade = Vector2i(int(round(global_position.x)), int(round(global_position.z)))
		Global.estradas_pos[coordenada_grade] = self
		return

	# Projetos fantasmas nï¿½o projetam sombra
	mesh.transparency = 0.5
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo_fisico.collision_layer = 2
	corpo_fisico.collision_mask = 0
	
	if luz:
		luz.visible = false
		_otimizar_luz_fogueira()
		
	if not is_bancada:
		add_to_group("projetos")

func _otimizar_luz_fogueira():
	# OmniLight3D com sombra ï¿½ o maior vilï¿½o de FPS em GPUs integradas (renderiza 6 cï¿½meras por luz!)
	luz.shadow_enabled = false
	# Faz a luz apagar suavemente quando a cï¿½mera estï¿½ longe (> 35m)
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 25.0
	luz.distance_fade_length = 10.0

func _obter_total_disponivel(recurso: String) -> int:
	return int(Global.get(recurso)) + int(Global.estoque_total_baus.get(recurso, 0))

func _consumir_recurso_global_ou_bau(recurso: String, qtd: int):
	var restante = qtd
	var no_jogador = int(Global.get(recurso))
	if no_jogador > 0:
		var tirar_jog = min(no_jogador, restante)
		Global.set(recurso, no_jogador - tirar_jog)
		restante -= tirar_jog
		
	if restante > 0:
		for bau in Global.baus_ativos:
			if is_instance_valid(bau) and bau.construida and bau.has_method("retirar_item_do_bau"):
				var tirado = bau.retirar_item_do_bau(recurso, restante)
				restante -= tirado
				if restante <= 0:
					break

func pode_pagar() -> bool:
	return (
		_obter_total_disponivel("madeira") >= custo_madeira and
		_obter_total_disponivel("pedra") >= custo_pedra and
		_obter_total_disponivel("gravetos") >= custo_gravetos and
		_obter_total_disponivel("pedrinhas") >= custo_pedrinhas
	)

func construir() -> bool:
	if is_in_group("estradas"):
		Global.estradas_pos.erase(coordenada_grade)
	if is_fogueira:
		Global.fogueiras_ativas.erase(self)
	if is_cama:
		Global.camas_ativas.erase(self)
	if is_canteiro:
		Global.canteiros_ativos.erase(self)
	if is_poco:
		Global.pocos_ativos.erase(self)
	if construida:
		return false
		
	if not pode_pagar():
		print("Faltam recursos! Precisa -> Mad:", custo_madeira, " | Pedra:", custo_pedra, " | Grav:", custo_gravetos, " | Pedrinhas:", custo_pedrinhas)
		return false

	_consumir_recurso_global_ou_bau("madeira", custo_madeira)
	_consumir_recurso_global_ou_bau("pedra", custo_pedra)
	_consumir_recurso_global_ou_bau("gravetos", custo_gravetos)
	_consumir_recurso_global_ou_bau("pedrinhas", custo_pedrinhas)
	
	construida = true
	reservado = false
	vida_atual = vida_maxima
	print("Construï¿½do: ", name)
	
	mesh.transparency = 0.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	corpo_fisico.collision_layer = 1
	corpo_fisico.collision_mask = 1
	
	remove_from_group("projetos")
	add_to_group("construidos")
	coordenada_grade = Vector2i(int(round(global_position.x)), int(round(global_position.z)))
	Global.estradas_pos[coordenada_grade] = self
	
	if luz:
		luz.visible = true
		_otimizar_luz_fogueira()
		
	# Sï¿½ ativa o _process se for realmente uma fogueira pronta
	if is_fogueira:
		add_to_group("fogueiras")
		if not self in Global.fogueiras_ativas:
			Global.fogueiras_ativas.append(self)
		if luz:
			set_process(true)
	
	if is_cama:
		add_to_group("camas")
		if not self in Global.camas_ativas:
			Global.camas_ativas.append(self)
	
	if is_bau:
		add_to_group("baus")
	if is_canteiro:
		add_to_group("canteiros")
	if is_poco:
		add_to_group("pocos")
		if not self in Global.pocos_ativos:
			Global.pocos_ativos.append(self)
		if not self in Global.canteiros_ativos:
			Global.canteiros_ativos.append(self)
		_criar_visual_cultivo()
		if not self in Global.baus_ativos:
			Global.baus_ativos.append(self)
	
	if is_parede:
		add_to_group("paredes")
		
	if is_teto:
		add_to_group("tetos")
	
	if has_node("AreaInteracao"):
		$AreaInteracao.queue_free()
		
	AudioManager.tocar("construir")
	_configurar_obstaculo_navegacao()
	Global.atualizar_navmesh_otimizado()
	return true


func esta_protegida_da_chuva() -> bool:
	var origem = global_position + Vector3(0, 0.5, 0)
	var destino = origem + Vector3(0, 10.0, 0)
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.collision_mask = 1
	var resultado = get_world_3d().direct_space_state.intersect_ray(query)
	return not resultado.is_empty()

func cozinhar() -> bool:
	if not construida or not is_fogueira:
		return false
		
	if Global.esta_chovendo() and not esta_protegida_da_chuva():
		print("🌧 A fogueira apagou por causa da chuva! Construa um teto acima dela.")
		return false
		
	if Global.carne_crua >= 1:
		Global.carne_crua -= 1
		Global.comida += 8
		print("🍖 Carne assada na fogueira! -1 Carne Crua | +8 Comida Pronta")
		return true
		
	elif Global.frutas >= 2:
		Global.frutas -= 2
		Global.comida += 5
		print("🍲 Frutas cozidas! -2 Frutas | +5 Comida Pronta")
		return true
		
	else:
		print("Vocï¿½ precisa de pelo menos 2 frutas cruas para cozinhar na fogueira!")
		return false

func demolir():
	if is_bancada:
		print("A Bancada principal não pode ser demolida!")
		return

	if is_in_group("estradas"):
		Global.estradas_pos.erase(coordenada_grade)

	if is_fogueira:
		Global.fogueiras_ativas.erase(self)
	if is_cama:
		Global.camas_ativas.erase(self)
	if is_canteiro:
		Global.canteiros_ativos.erase(self)
	if is_poco:
		Global.pocos_ativos.erase(self)
	if construida:
		Global.madeira += int(custo_madeira / 2.0)
		Global.pedra += int(custo_pedra / 2.0)
		Global.gravetos += int(custo_gravetos / 2.0)
		Global.pedrinhas += int(custo_pedrinhas / 2.0)
		if is_bau:
			Global.baus_ativos.erase(self)
			for tipo in estoque_bau.keys():
				var qtd_guardada = int(estoque_bau[tipo])
				if qtd_guardada > 0:
					Global.set(tipo, int(Global.get(tipo)) + qtd_guardada)
					Global.estoque_total_baus[tipo] = max(0, int(Global.estoque_total_baus.get(tipo, 0)) - qtd_guardada)
					estoque_bau[tipo] = 0
			print("Baú demolido! Todos os itens guardados + materiais devolvidos.")
		else:
			print("Estrutura demolida! Metade dos recursos devolvida.")
		Global.atualizar_navmesh_otimizado()
	else:
		print("Projeto cancelado: ", name)

	queue_free()

func _process(delta):
	# Sï¿½ roda em fogueiras construï¿½das!
	if Global.esta_chovendo():
		_timer_chuva -= delta
		if _timer_chuva <= 0.0:
			_timer_chuva = 2.0 # Verifica teto apenas 2x por segundo, nï¿½o 60x!
			_protegida_chuva_cache = esta_protegida_da_chuva()
		luz.visible = _protegida_chuva_cache
	else:
		luz.visible = true
		
	if luz.visible:
		luz.light_energy = 2.5 + sin(Time.get_ticks_msec() * 0.01) * 0.3

func alternar_portao():
	if not construida or not is_portao:
		return
	portao_aberto = not portao_aberto
	if is_instance_valid(obstaculo_nav):
		obstaculo_nav.avoidance_enabled = not portao_aberto
	AudioManager.tocar("portao")
	
	# Desativa colisï¿½o quando aberto para jogador e colonos passarem livres
	corpo_fisico.collision_layer = 0 if portao_aberto else 1
	corpo_fisico.collision_mask = 0 if portao_aberto else 1
	
	var angulo_alvo = rotation.y + (PI / 2.0 if portao_aberto else -PI / 2.0)
	var tween = create_tween()
	tween.tween_property(self, "rotation:y", angulo_alvo, 0.25)
	print("🚪 Portão ", "ABERTO" if portao_aberto else "FECHADO")

func receber_dano_estrutura(dano: int):
	if not construida:
		return
	vida_atual -= dano
	print("🛡 Estrutura atingida! HP: ", vida_atual, "/", vida_maxima)
	
	# Tremida rï¿½pida de impacto
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.04, 0.96, 1.04), 0.05)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.05)
	
	if vida_atual <= 0:
		print("💥 Estrutura destruída pelos inimigos!")
		Global.atualizar_navmesh_otimizado()
		queue_free()

func reparar() -> bool:
	if not construida or vida_atual >= vida_maxima:
		return false
		
	if is_muro:
		if Global.pedra < 1:
			print("⚠ Precisa de 1 Pedra para reparar o muro!")
			return false
		Global.pedra -= 1
	elif is_portao:
		if Global.madeira < 1:
			print("⚠ Precisa de 1 Madeira para reparar o portão!")
			return false
		Global.madeira -= 1
	else:
		return false
		
	vida_atual = min(vida_maxima, vida_atual + 40)
	print("Estrutura reparada! HP: ", vida_atual, " / ", vida_maxima)
	
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.03, 1.03, 1.03), 0.06)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.06)
	return true

# Funcoes do Bau de Armazenamento
func obter_total_itens_bau() -> int:
	var total = 0
	for qtd in estoque_bau.values():
		total += qtd
	return total

func guardar_item_no_bau(recurso: String, quantidade: int = 1) -> bool:
	if not construida or not is_bau:
		return false
	if obter_total_itens_bau() + quantidade > CAPACIDADE_MAXIMA_BAU:
		print("Bau cheio! Capacidade maxima: ", CAPACIDADE_MAXIMA_BAU)
		return false
	if not estoque_bau.has(recurso):
		estoque_bau[recurso] = 0
	estoque_bau[recurso] += quantidade
	Global.estoque_total_baus[recurso] = int(Global.estoque_total_baus.get(recurso, 0)) + quantidade
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.05, 0.95, 1.05), 0.08)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	return true

func retirar_item_do_bau(recurso: String, quantidade: int = 1) -> int:
	if not construida or not is_bau:
		return 0
	if not estoque_bau.has(recurso) or estoque_bau[recurso] <= 0:
		return 0
	var qtd_retirada = min(quantidade, estoque_bau[recurso])
	estoque_bau[recurso] -= qtd_retirada
	Global.estoque_total_baus[recurso] = max(0, int(Global.estoque_total_baus.get(recurso, 0)) - qtd_retirada)
	return qtd_retirada

func transferir_tudo_do_jogador():
	if not construida or not is_bau:
		return
	var depositou = false
	for tipo in ["madeira", "pedra", "gravetos", "pedrinhas", "comida", "frutas"]:
		var qtd_jog = int(Global.get(tipo))
		if qtd_jog > 0:
			var espaco = CAPACIDADE_MAXIMA_BAU - obter_total_itens_bau()
			var qtd_guardar = min(qtd_jog, espaco)
			if qtd_guardar > 0 and guardar_item_no_bau(tipo, qtd_guardar):
				Global.set(tipo, qtd_jog - qtd_guardar)
				depositou = true
				
	if depositou:
		print("📦 Recursos guardados no Baú! (", obter_total_itens_bau(), "/", CAPACIDADE_MAXIMA_BAU, ")")
		return
		
	# Se não tinha nada para guardar, retira até 10 unidades de cada recurso guardado para o jogador
	var retirou = false
	for tipo in ["madeira", "pedra", "gravetos", "pedrinhas", "comida", "frutas"]:
		var tirado = retirar_item_do_bau(tipo, 10)
		if tirado > 0:
			Global.set(tipo, int(Global.get(tipo)) + tirado)
			retirou = true
	if retirou:
		print("🎒 Recursos retirados do Baú para o inventário!")

func obter_resumo_bau() -> String:
	var partes = []
	if estoque_bau.get("madeira", 0) > 0: partes.append(str(estoque_bau["madeira"]) + " Mad")
	if estoque_bau.get("pedra", 0) > 0: partes.append(str(estoque_bau["pedra"]) + " Ped")
	if estoque_bau.get("gravetos", 0) > 0: partes.append(str(estoque_bau["gravetos"]) + " Grav")
	if estoque_bau.get("pedrinhas", 0) > 0: partes.append(str(estoque_bau["pedrinhas"]) + " Pedr")
	if estoque_bau.get("comida", 0) > 0: partes.append(str(estoque_bau["comida"]) + " Com")
	if estoque_bau.get("frutas", 0) > 0: partes.append(str(estoque_bau["frutas"]) + " Frut")
	return "Vazio" if partes.is_empty() else ", ".join(partes)

func _aplicar_visual_low_poly():
	if not is_instance_valid(mesh): return
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.85
	if is_bancada:
		mat.albedo_color = Color(0.55, 0.28, 0.12)
	elif is_bau:
		mat.albedo_color = Color(0.68, 0.44, 0.16)
	elif is_cama:
		mat.albedo_color = Color(0.22, 0.42, 0.68)
		var trav = MeshInstance3D.new()
		var box_trav = BoxMesh.new()
		box_trav.size = Vector3(0.7, 0.15, 0.3)
		var mat_trav = StandardMaterial3D.new()
		mat_trav.albedo_color = Color(0.9, 0.9, 0.92)
		box_trav.material = mat_trav
		trav.mesh = box_trav
		trav.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trav.position = Vector3(0, 0.22, -0.55)
		mesh.add_child(trav)
	elif is_fogueira:
		mat.albedo_color = Color(0.25, 0.25, 0.28)
		var brasa = MeshInstance3D.new()
		var box_brasa = BoxMesh.new()
		box_brasa.size = Vector3(0.35, 0.18, 0.35)
		var mat_brasa = StandardMaterial3D.new()
		mat_brasa.albedo_color = Color(1.0, 0.4, 0.05)
		mat_brasa.emission_enabled = true
		mat_brasa.emission = Color(1.0, 0.35, 0.05)
		mat_brasa.emission_energy_multiplier = 1.5
		box_brasa.material = mat_brasa
		brasa.mesh = box_brasa
		brasa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		brasa.position = Vector3(0, 0.15, 0)
		mesh.add_child(brasa)
	elif is_muro:
		mat.albedo_color = Color(0.42, 0.44, 0.48)
	elif is_portao:
		mat.albedo_color = Color(0.35, 0.20, 0.09)
	else:
		return
	mesh.material_override = mat

func _configurar_obstaculo_navegacao():
	if not (is_parede or is_muro or is_portao or is_bancada or is_bau): return
	if not is_instance_valid(obstaculo_nav):
		obstaculo_nav = NavigationObstacle3D.new()
		obstaculo_nav.radius = 0.65
		obstaculo_nav.height = 2.0
		obstaculo_nav.use_3d_avoidance = false
		add_child(obstaculo_nav)
	obstaculo_nav.avoidance_enabled = not (is_portao and portao_aberto)

func _criar_visual_cultivo():
	if is_instance_valid(mesh_cultivo): return
	mesh_cultivo = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.75, 0.55, 0.75)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.65, 0.2)
	box.material = mat
	mesh_cultivo.mesh = box
	mesh_cultivo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_cultivo.position = Vector3(0, 0.25, 0)
	mesh_cultivo.visible = false
	add_child(mesh_cultivo)
	_atualizar_visual_cultivo()

func _atualizar_visual_cultivo():
	if not is_instance_valid(mesh_cultivo): return
	if not canteiro_plantado:
		mesh_cultivo.visible = false
		return
	mesh_cultivo.visible = true
	var esc = lerp(0.25, 1.0, progresso_cultivo / 100.0)
	mesh_cultivo.scale = Vector3(esc, esc, esc)
	var mat = mesh_cultivo.mesh.material as StandardMaterial3D
	mat.albedo_color = Color(0.85, 0.18, 0.22) if progresso_cultivo >= 100.0 else Color(0.22, 0.68, 0.22)

func plantar_canteiro() -> bool:
	if not construida or not is_canteiro or canteiro_plantado:
		return false
	if _obter_total_disponivel("frutas") < 1:
		return false
	_consumir_recurso_global_ou_bau("frutas", 1)
	canteiro_plantado = true
	progresso_cultivo = 0.0
	set_process(true)
	_atualizar_visual_cultivo()
	AudioManager.tocar("coleta")
	print("Semente de fruta plantada no canteiro!")
	return true

func colher_canteiro(bonus_mochila: bool = true) -> int:
	if not construida or not is_canteiro or not canteiro_plantado or progresso_cultivo < 100.0:
		return 0
	var qtd = 5 if (bonus_mochila and Global.tem_mochila_couro) else 4
	canteiro_plantado = false
	progresso_cultivo = 0.0
	set_process(false)
	_atualizar_visual_cultivo()
	AudioManager.tocar("coleta")
	return qtd

func curtir_material() -> bool:
	if not construida or not is_curtume:
		return false
	if Global.carne_crua >= 2:
		Global.carne_crua -= 2
		Global.couro += 1
		AudioManager.tocar("coleta")
		print("🧵 Couro curtido! -2 Carne Crua | +1 Couro")
		return true
	elif Global.couro >= 1:
		Global.couro -= 1
		Global.gravetos += 4
		AudioManager.tocar("coleta")
		print("🧵 Couro cortado em tiras! -1 Couro | +4 Gravetos")
		return true
	print("Precisa de 2 Carnes Cruas ou 1 Couro para usar o Curtume!")
	return false
