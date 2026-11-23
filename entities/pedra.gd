extends StaticBody3D

var vida: int = 3
var quebrada: bool = false
var reservado: bool = false
var marcado_para_coleta: bool = false
@export var pedra_por_rocha: int = 8

func _ready():
	add_to_group("pedras")

func alternar_marcacao(ativar: bool):
	if marcado_para_coleta == ativar:
		return
	marcado_para_coleta = ativar
	if ativar: add_to_group("recursos_marcados")
	else: remove_from_group("recursos_marcados")
	if has_node("MeshInstance3D"):
		$MeshInstance3D.transparency = 0.35 if ativar else 0.0

# Chamado pelo Jogador batendo (Clique Esquerdo / R2)
func receber_dano(dano: int):
	if quebrada:
		return
	vida -= dano
	print("Tum! Vida da rocha: ", vida)
	
	# Efeito visual de impacto
	scale *= 0.92
	
	if vida <= 0:
		quebrar()

# Chamado ao quebrar ou pelo Colono minerando
func quebrar():
	if quebrada:
		return
	quebrada = true
	Global.pedra += pedra_por_rocha
	print("Rocha minerada! +", pedra_por_rocha, " pedra | Total: ", Global.pedra)
	queue_free()
