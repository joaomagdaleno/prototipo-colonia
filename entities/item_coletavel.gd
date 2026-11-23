extends StaticBody3D

@export_enum("graveto", "pedrinha") var tipo_item: String = "graveto"
@export var quantidade: int = 1

var reservado: bool = false
var marcado_para_coleta: bool = false

func _ready():
	add_to_group("coletaveis_chao")
	_otimizar_renderizacao_vega8()

func _otimizar_renderizacao_vega8():
	# Aplica configuraï¿½ï¿½es leves em todos os MeshInstance3D filhos (mesmo se a cena tiver vï¿½rios)
	for filho in get_children():
		if filho is MeshInstance3D:
			# 1. Itens minï¿½sculos no chï¿½o nï¿½o precisam calcular sombra em tempo real
			filho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# 2. Sï¿½ renderiza quando o jogador/cï¿½mera estiver a menos de 28m (corta ~85% dos Draw Calls!)
			filho.visibility_range_begin = 0.0
			filho.visibility_range_end = 28.0
			filho.visibility_range_end_margin = 4.0
			filho.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func alternar_marcacao(ativar: bool):
	if marcado_para_coleta == ativar:
		return
	marcado_para_coleta = ativar
	if ativar: add_to_group("recursos_marcados")
	else: remove_from_group("recursos_marcados")
	if has_node("MeshInstance3D"):
		$MeshInstance3D.transparency = 0.35 if ativar else 0.0
		# Quando marcado no Modo Planejador Aï¿½reo, aumenta o alcance de visï¿½o para o jogador ver de cima
		$MeshInstance3D.visibility_range_end = 150.0 if ativar else 28.0

# Chamado pelo Jogador (E / X) ou pelo Colono
func colher():
	var bonus = 1 if Global.tem_mochila_couro else 0
	var total = quantidade + bonus
	
	if tipo_item == "graveto":
		Global.gravetos += total
		print("🌿 Gravetos coletados! +", total, " | Total: ", Global.gravetos)
	elif tipo_item == "pedrinha":
		Global.pedrinhas += total
		print("🪨 Pedrinha coletada! +", total, " | Total: ", Global.pedrinhas)
	queue_free()
