extends Control

## Barra Inferior Dock de ConstruÃ§Ã£o
## Organiza as ferramentas e peÃ§as do modo Planejador AÃ©reo em abas limpas e compactas.

var dock_container: PanelContainer
var hbox_categorias: HBoxContainer
var subpainel_itens: PanelContainer
var hbox_itens: HBoxContainer

var camera_aerea: Camera3D

# Categorias do Planejador
var categorias := [
	{
		"nome": "Caminhos & Pisos",
		"icone": "ðŸ›¤ï¸",
		"itens": [
			{"nome": "Estrada", "path": "res://buildings/Estrada.tscn", "icone": "ðŸŸ«"},
			{"nome": "Bloco", "path": "res://buildings/Bloco.tscn", "icone": "ðŸŸ©"},
			{"nome": "Piso Madeira", "path": "res://buildings/Piso.tscn", "icone": "ðŸªµ"}
		]
	},
	{
		"nome": "Estruturas",
		"icone": "ðŸ ",
		"itens": [
			{"nome": "Parede", "path": "res://buildings/ParedeMadeira.tscn", "icone": "ðŸ§±"},
			{"nome": "Teto", "path": "res://buildings/TetoMadeira.tscn", "icone": "â›º"}
		]
	},
	{
		"nome": "Defesa",
		"icone": "ðŸ›¡ï¸",
		"itens": [
			{"nome": "Muro Pedra", "path": "res://buildings/MuroPedra.tscn", "icone": "ðŸª¨"},
			{"nome": "PortÃ£o", "path": "res://buildings/Portao.tscn", "icone": "ðŸšª"}
		]
	},
	{
		"nome": "Armazenamento & Trabalho",
		"icone": "ðŸ“¦",
		"itens": [
			{"nome": "BaÃº", "path": "res://buildings/Bau.tscn", "icone": "ðŸ“¦"},
			{"nome": "Fogueira", "path": "res://buildings/Fogueira.tscn", "icone": "ðŸ”¥"},
			{"nome": "Cama", "path": "res://buildings/Cama.tscn", "icone": "🛏"},
			{"nome": "Canteiro", "path": "res://buildings/Canteiro.tscn", "icone": "🌱"},
			{"nome": "Poço Água", "path": "res://buildings/PocoAgua.tscn", "icone": "🚰"},
			{"nome": "Curtume", "path": "res://buildings/Curtume.tscn", "icone": "🧵"}
		]
	}
]

var categoria_aberta: int = -1
var botoes_cat: Array[Button] = []
var cache_cenas: Dictionary = {}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carregar_cenas()
	_montar_dock()

func _carregar_cenas():
	for cat in categorias:
		for item in cat["itens"]:
			var p: String = item["path"]
			if ResourceLoader.exists(p):
				cache_cenas[p] = load(p)

func _montar_dock():
	# 1. Painel Popup de Sub-Itens (sobe acima da barra)
	subpainel_itens = PanelContainer.new()
	subpainel_itens.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subpainel_itens.offset_bottom = -70
	subpainel_itens.offset_top = -125
	subpainel_itens.offset_left = 120
	subpainel_itens.offset_right = -120
	subpainel_itens.visible = false
	add_child(subpainel_itens)

	var margem_sub = MarginContainer.new()
	margem_sub.add_theme_constant_override("margin_left", 15)
	margem_sub.add_theme_constant_override("margin_right", 15)
	margem_sub.add_theme_constant_override("margin_top", 8)
	margem_sub.add_theme_constant_override("margin_bottom", 8)
	subpainel_itens.add_child(margem_sub)

	hbox_itens = HBoxContainer.new()
	hbox_itens.add_theme_constant_override("separation", 10)
	margem_sub.add_child(hbox_itens)

	# 2. Barra Dock Principal no RodapÃ©
	dock_container = PanelContainer.new()
	dock_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock_container.offset_bottom = -15
	dock_container.offset_top = -65
	dock_container.offset_left = 80
	dock_container.offset_right = -80
	dock_container.visible = false
	add_child(dock_container)

	var margem_dock = MarginContainer.new()
	margem_dock.add_theme_constant_override("margin_left", 12)
	margem_dock.add_theme_constant_override("margin_right", 12)
	margem_dock.add_theme_constant_override("margin_top", 6)
	margem_dock.add_theme_constant_override("margin_bottom", 6)
	dock_container.add_child(margem_dock)

	hbox_categorias = HBoxContainer.new()
	hbox_categorias.add_theme_constant_override("separation", 8)
	margem_dock.add_child(hbox_categorias)

	for i in range(categorias.size()):
		var cat = categorias[i]
		var btn = Button.new()
		btn.text = cat["icone"] + " " + cat["nome"]
		btn.add_theme_font_size_override("font_size", 14)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx = i
		btn.pressed.connect(func(): _alternar_categoria(idx))
		hbox_categorias.add_child(btn)
		botoes_cat.append(btn)

	# BotÃ£o Pincel de DemoliÃ§Ã£o / Corte
	var btn_pincel = Button.new()
	btn_pincel.text = "ðŸª“ Pincel de Corte [C]"
	btn_pincel.add_theme_font_size_override("font_size", 14)
	btn_pincel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pincel.pressed.connect(func():
		if is_instance_valid(camera_aerea) and is_instance_valid(camera_aerea.pincel):
			camera_aerea.pincel.alternar()
	)
	hbox_categorias.add_child(btn_pincel)

func _alternar_categoria(indice: int):
	if categoria_aberta == indice:
		categoria_aberta = -1
		subpainel_itens.visible = false
		return

	categoria_aberta = indice
	subpainel_itens.visible = true
	_renderizar_itens_categoria()

func _renderizar_itens_categoria():
	for c in hbox_itens.get_children():
		c.queue_free()

	if categoria_aberta < 0 or categoria_aberta >= categorias.size():
		return

	var cat = categorias[categoria_aberta]
	for item in cat["itens"]:
		var path = item["path"]
		var cena: PackedScene = cache_cenas.get(path, null)
		if not cena: continue

		var btn_item = Button.new()
		btn_item.text = item["icone"] + " " + item["nome"]
		btn_item.add_theme_font_size_override("font_size", 13)
		var cena_sel = cena
		btn_item.pressed.connect(func():
			_selecionar_peca_planejador(cena_sel)
		)
		hbox_itens.add_child(btn_item)

func _selecionar_peca_planejador(cena: PackedScene):
	if not is_instance_valid(camera_aerea): return
	var idx = camera_aerea.opcoes_construcao.find(cena)
	if idx == -1:
		camera_aerea.opcoes_construcao.append(cena)
		idx = camera_aerea.opcoes_construcao.size() - 1
	camera_aerea._trocar_fantasma(idx)
	if camera_aerea.modo_marcacao:
		camera_aerea.pincel.desativar()

func definir_visivel(mostrar: bool):
	dock_container.visible = mostrar
	if not mostrar:
		subpainel_itens.visible = false
		categoria_aberta = -1
