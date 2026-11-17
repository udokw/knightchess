class_name Sfx
extends Node
## 程序化音效合成器：运行时用 AudioStreamWAV 生成 PCM，不依赖任何外部素材。
##  - 吃棋慢动作（起跳 / 砸落 / 压扁 / 庆祝 / 护盾格挡）
##  - 18 种道具各自独立的施法音
##  - 16 种随机事件各自独立的触发音
##  - 8 个复音槽轮转播放，避免同帧多个特效互相截断

const RATE := 22050
const VOICES := 8
const VOLUME_DB := -6.0

var enabled := true

var _cache: Dictionary = {}
var _players: Array = []
var _cursor := 0

## 音效配方
##  w: sine/tri/saw/square/metal/noise
##  f0→f1: 指数滑音；arp: 音阶序列（覆盖滑音）
##  t/d: 起始时间 / 时长；a: 振幅；atk: 起音；dec: 衰减指数
##  lp→lp1: 单极点低通系数（0.05 闷 ~ 0.9 亮）；nz: 白噪混合
##  trem/thz: 颤音；vib/vhz: 频率抖动
const RECIPES := {
	# ------------------------------------------------------------ 吃棋
	"cap_jump": {"vol": 0.55, "layers": [
		{"w": "noise", "d": 0.3, "a": 0.5, "atk": 0.05, "dec": 1.4, "lp": 0.05, "lp1": 0.62},
		{"w": "sine", "f0": 240.0, "f1": 900.0, "d": 0.3, "a": 0.3, "atk": 0.02, "dec": 1.2},
	]},
	"cap_slam": {"vol": 0.95, "layers": [
		{"w": "sine", "f0": 155.0, "f1": 36.0, "d": 0.55, "a": 0.95, "atk": 0.002, "dec": 1.7},
		{"w": "noise", "d": 0.24, "a": 0.6, "atk": 0.001, "dec": 2.6, "lp": 0.42, "lp1": 0.16},
		{"w": "metal", "f0": 330.0, "f1": 180.0, "d": 0.36, "a": 0.22, "dec": 2.2, "lp": 0.72},
	]},
	"cap_squash": {"vol": 0.62, "layers": [
		{"w": "tri", "f0": 260.0, "f1": 52.0, "d": 0.19, "a": 0.65, "atk": 0.002, "dec": 1.3},
		{"w": "noise", "d": 0.16, "a": 0.34, "dec": 2.4, "lp": 0.3, "lp1": 0.08},
	]},
	"cap_win": {"vol": 0.5, "layers": [
		{"w": "sine", "arp": [523.25, 659.25, 783.99, 1046.5], "d": 0.52, "a": 0.55, "atk": 0.004, "dec": 0.85},
		{"w": "metal", "f0": 1568.0, "d": 0.4, "a": 0.1, "atk": 0.02, "dec": 2.4, "lp": 0.9},
	]},
	"cap_block": {"vol": 0.72, "layers": [
		{"w": "metal", "f0": 960.0, "f1": 1280.0, "d": 0.45, "a": 0.55, "atk": 0.001, "dec": 2.3, "lp": 0.92},
		{"w": "sine", "f0": 540.0, "f1": 400.0, "d": 0.2, "a": 0.3, "dec": 2.0},
		{"w": "noise", "d": 0.1, "a": 0.2, "dec": 3.0, "lp": 0.7},
	]},

	# ------------------------------------------------------------ 道具
	"it_boost": {"vol": 0.55, "layers": [
		{"w": "saw", "f0": 300.0, "f1": 1150.0, "d": 0.34, "a": 0.34, "atk": 0.01, "dec": 1.2, "lp": 0.5},
		{"w": "sine", "f0": 620.0, "f1": 1650.0, "d": 0.3, "a": 0.24, "atk": 0.01, "dec": 1.5},
	]},
	"it_double": {"vol": 0.5, "layers": [
		{"w": "sine", "arp": [784.0, 1174.7], "d": 0.38, "a": 0.5, "atk": 0.003, "dec": 1.3},
		{"w": "metal", "f0": 1568.0, "d": 0.34, "a": 0.12, "atk": 0.01, "dec": 2.4, "lp": 0.9},
	]},
	"it_warp": {"vol": 0.55, "layers": [
		{"w": "sine", "f0": 900.0, "f1": 140.0, "d": 0.44, "a": 0.45, "vib": 0.03, "vhz": 15.0, "dec": 1.0},
		{"w": "noise", "d": 0.5, "a": 0.26, "atk": 0.03, "dec": 1.5, "lp": 0.12, "lp1": 0.55},
	]},
	"it_teleport": {"vol": 0.55, "layers": [
		{"w": "metal", "f0": 660.0, "f1": 1760.0, "d": 0.46, "a": 0.34, "atk": 0.01, "dec": 1.9},
		{"w": "sine", "f0": 1180.0, "f1": 2400.0, "d": 0.26, "a": 0.2, "atk": 0.02, "dec": 1.2},
	]},
	"it_snipe": {"vol": 0.78, "layers": [
		{"w": "noise", "d": 0.18, "a": 0.65, "atk": 0.001, "dec": 2.5, "lp": 0.85, "lp1": 0.3},
		{"w": "square", "f0": 1500.0, "f1": 200.0, "d": 0.22, "a": 0.24, "dec": 2.2, "lp": 0.45},
	]},
	"it_swap": {"vol": 0.52, "layers": [
		{"w": "sine", "f0": 480.0, "f1": 920.0, "d": 0.16, "a": 0.4, "dec": 1.0},
		{"w": "sine", "f0": 920.0, "f1": 480.0, "t": 0.16, "d": 0.18, "a": 0.4, "dec": 1.0},
		{"w": "noise", "d": 0.3, "a": 0.1, "atk": 0.05, "dec": 1.6, "lp": 0.35},
	]},
	"it_freeze": {"vol": 0.52, "layers": [
		{"w": "metal", "f0": 1600.0, "f1": 2150.0, "d": 0.72, "a": 0.34, "atk": 0.002, "dec": 2.6, "lp": 0.9},
		{"w": "sine", "f0": 250.0, "f1": 170.0, "d": 0.4, "a": 0.28, "dec": 2.0},
		{"w": "noise", "d": 0.5, "a": 0.18, "atk": 0.04, "dec": 1.8, "lp": 0.55, "lp1": 0.2},
	]},
	"it_frostlock": {"vol": 0.56, "layers": [
		{"w": "metal", "f0": 1500.0, "f1": 1900.0, "d": 0.7, "a": 0.32, "atk": 0.002, "dec": 2.5, "lp": 0.88},
		{"w": "metal", "f0": 720.0, "d": 0.62, "a": 0.28, "dec": 1.6, "lp": 0.55, "trem": 0.85, "thz": 22.0},
		{"w": "noise", "d": 0.4, "a": 0.16, "atk": 0.03, "dec": 2.0, "lp": 0.3},
	]},
	"it_inferno": {"vol": 0.82, "layers": [
		{"w": "noise", "d": 0.58, "a": 0.5, "atk": 0.02, "dec": 1.4, "lp": 0.1, "lp1": 0.42},
		{"w": "sine", "f0": 115.0, "f1": 58.0, "d": 0.62, "a": 0.55, "dec": 1.2},
		{"w": "saw", "f0": 170.0, "f1": 90.0, "d": 0.5, "a": 0.16, "dec": 1.6, "lp": 0.32},
	]},
	"it_moonstep": {"vol": 0.5, "layers": [
		{"w": "sine", "arp": [1318.5, 1046.5, 783.99], "d": 0.62, "a": 0.36, "atk": 0.008, "dec": 0.95},
		{"w": "noise", "d": 0.55, "a": 0.08, "atk": 0.1, "dec": 1.4, "lp": 0.75, "trem": 0.3, "thz": 7.0},
	]},
	"it_vortex": {"vol": 0.56, "layers": [
		{"w": "saw", "f0": 950.0, "f1": 170.0, "d": 0.72, "a": 0.24, "vib": 0.05, "vhz": 9.0, "lp": 0.38, "dec": 0.9, "trem": 0.45, "thz": 13.0},
		{"w": "noise", "d": 0.7, "a": 0.22, "atk": 0.03, "dec": 1.0, "lp": 0.45, "lp1": 0.12},
	]},
	"it_steal": {"vol": 0.55, "layers": [
		{"w": "metal", "arp": [1568.0, 2093.0, 2637.0], "d": 0.42, "a": 0.42, "atk": 0.001, "dec": 2.1},
		{"w": "noise", "d": 0.16, "a": 0.14, "dec": 3.0, "lp": 0.6},
	]},
	"it_bomb": {"vol": 0.88, "layers": [
		{"w": "square", "f0": 1200.0, "d": 0.05, "a": 0.16, "dec": 1.0},
		{"w": "square", "f0": 1200.0, "t": 0.17, "d": 0.05, "a": 0.16, "dec": 1.0},
		{"w": "sine", "f0": 135.0, "f1": 30.0, "t": 0.36, "d": 0.62, "a": 0.98, "dec": 1.7},
		{"w": "noise", "t": 0.36, "d": 0.42, "a": 0.55, "dec": 2.2, "lp": 0.5, "lp1": 0.1},
	]},
	"it_gale": {"vol": 0.6, "layers": [
		{"w": "noise", "d": 0.42, "a": 0.38, "atk": 0.06, "dec": 1.5, "lp": 0.12, "lp1": 0.6, "trem": 0.35, "thz": 17.0},
		{"w": "sine", "f0": 480.0, "f1": 880.0, "d": 0.3, "a": 0.14, "dec": 1.4},
	]},
	"it_jadeguard": {"vol": 0.55, "layers": [
		{"w": "metal", "f0": 430.0, "f1": 380.0, "d": 1.0, "a": 0.44, "atk": 0.004, "dec": 2.0, "lp": 0.85},
		{"w": "sine", "f0": 215.0, "f1": 200.0, "d": 1.0, "a": 0.32, "dec": 1.8},
	]},
	"it_shield": {"vol": 0.5, "layers": [
		{"w": "sine", "f0": 740.0, "f1": 1020.0, "d": 0.3, "a": 0.42, "atk": 0.004, "dec": 1.2},
		{"w": "metal", "f0": 1520.0, "d": 0.5, "a": 0.18, "atk": 0.004, "dec": 2.2, "lp": 0.85},
	]},
	"it_voidstep": {"vol": 0.62, "layers": [
		{"w": "sine", "f0": 165.0, "f1": 48.0, "d": 0.88, "a": 0.5, "atk": 0.03, "dec": 1.0},
		{"w": "noise", "d": 0.82, "a": 0.24, "atk": 0.06, "dec": 1.2, "lp": 0.2, "lp1": 0.06},
		{"w": "metal", "f0": 920.0, "f1": 190.0, "d": 0.7, "a": 0.14, "dec": 2.0, "trem": 0.55, "thz": 8.0},
	]},
	"it_item": {"vol": 0.5, "layers": [
		{"w": "sine", "f0": 520.0, "f1": 880.0, "d": 0.3, "a": 0.4, "atk": 0.005, "dec": 1.4},
		{"w": "noise", "d": 0.24, "a": 0.12, "dec": 2.2, "lp": 0.5},
	]},

	# ------------------------------------------------------------ 事件
	"ev_treasure": {"vol": 0.55, "layers": [
		{"w": "metal", "arp": [1046.5, 1318.5, 1568.0, 2093.0], "d": 0.62, "a": 0.4, "atk": 0.002, "dec": 2.0},
		{"w": "noise", "d": 0.4, "a": 0.08, "atk": 0.08, "dec": 1.6, "lp": 0.75},
	]},
	"ev_meteor": {"vol": 0.9, "layers": [
		{"w": "noise", "d": 0.55, "a": 0.22, "atk": 0.12, "dec": 0.8, "lp": 0.5, "lp1": 0.9},
		{"w": "sine", "f0": 1500.0, "f1": 300.0, "d": 0.55, "a": 0.2, "atk": 0.12, "dec": 0.9},
		{"w": "sine", "f0": 140.0, "f1": 28.0, "t": 0.52, "d": 0.62, "a": 0.95, "dec": 1.6},
		{"w": "noise", "t": 0.52, "d": 0.45, "a": 0.5, "dec": 2.2, "lp": 0.45, "lp1": 0.08},
	]},
	"ev_tailwind": {"vol": 0.55, "layers": [
		{"w": "noise", "d": 0.7, "a": 0.3, "atk": 0.15, "dec": 0.9, "lp": 0.1, "lp1": 0.55, "trem": 0.4, "thz": 11.0},
		{"w": "sine", "f0": 420.0, "f1": 760.0, "d": 0.6, "a": 0.12, "atk": 0.1, "dec": 1.0},
	]},
	"ev_trap": {"vol": 0.7, "layers": [
		{"w": "noise", "d": 0.06, "a": 0.5, "dec": 3.0, "lp": 0.9},
		{"w": "metal", "f0": 1250.0, "f1": 520.0, "d": 0.3, "a": 0.42, "atk": 0.001, "dec": 2.4, "lp": 0.8},
		{"w": "sine", "f0": 190.0, "f1": 90.0, "d": 0.28, "a": 0.35, "dec": 1.6},
	]},
	"ev_portal": {"vol": 0.6, "layers": [
		{"w": "sine", "f0": 160.0, "f1": 1200.0, "d": 0.7, "a": 0.28, "atk": 0.05, "vib": 0.02, "vhz": 11.0, "dec": 0.9},
		{"w": "noise", "d": 0.75, "a": 0.22, "atk": 0.1, "dec": 1.0, "lp": 0.1, "lp1": 0.5, "trem": 0.4, "thz": 15.0},
	]},
	"ev_chaos": {"vol": 0.6, "layers": [
		{"w": "square", "arp": [523.0, 932.0, 311.0, 1046.0, 466.0, 830.0], "d": 0.62, "a": 0.22, "atk": 0.004, "dec": 1.2, "lp": 0.5},
		{"w": "noise", "d": 0.62, "a": 0.16, "dec": 1.4, "lp": 0.4, "trem": 0.6, "thz": 19.0},
	]},
	"ev_bless": {"vol": 0.52, "layers": [
		{"w": "sine", "arp": [392.0, 523.25, 659.25], "d": 0.85, "a": 0.34, "atk": 0.06, "dec": 1.1},
		{"w": "metal", "f0": 1046.5, "d": 0.85, "a": 0.16, "atk": 0.1, "dec": 1.8, "lp": 0.85},
		{"w": "noise", "d": 0.6, "a": 0.07, "atk": 0.2, "dec": 1.2, "lp": 0.8},
	]},
	"ev_starlight": {"vol": 0.55, "layers": [
		{"w": "sine", "arp": [1568.0, 2093.0, 2637.0, 3136.0], "d": 0.78, "a": 0.3, "atk": 0.01, "dec": 1.6},
		{"w": "metal", "f0": 2637.0, "d": 0.7, "a": 0.14, "atk": 0.02, "dec": 2.4, "lp": 0.95},
		{"w": "noise", "d": 0.62, "a": 0.1, "atk": 0.15, "dec": 1.4, "lp": 0.85, "trem": 0.3, "thz": 24.0},
	]},
	"ev_blizzard": {"vol": 0.6, "layers": [
		{"w": "noise", "d": 0.95, "a": 0.34, "atk": 0.08, "dec": 0.85, "lp": 0.35, "lp1": 0.08, "trem": 0.5, "thz": 9.0},
		{"w": "metal", "f0": 2100.0, "f1": 1500.0, "d": 0.85, "a": 0.18, "atk": 0.05, "dec": 2.2, "lp": 0.9, "trem": 0.4, "thz": 15.0},
	]},
	"ev_eruption": {"vol": 0.9, "layers": [
		{"w": "noise", "d": 0.9, "a": 0.42, "atk": 0.04, "dec": 1.0, "lp": 0.08, "lp1": 0.4},
		{"w": "sine", "f0": 90.0, "f1": 42.0, "d": 0.85, "a": 0.65, "atk": 0.01, "dec": 1.2},
		{"w": "saw", "f0": 220.0, "f1": 110.0, "d": 0.7, "a": 0.16, "dec": 1.5, "lp": 0.3},
	]},
	"ev_ambush": {"vol": 0.75, "layers": [
		{"w": "noise", "d": 0.12, "a": 0.5, "dec": 3.0, "lp": 0.9},
		{"w": "square", "f0": 1800.0, "f1": 260.0, "d": 0.34, "a": 0.34, "atk": 0.001, "dec": 1.8, "lp": 0.5},
		{"w": "metal", "f0": 900.0, "f1": 400.0, "d": 0.3, "a": 0.2, "dec": 2.4, "lp": 0.8},
	]},
	"ev_goldrain": {"vol": 0.58, "layers": [
		{"w": "metal", "arp": [1568.0, 1876.0, 2093.0, 2349.0, 2637.0, 3136.0], "d": 0.95, "a": 0.34, "atk": 0.002, "dec": 2.2},
		{"w": "noise", "d": 0.9, "a": 0.1, "atk": 0.02, "dec": 2.0, "lp": 0.75, "trem": 0.5, "thz": 26.0},
	]},
	"ev_earthquake": {"vol": 0.9, "layers": [
		{"w": "sine", "f0": 62.0, "f1": 34.0, "d": 1.15, "a": 0.9, "atk": 0.01, "dec": 1.0},
		{"w": "noise", "d": 1.15, "a": 0.36, "atk": 0.02, "dec": 1.1, "lp": 0.06, "lp1": 0.14, "trem": 0.7, "thz": 7.0},
		{"w": "saw", "f0": 80.0, "f1": 46.0, "d": 1.0, "a": 0.18, "dec": 1.2, "lp": 0.2},
	]},
	"ev_curse": {"vol": 0.6, "layers": [
		{"w": "saw", "f0": 210.0, "f1": 76.0, "d": 1.0, "a": 0.26, "atk": 0.05, "dec": 1.0, "lp": 0.35, "vib": 0.03, "vhz": 4.5},
		{"w": "sine", "f0": 105.0, "f1": 42.0, "d": 1.05, "a": 0.34, "atk": 0.04, "dec": 1.0},
		{"w": "noise", "d": 0.85, "a": 0.12, "atk": 0.1, "dec": 1.4, "lp": 0.18, "trem": 0.4, "thz": 5.0},
	]},
	"ev_jadeserpent": {"vol": 0.62, "layers": [
		{"w": "noise", "d": 0.85, "a": 0.28, "atk": 0.15, "dec": 1.0, "lp": 0.62, "lp1": 0.3, "trem": 0.75, "thz": 8.0},
		{"w": "metal", "f0": 520.0, "f1": 340.0, "d": 0.8, "a": 0.2, "atk": 0.04, "dec": 2.0, "lp": 0.75, "trem": 0.6, "thz": 6.0},
	]},
	"ev_voidrift": {"vol": 0.75, "layers": [
		{"w": "sine", "f0": 170.0, "f1": 34.0, "d": 1.2, "a": 0.6, "atk": 0.02, "dec": 1.0},
		{"w": "noise", "d": 1.15, "a": 0.3, "atk": 0.05, "dec": 1.1, "lp": 0.25, "lp1": 0.05, "trem": 0.5, "thz": 6.0},
		{"w": "metal", "f0": 1200.0, "f1": 160.0, "d": 0.9, "a": 0.16, "dec": 2.0, "trem": 0.5, "thz": 10.0},
	]},
	"ev_sigil": {"vol": 0.72, "layers": [
		{"w": "sine", "arp": [261.6, 392.0, 523.25, 783.99], "d": 1.25, "a": 0.36, "atk": 0.05, "dec": 0.8},
		{"w": "metal", "f0": 1046.5, "f1": 2093.0, "d": 1.15, "a": 0.24, "atk": 0.08, "dec": 1.4, "lp": 0.9},
		{"w": "noise", "d": 1.2, "a": 0.14, "atk": 0.25, "dec": 1.0, "lp": 0.85, "trem": 0.25, "thz": 12.0},
		{"w": "sine", "f0": 65.0, "d": 1.25, "a": 0.3, "atk": 0.06, "dec": 1.0},
	]},
}


func _ready() -> void:
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)
	# 逐帧预热：避免第一次开特效时才合成造成掉帧
	call_deferred("_warmup")


func _warmup() -> void:
	for k in RECIPES.keys():
		if not is_inside_tree():
			return
		var key := String(k)
		if not _cache.has(key):
			_cache[key] = _build(key)
		await get_tree().process_frame


func play(kind: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled or _players.is_empty():
		return
	var stream: AudioStreamWAV = _cache.get(kind)
	if stream == null:
		stream = _build(kind if RECIPES.has(kind) else "it_item")
		_cache[kind] = stream
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = stream
	p.volume_db = VOLUME_DB + vol_db
	p.pitch_scale = pitch
	p.play()


func _build(kind: String) -> AudioStreamWAV:
	var r: Dictionary = RECIPES.get(kind, RECIPES["it_item"])
	var layers: Array = r.get("layers", [])
	var vol := float(r.get("vol", 0.6))
	var dur := 0.05
	for l in layers:
		dur = maxf(dur, float(l.get("t", 0.0)) + float(l.get("d", 0.3)))
	var n := int(dur * float(RATE)) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for l in layers:
		_mix(buf, l, rng)
	# 峰值归一 + 首尾淡入淡出，避免电平差太大或爆音
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var gain := vol / peak
	var fade := maxi(1, int(0.004 * float(RATE)))
	for i in n:
		var v := buf[i] * gain
		if i < fade:
			v *= float(i) / float(fade)
		if i > n - fade:
			v *= float(n - i) / float(fade)
		buf[i] = clampf(v, -1.0, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(buf[i] * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _mix(buf: PackedFloat32Array, layer: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(float(layer.get("t", 0.0)) * float(RATE))
	var count := int(float(layer.get("d", 0.3)) * float(RATE))
	if count <= 0:
		return
	var w := String(layer.get("w", "sine"))
	var f0 := float(layer.get("f0", 440.0))
	var f1 := float(layer.get("f1", f0))
	var amp := float(layer.get("a", 0.5))
	var atk := float(layer.get("atk", 0.004))
	var dec := float(layer.get("dec", 1.4))
	var lp0 := float(layer.get("lp", 1.0))
	var lp1 := float(layer.get("lp1", lp0))
	var nz := float(layer.get("nz", 0.0))
	var trem := float(layer.get("trem", 0.0))
	var thz := float(layer.get("thz", 14.0))
	var vib := float(layer.get("vib", 0.0))
	var vhz := float(layer.get("vhz", 6.0))
	var arp: Array = layer.get("arp", [])
	var phase := 0.0
	var lpv := 0.0
	for i in count:
		var idx := start + i
		if idx >= buf.size():
			break
		var tt := float(i) / float(RATE)
		var p := float(i) / float(maxi(count - 1, 1))
		var f := f0 * pow(maxf(f1, 1.0) / maxf(f0, 1.0), p)
		if not arp.is_empty():
			f = float(arp[mini(int(p * float(arp.size())), arp.size() - 1)])
		if vib > 0.0:
			f *= 1.0 + sin(TAU * vhz * tt) * vib
		phase += TAU * f / float(RATE)
		var s := _wave(w, phase, rng)
		if nz > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0), nz)
		var lpc := lerpf(lp0, lp1, p)
		if lpc < 0.999:
			lpv += (s - lpv) * lpc
			s = lpv
		var env := 1.0
		if atk > 0.0:
			env = minf(1.0, tt / atk)
		env *= pow(maxf(0.0, 1.0 - p), dec)
		if trem > 0.0:
			env *= 1.0 - trem * 0.5 * (1.0 + sin(TAU * thz * tt))
		buf[idx] += s * env * amp


func _wave(kind: String, phase: float, rng: RandomNumberGenerator) -> float:
	match kind:
		"sine":
			return sin(phase)
		"tri":
			return 4.0 * absf(fposmod(phase / TAU + 0.25, 1.0) - 0.5) - 1.0
		"saw":
			return 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		"square":
			return 1.0 if fposmod(phase / TAU, 1.0) < 0.5 else -1.0
		"metal":
			return sin(phase) * 0.55 + sin(phase * 2.37) * 0.28 + sin(phase * 4.11) * 0.17
		_:
			return rng.randf_range(-1.0, 1.0)
