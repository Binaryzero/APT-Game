extends Node
## Tiny procedural SFX bank (no audio files): short synthesized blips.

const RATE := 22050
var _bank: Dictionary = {}
var _players: Array = []
var enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 4:
		var ap := AudioStreamPlayer.new()
		ap.volume_db = -10.0
		add_child(ap)
		_players.append(ap)
	_bank["click"] = _tone([[660.0, 660.0, 0.05]], 0.35, 0)
	_bank["play"] = _tone([[420.0, 780.0, 0.12]], 0.4, 0)
	_bank["install"] = _tone([[520.0, 520.0, 0.06], [780.0, 780.0, 0.10]], 0.4, 0)
	_bank["zd"] = _tone([[900.0, 300.0, 0.14], [300.0, 1000.0, 0.16]], 0.4, 1)
	_bank["bad"] = _tone([[220.0, 120.0, 0.2]], 0.45, 1)
	_bank["warn"] = _tone([[200.0, 200.0, 0.1]], 0.3, 1)
	_bank["win"] = _tone([[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.3]], 0.4, 0)
	_bank["lose"] = _tone([[392.0, 392.0, 0.18], [330.0, 330.0, 0.18], [262.0, 262.0, 0.35]], 0.4, 1)

func _tone(segments: Array, amp: float, wave: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	for seg in segments:
		var f0: float = seg[0]
		var f1: float = seg[1]
		var dur: float = seg[2]
		var n := int(RATE * dur)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			var f := lerpf(f0, f1, t)
			phase += TAU * f / RATE
			var v := sin(phase)
			if wave == 1:
				v = signf(v) * 0.6 + sin(phase * 0.5) * 0.2
			var env := minf(1.0, t * 12.0) * (1.0 - t) ** 0.7
			var s := int(clampf(v * env * amp, -1.0, 1.0) * 32000.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func play(kind: String) -> void:
	if not enabled or not _bank.has(kind):
		return
	for ap: AudioStreamPlayer in _players:
		if not ap.playing:
			ap.stream = _bank[kind]
			ap.play()
			return
	var first: AudioStreamPlayer = _players[0]
	first.stream = _bank[kind]
	first.play()
