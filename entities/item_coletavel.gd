extends StaticBody3D

@export_enum("graveto", "pedrinha") var tipo_item: String = "graveto"
@export var quantidade: int = 1

var reservado: bool = false
var marcado_para_coleta: bool = false
var multimesh_ref: MultiMesh = null
var multimesh_idx: int = -1

func _ready():
	add_to_group("coletaveis_chao")
	_otimizar_renderizacao_vega8()

func vincular_multimesh(mm: MultiMesh, idx: int):
	multimesh_ref = mm
	multimesh_idx = idx
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.visible = false

func _otimizar_renderizacao_vega8():
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		if multimesh_ref != null:
			.visible = ativar
		.transparency = 0.35 if ativar else 0.0
		.visibility_range_end = 150.0 if ativar else 28.0

# Chamado pelo Jogador (E / X) ou pelo Colono
func colher():
	if multimesh_ref != null and multimesh_idx >= 0 and multimesh_idx < multimesh_ref.instance_count:
		multimesh_ref.set_instance_transform(multimesh_idx, Transform3D(Basis().scaled(Vector3.ZERO), global_position))
		multimesh_ref = null

	var bonus = 1 if Global.tem_mochila_couro else 0
	var total = quantidade + bonus

	if tipo_item == "graveto":
		Global.gravetos += total
		print("🌿 Gravetos coletados! +", total, " | Total: ", Global.gravetos)
	elif tipo_item == "pedrinha":
		Global.pedrinhas += total
		print("🪨 Pedrinha coletada! +", total, " | Total: ", Global.pedrinhas)
	queue_free()