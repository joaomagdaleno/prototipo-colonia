extends Node

## Gerenciador de Audio Procedural Leve (AudioStreamGenerator)
## Sintetiza efeitos sonoros curtos em memoria sem exigir arquivos .wav externos.

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
const TAXA_AMOSTRAGEM := 22050.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = TAXA_AMOSTRAGEM
	stream.buffer_length = 0.25
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func tocar(tipo: String):
	if not is_instance_valid(player):
		return
	playback = player.get_stream_playback()
	if not is_instance_valid(playback):
		return
	var duracao := 0.12
	var freq_ini := 220.0
	var freq_fim := 110.0
	var ruido := 0.0

	match tipo:
		"golpe":
			duracao = 0.08
			freq_ini = 180.0
			freq_fim = 60.0
			ruido = 0.45
		"coleta":
			duracao = 0.11
			freq_ini = 360.0
			freq_fim = 580.0
		"construir":
			duracao = 0.14
			freq_ini = 240.0
			freq_fim = 420.0
		"trovao":
			duracao = 1.1
			freq_ini = 95.0
			freq_fim = 32.0
			ruido = 0.85
		"dano":
			duracao = 0.18
			freq_ini = 150.0
			freq_fim = 45.0
			ruido = 0.6
		"comer":
			duracao = 0.10
			freq_ini = 300.0
			freq_fim = 480.0

	var total_amostras = int(TAXA_AMOSTRAGEM * duracao)
	var disponivel = playback.get_frames_available()
	total_amostras = min(total_amostras, disponivel)
	var fase := 0.0
	for i in range(total_amostras):
		var t = float(i) / max(1.0, float(total_amostras))
		var freq = lerp(freq_ini, freq_fim, t)
		fase += freq / TAXA_AMOSTRAGEM
		var onda = sin(fase * TAU) * (1.0 - ruido) + randf_range(-1.0, 1.0) * ruido
		var envelope = (1.0 - t) * 0.6
		var amostra = clamp(onda * envelope, -1.0, 1.0)
		playback.push_frame(Vector2(amostra, amostra))
