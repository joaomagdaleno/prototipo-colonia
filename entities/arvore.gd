extends StaticBody3D

var cortada: bool = false
var reservado: bool = false # Impede 2 colonos na mesma árvore
var marcado_para_coleta: bool = false
var vida: int = 3 # Precisa de 3 machadadas do jogador para cair

func _ready():
	add_to_group("arvores")
	_otimizar_renderizacao_vega8()

func _otimizar_renderizacao_vega8():
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.visibility_range_begin = 0.0
			filho.visibility_range_end = 145.0
			filho.visibility_range_end_margin = 15.0
			filho.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func alternar_marcacao(ativar: bool):
	if marcado_para_coleta == ativar:
		return
	marcado_para_coleta = ativar
	if ativar: add_to_group("recursos_marcados")
	else: remove_from_group("recursos_marcados")
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.transparency = 0.35 if ativar else 0.0

# Função chamada pelo Jogador quando bate com o clique esquerdo
func receber_dano(quantidade: int = 1):
	if cortada:
		return
	
	vida -= quantidade
	print("Toc! Vida da árvore: ", vida)
	
	# Efeito visual rápido de impacto (tremida na árvore)
	var malhas = get_children().filter(func(n): return n is MeshInstance3D)
	if not malhas.is_empty():
		var tween = create_tween()
		for f in malhas:
		tween.parallel().tween_property(f, "scale", Vector3(1.06, 0.94, 1.06), 0.05)
			tween.tween_property(f, "scale", Vector3(1.0, 1.0, 1.0), 0.05)
	
	if vida <= 0:
		cortar()

# Função chamada quando a vida zera (ou diretamente pelo Colono)
func cortar():
	if cortada:
		return
	cortada = true
	print("Árvore cortada! +10 madeira")
	Global.madeira += 10
	
	Global.atualizar_navmesh_otimizado()
	queue_free()
