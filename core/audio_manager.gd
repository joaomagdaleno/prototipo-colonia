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
if not is_instance_valid(playback):
return
playback.clear_buffer()
var duracao := 0.12
var freq_ini := 220.0
var freq_fim := 110.0
var ruido := 0.0

match tipo:
"golpe":
duracao = 0.10; freq_ini = 160.0; freq_fim = 65.0; ruido = 0.45
"coleta":
duracao = 0.09; freq_ini = 440.0; freq_fim = 660.0; ruido = 0.0
"construir":
duracao = 0.16; freq_ini = 260.0; freq_fim = 390.0; ruido = 0.15
"portao":
duracao = 0.18; freq_ini = 120.0; freq_fim = 180.0; ruido = 0.25
"trovao":
			duracao = 1.1
			freq_ini = 95.0
			freq_fim = 32.0
			ruido = 0.85
		"dano":
duracao = 0.22; freq_ini = 130.0; freq_fim = 55.0; ruido = 0.35

var total_frames = int(TAXA_AMOSTRAGEM * duracao)
var frames_disp = min(total_frames, playback.get_frames_available())
var fase := 0.0

for i in range(frames_disp):
var t = float(i) / float(total_frames)
var env = (1.0 - t) * (1.0 - t)
var freq = lerp(freq_ini, freq_fim, t)
fase += freq / TAXA_AMOSTRAGEM
var onda = sin(fase * TAU) * (1.0 - ruido) + randf_range(-1.0, 1.0) * ruido
var amostra = clamp(onda * env * 0.6, -1.0, 1.0)
playback.push_frame(Vector2(amostra, amostra))