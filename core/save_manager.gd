extends Node

const CAMINHO_SAVE: String = "user://savegame.json"
var carregar_ao_iniciar: bool = false

func tem_save() -> bool:
	return FileAccess.file_exists(CAMINHO_SAVE)

func salvar_jogo() -> bool:
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	if not jogador:
		return false
		
	var dados = {
		"recursos": {
			"madeira": Global.madeira,
			"pedra": Global.pedra,
			"pedrinhas": Global.pedrinhas,
			"gravetos": Global.gravetos,
			"comida": Global.comida,
			"frutas": Global.frutas,
			"carne_crua": Global.carne_crua,
			"couro": Global.couro,
			"hora_do_dia": Global.hora_do_dia,
			"clima_atual": int(Global.clima_atual),
			"tem_machado_pedra": Global.tem_machado_pedra,
			"tem_mochila_couro": Global.tem_mochila_couro,
			"vida_jogador": Global.vida_jogador,
			"saciedade_jogador": Global.saciedade_jogador,
			"hidratacao_jogador": Global.hidratacao_jogador
		},
		"jogador": {
			"pos": [jogador.global_position.x, jogador.global_position.y, jogador.global_position.z],
			"rot_y": jogador.rotation.y
		},
		"estruturas": [],
		"colonos": [],
		"natureza_viva": []
	}
	
	for est in get_tree().get_nodes_in_group("construidos") + get_tree().get_nodes_in_group("projetos"):
		if is_instance_valid(est) and est.scene_file_path != "":
			dados["estruturas"].append({
				"cena": est.scene_file_path,
				"pos": [est.global_position.x, est.global_position.y, est.global_position.z],
				"rot_y": est.rotation.y,
				"construida": est.construida if "construida" in est else true,
				"vida_atual": est.vida_atual if "vida_atual" in est else 100,
				"estoque_bau": est.estoque_bau.duplicate() if ("estoque_bau" in est and est.is_bau) else {}
			})
			
	for col in get_tree().get_nodes_in_group("colonos"):
		if is_instance_valid(col):
			dados["colonos"].append({
				"pos": [col.global_position.x, col.global_position.y, col.global_position.z],
				"energia": col.energia,
				"fome": col.fome
			})

	for grp in ["arvores", "arbustos", "pedras", "coletaveis_chao"]:
		for item in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(item) and item.scene_file_path != "":
				var cortada = ("cortada" in item and item.cortada) or ("quebrada" in item and item.quebrada)
				if not cortada:
					dados["natureza_viva"].append({
						"cena": item.scene_file_path,
						"x": snapped(item.global_position.x, 0.1),
						"y": snapped(item.global_position.y, 0.1),
						"z": snapped(item.global_position.z, 0.1),
						"rot_y": snapped(item.rotation.y, 0.05),
						"marcado": item.marcado_para_coleta if "marcado_para_coleta" in item else false,
						"tem_frutas": item.tem_frutas if "tem_frutas" in item else true
					})
			
	var arquivo = FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arquivo:
		arquivo.store_string(JSON.stringify(dados, "\t"))
		arquivo.close()
		print("ðŸ’¾ JOGO SALVO! Estruturas: ", dados["estruturas"].size(), " | Colonos: ", dados["colonos"].size())
		return true
	return false

func carregar_jogo() -> bool:
	if not tem_save():
		return false
		
	var arquivo = FileAccess.open(CAMINHO_SAVE, FileAccess.READ)
	var texto = arquivo.get_as_text()
	arquivo.close()
	
	var json = JSON.new()
	if json.parse(texto) != OK:
		return false
		
	var dados = json.data
	var rec = dados["recursos"]
	
	Global.madeira = int(rec.get("madeira", 0))
	Global.pedra = int(rec.get("pedra", 0))
	Global.pedrinhas = int(rec.get("pedrinhas", 0))
	Global.gravetos = int(rec.get("gravetos", 0))
	Global.comida = int(rec.get("comida", 5))
	Global.frutas = int(rec.get("frutas", 0))
	Global.carne_crua = int(rec.get("carne_crua", 0))
	Global.couro = int(rec.get("couro", 0))
	Global.hora_do_dia = float(rec.get("hora_do_dia", 8.0))
	Global.clima_atual = int(rec.get("clima_atual", 0)) as Global.Clima
	Global.tem_machado_pedra = bool(rec.get("tem_machado_pedra", false))
	Global.tem_mochila_couro = bool(rec.get("tem_mochila_couro", false))
	Global.vida_jogador = int(rec.get("vida_jogador", 100))
	Global.saciedade_jogador = float(rec.get("saciedade_jogador", 85.0))
	Global.hidratacao_jogador = float(rec.get("hidratacao_jogador", 85.0))
	Global.estoque_total_baus = {"madeira": 0, "pedra": 0, "gravetos": 0, "pedrinhas": 0, "comida": 0, "frutas": 0}
	
	var jogador = get_tree().current_scene.get_node_or_null("Jogador")
	if jogador and dados.has("jogador"):
		var p = dados["jogador"]["pos"]
		jogador.global_position = Vector3(p[0], p[1], p[2])
		jogador.rotation.y = float(dados["jogador"]["rot_y"])
		
	for est in get_tree().get_nodes_in_group("construidos") + get_tree().get_nodes_in_group("projetos"):
		if is_instance_valid(est): est.queue_free()
	for col in get_tree().get_nodes_in_group("colonos"):
		if is_instance_valid(col): col.queue_free()
		
	for item in dados["estruturas"]:
		var cena_res = load(item["cena"])
		if cena_res:
			var inst = cena_res.instantiate()
			get_tree().current_scene.add_child(inst)
			var pos = item["pos"]
			inst.global_position = Vector3(pos[0], pos[1], pos[2])
			inst.rotation.y = float(item["rot_y"])
			if item["construida"] and inst.has_method("construir") and not inst.construida:
				var c_mad = inst.custo_madeira; var c_ped = inst.custo_pedra; var c_grav = inst.custo_gravetos; var c_pedr = inst.custo_pedrinhas
				inst.custo_madeira = 0; inst.custo_pedra = 0; inst.custo_gravetos = 0; inst.custo_pedrinhas = 0
				inst.construir()
				inst.custo_madeira = c_mad; inst.custo_pedra = c_ped; inst.custo_gravetos = c_grav; inst.custo_pedrinhas = c_pedr
			if item.has("vida_atual") and "vida_atual" in inst:
				inst.vida_atual = int(item["vida_atual"])
			if item.has("estoque_bau") and "estoque_bau" in inst and inst.is_bau:
				inst.estoque_bau = item["estoque_bau"].duplicate()
				for k in inst.estoque_bau.keys():
					Global.estoque_total_baus[k] = int(Global.estoque_total_baus.get(k, 0)) + int(inst.estoque_bau[k])
				
	for c_data in dados["colonos"]:
		var novo_col = Global.cena_colono.instantiate()
		get_tree().current_scene.add_child(novo_col)
		var pos = c_data["pos"]
		novo_col.global_position = Vector3(pos[0], pos[1], pos[2])
		novo_col.energia = float(c_data.get("energia", 100.0))
		novo_col.fome = float(c_data.get("fome", 0.0))

	if dados.has("natureza_viva"):
		for grp in ["arvores", "arbustos", "pedras", "coletaveis_chao"]:
			for item in get_tree().get_nodes_in_group(grp):
				if is_instance_valid(item):
					item.queue_free()
					
		var cache_cenas = {}
		var gerador = get_tree().current_scene.get_node_or_null("GeradorMundo")
		
		for n in dados["natureza_viva"]:
			if n.has("cena") and n["cena"] != "":
				var caminho = n["cena"]
				if not cache_cenas.has(caminho):
					cache_cenas[caminho] = load(caminho)
				if cache_cenas[caminho]:
					var inst = cache_cenas[caminho].instantiate()
					get_tree().current_scene.add_child(inst)
					inst.global_position = Vector3(float(n["x"]), float(n.get("y", 0.0)), float(n["z"]))
					inst.rotation.y = float(n.get("rot_y", 0.0))
					
					if is_instance_valid(gerador) and gerador.has_method("aplicar_otimizacao_item"):
						gerador.aplicar_otimizacao_item(inst)
						
					if inst.has_method("alternar_marcacao"):
						inst.alternar_marcacao(bool(n.get("marcado", false)))
						
					if "tem_frutas" in inst and not bool(n.get("tem_frutas", true)):
						inst.tem_frutas = false
						if "grupo_frutas" in inst and is_instance_valid(inst.grupo_frutas):
							inst.grupo_frutas.visible = false
							
	Global.atualizar_navmesh_otimizado()
	print("📂 JOGO CARREGADO COM SUCESSO!")
	return true
