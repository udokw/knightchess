class_name Arena
extends Node3D
## 天空竞技场：程序化生成的全部场景美术（不依赖原版贴图）
##  - 暮色全景天空 + ACES 色调映射 + 辉光
##  - 悬浮石台 / 40 格环道 / 四条终点跑道 / 四角阵地 / 中央高台
##  - 程序化棋子（车削网格）、3D 骰子、落点与吃子特效

const TILE_SIZE := 100.0
## 画面清晰度调校：弱化辉光与雾、提升对比与暗部，避免“眼花缭乱”
const GLOW_SCALE := 0.32
const FOG_SCALE := 0.32
const AMBIENT_LIFT := 1.25
const SAT_SCALE := 0.92
const CONTRAST := 1.16
const TILE_TOP := 8.0
const DECK_HALF := 890.0
## 自然场景的地面高度：广场像真实村落广场一样贴着地面，而不是悬空的台子
const SCENE_GROUND := -70.0
const DICE_HOME_BASE := Vector3(0, 300, 0)
const DICE_LAND := Vector3(0, 276, 0)
## 骰子整体缩放：2 倍于原尺寸，保证手机屏上点数清晰可读
const DICE_SCALE := 2.64

const DIE_FACES := {
	1: {"n": Vector3(1, 0, 0), "u": Vector3(0, 1, 0), "v": Vector3(0, 0, 1)},
	6: {"n": Vector3(-1, 0, 0), "u": Vector3(0, 1, 0), "v": Vector3(0, 0, -1)},
	2: {"n": Vector3(0, 1, 0), "u": Vector3(0, 0, 1), "v": Vector3(1, 0, 0)},
	5: {"n": Vector3(0, -1, 0), "u": Vector3(0, 0, 1), "v": Vector3(-1, 0, 0)},
	3: {"n": Vector3(0, 0, 1), "u": Vector3(1, 0, 0), "v": Vector3(0, 1, 0)},
	4: {"n": Vector3(0, 0, -1), "u": Vector3(-1, 0, 0), "v": Vector3(0, 1, 0)},
}

## 三套棋盘主题：天空 / 光照 / 雾 / 石材 / 金属 全部参数化
const THEMES := {
	"dusk": {
		"sky": "res://assets/textures/sky_dusk.png", "sky_energy": 0.85,
		"ambient": 0.34, "exposure": 1.02, "saturation": 1.18, "glow": 0.7,
		"sun_color": "ffdcb8", "sun_energy": 2.0, "sun_rot": Vector3(-55, -30, 0),
		"fill_color": "6f8fd8", "fill_energy": 0.28,
		"fog_color": "a8b8d6", "fog_energy": 0.45, "fog_density": 0.00005,
		"center_color": "ffb46b", "center_energy": 2.2,
		"stone_a": "c8d2e2", "stone_b": "b4c0d6", "stone_dark": "8e99b2", "deck": "7d879e",
		"tint_a": 0.94, "tint_b": 0.94, "tint_dark": 0.85, "tint_deck": 0.60,
		"gold": "d2a356", "gold_em": "a06a24",
		"chevron": "8e7440", "chevron_em": "c79a4e",
		"trim": "7fe3ff", "motes": "ffcf94",
	},
	"frost": {
		"sky": "res://assets/textures/sky_frost.png", "sky_energy": 0.95,
		"ambient": 0.30, "exposure": 0.86, "saturation": 1.02, "glow": 0.55,
		"sun_color": "e6f4ff", "sun_energy": 1.6, "sun_rot": Vector3(-48, -20, 0),
		"fill_color": "7fb0ff", "fill_energy": 0.40,
		"fog_color": "cfe6ff", "fog_energy": 0.5, "fog_density": 0.00009,
		"center_color": "bfe6ff", "center_energy": 1.7,
		"stone_a": "a9c0d8", "stone_b": "93aecb", "stone_dark": "5d7288", "deck": "6a7f96",
		"tint_a": 0.94, "tint_b": 0.94, "tint_dark": 0.78, "tint_deck": 0.62,
		"gold": "d8ecff", "gold_em": "4fa8dc",
		"chevron": "6f93a8", "chevron_em": "6fd4ff",
		"trim": "aef0ff", "motes": "e8f8ff",
	},
	"ember": {
		"sky": "res://assets/textures/sky_ember.png", "sky_energy": 0.80,
		"ambient": 0.30, "exposure": 0.96, "saturation": 1.26, "glow": 0.76,
		"sun_color": "ffb070", "sun_energy": 2.3, "sun_rot": Vector3(-62, -38, 0),
		"fill_color": "ff5a3a", "fill_energy": 0.30,
		"fog_color": "d98a6a", "fog_energy": 0.5, "fog_density": 0.00007,
		"center_color": "ff7a3a", "center_energy": 2.7,
		"stone_a": "8a6f66", "stone_b": "78605a", "stone_dark": "42333a", "deck": "3f3134",
		"tint_a": 1.0, "tint_b": 1.0, "tint_dark": 1.0, "tint_deck": 1.0,
		"gold": "e0a04a", "gold_em": "ff6a1e",
		"chevron": "c07038", "chevron_em": "ff9a3c",
		"trim": "ffb84a", "motes": "ffb066",
	},
	"jade": {
		"sky": "res://assets/textures/sky_jade.png", "sky_energy": 0.88,
		"ambient": 0.34, "exposure": 0.98, "saturation": 1.10, "glow": 0.62,
		"sun_color": "dcffd2", "sun_energy": 1.9, "sun_rot": Vector3(-50, -26, 0),
		"fill_color": "58c88a", "fill_energy": 0.32,
		"fog_color": "a6e2c2", "fog_energy": 0.46, "fog_density": 0.00006,
		"center_color": "7cffb8", "center_energy": 2.1,
		"stone_a": "a6c6ac", "stone_b": "8cae96", "stone_dark": "45604e", "deck": "526f5c",
		"tint_a": 0.95, "tint_b": 0.95, "tint_dark": 0.88, "tint_deck": 0.72,
		"gold": "cbbb72", "gold_em": "4f9b62",
		"chevron": "7c9a6a", "chevron_em": "a8ff9a",
		"trim": "a8ffd0", "motes": "d8ffe0",
	},
	"void": {
		"sky": "res://assets/textures/sky_void.png", "sky_energy": 0.92,
		"ambient": 0.26, "exposure": 0.90, "saturation": 1.16, "glow": 0.86,
		"sun_color": "c0b0ff", "sun_energy": 1.35, "sun_rot": Vector3(-68, -44, 0),
		"fill_color": "6a4fd8", "fill_energy": 0.42,
		"fog_color": "7a6ac0", "fog_energy": 0.40, "fog_density": 0.00006,
		"center_color": "a07cff", "center_energy": 2.6,
		"stone_a": "72729a", "stone_b": "5c5c80", "stone_dark": "2c2a44", "deck": "26243a",
		"tint_a": 0.95, "tint_b": 0.95, "tint_dark": 0.9, "tint_deck": 0.78,
		"gold": "bcacec", "gold_em": "7c5cff",
		"chevron": "6a5a9a", "chevron_em": "b8a0ff",
		"trim": "c8b8ff", "motes": "e0d8ff",
	},
	# 晴日草地：程序化晴空 + 暖砂台面，零泛光，主打松弛清晰的休闲感
	"cozy": {
		"sky": "", "sky_energy": 1.0,
		"sky_top": "B7DDEE", "sky_horizon": "FDF4E2",
		"ground_horizon": "EEF4DF", "ground_bottom": "CFE3C0",
		"ambient": 0.18, "exposure": 0.72, "saturation": 1.12, "glow": 0.0, "contrast": 1.24,
		"sun_color": "fff3da", "sun_energy": 1.18, "sun_rot": Vector3(-54, -32, 0),
		"fill_color": "d2e6f4", "fill_energy": 0.18,
		"fog_color": "e6f1e2", "fog_energy": 0.0, "fog_density": 0.0,
		"center_color": "ffe6b4", "center_energy": 0.6,
		"stone_a": "C3A87C", "stone_b": "B79C6E", "stone_dark": "8E744E", "deck": "BFA270",
		"deck_gain": 0.86,
		"tint_a": 0.84, "tint_b": 0.84, "tint_dark": 0.80, "tint_deck": 0.86,
		"gold": "B08748", "gold_em": "3A2C14",
		"chevron": "B99E74", "chevron_em": "4E3F26",
		"trim": "F2E0BA", "motes": "FFF6E2",
		"ground": "6A9446",
		# 环道踏步石比广场更浅，像被踩得发白的旧石板，路径一眼可读
		"path_a": "DFD2B4", "path_b": "CDBF9E",
		# 自然场景色板：夯土 / 木料 / 树叶 / 水面 / 远景山丘
		"nature": true,
		"soil": "A87F50", "wood": "6E4E32",
		"leaf_a": "3F7A30", "leaf_b": "33652A", "leaf_c": "5C9340",
		"water": "6FB6C8", "hill": "7FA85F",
	},
}

var team_colors: Array = []
var theme_id := "dusk"
var _env: Environment
var _sun: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _center_light: OmniLight3D
var _motes_mat: StandardMaterial3D
var _base_rings: Array = []
var _base_lights: Array = []
var _base_gems: Array = []
var _base_flags: Array = []
var _active_team := -1
var _movable_fx: Array = []
var _movable_halos: Array = []
var _sel_rings: Array = []
var _sel_orbs: Array = []
var _selected: Node3D
var _center_orb: Node3D
var _stone_a: StandardMaterial3D
var _stone_b: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _deck_top: StandardMaterial3D
var _gold: StandardMaterial3D
var _trim: StandardMaterial3D
var _chevron: StandardMaterial3D
var _team_metal: Array = []
var _team_glow: Array = []
var _team_soft: Array = []
# 自然场景材质：夯土 / 木料 / 树叶 / 水面
var _soil: StandardMaterial3D
var _wood: StandardMaterial3D
var _leaf_a: StandardMaterial3D
var _leaf_b: StandardMaterial3D
var _leaf_c: StandardMaterial3D
var _water: StandardMaterial3D
# 环道踏步石：比广场浅一档，让"路"从广场里浮出来
var _path_a: StandardMaterial3D
var _path_b: StandardMaterial3D
var _scenery: Node3D
var _camp_fires: Array = []
var _noise_tex: NoiseTexture2D
## 由原石纹提亮而来的浅色细节贴图：能直接当反照率用，又不会把广场压成黑片
var _stone_light: Texture2D
var _stone_rgh: Texture2D
var _shadow_tex: Texture2D
var _pawn_mesh: ArrayMesh

var _dice: Node3D
var _fx: Node3D
var _motes: MultiMeshInstance3D
var _marks: Array = []
var _piece_marks: Array = []
var _time := 0.0
var _rolling := false
var _dice_locked := false
var _dice_home := DICE_HOME_BASE
## 投掷拖影：骰子飞行时留下的一串渐淡光点
var _dice_trail: Array = []
var _dice_trail_pts: Array = []
var _tile_size := TILE_SIZE
var _board_scale := 1.0

# 事件格 / 安全格 / 荆棘 / 传送 3D 标记
var _chests: Array = []
var _safe_marks: Array = []
var _thorn_marks: Array = []
var _portal_marks: Array = []
# 随机事件格与随机掉落物（会频繁增删）
var _event_nodes: Array = []
var _drop_nodes: Array = []
# 主题环境粒子
var _theme_mm: MultiMeshInstance3D
var _theme_pts: Array = []
var _theme_kind := "dusk"
# 棋子拟人动画数据
var _actors: Array = []
## 程序化音效合成器（由 Main 注入，内部用 fx_sound 调用）
var sfx: Node = null

const PIECE_STYLE_NAMES := [
	"骑士", "法师", "弓手", "国王", "刺客", "守卫", "女武神", "机械兵",
]


func build(points: Dictionary, ring: Array, colors: Array, theme := "dusk",
		tile_size := TILE_SIZE, board_scale := 1.0) -> void:
	team_colors = colors
	theme_id = theme if THEMES.has(theme) else "dusk"
	_tile_size = tile_size
	_board_scale = board_scale
	# 骰子悬浮在棋盘正中央上空，慢慢自转，镜头一眼就能读到点数
	_dice_home = Vector3(0.0, 460.0, 0.0)
	# 棋盘不再整体缩放：格数越多，坐标外扩越大，格子世界尺寸恒定，画面更清晰不拥挤
	_build_environment()
	_build_ground()
	_make_materials()
	_build_platform()
	_build_track(points, ring)
	_build_goal_lanes(points)
	_build_bases(points)
	_build_center()
	_build_scenery()
	_build_motes()
	_build_theme_fx()
	_build_dice()
	_fx = Node3D.new()
	_fx.name = "FX"
	add_child(_fx)
	set_theme(theme_id)


func _process(delta: float) -> void:
	_time += delta
	for m in _marks:
		if is_instance_valid(m):
			var s: float = 1.0 + sin(_time * 4.0) * 0.06
			m.scale = Vector3(s, 1.0, s)
	for m in _piece_marks:
		if is_instance_valid(m):
			var s: float = 1.0 + sin(_time * 6.0) * 0.08
			m.scale = Vector3(s, 1.0, s)
	if _motes and is_instance_valid(_motes):
		_motes.rotation.y += delta * 0.01
	_animate_theme_fx(delta)
	if _dice and not _rolling:
		_dice.position.y = _dice_home.y + sin(_time * 1.6) * 5.0
		_dice.rotation.y += delta * 0.55
		# 斜着摆：同时看到三个面，远看才像个立方体而不是一张白卡片
		_dice.rotation.x = 0.40 + sin(_time * 0.9) * 0.08
		_dice.rotation.z = 0.22
	_update_dice_trail()

	# 事件宝箱：悬浮 + 自转 + 光柱呼吸
	for i in _chests.size():
		var chest: Node3D = _chests[i]
		if not is_instance_valid(chest):
			continue
		chest.position.y = 26.0 + sin(_time * 2.0 + float(i) * 0.7) * 5.0
		chest.rotation.y += delta * 0.9
	for i in _safe_marks.size():
		var pad: Node3D = _safe_marks[i]
		if not is_instance_valid(pad):
			continue
		pad.rotation.y -= delta * 0.6
		var pulse: float = 1.0 + sin(_time * 3.0 + float(i)) * 0.08
		pad.scale = Vector3(pulse, 1.0, pulse)

	for i in _thorn_marks.size():
		var spikes: Node3D = _thorn_marks[i]
		if is_instance_valid(spikes):
			spikes.rotation.y += delta * 0.35
			var ts: float = 1.0 + sin(_time * 2.2 + float(i)) * 0.05
			spikes.scale = Vector3(ts, 1.0, ts)
	for i in _portal_marks.size():
		var pad: Node3D = _portal_marks[i]
		if is_instance_valid(pad):
			pad.rotation.y -= delta * 1.2
			var ps: float = 1.0 + sin(_time * 3.6 + float(i)) * 0.10
			pad.scale = Vector3(ps, 1.0, ps)
	for i in _event_nodes.size():
		var ev: Node3D = _event_nodes[i]
		if not is_instance_valid(ev):
			continue
		ev.position.y = 30.0 + sin(_time * 2.6 + float(i) * 0.9) * 7.0
		ev.rotation.y += delta * 1.4
	for i in _drop_nodes.size():
		var dr: Node3D = _drop_nodes[i]
		if not is_instance_valid(dr):
			continue
		dr.position.y = 34.0 + sin(_time * 3.4 + float(i) * 1.3) * 9.0
		dr.rotation.y += delta * 2.6
		dr.rotation.x = sin(_time * 1.8 + float(i)) * 0.25

	# 棋子待机拟人动画
	for a in _actors:
		if not is_instance_valid(a["body"]):
			continue
		# 道具演出期间由 tween 接管身体姿态，待机摆动让位，避免逐帧覆盖
		if int(a.get("anim", 0)) > 0:
			continue
		var body: Node3D = a["body"]
		var ph: float = a["phase"]
		var style_i := int(a["style"])
		body.position.y = sin(_time * 2.2 + ph) * 2.4
		body.rotation.z = sin(_time * 1.7 + ph) * 0.022
		body.rotation.x = sin(_time * 1.1 + ph) * 0.018
		var gem: Node3D = a.get("gem")
		if is_instance_valid(gem):
			gem.rotation.y += delta * 1.9
			var gp: float = 1.0 + sin(_time * 3.4 + ph) * 0.16
			gem.scale = Vector3(gp, gp, gp)
		var orbit: Node3D = a.get("orbit")
		if is_instance_valid(orbit):
			var oa: float = _time * (1.6 + 0.12 * float(style_i)) + ph
			orbit.position = Vector3(cos(oa) * 42.0, 66.0 + sin(_time * 2.6 + ph) * 12.0, sin(oa) * 42.0)
		if style_i == 1 or style_i == 7:
			var spin_plume: Node3D = a["plume"]
			if is_instance_valid(spin_plume):
				spin_plume.rotation.y += delta * 0.9
		var cape: Node3D = a["cape"]
		if is_instance_valid(cape):
			cape.rotation.x = 0.12 + sin(_time * 2.9 + ph) * 0.10
		var plume: Node3D = a["plume"]
		if is_instance_valid(plume):
			plume.rotation.z = sin(_time * 3.4 + ph) * 0.16
		var banner: Node3D = a["banner"]
		if is_instance_valid(banner):
			banner.rotation.y = sin(_time * 1.3 + ph) * 0.22

	# 当前回合的基地呼吸
	for t in _base_rings.size():
		var ring: MeshInstance3D = _base_rings[t]
		if not is_instance_valid(ring):
			continue
		var active := t == _active_team
		var base_scale := 1.0
		var amp := 0.06
		if active:
			base_scale = 1.12
			amp = 0.14
		var s2: float = base_scale + sin(_time * (4.2 if active else 1.6)) * amp
		ring.scale = Vector3(s2, 1.0, s2)
		var gem: MeshInstance3D = _base_gems[t]
		if is_instance_valid(gem):
			var gs: float = (1.0 + sin(_time * (5.0 if active else 2.0)) * (0.22 if active else 0.06))
			gem.scale = Vector3(gs, gs, gs)
		var flag: Node3D = _base_flags[t]
		if is_instance_valid(flag):
			flag.rotation.z = sin(_time * 2.4 + float(t)) * (0.16 if active else 0.05)

	# 营地篝火：火苗上下跳动
	for i in _camp_fires.size():
		var fl: MeshInstance3D = _camp_fires[i]
		if is_instance_valid(fl):
			var fs: float = 1.0 + sin(_time * 8.6 + float(i) * 1.7) * 0.17
			fl.scale = Vector3(1.0 + sin(_time * 6.2 + float(i)) * 0.06, fs, 1.0 + cos(_time * 7.1 + float(i)) * 0.06)

	for fx in _movable_fx:
		if is_instance_valid(fx):
			fx.position.y = 172.0 + sin(_time * 5.0) * 9.0
			fx.rotation.y += delta * 1.8
	for r in _sel_rings:
		if is_instance_valid(r):
			var ss: float = 1.0 + sin(_time * 7.0) * 0.07
			r.scale = Vector3(ss, 1.0, ss)
	for i in _sel_orbs.size():
		var orb: MeshInstance3D = _sel_orbs[i]
		if is_instance_valid(orb):
			var a: float = _time * 2.6 + TAU * float(i) / 3.0
			orb.position = Vector3(cos(a) * 56.0, 30.0 + sin(_time * 3.0 + float(i)) * 6.0, sin(a) * 56.0)
	if _center_orb and is_instance_valid(_center_orb):
		_center_orb.rotation.y += delta * 0.35
		_center_orb.rotation.x = sin(_time * 0.4) * 0.12


# ---------------------------------------------------------------- 环境与材质

## 草地地面：把悬浮石台放回"真实场地"里，背景不再是空灰
func _build_ground() -> void:
	var gc: String = String(THEMES[theme_id].get("ground", ""))
	if gc == "":
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000.0, 9000.0)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = pm
	mi.position = Vector3(0, SCENE_GROUND, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(gc)
	m.roughness = 1.0
	m.metallic = 0.0
	mi.material_override = m
	add_child(mi)


func _build_environment() -> void:
	var th: Dictionary = THEMES[theme_id]
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_path: String = th["sky"]
	if sky_path != "" and ResourceLoader.exists(sky_path):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(sky_path)
		pano.energy_multiplier = th["sky_energy"]
		sky.sky_material = pano
	else:
		# 程序化晴空：不用贴图也能得到干净通透的日光天空
		var ps := ProceduralSkyMaterial.new()
		ps.sky_top_color = Color(th.get("sky_top", "0b1026"))
		ps.sky_horizon_color = Color(th.get("sky_horizon", "ffa06a"))
		ps.sky_curve = 0.16
		ps.ground_bottom_color = Color(th.get("ground_bottom", "1a2036"))
		ps.ground_horizon_color = Color(th.get("ground_horizon", "c98a72"))
		sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = float(th["ambient"]) * AMBIENT_LIFT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = th["exposure"]
	env.glow_enabled = true
	env.glow_intensity = float(th["glow"]) * GLOW_SCALE
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.set("glow_levels/2", 0.8)
	env.set("glow_levels/3", 0.6)
	env.set("glow_levels/4", 0.25)
	env.adjustment_enabled = true
	env.adjustment_saturation = float(th["saturation"]) * SAT_SCALE
	env.adjustment_contrast = float(th.get("contrast", CONTRAST))
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(th["fog_color"])
	env.fog_light_energy = float(th["fog_energy"]) * FOG_SCALE
	env.fog_density = float(th["fog_density"]) * FOG_SCALE
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = th["sun_rot"]
	sun.light_energy = th["sun_energy"]
	sun.light_color = Color(th["sun_color"])
	# 开启柔和日光投影：让棋子真正"落在"棋盘上，层次立刻立起来
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# 阴影距离按相机到广场的距离算：镜头在 3700 外，原来 2200 会把整盘阴影全裁掉
	sun.directional_shadow_max_distance = 6500.0
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.08
	add_child(sun)
	_sun = sun

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 148, 0)
	fill.light_energy = th["fill_energy"]
	fill.light_color = Color(th["fill_color"])
	add_child(fill)
	_fill_light = fill

	var center_light := OmniLight3D.new()
	center_light.position = Vector3(0, 260.0 * _board_scale, 0)
	center_light.light_color = Color(th["center_color"])
	center_light.light_energy = th["center_energy"]
	center_light.omni_range = 900.0 * _board_scale
	add_child(center_light)
	_center_light = center_light


func _make_materials() -> void:
	_noise_tex = NoiseTexture2D.new()
	var f := FastNoiseLite.new()
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX
	f.frequency = 0.035
	f.fractal_octaves = 4
	_noise_tex.noise = f
	_noise_tex.width = 512
	_noise_tex.height = 512
	_noise_tex.seamless = true
	_noise_tex.as_normal_map = true
	_noise_tex.bump_strength = 3.0

	# 接地软阴影贴图：径向渐变的暗斑，棋子/骰子垫在下面才有"压在地上"的重量感
	var st := GradientTexture2D.new()
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(1.0, 0.5)
	st.width = 128
	st.height = 128
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	sg.colors = PackedColorArray([
		Color(0, 0, 0, 0.44), Color(0, 0, 0, 0.26), Color(0, 0, 0, 0.0)])
	st.gradient = sg
	_shadow_tex = st

	if ResourceLoader.exists("res://assets/textures/stone_light.png"):
		_stone_light = load("res://assets/textures/stone_light.png")
	if ResourceLoader.exists("res://assets/textures/stone_rough.png"):
		_stone_rgh = load("res://assets/textures/stone_rough.png")

	var th: Dictionary = THEMES[theme_id]
	_stone_a = _pbr(Color(th["stone_a"]), 0.22, 0.62)
	_recolor_stone(_stone_a, Color(th["stone_a"]), float(th["tint_a"]), 0.0075, 0.22, 0.62)

	_stone_b = _pbr(Color(th["stone_b"]), 0.22, 0.56)
	_recolor_stone(_stone_b, Color(th["stone_b"]), float(th["tint_b"]), 0.0075, 0.22, 0.56)

	_stone_dark = _pbr(Color(th["stone_dark"]), 0.3, 0.5)
	_recolor_stone(_stone_dark, Color(th["stone_dark"]), float(th["tint_dark"]), 0.0065, 0.3, 0.5)

	_deck_top = _pbr(Color(th["deck"]), 0.26, 0.58)
	_recolor_stone(_deck_top, Color(th["deck"]), float(th["tint_deck"]) * float(th.get("deck_gain", 1.28)), 0.0060, 0.26, 0.58)

	_gold = _pbr(Color(th["gold"]), 0.72, 0.3)
	_gold.emission_enabled = true
	_gold.emission = Color(th["gold_em"])
	_gold.emission_energy_multiplier = 0.28
	_gold.rim_enabled = true
	_gold.rim = 0.18

	_trim = _pbr(Color("101820"), 0.4, 0.3)
	_trim.emission_enabled = true
	_trim.emission = Color(th["trim"])
	_trim.emission_energy_multiplier = 0.7

	_chevron = _pbr(Color(th["chevron"]).darkened(0.3), 0.5, 0.42)
	_chevron.emission_enabled = true
	_chevron.emission = Color(th["chevron_em"])
	_chevron.emission_energy_multiplier = 0.5

	# 自然场景材质：没有自然色板的主题退化为石材色，保持各处可运行
	_soil = _pbr(Color(th.get("soil", th["stone_dark"])), 0.0, 0.95)
	_wood = _pbr(Color(th.get("wood", th["stone_dark"])), 0.0, 0.8)
	_leaf_a = _pbr(Color(th.get("leaf_a", th["stone_b"])), 0.0, 0.86)
	_leaf_b = _pbr(Color(th.get("leaf_b", th["stone_a"])), 0.0, 0.86)
	_leaf_c = _pbr(Color(th.get("leaf_c", th["stone_a"])), 0.0, 0.86)
	_water = _pbr(Color(th.get("water", th["trim"])), 0.0, 0.34)
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wc := Color(th.get("water", th["trim"]))
	_water.albedo_color = Color(wc.r, wc.g, wc.b, 0.86)
	_water.emission_enabled = true
	_water.emission = wc
	_water.emission_energy_multiplier = 0.10
	_path_a = _pbr(Color(th.get("path_a", th["stone_a"])), 0.16, 0.58)
	_path_b = _pbr(Color(th.get("path_b", th["stone_b"])), 0.16, 0.54)
	# 踏步石铺一层石纹，环道不再是纯色塑料片
	_add_stone_detail(_path_a, 0.013, true)
	_add_stone_detail(_path_b, 0.012, true)

	for c in team_colors:
		var m := _pbr(Color(c).darkened(0.04), 0.34, 0.34)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.14
		m.rim_enabled = true
		m.rim = 0.5
		_team_metal.append(m)

		var g := _pbr(Color(c).darkened(0.55), 0.2, 0.35)
		g.emission_enabled = true
		g.emission = c
		g.emission_energy_multiplier = 1.1
		_team_glow.append(g)

		var s := _pbr(Color(c).darkened(0.45), 0.32, 0.5)
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = 0.16
		s.rim_enabled = true
		s.rim = 0.35
		_apply_stone(s, 1.0, 0.0024)
		_team_soft.append(s)


func _pbr(albedo: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _apply_stone(m: StandardMaterial3D, tint: float, tri: float) -> void:
	m.albedo_color = Color(m.albedo_color.r * tint, m.albedo_color.g * tint, m.albedo_color.b * tint)
	_add_stone_detail(m, tri, true)


## 只叠加石纹的粗糙度与法线，保留材质本身的浅色反照率
func _add_stone_detail(m: StandardMaterial3D, tri: float, albedo := false) -> void:
	if albedo and _stone_light:
		m.albedo_texture = _stone_light
	if _stone_rgh:
		m.roughness_texture = _stone_rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = _noise_tex
	m.normal_scale = 0.55
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tri, tri, tri)


func _recolor_stone(m: StandardMaterial3D, base: Color, tint: float, tri: float, metallic: float, rough: float) -> void:
	if m == null:
		return
	# 台面提亮：让棋盘、棋子、道具分层清晰，不再大片死黑
	var t := minf(tint * 1.20, 1.08)
	m.albedo_color = Color(base.r * t, base.g * t, base.b * t)
	m.metallic = metallic
	m.roughness = rough
	# 用提亮过的石纹做反照率：既保留石板斑驳的天然质感，又不会把台面压暗
	m.albedo_texture = _stone_light
	if _stone_rgh:
		m.roughness_texture = _stone_rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = _noise_tex
	# 法线强度提高一档：广场石缝和颗粒在斜视角下也读得出来，不再是平板一块
	m.normal_scale = 0.55
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tri, tri, tri)


## 运行时切换主题：只改环境与材质，不重建几何
func set_theme(id: String) -> void:
	if not THEMES.has(id):
		return
	var changed := id != theme_id
	theme_id = id
	var th: Dictionary = THEMES[id]

	if _env:
		_env.ambient_light_energy = float(th["ambient"]) * AMBIENT_LIFT
		_env.tonemap_exposure = th["exposure"]
		_env.glow_intensity = float(th["glow"]) * GLOW_SCALE
		_env.adjustment_saturation = float(th["saturation"]) * SAT_SCALE
		_env.fog_light_color = Color(th["fog_color"])
		_env.fog_light_energy = float(th["fog_energy"]) * FOG_SCALE
		_env.fog_density = float(th["fog_density"]) * FOG_SCALE
		var sky_path: String = th["sky"]
		if _env.sky:
			if sky_path != "" and ResourceLoader.exists(sky_path):
				var pano := PanoramaSkyMaterial.new()
				pano.panorama = load(sky_path)
				pano.energy_multiplier = th["sky_energy"]
				_env.sky.sky_material = pano
			else:
				var ps := ProceduralSkyMaterial.new()
				ps.sky_top_color = Color(th.get("sky_top", "0b1026"))
				ps.sky_horizon_color = Color(th.get("sky_horizon", "ffa06a"))
				ps.sky_curve = 0.16
				ps.ground_bottom_color = Color(th.get("ground_bottom", "1a2036"))
				ps.ground_horizon_color = Color(th.get("ground_horizon", "c98a72"))
				_env.sky.sky_material = ps
	if _sun:
		_sun.light_energy = th["sun_energy"]
		_sun.light_color = Color(th["sun_color"])
		_sun.rotation_degrees = th["sun_rot"]
	if _fill_light:
		_fill_light.light_energy = th["fill_energy"]
		_fill_light.light_color = Color(th["fill_color"])
	if _center_light:
		_center_light.light_energy = th["center_energy"]
		_center_light.light_color = Color(th["center_color"])

	_recolor_stone(_stone_a, Color(th["stone_a"]), float(th["tint_a"]), 0.0014, 0.22, 0.62)
	_recolor_stone(_stone_b, Color(th["stone_b"]), float(th["tint_b"]), 0.0014, 0.22, 0.56)
	_recolor_stone(_stone_dark, Color(th["stone_dark"]), float(th["tint_dark"]), 0.0011, 0.3, 0.5)
	_recolor_stone(_deck_top, Color(th["deck"]), float(th["tint_deck"]) * float(th.get("deck_gain", 1.28)), 0.0009, 0.26, 0.58)

	if _gold:
		_gold.albedo_color = Color(th["gold"])
		_gold.emission = Color(th["gold_em"])
	if _trim:
		_trim.emission = Color(th["trim"])
	if _chevron:
		_chevron.albedo_color = Color(th["chevron"])
		_chevron.emission = Color(th["chevron_em"])
	if _soil:
		_soil.albedo_color = Color(th.get("soil", th["stone_dark"]))
	if _wood:
		_wood.albedo_color = Color(th.get("wood", th["stone_dark"]))
	if _leaf_a:
		_leaf_a.albedo_color = Color(th.get("leaf_a", th["stone_b"]))
	if _leaf_b:
		_leaf_b.albedo_color = Color(th.get("leaf_b", th["stone_a"]))
	if _leaf_c:
		_leaf_c.albedo_color = Color(th.get("leaf_c", th["stone_a"]))
	if _water:
		var wc2 := Color(th.get("water", th["trim"]))
		_water.albedo_color = Color(wc2.r, wc2.g, wc2.b, 0.8)
		_water.emission = wc2
	if _path_a:
		_path_a.albedo_color = Color(th.get("path_a", th["stone_a"]))
	if _path_b:
		_path_b.albedo_color = Color(th.get("path_b", th["stone_b"]))
	# 自然景物只在自然主题下出现，其他主题保持原竞技场观感
	if _scenery:
		_scenery.visible = bool(th.get("nature", false))
	if _motes_mat:
		_motes_mat.albedo_color = Color(th["motes"])
		_motes_mat.emission = Color(th["motes"])
	if changed and _theme_mm != null:
		_theme_mm.queue_free()
		_theme_mm = null
		_build_theme_fx()


# ---------------------------------------------------------------- 几何工具

func _add_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _add_cyl(parent: Node, rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg := 28) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_torus(parent: Node, inner: float, outer: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 36
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 接地软阴影：一层径向渐变的暗斑，棋子/骰子垫在下面才有压在地面上的重量感
func _add_contact_shadow(parent: Node, radius: float, y := 0.8) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _shadow_tex
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 3D 场景里的广告牌文字（宝箱 / 安全格标识）
func _billboard_label(text: String, color: Color, height_units: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	l.font_size = 64
	l.pixel_size = height_units / 64.0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.double_sided = true
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 18
	l.outline_modulate = Color(0.02, 0.02, 0.05, 0.9)
	l.render_priority = 4
	return l


func _pt(points: Dictionary, name: String) -> Vector3:
	if not points.has(name):
		return Vector3.ZERO
	var p: Array = points[name]
	return Vector3(float(p[0]), TILE_TOP, float(p[2]))


# ---------------------------------------------------------------- 石台与环道

func _build_platform() -> void:
	var grow := maxf(_board_scale, 0.001)
	# 村落广场：圆形石铺广场贴着地面铺开。环道 940 是主体，广场只比环道外扩一圈营地
	var ring_r := 940.0 * grow
	var r := ring_r + 560.0
	var edges := 72
	var skirt_h := -SCENE_GROUND
	var skirt := _add_cyl(self, r * 0.995, r * 1.10, skirt_h, Vector3(0, SCENE_GROUND * 0.5, 0), _soil, edges)
	skirt.name = "PlazaSkirt"
	var deck := _add_cyl(self, r, r * 1.01, 18.0, Vector3(0, -9.0, 0), _stone_b, edges)
	deck.name = "Deck"
	var top := _add_cyl(self, r - 26.0, r - 22.0, 9.0, Vector3(0, -4.2, 0), _deck_top, edges)
	top.name = "DeckTop"

	# 放射状铺石缝：把大石面切成扇形石板，近看才有的手工感
	for k in 24:
		var a := TAU * float(k) / 24.0 + PI * 0.1
		var plen := r - 34.0
		var seam := _add_box(self, Vector3(plen, 1.6, 5.0), Vector3(cos(a) * plen * 0.5, 0.4, sin(a) * plen * 0.5), _stone_dark, -a)
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 同心石缝：一圈圈石板接缝，把广场铺成规整的环形铺装
	var seam_r := 190.0
	while seam_r < r - 46.0:
		var gro := _add_torus(self, seam_r - 2.6, seam_r + 2.6, Vector3(0, 0.5, 0), _stone_dark)
		gro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seam_r += 190.0

	# 广场外沿的矮石缘
	var kerb := _add_torus(self, r - 12.0, r + 10.0, Vector3(0, 2.0, 0), _stone_dark)
	kerb.name = "Kerb"
	kerb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_track(points: Dictionary, ring: Array) -> void:
	var n := ring.size()
	if n == 0:
		return
	var step: int = maxi(n / 4, 1)
	# 环线格子尺寸按周长自适应：格数越多格子越小，配合 board_scale 让整盘真正变大/变小
	var perim := 0.0
	for i in n:
		var pa := _pt(points, ring[i])
		var pb := _pt(points, ring[(i + 1) % n])
		perim += Vector2(pa.x - pb.x, pa.z - pb.z).length()
	var ts: float = clampf(perim / float(n) * 0.96, 45.0, 180.0)
	for i in n:
		var p := _pt(points, ring[i])
		var prev := _pt(points, ring[(i - 1 + n) % n])
		var nxt := _pt(points, ring[(i + 1) % n])
		var d_prev := (p - prev)
		var d_next := (nxt - p)
		d_prev.y = 0.0
		d_next.y = 0.0
		var d_avg := (d_prev.normalized() - d_next.normalized())
		var yaw_avg := atan2(-d_avg.x, -d_avg.z) if d_avg.length() > 0.001 else atan2(d_next.x, d_next.z)
		var yaw_next := atan2(d_next.x, d_next.z)

		var tile := Node3D.new()
		tile.position = p
		tile.rotation.y = yaw_avg
		add_child(tile)

		var team := i / step
		var is_start := i % step == 0
		var base_mat := _path_b if i % 2 == 0 else _path_a
		# 踏步石：等距圆形石板，像村落广场上一圈手工铺的石墩
		var wob := 1.0 + sin(float(i) * 2.31) * 0.035
		var sr := ts * 0.455 * wob
		var stone := _add_cyl(tile, sr, sr * 1.05, TILE_TOP, Vector3(0, -TILE_TOP * 0.5, 0), base_mat, 22)
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		stone.scale = Vector3(1.0, 1.0, 1.0 + cos(float(i) * 1.7) * 0.05)
		# 接缝：石板下压一层暗色薄盘，踏石之间形成自然缝隙阴影
		var gap := _add_cyl(tile, sr * 1.09, sr * 1.09, 4.0, Vector3(0, -TILE_TOP + 2.0, 0), _stone_dark, 22)
		gap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 方向箭头（尖端指向行进方向）
		var local_yaw := wrapf(yaw_next - yaw_avg, -PI, PI)
		var chev := Node3D.new()
		chev.rotation.y = local_yaw
		chev.position.y = 0.8
		tile.add_child(chev)
		for side in [-1, 1]:
			var bar := _add_box(chev, Vector3(ts * 0.1, 2.4, ts * 0.34), Vector3(ts * 0.12 * side, 0, ts * 0.03), _chevron, deg_to_rad(-32.0 * side))
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 固定特殊地形：宝箱格 / 安全格 / 传送格 / 荆棘格 / 道具格
		if i % step == step / 2:
			_make_chest(tile)
		elif i % step == 0:
			_make_safe_pad(tile)
		elif i % step == step * 3 / 10:
			_make_portal_pad(tile)
		elif i % step == step * 7 / 10:
			_make_thorn_pad(tile)
		elif i % step == step * 2 / 10 and (i / step) % 2 == 0:
			_make_item_pad(tile)

		if is_start and team >= 0 and team < _team_glow.size():
			_add_cyl(tile, ts * 0.40, ts * 0.40, 2.0, Vector3(0, 0.6, 0), _team_soft[team], 20).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var halo := _add_torus(tile, ts * 0.34, ts * 0.38, Vector3(0, 1.4, 0), _team_glow[team])
			halo.name = "StartHalo"


## 宝箱格：悬浮旋转的宝箱 + 金色光柱
func _make_chest(tile: Node3D) -> void:
	var chest := Node3D.new()
	chest.position.y = 24.0
	tile.add_child(chest)
	_chests.append(chest)

	var wood := _pbr(Color("7a4a24"), 0.15, 0.62)
	var body := _add_box(chest, Vector3(46, 28, 34), Vector3(0, 0, 0), wood)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(chest, Vector3(48, 10, 36), Vector3(0, 18, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sd in [-1.0, 1.0]:
		_add_box(chest, Vector3(6, 30, 37), Vector3(18.0 * sd, 1, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0
	sm.height = 12.0
	sm.radial_segments = 6
	sm.rings = 3
	lock.mesh = sm
	lock.material_override = _unshaded(Color("ffe9a8"), 3.4)
	lock.position = Vector3(0, 4, 19)
	chest.add_child(lock)

	# 光柱：让宝箱格从高空一眼可辨
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 26.0
	cm.bottom_radius = 14.0
	cm.height = 210.0
	cm.radial_segments = 18
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm := _unshaded(Color("ffd166"), 1.3)
	(bm as StandardMaterial3D).albedo_color = Color(1.0, 0.82, 0.4, 0.07)
	beam.material_override = bm
	beam.position.y = 78.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(beam)

	var halo := _add_torus(tile, 26.0, 32.0, Vector3(0, 1.6, 0), _unshaded(Color("ffd166"), 1.8))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 头顶「？」招牌：远处也能一眼看出这是事件格
	var sign_l := _billboard_label("？", Color("fff6dd"), 64.0)
	sign_l.position = Vector3(0, 100.0, 0)
	chest.add_child(sign_l)


## 固定道具格：悬浮青色宝晶 + 光柱（踩中触发道具轮盘）
func _make_item_pad(tile: Node3D) -> void:
	var gem := Node3D.new()
	gem.position.y = 30.0
	tile.add_child(gem)
	_chests.append(gem)
	var crystal := MeshInstance3D.new()
	var cm := PrismMesh.new()
	cm.size = Vector3(34.0, 58.0, 34.0)
	crystal.mesh = cm
	crystal.material_override = _unshaded(Color("8ff0c0"), 1.4)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gem.add_child(crystal)
	var halo := _add_torus(tile, 24.0, 30.0, Vector3(0, 2.0, 0), _unshaded(Color("8ff0c0"), 1.2))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var beam := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 18.0
	bcm.bottom_radius = 10.0
	bcm.height = 180.0
	bcm.radial_segments = 14
	bcm.cap_top = false
	bcm.cap_bottom = false
	beam.mesh = bcm
	var bm := _unshaded(Color("8ff0c0"), 1.2)
	(bm as StandardMaterial3D).albedo_color = Color(0.56, 0.94, 0.75, 0.06)
	beam.material_override = bm
	beam.position.y = 64.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(beam)

	var sign_l := _billboard_label("道具", Color("dfffe8"), 42.0)
	sign_l.position = Vector3(0, 76.0, 0)
	gem.add_child(sign_l)


## 安全格：贴地的旋转金环 + 四枚小晶棱
func _make_safe_pad(tile: Node3D) -> void:
	var pad := Node3D.new()
	pad.position.y = 1.4
	tile.add_child(pad)
	_safe_marks.append(pad)

	var mat := _unshaded(Color("8fe6ff"), 1.4)
	var ring := _add_torus(pad, 26.0, 31.0, Vector3.ZERO, mat)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_torus(pad, 14.0, 17.0, Vector3.ZERO, _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var a := TAU * float(k) / 4.0 + deg_to_rad(45.0)
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 4.0
		sm.height = 8.0
		sm.radial_segments = 4
		sm.rings = 2
		gem.mesh = sm
		gem.material_override = mat
		gem.position = Vector3(cos(a) * 36.0, 1.0, sin(a) * 36.0)
		gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pad.add_child(gem)

	var sign_l := _billboard_label("安全区", Color("9fe8ff"), 34.0)
	sign_l.position = Vector3(0, 46.0, 0)
	tile.add_child(sign_l)


## 传送格：紫色旋涡 + 双层环 + 「传送」招牌（踩中前进 4 格）
func _make_portal_pad(tile: Node3D) -> void:
	var pad := Node3D.new()
	pad.position.y = 1.4
	tile.add_child(pad)
	_portal_marks.append(pad)

	var mat := _unshaded(Color("b484ff"), 1.6)
	_add_torus(pad, 26.0, 31.0, Vector3.ZERO, mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r2 := _add_torus(pad, 15.0, 18.0, Vector3(0, 6.0, 0), _unshaded(Color("e2c8ff"), 2.2))
	r2.rotation.x = deg_to_rad(90.0)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.4
		sm.height = 6.8
		sm.radial_segments = 4
		sm.rings = 2
		gem.mesh = sm
		gem.material_override = _unshaded(Color("c9a6ff"), 2.6)
		gem.position = Vector3(cos(a) * 34.0, 8.0, sin(a) * 34.0)
		gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pad.add_child(gem)

	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 20.0
	cm.bottom_radius = 10.0
	cm.height = 190.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm := _unshaded(Color("b484ff"), 1.2)
	(bm as StandardMaterial3D).albedo_color = Color(0.70, 0.52, 1.0, 0.06)
	beam.material_override = bm
	beam.position.y = 92.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(beam)

	var sign_l := _billboard_label("传送", Color("d8c4ff"), 34.0)
	sign_l.position = Vector3(0, 52.0, 0)
	tile.add_child(sign_l)


## 荆棘格：暗红尖刺 + 「荆棘」招牌（踩中后退 2 格）
func _make_thorn_pad(tile: Node3D) -> void:
	var holder := Node3D.new()
	holder.position.y = 1.0
	tile.add_child(holder)
	_thorn_marks.append(holder)

	var mat := _unshaded(Color("ff5566"), 1.5)
	_add_torus(holder, 26.0, 30.0, Vector3.ZERO, _unshaded(Color("8a2430"), 1.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 7:
		var a := TAU * float(k) / 7.0 + 0.2
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 8.0
		cm.height = 34.0
		cm.radial_segments = 4
		spike.mesh = cm
		spike.material_override = mat
		spike.position = Vector3(cos(a) * 30.0, 12.0, sin(a) * 30.0)
		spike.rotation.z = cos(a) * 0.3
		spike.rotation.x = sin(a) * 0.3
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(spike)

	var sign_l := _billboard_label("荆棘", Color("ff8a92"), 32.0)
	sign_l.position = Vector3(0, 48.0, 0)
	tile.add_child(sign_l)


## 随机事件格：漂浮符印 + 光柱（位置由 Main 随机指定）
func spawn_event_cell(pos: Vector3, color: Color, symbol: String) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 30.0, pos.z)
	add_child(root)
	_event_nodes.append(root)

	var ring := _add_torus(root, 28.0, 34.0, Vector3.ZERO, _unshaded(color, 2.2))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring2 := _add_torus(root, 14.0, 18.0, Vector3(0, 6.0, 0), _unshaded(color.lightened(0.3), 2.8))
	ring2.rotation.x = deg_to_rad(90.0)
	ring2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 10.0
	sm.height = 20.0
	sm.radial_segments = 4
	sm.rings = 2
	core.mesh = sm
	core.material_override = _unshaded(color.lightened(0.45), 1.8)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)

	var lbl := _billboard_label(symbol, color.lightened(0.35), 40.0)
	lbl.position = Vector3(0, 42.0, 0)
	root.add_child(lbl)

	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 18.0
	cm.bottom_radius = 9.0
	cm.height = 190.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm := _unshaded(color, 1.4)
	(bm as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.055)
	beam.material_override = bm
	beam.position = Vector3(0, 80.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	return root


func remove_event_cell(node: Node3D) -> void:
	_event_nodes.erase(node)
	if is_instance_valid(node):
		node.queue_free()


## 随机掉落道具：悬浮宝珠 + 小光柱（位置由 Main 随机指定）
func spawn_drop(pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 34.0, pos.z)
	add_child(root)
	_drop_nodes.append(root)

	var shell := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(18, 18, 18)
	shell.mesh = bm
	shell.material_override = _unshaded(color.lightened(0.35), 3.0)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)

	var ring := _add_torus(root, 20.0, 24.0, Vector3.ZERO, _unshaded(color, 2.4))
	ring.rotation.x = deg_to_rad(72.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 14.0
	cm.bottom_radius = 6.0
	cm.height = 200.0
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm2 := _unshaded(color, 1.2)
	(bm2 as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.10)
	beam.material_override = bm2
	beam.position = Vector3(0, -100.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	return root


func remove_drop(node: Node3D) -> void:
	_drop_nodes.erase(node)
	if is_instance_valid(node):
		node.queue_free()


func clear_random_marks() -> void:
	for n in _event_nodes.duplicate():
		remove_event_cell(n)
	for n in _drop_nodes.duplicate():
		remove_drop(n)

func _build_goal_lanes(points: Dictionary) -> void:
	for t in 4:
		# 由外向内：GLt_1 .. GLt_4
		var outer := _pt(points, "GL%d_1" % (t + 1))
		var inner := _pt(points, "GL%d_4" % (t + 1))
		var d := inner - outer
		d.y = 0.0
		var yaw := atan2(d.x, d.z)
		for s in 4:
			var p := _pt(points, "GL%d_%d" % [t + 1, s + 1])
			var pad := Node3D.new()
			pad.position = p
			pad.rotation.y = yaw
			add_child(pad)
			_add_cyl(pad, 54.0, 56.0, 8.0, Vector3(0, -4.0, 0), _stone_b, 22).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_add_cyl(pad, 44.0, 45.0, 2.0, Vector3(0, 0.6, 0), _stone_a, 22).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_torus(pad, 37.0, 40.0, Vector3(0, 2.2, 0), _team_glow[t])
			if s == 3:
				_add_torus(pad, 30, 36, Vector3(0, 2.2, 0), _gold)

		# 跑道两沿的黄铜嵌线：像广场上铺出的迎宾石径
		var lane_mid := (outer + inner) * 0.5
		var length := d.length() + 80.0
		for side in [-1, 1]:
			var sd := float(side)
			var off: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 56.0 * sd
			_add_box(self, Vector3(4, 2.4, length), Vector3(lane_mid.x + off.x, 0.4, lane_mid.z + off.z), _gold, yaw).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 终点门拱：两根立柱 + 横梁 + 队色宝石
		var arch := Node3D.new()
		arch.position = inner - d.normalized() * 8.0
		arch.rotation.y = yaw
		arch.name = "GoalArch%d" % t
		add_child(arch)
		for side in [-1, 1]:
			var sd2 := float(side)
			_add_box(arch, Vector3(16, 118, 16), Vector3(64.0 * sd2, 59.0, 0), _stone_b).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_add_box(arch, Vector3(10, 104, 10), Vector3(64.0 * sd2, 55.0, 10.0), _team_metal[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_box(arch, Vector3(148, 14, 16), Vector3(0, 120.0, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var crown := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 12.0
		cs.height = 24.0
		cs.radial_segments = 6
		cs.rings = 3
		crown.mesh = cs
		crown.material_override = _team_glow[t]
		crown.position = Vector3(0, 142.0, 0)
		crown.name = "ArchCrown%d" % t
		arch.add_child(crown)


func _build_bases(points: Dictionary) -> void:
	var ring_pt := _pt(points, "BS00")
	var ring_r := Vector2(ring_pt.x, ring_pt.z).length()
	for t in 4:
		var c := Vector3.ZERO
		for i in 4:
			c += _pt(points, "HM%d_%d" % [t + 1, i + 1])
		c /= 4.0
		var outward := Vector3(c.x, 0, c.z).normalized()
		var tangent := Vector3(-outward.z, 0, outward.x)
		var ba := atan2(outward.z, outward.x)

		# 站位：1+3 两行紧凑弧形，贴着环道外沿，不再铺一大块圆形营地
		for i in 4:
			var p := _pt(points, "HM%d_%d" % [t + 1, i + 1])
			var pad := _add_cyl(self, 50.0, 53.0, 8.0, Vector3(p.x, 4.0, p.z), _stone_dark, 26)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_add_cyl(self, 43.0, 44.0, 2.2, Vector3(p.x, 8.6, p.z), _team_metal[t], 26).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_torus(self, 40.0, 45.0, Vector3(p.x, 9.4, p.z), _gold)

		# 队伍地界：贴着广场的一圈细光（当前回合会呼吸）
		var halo := _add_torus(self, 132.0, 140.0, Vector3(c.x, 1.2, c.z), _team_glow[t])
		halo.name = "BaseHalo%d" % t
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_base_rings.append(halo)

		# 弧形石栏：把 1+3 四个站位围成"一家人的地界"，而不是散落的四块石头
		for k in 7:
			var ka := (float(k) - 3.0) * 0.062
			var kp := outward * (ring_r + 228.0 + 74.0) + tangent * (sin(ka) * (ring_r + 302.0))
			var kb := _add_box(self, Vector3(62.0, 10.0, 20.0), Vector3(kp.x, 5.0, kp.z), _stone_dark, -ba - ka - PI * 0.5)
			kb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		# 队伍图腾柱 + 旗帜：立在基地一侧
		var ob_pos := c - tangent * 380.0
		var ob := _add_cyl(self, 5.0, 24.0, 150.0, Vector3(ob_pos.x, 83.0, ob_pos.z), _team_metal[t], 4)
		ob.rotation.y = deg_to_rad(45.0)
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 13.0
		sm.height = 26.0
		sm.radial_segments = 4
		sm.rings = 2
		gem.mesh = sm
		gem.material_override = _team_glow[t]
		gem.position = Vector3(ob_pos.x, 178.0, ob_pos.z)
		gem.name = "BaseGem%d" % t
		add_child(gem)
		_base_gems.append(gem)
		_add_torus(self, 26.0, 30.0, Vector3(ob_pos.x, 120.0, ob_pos.z), _team_glow[t], Vector3(deg_to_rad(90), 0, 0))

		var flag := Node3D.new()
		flag.position = Vector3(ob_pos.x, 0, ob_pos.z)
		flag.name = "BaseFlag%d" % t
		add_child(flag)
		_add_cyl(flag, 2.4, 2.4, 120.0, Vector3(0, 60.0, 0), _gold, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cloth := _add_box(flag, Vector3(58.0, 30.0, 3.0), Vector3(30.0, 108.0, 0), _team_soft[t])
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var cloth_gem := MeshInstance3D.new()
		var cg := SphereMesh.new()
		cg.radius = 9.0
		cg.height = 18.0
		cg.radial_segments = 6
		cg.rings = 3
		cloth_gem.mesh = cg
		cloth_gem.material_override = _team_glow[t]
		cloth_gem.position = Vector3(30.0, 108.0, 3.0)
		flag.add_child(cloth_gem)
		_base_flags.append(flag)

		# 毡帐：扎在基地最外侧，门朝环道
		var tent_pos := c - tangent * 240.0
		var tent := Node3D.new()
		tent.position = tent_pos
		tent.rotation.y = atan2(-outward.x, -outward.z)
		tent.name = "BaseTent%d" % t
		add_child(tent)
		_add_cyl(tent, 92.0, 96.0, 6.0, Vector3(0, 3.0, 0), _soil, 24)
		# 短帐身 + 陡锥顶：从上往下看是一个"尖顶帐"，不会再像扁鼓或帽子
		_add_cyl(tent, 66.0, 72.0, 58.0, Vector3(0, 35.0, 0), _path_a, 24)
		_add_torus(tent, 70.0, 76.0, Vector3(0, 10.0, 0), _wood)
		_add_torus(tent, 68.0, 73.0, Vector3(0, 52.0, 0), _team_soft[t])
		var roof := _add_cyl(tent, 6.0, 88.0, 62.0, Vector3(0, 95.0, 0), _wood, 24)
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_add_torus(tent, 82.0, 90.0, Vector3(0, 66.0, 0), _gold)
		_add_cyl(tent, 1.6, 1.6, 36.0, Vector3(0, 140.0, 0), _wood, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pennant := _add_box(tent, Vector3(2.0, 16.0, 36.0), Vector3(0, 152.0, 19.0), _team_glow[t])
		pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 门帘朝环道，让"门在哪"一眼可辨
		_add_box(tent, Vector3(26.0, 40.0, 8.0), Vector3(0, 24.0, 68.0), _stone_dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 营地杂物：木箱 / 酒桶 / 柴堆，把"有人在这儿生活"的细节补上
		var prop := tent_pos + outward * 44.0 - tangent * 62.0
		_add_box(self, Vector3(30, 30, 30), Vector3(prop.x, 23.0, prop.z), _wood, 0.4)
		_add_box(self, Vector3(24, 24, 24), Vector3(prop.x - tangent.x * 34.0, 20.0, prop.z - tangent.z * 34.0), _wood, -0.3)
		_add_cyl(self, 15.0, 17.0, 34.0, Vector3(prop.x + outward.x * 36.0, 25.0, prop.z + outward.z * 36.0), _wood, 10)
		var pile := prop + tangent * 58.0
		var log1 := _add_cyl(self, 9.0, 9.0, 52.0, Vector3(pile.x, 17.0, pile.z), _wood, 8)
		log1.rotation.z = deg_to_rad(90.0)
		var log2 := _add_cyl(self, 9.0, 9.0, 46.0, Vector3(pile.x, 27.0, pile.z + 12.0), _wood, 8)
		log2.rotation.z = deg_to_rad(90.0)

		# 篝火：围石 + 交叉柴火 + 跳动的火苗
		var fire := Node3D.new()
		fire.position = c - tangent * 472.0
		fire.name = "BaseFire%d" % t
		add_child(fire)
		for k in 6:
			var fa := TAU * float(k) / 6.0
			_add_cyl(fire, 7.0, 9.0, 9.0, Vector3(cos(fa) * 27.0, 12.5, sin(fa) * 27.0), _stone_dark, 6)
		for k in 2:
			var logm := _add_box(fire, Vector3(48, 9, 9), Vector3(0, 18.0, 0), _wood, deg_to_rad(36.0 + 92.0 * float(k)))
			logm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flame := _add_cyl(fire, 0.0, 16.0, 42.0, Vector3(0, 40.0, 0), _unshaded(Color("FFB258"), 1.7), 6)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.name = "Flame"
		_camp_fires.append(flame)

		var light := OmniLight3D.new()
		light.position = Vector3(c.x, 70.0, c.z)
		light.light_color = team_colors[t]
		light.light_energy = 1.1
		light.omni_range = 430.0
		light.shadow_enabled = false
		add_child(light)
		_base_lights.append(light)


## 当前回合：对应基地整体提亮
func set_active_team(team: int) -> void:
	_active_team = team
	for t in _base_lights.size():
		var light: OmniLight3D = _base_lights[t]
		if is_instance_valid(light):
			light.light_energy = 2.4 if t == team else 0.9


func _build_center() -> void:
	# 广场中央的水景：石砌水池 + 中央石柱 + 悬浮水球
	_add_cyl(self, 150.0, 162.0, 16.0, Vector3(0, 8.0, 0), _stone_dark, 40)
	_add_cyl(self, 132.0, 134.0, 3.0, Vector3(0, 15.5, 0), _water, 40).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_torus(self, 130.0, 152.0, Vector3(0, 17.0, 0), _stone_b)
	for k in 4:
		var a := TAU * float(k) / 4.0 + deg_to_rad(45.0)
		_add_cyl(self, 16.0, 21.0, 18.0, Vector3(cos(a) * 142.0, 25.0, sin(a) * 142.0), _stone_dark, 6)
	# 中央石柱与上水盘
	_add_cyl(self, 26.0, 38.0, 56.0, Vector3(0, 47.0, 0), _stone_b, 22)
	_add_cyl(self, 60.0, 28.0, 14.0, Vector3(0, 82.0, 0), _stone_a, 30)
	_add_cyl(self, 44.0, 44.0, 3.0, Vector3(0, 89.0, 0), _water, 30).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var orb := Node3D.new()
	orb.name = "CenterOrb"
	orb.position = Vector3(0, 158, 0)
	add_child(orb)
	_center_orb = orb

	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 28.0
	sm.height = 56.0
	sm.radial_segments = 12
	sm.rings = 6
	gem.mesh = sm
	gem.material_override = _gold
	gem.name = "CenterGem"
	orb.add_child(gem)

	# 金球外的两道细环
	_add_torus(orb, 40.0, 44.0, Vector3.ZERO, _trim, Vector3(deg_to_rad(24), 0, 0))
	_add_torus(orb, 52.0, 55.0, Vector3.ZERO, _trim, Vector3(deg_to_rad(-30), deg_to_rad(24), 0))

	for t in 4:
		var a := TAU * t / 4.0 + deg_to_rad(45.0)
		var p := Vector3(cos(a) * 196.0, 30.0, sin(a) * 196.0)
		var g := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = 11.0
		s2.height = 22.0
		s2.radial_segments = 4
		s2.rings = 2
		g.mesh = s2
		g.material_override = _team_glow[t]
		g.position = p
		g.name = "CenterCrystal%d" % t
		add_child(g)


## 村落外景：远山 / 树木 / 灌木 / 岩石。非自然主题下整体隐藏
func _build_scenery() -> void:
	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)
	var grow := maxf(_board_scale, 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6172

	# 远山：地平线上一圈低多边形山丘，把场景纵深撑开
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.37
		var dist := rng.randf_range(3600.0, 5000.0) * grow
		var hr := rng.randf_range(700.0, 1100.0) * grow
		var hill := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = hr
		hm.height = hr * 0.72
		hm.radial_segments = 14
		hm.rings = 7
		hill.mesh = hm
		hill.material_override = _leaf_c
		hill.position = Vector3(cos(a) * dist, SCENE_GROUND - hr * 0.24, sin(a) * dist)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scenery.add_child(hill)

	# 从广场延伸出去的土路：让这里像村落的中心广场，而不是一块棋盘
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.9
		var d := Vector3(cos(a), 0, sin(a))
		var plen := 1150.0 * grow
		var start := 1580.0 * grow
		var road := _add_box(_scenery, Vector3(plen, 4.0, 180.0), Vector3(d.x * (start + plen * 0.5), SCENE_GROUND + 1.0, d.z * (start + plen * 0.5)), _soil, -a)
		road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 环广场一周的树木：真实树高，站在草地上衬出广场的尺度
	for k in 14:
		var a := TAU * float(k) / 14.0 + rng.randf_range(-0.12, 0.12)
		# 相机默认从 34° 方位看进来，这个方向留空，避免树挡住画面
		if absf(wrapf(a - deg_to_rad(34.0), -PI, PI)) < 0.34:
			continue
		var dist := rng.randf_range(1780.0, 2400.0) * grow
		var px := cos(a) * dist
		var pz := sin(a) * dist
		var th := rng.randf_range(400.0, 640.0)
		_add_cyl(_scenery, 12.0, 22.0, th, Vector3(px, SCENE_GROUND + th * 0.5, pz), _wood, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for c in 3:
			var cr := rng.randf_range(105.0, 168.0)
			var leaf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = cr
			sm.height = cr * 1.55
			sm.radial_segments = 10
			sm.rings = 5
			leaf.mesh = sm
			leaf.material_override = _leaf_a if c % 2 == 0 else _leaf_b
			leaf.position = Vector3(px + rng.randf_range(-40.0, 40.0), SCENE_GROUND + th * 0.88 + float(c) * cr * 0.58, pz + rng.randf_range(-40.0, 40.0))
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_scenery.add_child(leaf)

	# 灌木与散石：给草地加些近处的细节
	for k in 10:
		var a := TAU * float(k) / 10.0 + 0.9
		var dist := rng.randf_range(1740.0, 2300.0) * grow
		var px := cos(a) * dist
		var pz := sin(a) * dist
		for c in 2:
			var br := rng.randf_range(38.0, 66.0)
			var bush := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = br
			bm.height = br * 1.05
			bm.radial_segments = 8
			bm.rings = 4
			bush.mesh = bm
			bush.material_override = _leaf_b if c == 0 else _leaf_c
			bush.position = Vector3(px + float(c) * 52.0 * cos(a), SCENE_GROUND + br * 0.4, pz + float(c) * 52.0 * sin(a))
			bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_scenery.add_child(bush)
	for k in 10:
		var a := TAU * float(k) / 10.0 + 2.1
		var dist := rng.randf_range(1740.0, 2340.0) * grow
		var rr := rng.randf_range(30.0, 72.0)
		var rock := _add_cyl(_scenery, rr * 0.7, rr, rr * 0.62, Vector3(cos(a) * dist, SCENE_GROUND + rr * 0.24, sin(a) * dist), _stone_dark, 6)
		rock.rotation.y = a * 2.3
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_scenery.visible = bool(THEMES[theme_id].get("nature", false))


func _build_motes() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7788
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 40
	var sm := SphereMesh.new()
	sm.radius = 1.8
	sm.height = 3.6
	sm.radial_segments = 6
	sm.rings = 3
	var th: Dictionary = THEMES[theme_id]
	var mat := _pbr(Color(th["motes"]), 0.0, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(th["motes"])
	mat.emission_energy_multiplier = 0.9
	_motes_mat = mat
	sm.material = mat
	mm.mesh = sm
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 980.0 * _board_scale
		var y := rng.randf_range(20.0, 520.0)
		var xf := Transform3D(Basis(), Vector3(cos(a) * r, y, sin(a) * r))
		mm.set_instance_transform(i, xf)
	_motes = MultiMeshInstance3D.new()
	_motes.multimesh = mm
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


## 主题专属环境粒子：暮色余烬 / 霜封落雪 / 熔火飞灰
func _build_theme_fx() -> void:
	_theme_kind = theme_id
	if DisplayServer.get_name() == "headless":
		return
	var count := 42
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	var mesh: Mesh
	if theme_id == "frost":
		var bm := BoxMesh.new()
		bm.size = Vector3(3.4, 3.4, 3.4)
		mesh = bm
	elif theme_id == "ember":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 2.6
		cm.height = 7.0
		cm.radial_segments = 4
		mesh = cm
	elif theme_id == "jade":
		var lm := BoxMesh.new()
		lm.size = Vector3(5.0, 1.2, 3.0)
		mesh = lm
	elif theme_id == "void":
		var vm := BoxMesh.new()
		vm.size = Vector3(2.6, 2.6, 2.6)
		mesh = vm
	else:
		var sm := SphereMesh.new()
		sm.radius = 2.2
		sm.height = 4.4
		sm.radial_segments = 5
		sm.rings = 3
		mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var col: Color = Color(THEMES[theme_id]["motes"])
	if theme_id == "frost":
		col = Color(0.82, 0.94, 1.0)
	elif theme_id == "ember":
		col = Color(1.0, 0.55, 0.22)
	elif theme_id == "jade":
		col = Color(0.62, 1.0, 0.72)
	elif theme_id == "void":
		col = Color(0.76, 0.66, 1.0)
	mat.albedo_color = Color(col.r, col.g, col.b, 0.5)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	elif mesh is ArrayMesh and (mesh as ArrayMesh).get_surface_count() > 0:
		mesh.surface_set_material(0, mat)
	mm.mesh = mesh
	_theme_pts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 1060.0 * _board_scale
		var y := rng.randf_range(10.0, 620.0)
		var base := Vector3(cos(a) * r, y, sin(a) * r)
		mm.set_instance_transform(i, Transform3D(Basis(), base))
		_theme_pts.append({"pos": base, "speed": rng.randf_range(0.5, 1.5), "phase": rng.randf() * TAU})
	_theme_mm = MultiMeshInstance3D.new()
	_theme_mm.multimesh = mm
	_theme_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_theme_mm)


func _animate_theme_fx(delta: float) -> void:
	if _theme_mm == null or _theme_mm.multimesh == null:
		return
	var mm: MultiMesh = _theme_mm.multimesh
	var count := _theme_pts.size()
	for i in count:
		var d: Dictionary = _theme_pts[i]
		var p: Vector3 = d["pos"]
		var sp: float = d["speed"]
		var ph: float = d["phase"]
		if _theme_kind == "frost":
			# 落雪：缓慢下坠 + 横向摆动
			p.y -= delta * 34.0 * sp
			p.x += sin(_time * 0.8 + ph) * delta * 10.0
			if p.y < 6.0:
				p.y = 620.0
		elif _theme_kind == "ember":
			# 飞灰：快速上升 + 闪烁偏移
			p.y += delta * 62.0 * sp
			p.x += sin(_time * 2.4 + ph) * delta * 16.0
			if p.y > 640.0:
				p.y = 6.0
		elif _theme_kind == "jade":
			# 翠叶：随风飘落并打旋
			p.y -= delta * 18.0 * sp
			p.x += sin(_time * 0.9 + ph) * delta * 22.0
			p.z += cos(_time * 0.7 + ph) * delta * 14.0
			if p.y < 6.0:
				p.y = 560.0
		elif _theme_kind == "void":
			# 虚空星尘：缓慢上浮 + 明灭
			p.y += delta * 12.0 * sp
			p.x += sin(_time * 0.4 + ph) * delta * 8.0
			if p.y > 640.0:
				p.y = 8.0
		else:
			# 暮色余烬：缓慢上升 + 盘旋
			p.y += delta * 16.0 * sp
			p.x += sin(_time * 0.5 + ph) * delta * 6.0
			if p.y > 620.0:
				p.y = 8.0
		d["pos"] = p
		var s := 1.0
		if _theme_kind == "ember":
			s = 0.7 + 0.5 * absf(sin(_time * 3.0 + ph))
		elif _theme_kind == "void":
			s = 0.5 + 0.7 * absf(sin(_time * 1.7 + ph))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))


# ---------------------------------------------------------------- 棋子

func make_piece(team: int, style := 0) -> Node3D:
	if _pawn_mesh == null:
		_pawn_mesh = _build_pawn_mesh()
	style = clampi(style, 0, PIECE_STYLE_NAMES.size() - 1)
	var root := Node3D.new()
	root.name = "Piece"

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 47.0
	bm.bottom_radius = 49.0
	bm.height = 6.0
	bm.radial_segments = 32
	base.mesh = bm
	base.position.y = 3.0
	base.material_override = _stone_dark
	root.add_child(base)

	var ring := _add_torus(root, 38.0, 47.0, Vector3(0, 7.0, 0), _team_glow[team])
	ring.name = "Ring"

	# 接地软阴影：一圈渐变的暗斑，人物看起来是站在石板上，而不是飘在半空
	var shadow := _add_contact_shadow(root, 64.0)
	shadow.name = "ContactShadow"

	# 拟人化身体：所有部件挂在 Body 下，可独立做呼吸 / 出剑 / 受击动画
	var body := Node3D.new()
	body.name = "Body"
	# 人物比例放大一档：底座不变，身形/头盔更高大，远看也读得出是"人"
	body.scale = Vector3(1.16, 1.24, 1.16)
	root.add_child(body)

	var torso := MeshInstance3D.new()
	torso.mesh = _pawn_mesh
	torso.material_override = _team_metal[team]
	body.add_child(torso)

	var belt := _add_torus(body, 16.0, 20.0, Vector3(0, 34.0, 0), _gold)
	belt.name = "Belt"
	# 腰带扣：正面一枚小金牌，近看有做工感
	var buckle := _add_box(body, Vector3(7.0, 7.0, 3.0), Vector3(0, 34.0, 20.0), _gold)
	buckle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if style != 7:
		var crest := _add_box(body, Vector3(15.0, 20.0, 4.0), Vector3(0, 62.0, 19.0), _team_glow[team])
		crest.name = "Crest"
		crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_box(body, Vector3(7.0, 10.0, 3.0), Vector3(0, 62.0, 21.5), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# ---- 头部：按角色风格区分轮廓 ----
	if style == 7:
		# 机械兵：方形头颅 + 单眼 + 天线
		_add_box(body, Vector3(30.0, 28.0, 28.0), Vector3(0, 104.0, 0), _pbr(Color("46525f"), 0.8, 0.35))
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 4.6
		es.height = 9.2
		es.radial_segments = 10
		es.rings = 5
		eye.mesh = es
		eye.position = Vector3(0, 106.0, 15.5)
		eye.material_override = _team_glow[team]
		eye.name = "Eye"
		body.add_child(eye)
		_add_box(body, Vector3(22.0, 3.0, 3.0), Vector3(0, 94.0, 15.0), _pbr(Color("141a24"), 0.4, 0.3))
	else:
		var helmet := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 17.5
		hs.height = 30.0
		hs.radial_segments = 16
		hs.rings = 8
		helmet.mesh = hs
		helmet.material_override = _team_metal[team]
		helmet.position.y = 104.0
		body.add_child(helmet)
		_add_torus(body, 15.0, 18.5, Vector3(0, 96.0, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if style != 2 and style != 4:
			var visor := _add_box(body, Vector3(22.0, 6.0, 4.0), Vector3(0, 105.0, 14.0), _pbr(Color("141a24"), 0.4, 0.3))
			visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_box(body, Vector3(6.0, 3.0, 2.0), Vector3(0, 105.0, 17.0), _team_glow[team]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		if style == 1:
			# 法师尖顶帽 + 帽环
			_add_cyl(body, 0.0, 22.0, 44.0, Vector3(0, 130.0, 0), _pbr(team_colors[team].darkened(0.35), 0.2, 0.6), 18)
			_add_torus(body, 18.0, 23.0, Vector3(0, 112.0, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif style == 2 or style == 4:
			# 兜帽
			_add_cyl(body, 3.0, 23.0, 36.0, Vector3(0, 118.0, -1.0), _pbr(team_colors[team].darkened(0.5), 0.1, 0.8), 16)
			_add_box(body, Vector3(24.0, 8.0, 5.0), Vector3(0, 104.0, 13.5), _pbr(Color("10151c"), 0.3, 0.4))
		elif style == 3:
			# 王冠
			_add_cyl(body, 20.0, 20.0, 8.0, Vector3(0, 122.0, 0), _gold, 20)
			for k in 5:
				var a := TAU * float(k) / 5.0
				var spike := _add_box(body, Vector3(4.0, 13.0, 4.0), Vector3(cos(a) * 16.0, 130.0, sin(a) * 16.0), _gold)
				spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif style == 6:
			# 女武神双翼头盔
			for sd in [-1.0, 1.0]:
				var wing := _add_box(body, Vector3(5.0, 17.0, 26.0), Vector3(20.0 * sd, 116.0, -4.0), _gold, deg_to_rad(20.0 * sd))
				wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif style == 5:
			# 守卫重盔护颊
			for sd in [-1.0, 1.0]:
				_add_box(body, Vector3(5.0, 16.0, 14.0), Vector3(15.0 * sd, 101.0, 5.0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 肩甲（守卫更宽大）
	var pauldron_scale := 1.35 if style == 5 else 1.0
	for sd in [-1.0, 1.0]:
		var pauldron := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 11.0 * pauldron_scale
		ps.height = 20.0 * pauldron_scale
		ps.radial_segments = 12
		ps.rings = 6
		pauldron.mesh = ps
		pauldron.material_override = _gold
		pauldron.position = Vector3(22.0 * sd, 76.0, 0)
		pauldron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(pauldron)

	# ---- 头饰 / 披风 / 武器：每个角色的辨识度 ----
	var plume := Node3D.new()
	plume.name = "Plume"
	plume.position = Vector3(0, 112.0, -4.0)
	body.add_child(plume)
	var cape := Node3D.new()
	cape.name = "Cape"
	cape.position = Vector3(0, 86.0, -16.0)
	body.add_child(cape)
	var banner := Node3D.new()
	banner.name = "Banner"
	banner.position = Vector3(0, 70.0, -20.0)
	body.add_child(banner)

	match style:
		0:
			# 骑士：羽饰 + 披风 + 长剑 + 背旗
			var pc := _add_cyl(plume, 0.0, 6.0, 30.0, Vector3(0, 12.0, -4.0), _team_glow[team], 6)
			pc.rotation.x = -0.35
			pc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_cape_sheet(cape, team, 33.0, 54.0)
			var sword := Node3D.new()
			sword.position = Vector3(27.0, 56.0, 6.0)
			sword.rotation.z = -0.22
			body.add_child(sword)
			_add_box(sword, Vector3(4.0, 42.0, 9.0), Vector3.ZERO, _pbr(Color("dfe8f6"), 0.7, 0.28))
			_add_box(sword, Vector3(12.0, 4.0, 6.0), Vector3(0, -21.0, 0), _gold)
			_add_box(sword, Vector3(4.0, 12.0, 5.0), Vector3(0, -29.0, 0), _pbr(Color("4a2f1c"), 0.1, 0.7))
			_add_banner(banner, team)
		1:
			# 法师：长袍 + 法杖 + 绕体符文环
			var robe := _add_cyl(body, 26.0, 36.0, 46.0, Vector3(0, 16.0, 0), _pbr(team_colors[team].darkened(0.3), 0.2, 0.55), 18)
			robe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var staff := Node3D.new()
			staff.position = Vector3(28.0, 52.0, 8.0)
			staff.rotation.z = -0.12
			body.add_child(staff)
			_add_cyl(staff, 1.8, 1.8, 66.0, Vector3.ZERO, _pbr(Color("5a3c22"), 0.1, 0.7), 6)
			var orb := MeshInstance3D.new()
			var os := SphereMesh.new()
			os.radius = 6.2
			os.height = 12.4
			os.radial_segments = 12
			os.rings = 6
			orb.mesh = os
			orb.position = Vector3(0, 36.0, 0)
			orb.material_override = _unshaded(team_colors[team].lightened(0.25), 2.6)
			staff.add_child(orb)
			var rune := _add_torus(plume, 17.0, 20.0, Vector3(0, -4.0, 0), _unshaded(team_colors[team].lightened(0.3), 2.0))
			rune.rotation.x = deg_to_rad(78.0)
			rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_cape_sheet(cape, team, 30.0, 50.0)
		2:
			# 弓手：兜帽羽翎 + 长弓 + 箭袋
			var feather := _add_cyl(plume, 0.0, 4.0, 34.0, Vector3(0, 10.0, -6.0), _team_glow[team], 6)
			feather.rotation.x = -0.6
			_add_cape_sheet(cape, team, 28.0, 44.0)
			var bow := Node3D.new()
			bow.position = Vector3(-27.0, 60.0, 4.0)
			bow.rotation.z = 0.18
			body.add_child(bow)
			_add_box(bow, Vector3(3.0, 20.0, 4.0), Vector3(0, 14.0, 0), _pbr(Color("6a4a2a"), 0.2, 0.6), deg_to_rad(16.0))
			_add_box(bow, Vector3(3.0, 20.0, 4.0), Vector3(0, -14.0, 0), _pbr(Color("6a4a2a"), 0.2, 0.6), deg_to_rad(-16.0))
			_add_box(bow, Vector3(1.4, 46.0, 1.4), Vector3(-5.0, 0, 0), _pbr(Color("d8e2f0"), 0.6, 0.3))
			var quiver := _add_cyl(body, 8.0, 7.0, 30.0, Vector3(16.0, 76.0, -18.0), _pbr(Color("4a2f1c"), 0.1, 0.7), 10)
			quiver.rotation.x = -0.3
			for k in 3:
				_add_box(body, Vector3(1.4, 18.0, 1.4), Vector3(14.0 + k * 2.4, 92.0, -20.0), _gold)
		3:
			# 国王：披风 + 权杖 + 背旗
			var scepter := Node3D.new()
			scepter.position = Vector3(28.0, 54.0, 6.0)
			scepter.rotation.z = -0.16
			body.add_child(scepter)
			_add_cyl(scepter, 2.2, 2.2, 54.0, Vector3.ZERO, _gold, 8)
			var jewel := MeshInstance3D.new()
			var js := SphereMesh.new()
			js.radius = 7.0
			js.height = 14.0
			js.radial_segments = 8
			js.rings = 4
			jewel.mesh = js
			jewel.position = Vector3(0, 30.0, 0)
			jewel.material_override = _unshaded(team_colors[team].lightened(0.35), 2.4)
			scepter.add_child(jewel)
			_add_cape_sheet(cape, team, 42.0, 66.0)
			_add_banner(banner, team)
		4:
			# 刺客：面巾 + 双匕首 + 短披风
			_add_box(body, Vector3(24.0, 10.0, 24.0), Vector3(0, 100.0, 0), _pbr(Color("20262f"), 0.4, 0.5))
			_add_box(body, Vector3(12.0, 4.0, 3.0), Vector3(0, 103.0, 14.0), _team_glow[team])
			_add_cape_sheet(cape, team, 24.0, 38.0)
			for sd in [-1.0, 1.0]:
				var dagger := Node3D.new()
				dagger.position = Vector3(27.0 * sd, 54.0, 8.0)
				dagger.rotation.z = 0.5 * sd
				body.add_child(dagger)
				_add_box(dagger, Vector3(3.0, 26.0, 6.0), Vector3(0, 4.0, 0), _pbr(Color("e2ecf8"), 0.8, 0.25))
				_add_box(dagger, Vector3(9.0, 3.0, 5.0), Vector3(0, -10.0, 0), _gold)
		5:
			# 守卫：塔盾 + 战锤
			var shield := _add_box(body, Vector3(8.0, 64.0, 40.0), Vector3(-30.0, 58.0, 8.0), _team_metal[team])
			shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_box(body, Vector3(11.0, 12.0, 30.0), Vector3(-30.0, 58.0, 8.0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var hammer := Node3D.new()
			hammer.position = Vector3(30.0, 58.0, 4.0)
			hammer.rotation.z = -0.2
			body.add_child(hammer)
			_add_cyl(hammer, 2.4, 2.4, 54.0, Vector3.ZERO, _pbr(Color("4a2f1c"), 0.1, 0.7), 8)
			_add_box(hammer, Vector3(18.0, 14.0, 14.0), Vector3(0, 30.0, 0), _team_metal[team])
			_add_cape_sheet(cape, team, 30.0, 42.0)
		6:
			# 女武神：长枪 + 披风 + 翼羽
			var spear := Node3D.new()
			spear.position = Vector3(28.0, 58.0, 8.0)
			spear.rotation.z = -0.1
			body.add_child(spear)
			_add_cyl(spear, 1.8, 1.8, 96.0, Vector3.ZERO, _pbr(Color("e8eef8"), 0.7, 0.3), 8)
			var tip := _add_cyl(spear, 0.0, 5.0, 20.0, Vector3(0, 54.0, 0), _gold, 4)
			tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_cape_sheet(cape, team, 34.0, 58.0)
			var wing := _add_box(plume, Vector3(4.0, 26.0, 10.0), Vector3(0, 12.0, -2.0), _team_glow[team])
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		7:
			# 机械兵：天线 + 活塞臂 + 无披风
			_add_cyl(plume, 1.4, 2.2, 22.0, Vector3(0, 6.0, 0), _pbr(Color("8a97a6"), 0.8, 0.3), 6)
			var beacon := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 4.2
			bs.height = 8.4
			bs.radial_segments = 8
			bs.rings = 4
			beacon.mesh = bs
			beacon.position = Vector3(0, 18.0, 0)
			beacon.material_override = _unshaded(team_colors[team].lightened(0.3), 2.8)
			plume.add_child(beacon)
			for sd in [-1.0, 1.0]:
				_add_cyl(body, 6.0, 7.0, 30.0, Vector3(27.0 * sd, 52.0, 0), _pbr(Color("5b6672"), 0.7, 0.35), 10)
				_add_box(body, Vector3(12.0, 12.0, 12.0), Vector3(27.0 * sd, 34.0, 0), _team_metal[team])

	# 头顶阵营信标
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.0
	sm.height = 8.0
	sm.radial_segments = 4
	sm.rings = 2
	gem.mesh = sm
	gem.position.y = 152.0 if style == 7 else 146.0
	gem.material_override = _team_glow[team]
	gem.name = "Gem"
	body.add_child(gem)

	# 绕体灵光：给每个棋子一点持续的微动态，站着也不死板
	var orbit := MeshInstance3D.new()
	var os2 := SphereMesh.new()
	os2.radius = 2.6
	os2.height = 5.2
	os2.radial_segments = 6
	os2.rings = 3
	orbit.mesh = os2
	orbit.material_override = _unshaded(team_colors[team].lightened(0.35), 2.0)
	orbit.name = "Orbit"
	body.add_child(orbit)

	# 棋子随棋盘一起缩放：28 格时棋子更小、52 格时更大，与格子比例保持一致
	_actors.append({
		"root": root, "body": body, "cape": cape, "plume": plume, "banner": banner,
		"gem": gem, "orbit": orbit,
		"phase": randf() * TAU, "style": style,
	})
	return root


func _add_cape_sheet(cape: Node3D, team: int, w: float, h: float) -> void:
	var cape_mat := _pbr(team_colors[team].darkened(0.45), 0.08, 0.7)
	var sheet := _add_box(cape, Vector3(w, h, 3.0), Vector3(0, -h * 0.5, 0), cape_mat)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.rotation.x = 0.12


func _add_banner(banner: Node3D, team: int) -> void:
	var pole := _add_cyl(banner, 1.6, 1.6, 62.0, Vector3(0, 14.0, 0), _gold, 6)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flag := _add_box(banner, Vector3(1.6, 18.0, 24.0), Vector3(0, 34.0, 11.0), _team_glow[team])
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _actor_of(node: Node) -> Dictionary:
	for a in _actors:
		if a["root"] == node:
			return a
	return {}


## 出剑：向行进方向短促前倾
func piece_lunge(node: Node3D) -> void:
	if node == null:
		return
	var a := _actor_of(node)
	if a.is_empty():
		return
	var body: Node3D = a["body"]
	var t := create_tween()
	t.tween_property(body, "position:z", 12.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position:z", 0.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 受击：左右晃动
func piece_hit(node: Node3D) -> void:
	if node == null:
		return
	var a := _actor_of(node)
	if a.is_empty():
		return
	var body: Node3D = a["body"]
	var t := create_tween()
	t.tween_property(body, "rotation:y", 0.34, 0.07)
	t.tween_property(body, "rotation:y", -0.30, 0.09)
	t.tween_property(body, "rotation:y", 0.20, 0.09)
	t.tween_property(body, "rotation:y", 0.0, 0.12)


## 播放合成音效：sfx 由 Main 注入，缺失时静默跳过
func fx_sound(kind: String, vol_db := 0.0, pitch := 1.0) -> void:
	if sfx == null or not is_instance_valid(sfx):
		return
	if not sfx.has_method("play"):
		return
	sfx.play(kind, vol_db, pitch)


## 道具命中瞬间：棋子本体按道具类型弹出不同力道，避免所有道具一个手感
func _cast_pop(node: Node3D, kind: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var t := create_tween()
	if kind in ["boost", "double", "warp", "teleport", "moonstep", "inferno", "gale"]:
		# 向上类：先拔高拉长，再回弹
		t.tween_property(node, "scale", Vector3(0.86, 1.24, 0.86), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif kind in ["shield", "jadeguard", "freeze", "frostlock"]:
		# 防护类：向外撑开压扁，像罩上护罩
		t.tween_property(node, "scale", Vector3(1.24, 0.84, 1.24), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif kind in ["snipe", "swap", "steal", "bomb", "vortex", "voidstep"]:
		# 攻击类：两下急促抖动
		t.tween_property(node, "scale", Vector3(1.16, 1.16, 1.16), 0.06)
		t.tween_property(node, "scale", Vector3(0.92, 0.92, 0.92), 0.07)
	else:
		t.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
	t.tween_property(node, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 胜利 / 吃到棋子：原地旋转 + 弹跳
func piece_celebrate(node: Node3D) -> void:
	if node == null:
		return
	var a := _actor_of(node)
	if a.is_empty():
		return
	var body: Node3D = a["body"]
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(body, "rotation:y", body.rotation.y + TAU, 0.7).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(body, "scale", Vector3(1.15, 1.15, 1.15), 0.18)
	t.chain().tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)


## 吃棋：蓄力 → 跃起 → 滞空 → 砸落 → 踩扁 → 溅开 → 收势（七阶段，tween 合计约 1.72s）
func capture_stomp(attacker: Node3D, victim: Node3D, color: Color) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var a := _actor_of(attacker)
	var body: Node3D = a.get("body", null) if not a.is_empty() else null
	var has_victim := victim != null and is_instance_valid(victim)
	var start := attacker.position
	var vpos := start
	if has_victim:
		vpos = victim.position
	var flat := Vector2(vpos.x - start.x, vpos.z - start.z)
	if flat.length() > 1.0:
		attacker.rotation.y = atan2(vpos.x - start.x, vpos.z - start.z)
	# 受害者身体：能从 _actor_of 取到就抖身体，取不到就抖根节点
	var vbody: Node3D = null
	if has_victim:
		var va := _actor_of(victim)
		if not va.is_empty():
			vbody = va["body"]
	var vshake: Node3D = vbody if vbody != null else victim
	# 1. 蓄力 0.20s：攻击方下蹲，目标方原地发抖
	if has_victim and is_instance_valid(vshake):
		var tremble := create_tween()
		tremble.tween_property(vshake, "rotation:y", 0.16, 0.05)
		tremble.tween_property(vshake, "rotation:y", -0.14, 0.06)
		tremble.tween_property(vshake, "rotation:y", 0.10, 0.05)
		tremble.tween_property(vshake, "rotation:y", 0.0, 0.04)
	if body != null:
		var crouch := create_tween()
		crouch.set_parallel(true)
		crouch.tween_property(body, "position:y", -11.0, 0.20).set_trans(Tween.TRANS_QUAD)
		crouch.tween_property(body, "scale", Vector3(1.14, 0.84, 1.14), 0.20)
		await crouch.finished
	else:
		await get_tree().create_timer(0.20).timeout
	# 2. 跃起 0.36s：沿抛物线飞到目标正上方，身体拉长并自旋半圈
	fx_sound("cap_jump")
	var apex := Vector3(vpos.x, start.y + 200.0, vpos.z)
	var jump := create_tween()
	jump.set_parallel(true)
	jump.tween_property(attacker, "position", apex, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(attacker, "rotation:y", attacker.rotation.y + PI, 0.36)
	if body != null:
		jump.tween_property(body, "position:y", 0.0, 0.20)
		jump.tween_property(body, "scale", Vector3(0.92, 1.18, 0.92), 0.20)
	await jump.finished
	# 3. 滞空 0.10s：顶点悬停不动，给“跃起”留辨识时间
	var hover := create_tween()
	hover.tween_interval(0.10)
	await hover.finished
	# 4. 砸落 0.16s：QUART 加速直坠，身体压扁
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(attacker, "position", vpos, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if body != null:
		fall.tween_property(body, "scale", Vector3(1.24, 0.80, 1.24), 0.16)
	await fall.finished
	fx_sound("cap_slam")
	impact(Vector3(vpos.x, TILE_TOP, vpos.z), color)
	# 5. 踩扁 0.10s：目标瞬间压成一张薄片
	fx_sound("cap_squash")
	var squash := create_tween()
	squash.set_parallel(true)
	squash.tween_interval(0.10)
	if has_victim and is_instance_valid(victim):
		squash.tween_property(victim, "scale", Vector3(1.55, 0.06, 1.55), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		squash.tween_property(victim, "rotation", Vector3.ZERO, 0.10)
	await squash.finished
	# 6. 溅开 0.55s：一滩 + 两圈错开冲击波 + 碎屑 + 中心闪光（主流程等 0.50s 后收势）
	puddle(vpos, color)
	_shockwave(vpos, color, 0.0, 3.2, 0.55)
	_shockwave(vpos, color.lightened(0.25), 0.06, 4.6, 0.55)
	_fx_shards(Vector3(vpos.x, TILE_TOP + 2.0, vpos.z), color.lightened(0.2), 10, 70.0, 90.0, 6.0, 0.55)
	capture_blast(vpos, color)
	var splash := create_tween()
	splash.tween_interval(0.50)
	await splash.finished
	# 7. 收势 0.30s：恢复站姿 + 胜利小跳
	fx_sound("cap_win", -2.0)
	if body != null:
		var rise := create_tween()
		rise.set_parallel(true)
		rise.tween_property(body, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(body, "position:y", 0.0, 0.16)
		await rise.finished
	var hop := create_tween()
	hop.tween_property(attacker, "position:y", vpos.y + 12.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(attacker, "position:y", vpos.y, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hop.finished
	piece_celebrate(attacker)
	# 收尾：清掉受害者的薄片残留（位置与可见性由 Main 负责复位到基地）
	if has_victim and is_instance_valid(victim):
		victim.scale = Vector3.ONE
		victim.rotation = Vector3.ZERO


# ---------------------------------------------------------------- 道具演出原语
# 全部围绕“施法动作 → 传递 → 受击反应 → 结果”四段设计：
# 棋子本体真的抬手/后仰/前压/滑退/翻滚，粒子只做辅助。

## 演出期间接管拟人待机动画：锁定后 _process 不再覆盖身体姿态，避免 tween 被待机摆动抵消
func _anim_begin(node: Node3D) -> Dictionary:
	var a := _actor_of(node)
	if not a.is_empty():
		a["anim"] = int(a.get("anim", 0)) + 1
	return a


func _anim_end(a: Dictionary, body: Node3D) -> void:
	if body != null and is_instance_valid(body):
		body.position.z = 0.0
		body.rotation = Vector3.ZERO
	if not a.is_empty():
		a["anim"] = maxi(int(a.get("anim", 1)) - 1, 0)


## 蓄力：重心后坐 + 身体后仰 + 脚下符文环 + 少量能量粒子
func anim_windup(node: Node3D, color: Color, dur := 0.25) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var g := Vector3(node.position.x, TILE_TOP, node.position.z)
	var s0 := node.scale
	event_ring(g, color)
	_fx_shards(g + Vector3(0, 2.0, 0), color, 5, 26.0, 52.0, 3.4, 0.42)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector3(s0.x * 0.97, s0.y * 1.03, s0.z * 0.97), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if body != null:
		t.tween_property(body, "position:z", -8.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(body, "rotation:x", -0.18, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	if is_instance_valid(node):
		node.scale = s0
	_anim_end(a, body)


## 释放：上身猛前压 + 脚下炸开冲击波
func anim_release(node: Node3D, color: Color, dur := 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var g := Vector3(node.position.x, TILE_TOP, node.position.z)
	var s0 := node.scale
	_shockwave(g, color, 0.0, 2.5, 0.42)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector3(s0.x * 1.06, s0.y * 0.95, s0.z * 1.06), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if body != null:
		t.tween_property(body, "position:z", 10.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(body, "rotation:x", 0.22, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	if is_instance_valid(node):
		node.scale = s0
	_anim_end(a, body)


## 受击：先压扁 15%，再沿 dir 水平滑出并倾斜，最后回正
func piece_recoil(node: Node3D, dir: Vector3, power := 1.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var start := node.position
	var s0 := node.scale
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		d = Vector3.BACK
	d = d.normalized()
	var squash := create_tween()
	squash.set_parallel(true)
	squash.tween_property(node, "scale", Vector3(s0.x * 1.15, s0.y * 0.85, s0.z * 1.15), 0.08)
	if body != null:
		squash.tween_property(body, "rotation:x", 0.2, 0.08)
	await squash.finished
	var slide := create_tween()
	slide.set_parallel(true)
	slide.tween_property(node, "position", start + d * 20.0 * power, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_property(node, "rotation:z", 0.16 * power, 0.14)
	if body != null:
		slide.tween_property(body, "rotation:x", -0.12, 0.14)
	await slide.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(node, "position", start, 0.08).set_trans(Tween.TRANS_SINE)
	settle.tween_property(node, "scale", s0, 0.08)
	settle.tween_property(node, "rotation:z", 0.0, 0.08)
	if body != null:
		settle.tween_property(body, "rotation:x", 0.0, 0.08)
	await settle.finished
	_anim_end(a, body)


## 整枚棋子翻滚沿抛物线飞出，落地弹跳一次并扬起灰尘
func piece_launch(node: Node3D, to: Vector3, height := 120.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var start := node.position
	var ctrl := (start + to) * 0.5 + Vector3(0, height, 0)
	var r0 := node.rotation
	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(_launch_step.bind(node, start, ctrl, to), 0.0, 1.0, 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "rotation:x", r0.x + TAU, 0.58)
	if body != null:
		t.tween_property(body, "scale", Vector3(0.9, 1.12, 0.9), 0.22)
	await t.finished
	if not is_instance_valid(node):
		return
	node.rotation = r0
	if body != null and is_instance_valid(body):
		body.scale = Vector3.ONE
	_fx_shards(Vector3(to.x, TILE_TOP + 2.0, to.z), Color("d8cdb8"), 8, 44.0, 30.0, 4.0, 0.4)
	var bounce := create_tween()
	bounce.tween_property(node, "position:y", to.y + 16.0, 0.08)
	bounce.tween_property(node, "position:y", to.y, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await bounce.finished
	_anim_end(a, body)


func _launch_step(v: float, node: Node3D, p0: Vector3, ctrl: Vector3, p1: Vector3) -> void:
	if is_instance_valid(node):
		node.position = _swap_arc_point(v, p0, ctrl, p1)


## 碎裂：24 个小方块从身体位置散开收缩，棋子本体积同步缩到一点
func piece_dissolve(node: Node3D, color := Color("c8b8ff")) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var s0 := node.scale
	node.set_meta("fx_scale", s0)
	var yaw0 := node.rotation.y
	node.set_meta("fx_yaw", yaw0)
	var g := Vector3(node.position.x, node.position.y + 56.0, node.position.z)
	for i in 24:
		var bm := BoxMesh.new()
		var sz := randf_range(4.0, 9.0)
		bm.size = Vector3(sz, sz, sz)
		var mi := _fx_mesh(bm, g + Vector3(randf_range(-26.0, 26.0), randf_range(-40.0, 40.0), randf_range(-26.0, 26.0)), color, 2.4)
		var a2 := TAU * randf()
		var end := g + Vector3(cos(a2) * randf_range(40.0, 96.0), randf_range(-50.0, 70.0), sin(a2) * randf_range(40.0, 96.0))
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", end, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), 0.34)
		t.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.34)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.34)
		t.chain().tween_callback(mi.queue_free)
	var shrink := create_tween()
	shrink.set_parallel(true)
	shrink.tween_property(node, "scale", Vector3.ONE * 0.02, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink.tween_property(node, "rotation:y", yaw0 + TAU * 0.5, 0.35)
	await shrink.finished
	_anim_end(a, body)


## 重组：24 个小方块从四周合拢，棋子本体从一点放大回原尺寸
func piece_reassemble(node: Node3D, color := Color("c8b8ff")) -> void:
	if node == null or not is_instance_valid(node):
		return
	var a := _anim_begin(node)
	var body: Node3D = a.get("body", null)
	var s0: Vector3 = node.get_meta("fx_scale", Vector3.ONE)
	var yaw0: float = node.get_meta("fx_yaw", node.rotation.y)
	var g := Vector3(node.position.x, node.position.y + 56.0, node.position.z)
	for i in 24:
		var bm := BoxMesh.new()
		var sz := randf_range(4.0, 9.0)
		bm.size = Vector3(sz, sz, sz)
		var a2 := TAU * float(i) / 24.0 + randf() * 0.3
		var start := g + Vector3(cos(a2) * randf_range(60.0, 110.0), randf_range(-60.0, 90.0), sin(a2) * randf_range(60.0, 110.0))
		var mi := _fx_mesh(bm, start, color, 2.8)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", g, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(mi, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), 0.35)
		t.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.35)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.35)
		t.chain().tween_callback(mi.queue_free)
	var grow := create_tween()
	grow.set_parallel(true)
	grow.tween_property(node, "scale", s0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(node, "rotation:y", yaw0, 0.35)
	await grow.finished
	_anim_end(a, body)
	if is_instance_valid(node):
		event_ring(Vector3(node.position.x, TILE_TOP, node.position.z), color)


## 发光球沿浅弧线飞行，到达终点即“命中帧”；尾迹可以是火花或烟
func orb_fly(from: Vector3, to: Vector3, color: Color, trail := "spark", dur := 0.35) -> void:
	var ctrl := (from + to) * 0.5 + Vector3(0, maxf(from.distance_to(to) * 0.18, 46.0), 0)
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 18.0
	sm.radial_segments = 10
	sm.rings = 6
	var mi := _fx_mesh(sm, from, color, 4.0)
	var t := create_tween()
	t.tween_method(_orb_step.bind(mi, from, ctrl, to), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for k in 5:
		var at := dur * float(k) / 5.0
		var pt := _swap_arc_point(float(k) / 5.0, from, ctrl, to)
		var tt := create_tween()
		tt.tween_interval(at)
		tt.tween_callback(_spawn_trail_dot.bind(pt, color, trail))
	await t.finished
	_fx_shards(to, color, 4, 26.0, 36.0, 3.4, 0.3)
	if is_instance_valid(mi):
		mi.queue_free()


func _orb_step(v: float, mi: Node3D, p0: Vector3, ctrl: Vector3, p1: Vector3) -> void:
	if is_instance_valid(mi):
		mi.position = _swap_arc_point(v, p0, ctrl, p1)


func _spawn_trail_dot(pos: Vector3, color: Color, trail: String) -> void:
	var sm := SphereMesh.new()
	sm.radius = 6.5
	sm.height = 13.0
	sm.radial_segments = 6
	sm.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	if trail == "smoke":
		mi.material_override = _unshaded(Color(0.14, 0.12, 0.13), 0.2)
		(mi.material_override as StandardMaterial3D).albedo_color = Color(0.16, 0.14, 0.15, 0.5)
	else:
		mi.material_override = _unshaded(color, 2.6)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * (2.0 if trail == "smoke" else 0.2), 0.4)
	t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.4)
	t.chain().tween_callback(mi.queue_free)


## 命中特效：ice 冰晶+冰雾 / fire 火柱+焦痕 / hit 闪光+碎屑 / gravity 下压环
func impact_kind(kind: String, pos: Vector3, color: Color) -> void:
	var g := Vector3(pos.x, TILE_TOP + 2.0, pos.z)
	match kind:
		"ice":
			_fx_spikes(g, color.lightened(0.3), 8, 30.0, 54.0)
			for i in 6:
				var sm := SphereMesh.new()
				sm.radius = 18.0
				sm.height = 36.0
				sm.radial_segments = 8
				sm.rings = 5
				var a := TAU * float(i) / 6.0
				var mi := _fx_mesh(sm, g + Vector3(cos(a) * 30.0, 18.0, sin(a) * 30.0), Color("cfeaff"), 1.0)
				(mi.material_override as StandardMaterial3D).albedo_color = Color(0.82, 0.94, 1.0, 0.28)
				var t := create_tween()
				t.set_parallel(true)
				t.tween_property(mi, "position", g + Vector3(cos(a) * 74.0, 44.0, sin(a) * 74.0), 0.6)
				t.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.6)
				t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.6)
				t.chain().tween_callback(mi.queue_free)
			_shockwave(g, color, 0.0, 3.0, 0.5)
		"fire":
			var cm := CylinderMesh.new()
			cm.top_radius = 8.0
			cm.bottom_radius = 26.0
			cm.height = 150.0
			cm.radial_segments = 12
			var col := _fx_mesh(cm, g + Vector3(0, 20.0, 0), color, 3.0)
			col.scale = Vector3(0.3, 0.08, 0.3)
			var t := create_tween()
			t.set_parallel(true)
			t.tween_property(col, "scale", Vector3(1.0, 1.5, 1.0), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(col.material_override, "albedo_color:a", 0.0, 0.36).set_delay(0.28)
			t.chain().tween_callback(col.queue_free)
			_fx_fire_puffs(g, color, 6)
			_fx_shards(g, color.lightened(0.2), 10, 82.0, 120.0, 5.0, 0.5)
			decal_scorch(Vector3(pos.x, 0.0, pos.z))
		"gravity":
			var ring := _glow_ring(color, 36.0, 48.0)
			ring.position = Vector3(g.x, TILE_TOP + 190.0, g.z)
			ring.rotation.x = PI * 0.5
			ring.scale = Vector3(1.4, 1.4, 1.4)
			var t := create_tween()
			t.set_parallel(true)
			t.tween_property(ring, "position:y", TILE_TOP + 4.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.28)
			t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.16)
			t.chain().tween_callback(ring.queue_free)
			_fx_shards(g, color.darkened(0.15), 8, 52.0, 26.0, 5.0, 0.42)
		_:
			impact(pos, color)
			_fx_shards(g, color, 10, 68.0, 82.0, 5.0, 0.42)


## 施法者手心连向目标的一条逐渐绷直的细光束，结束后自动淡出释放
func tether(from: Node3D, to: Node3D, color: Color, dur := 0.4) -> void:
	if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
		return
	var a := from.position + Vector3(0, 68.0, 0)
	var b := to.position + Vector3(0, 58.0, 0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.2
	cm.bottom_radius = 3.2
	cm.height = maxf(a.distance_to(b), 1.0)
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _unshaded(color, 3.4)
	mi.position = (a + b) * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	mi.look_at(b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	mi.scale = Vector3(1.0, 0.05, 1.0)
	var t := create_tween()
	t.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), dur * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(dur * 0.25, 0.05))
	t.tween_property(mi.material_override, "albedo_color:a", 0.0, dur * 0.4)
	t.tween_callback(_free_if_valid.bind(mi))
	await get_tree().create_timer(dur * 0.8).timeout


## 护体：光环从脚底升起收束，随后留一层持续可见的同色边缘光
func aura_bind(node: Node3D, color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	var g := Vector3(node.position.x, TILE_TOP + 2.0, node.position.z)
	for k in 2:
		var ring := _glow_ring(color, 34.0 + float(k) * 10.0, 42.0 + float(k) * 10.0)
		ring.position = g + Vector3(0, 4.0, 0)
		ring.scale = Vector3(1.25, 1.0, 1.25)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "position:y", g.y + 108.0, 0.34).set_delay(0.06 * float(k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "scale", Vector3(0.35, 1.0, 0.35), 0.34).set_delay(0.06 * float(k))
		t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.12 + 0.06 * float(k))
		t.chain().tween_callback(ring.queue_free)
	if node.has_node("AuraBind"):
		(node.get_node("AuraBind") as Node3D).queue_free()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 62.0
	sm.height = 124.0
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.13)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position.y = 56.0
	mi.name = "AuraBind"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	await get_tree().create_timer(0.36).timeout


func aura_unbind(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n := node.get_node_or_null("AuraBind")
	if n:
		n.queue_free()


## 卡牌：一张扁平小方块旋转着沿弧线飞回
func card_arc(from: Vector3, to: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(26.0, 2.0, 34.0)
	var mi := _fx_mesh(bm, from, Color("ffd98a"), 2.6)
	var ctrl := (from + to) * 0.5 + Vector3(0, maxf(from.distance_to(to) * 0.16, 70.0), 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(_launch_step.bind(mi, from, ctrl, to), 0.0, 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(mi, "rotation", Vector3(TAU * 1.5, TAU, TAU * 0.5), 0.5)
	await t.finished
	if is_instance_valid(mi):
		var f := create_tween()
		f.set_parallel(true)
		f.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.2)
		f.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.2)
		f.chain().tween_callback(mi.queue_free)
		await f.finished


## 地面焦痕：深色扁圆贴片，6 秒内淡出
func decal_scorch(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.06, 0.045, 0.04, 0.72)
	var root := Node3D.new()
	root.name = "Scorch"
	root.position = Vector3(pos.x, TILE_TOP + 0.5, pos.z)
	root.scale = Vector3(0.6, 1.0, 0.6)
	_fx.add_child(root)
	var disc := _add_cyl(root, 44.0, 44.0, 0.6, Vector3.ZERO, mat, 24)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := create_tween()
	t.tween_property(root, "scale", Vector3(1.0, 1.0, 1.0), 0.25)
	t.tween_interval(5.2)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	t.tween_callback(_free_if_valid.bind(root))


func _free_if_valid(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()


## 施法者头顶升起一个该道具色的小立方，放大 0.25s 后朝 dir 方向飞走
func item_glyph(node: Node3D, item_id: String, color: Color, dir := Vector3.ZERO) -> void:
	if node == null or not is_instance_valid(node):
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(18.0, 18.0, 5.0) if item_id in ["double", "shield"] else Vector3(16.0, 16.0, 16.0)
	var mi := _fx_mesh(bm, node.position + Vector3(0, 148.0, 0), color, 3.0)
	mi.scale = Vector3.ONE * 0.2
	var fly := Vector3(dir.x, 0.0, dir.z)
	if fly.length() < 0.001:
		fly = Vector3(sin(node.rotation.y), 0.0, cos(node.rotation.y))
	fly = fly.normalized()
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(mi, "rotation", Vector3(0.3, 1.2, 0.2), 0.25)
	await rise.finished
	if not is_instance_valid(mi):
		return
	var go := create_tween()
	go.set_parallel(true)
	go.tween_property(mi, "position", mi.position + fly * 150.0 + Vector3(0, 26.0, 0), 0.34)
	go.tween_property(mi, "scale", Vector3.ONE * 0.15, 0.34)
	go.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.34)
	go.chain().tween_callback(mi.queue_free)


## 速度线：3 条细长光条从身后掠过（boost / steal 的手影复用）
func speed_lines(node: Node3D, color: Color, count := 3, dur := 0.35, dir := Vector3.ZERO) -> void:
	if node == null or not is_instance_valid(node):
		return
	var forward := Vector3(dir.x, 0.0, dir.z)
	if forward.length() < 0.001:
		forward = Vector3(sin(node.rotation.y), 0.0, cos(node.rotation.y))
	forward = forward.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	for i in count:
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 3.0, 58.0)
		var off := side * (float(i) - float(count - 1) * 0.5) * 26.0
		var mi := _fx_mesh(bm, node.position + off - forward * 130.0 + Vector3(0, 26.0 + float(i) * 22.0, 0), color, 3.2)
		mi.rotation.y = atan2(forward.x, forward.z)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", mi.position + forward * 300.0, dur).set_delay(0.04 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.8), dur).set_delay(0.04 * float(i))
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, dur).set_delay(0.04 * float(i))
		t.chain().tween_callback(mi.queue_free)
	await get_tree().create_timer(dur + 0.08).timeout


## 护盾拼装：12 块小方块从四周飞来，在身体周围扣合成罩
func shield_build(node: Node3D, color: Color, count := 12, dur := 0.35) -> void:
	if node == null or not is_instance_valid(node):
		return
	var g := Vector3(node.position.x, node.position.y + 56.0, node.position.z)
	for i in count:
		var a := TAU * float(i) / float(count)
		var bm := BoxMesh.new()
		bm.size = Vector3(12.0, 12.0, 5.0)
		var mi := _fx_mesh(bm, g + Vector3(cos(a) * 120.0, randf_range(-40.0, 90.0), sin(a) * 120.0), color, 2.6)
		var home := g + Vector3(cos(a) * 52.0, randf_range(-26.0, 62.0), sin(a) * 52.0)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", home, dur).set_delay(0.02 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "rotation", Vector3(0.6, a, 0.3), dur)
		t.chain().tween_property(mi.material_override, "albedo_color:a", 0.0, 0.12)
		t.chain().tween_callback(mi.queue_free)
	await get_tree().create_timer(dur + 0.12).timeout
	_shockwave(Vector3(node.position.x, TILE_TOP, node.position.z), color, 0.0, 2.6, 0.45)


## 冰壳：半透明冰层从脚往上爬到头顶，短暂停留后淡出
func ice_shell(node: Node3D, color: Color, dur := 0.5) -> void:
	if node == null or not is_instance_valid(node):
		return
	# 冰封期间冻结拟人待机，制造“停住”的受击反应
	var aa := _anim_begin(node)
	var abody: Node3D = aa.get("body", null)
	var root := Node3D.new()
	root.name = "IceShell"
	root.position = node.position + Vector3(0, 2.0, 0)
	_fx.add_child(root)
	var cm := CylinderMesh.new()
	cm.top_radius = 34.0
	cm.bottom_radius = 46.0
	cm.height = 118.0
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.30)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position.y = 59.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.scale = Vector3(1.0, 0.03, 1.0)
	var t := create_tween()
	t.tween_property(root, "scale", Vector3(1.0, 1.0, 1.0), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var spire := MeshInstance3D.new()
		var scm := CylinderMesh.new()
		scm.top_radius = 0.0
		scm.bottom_radius = 7.0
		scm.height = 34.0
		scm.radial_segments = 5
		spire.mesh = scm
		spire.material_override = _unshaded(color.lightened(0.25), 2.2)
		spire.position = Vector3(cos(a) * 42.0, 12.0, sin(a) * 42.0)
		root.add_child(spire)
	await t.finished
	impact_kind("ice", node.position, color)
	await get_tree().create_timer(0.85 * dur + 0.25).timeout
	_anim_end(aa, abody)
	if is_instance_valid(root):
		var f := create_tween()
		f.set_parallel(true)
		f.tween_property(mat, "albedo_color:a", 0.0, 0.35)
		for ch in root.get_children():
			if ch is MeshInstance3D and ch != mi:
				f.tween_property(ch.material_override, "albedo_color:a", 0.0, 0.35)
		f.chain().tween_callback(root.queue_free)


## 锁定环：目标头顶红色锁定圈收缩闪一下
func lock_on(node: Node3D, color: Color, dur := 0.2) -> void:
	if node == null or not is_instance_valid(node):
		return
	var ring := _glow_ring(color, 30.0, 38.0)
	ring.position = Vector3(node.position.x, node.position.y + 150.0, node.position.z)
	ring.rotation.x = PI * 0.5
	ring.scale = Vector3(2.0, 2.0, 2.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(0.45, 0.45, 0.45), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, dur).set_delay(0.08)
	t.chain().tween_callback(ring.queue_free)
	await get_tree().create_timer(dur).timeout


## 旋风：3 个旋转薄环绕身旋转
func wind_rings(node: Node3D, color: Color, count := 3, dur := 0.45) -> void:
	if node == null or not is_instance_valid(node):
		return
	for i in count:
		var ring := _glow_ring(color, 30.0, 38.0)
		ring.position = Vector3(node.position.x, node.position.y + 34.0 + float(i) * 30.0, node.position.z)
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3(0.4, 0.4, 0.4)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector3(1.5, 1.5, 1.5), dur * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "rotation:y", 9.0 + float(i) * 2.0, dur)
		t.chain().tween_property(ring.material_override, "albedo_color:a", 0.0, dur * 0.4)
		t.chain().tween_callback(ring.queue_free)
	await get_tree().create_timer(dur).timeout


## 虚空裂纹：地面裂开黑紫裂隙并向下拉拽
func void_crack(pos: Vector3, color: Color) -> void:
	impact_kind("gravity", pos, color)
	_fx_rift(Vector3(pos.x, TILE_TOP, pos.z), color)
	_fx_spiral(Vector3(pos.x, TILE_TOP + 2.0, pos.z), color, 12, 58.0, 40.0, true)
	await get_tree().create_timer(0.32).timeout


## 投掷炸弹：铁球带着引线旋转抛出，落地弹一下后白闪 + 火球 + 碎片 + 烟尘 + 焦痕
func bomb_throw(from: Vector3, to: Vector3, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 14.0
	sm.height = 28.0
	sm.radial_segments = 10
	sm.rings = 6
	var ball := MeshInstance3D.new()
	ball.mesh = sm
	ball.material_override = _pbr(Color("2f343c"), 0.6, 0.4)
	ball.position = from + Vector3(0, 70.0, 0)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(ball)
	var fuse := _fx_mesh(sm, ball.position + Vector3(0, 18.0, 0), Color("ffd166"), 3.6)
	fuse.scale = Vector3(0.22, 0.22, 0.22)
	var ctrl := (ball.position + to) * 0.5 + Vector3(0, 150.0, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(_launch_step.bind(ball, ball.position, ctrl, to), 0.0, 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ball, "rotation", Vector3(TAU, TAU * 0.6, TAU), 0.5)
	t.chain().tween_callback(_free_if_valid.bind(fuse))
	await t.finished
	if not is_instance_valid(ball):
		return
	var hop := create_tween()
	hop.tween_property(ball, "position:y", to.y + 26.0, 0.07)
	hop.tween_property(ball, "position:y", to.y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hop.finished
	fx_sound("cap_slam")
	if is_instance_valid(ball):
		ball.queue_free()
	_shockwave(to, Color(1.0, 0.96, 0.86), 0.0, 4.6, 0.4)
	impact_kind("fire", to, color)
	_fx_shards(Vector3(to.x, TILE_TOP + 2.0, to.z), color.lightened(0.3), 12, 120.0, 140.0, 7.0, 0.6)
	for k in 4:
		_spawn_trail_dot(Vector3(to.x, TILE_TOP + 20.0, to.z), color, "smoke")
	await get_tree().create_timer(0.18).timeout


## 换位：两枚棋子同时腾空，沿镜像弧线交叉飞过，中途留残影，落地各炸一圈光环
## a_to / b_to 省略时按“互相飞到对方当前坐标”处理
func piece_swap_arc(a: Node3D, b: Node3D, color: Color, a_to := Vector3.INF, b_to := Vector3.INF) -> void:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return
	var a_start := a.position
	var b_start := b.position
	if a_to == Vector3.INF:
		a_to = b_start
	if b_to == Vector3.INF:
		b_to = a_start
	var mid := (a_start + b_start) * 0.5
	# 出发点连线的垂线，用来把两条弧线掰向左右两侧
	var flat := Vector2(b_start.x - a_start.x, b_start.z - a_start.z)
	var perp := Vector3(-flat.y, 0.0, flat.x)
	if perp.length() < 0.001:
		perp = Vector3.RIGHT
	perp = perp.normalized()
	# 两枚棋子都在 y + 70 的高空掠过，高点再错开 18 单位避免穿模
	var ctrl_a := mid + perp * 46.0 + Vector3(0.0, 70.0, 0.0)
	var ctrl_b := mid - perp * 46.0 + Vector3(0.0, 88.0, 0.0)
	_swap_ghost_trail(a, a_start, ctrl_a, a_to, color)
	_swap_ghost_trail(b, b_start, ctrl_b, b_to, color)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(_swap_arc_step.bind(a, a_start, ctrl_a, a_to), 0.0, 1.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_swap_arc_step.bind(b, b_start, ctrl_b, b_to), 0.0, 1.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	# 落地各炸一圈；节点位置交给主流程按数据设置，这里不改
	if is_instance_valid(a):
		event_ring(a.position, color)
	if is_instance_valid(b):
		event_ring(b.position, color)


## 二次贝塞尔：t = 0 起点、t = 1 终点
func _swap_arc_point(t: float, p0: Vector3, ctrl: Vector3, p1: Vector3) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u) + ctrl * (2.0 * u * t) + p1 * (t * t)


func _swap_arc_step(t: float, node: Node3D, p0: Vector3, ctrl: Vector3, p1: Vector3) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.position = _swap_arc_point(t, p0, ctrl, p1)


## 飞行途中在弧线上留下 3 个半透明残影，只做视觉，不进 pieces 数据
func _swap_ghost_trail(node: Node3D, p0: Vector3, ctrl: Vector3, p1: Vector3, color: Color) -> void:
	for k in 3:
		var at := 0.30 + 0.18 * float(k)
		var pos := _swap_arc_point(at / 1.2, p0, ctrl, p1)
		var t := create_tween()
		t.tween_interval(at)
		t.tween_callback(_spawn_swap_ghost.bind(node, pos, color))


func _spawn_swap_ghost(node: Node3D, pos: Vector3, color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	var ghost := node.duplicate() as Node3D
	if ghost == null:
		return
	ghost.name = "SwapGhost"
	ghost.position = pos
	ghost.rotation = node.rotation
	ghost.scale = node.scale
	var fade_mats: Array = []
	for mi in _mesh_nodes(ghost):
		if String(mi.name).contains("ContactShadow"):
			mi.visible = false
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var src := mi.material_override as StandardMaterial3D
		var mat: StandardMaterial3D = null
		if src != null:
			mat = src.duplicate() as StandardMaterial3D
			mat.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, 0.45)
		else:
			mat = _unshaded(color.lightened(0.3), 1.4)
			mat.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		fade_mats.append(mat)
	_fx.add_child(ghost)
	var t := create_tween()
	t.set_parallel(true)
	for mat in fade_mats:
		t.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	t.tween_property(ghost, "scale", ghost.scale * 1.2, 0.42)
	t.chain().tween_callback(ghost.queue_free)


func _mesh_nodes(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_mesh_nodes(child))
	return out


func _build_pawn_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(38.0, 0.0), Vector2(43.0, 5.0), Vector2(43.0, 10.0),
		Vector2(33.0, 14.0), Vector2(20.0, 19.0), Vector2(16.0, 32.0), Vector2(23.0, 40.0),
		Vector2(31.0, 45.0), Vector2(27.0, 51.0), Vector2(15.0, 56.0), Vector2(13.0, 70.0),
		Vector2(17.0, 78.0), Vector2(20.0, 84.0), Vector2(14.0, 91.0), Vector2(0.0, 96.0),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 32
	var rings := profile.size()
	for s in segs:
		var a0 := TAU * s / segs
		var a1 := TAU * (s + 1) / segs
		for i in rings - 1:
			var p0 := profile[i]
			var p1 := profile[i + 1]
			var v00 := Vector3(p0.x * cos(a0), p0.y, p0.x * sin(a0))
			var v01 := Vector3(p0.x * cos(a1), p0.y, p0.x * sin(a1))
			var v11 := Vector3(p1.x * cos(a1), p1.y, p1.x * sin(a1))
			var v10 := Vector3(p1.x * cos(a0), p1.y, p1.x * sin(a0))
			var u0 := float(s) / segs
			var u1 := float(s + 1) / segs
			var v0 := float(i) / (rings - 1)
			var v1 := float(i + 1) / (rings - 1)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(v00)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(v11)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(v01)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(v00)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(v10)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(v11)
	st.index()
	st.generate_normals()
	return st.commit()


func add_shield(node: Node3D) -> void:
	if node.has_node("Shield"):
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 57.0
	sm.height = 114.0
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.45, 0.85, 1.0, 0.16)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position.y = 56.0
	mi.name = "Shield"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


func remove_shield(node: Node3D) -> void:
	var s := node.get_node_or_null("Shield")
	if s:
		s.queue_free()


# ---------------------------------------------------------------- 骰子

func _build_dice() -> void:
	_dice = Node3D.new()
	_dice.name = "Dice"
	_dice.position = _dice_home
	_dice.scale = Vector3.ONE * DICE_SCALE
	add_child(_dice)

	# 立体骰子模型：六块面板 + 12 条倒角棱 + 8 个圆角球，拼成一颗真正圆润的骰子
	# （Godot 没有内置倒角立方体，用基础几何拼反而能得到干净的圆角高光）
	var half := 46.0
	var bevel := 8.0
	var inner := half - bevel
	var face := inner * 2.0
	var ivory := _pbr(Color("ece4d4"), 0.04, 0.34)
	ivory.rim_enabled = true
	ivory.rim = 0.45
	ivory.rim_tint = 0.55

	for axis in 3:
		for s in [-1.0, 1.0]:
			var size := Vector3(6.0, face, face)
			var pos := Vector3((half - 3.0) * s, 0, 0)
			if axis == 1:
				size = Vector3(face, 6.0, face)
				pos = Vector3(0, (half - 3.0) * s, 0)
			elif axis == 2:
				size = Vector3(face, face, 6.0)
				pos = Vector3(0, 0, (half - 3.0) * s)
			_add_box(_dice, size, pos, ivory)

	for axis in 3:
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				if axis == 0:
					var ex := _add_cyl(_dice, bevel, bevel, face, Vector3(0, inner * sa, inner * sb), ivory, 12)
					ex.rotation.z = PI * 0.5
				elif axis == 1:
					_add_cyl(_dice, bevel, bevel, face, Vector3(inner * sa, 0, inner * sb), ivory, 12)
				else:
					var ez := _add_cyl(_dice, bevel, bevel, face, Vector3(inner * sa, inner * sb, 0), ivory, 12)
					ez.rotation.x = PI * 0.5

	var corner_mesh := SphereMesh.new()
	corner_mesh.radius = bevel
	corner_mesh.height = bevel * 2.0
	corner_mesh.radial_segments = 12
	corner_mesh.rings = 6
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			for sc in [-1.0, 1.0]:
				var corner := MeshInstance3D.new()
				corner.mesh = corner_mesh
				corner.material_override = ivory
				corner.position = Vector3(inner * sa, inner * sb, inner * sc)
				_dice.add_child(corner)

	var pip_mat := _pbr(Color("141821"), 0.25, 0.42)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 7.4
	pip_mesh.height = 13.0
	pip_mesh.radial_segments = 12
	pip_mesh.rings = 6
	pip_mesh.material = pip_mat

	var layouts := {
		1: [Vector2i(0, 0)],
		2: [Vector2i(-1, -1), Vector2i(1, 1)],
		3: [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(1, 1)],
		4: [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)],
		5: [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(1, -1), Vector2i(1, 1)],
		6: [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)],
	}
	for value in DIE_FACES.keys():
		var face_data: Dictionary = DIE_FACES[value]
		var nrm: Vector3 = face_data["n"]
		var uax: Vector3 = face_data["u"]
		var vax: Vector3 = face_data["v"]
		for cell in layouts[value]:
			var off: Vector3 = nrm * (half - 4.0) + uax * (float(cell.x) * 20.0) + vax * (float(cell.y) * 20.0)
			var pip := MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.position = off
			pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_dice.add_child(pip)

	# 投掷拖影：一串逐渐变小变淡的光点，跟着骰子飞行
	_dice_trail.clear()
	_dice_trail_pts.clear()
	for i in 6:
		var orb := MeshInstance3D.new()
		var osm := SphereMesh.new()
		osm.radius = 9.0
		osm.height = 18.0
		osm.radial_segments = 10
		osm.rings = 5
		orb.mesh = osm
		var om := _pbr(Color("ffe6b0"), 0.0, 0.4)
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		om.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		om.albedo_color = Color(1.0, 0.92, 0.72, 0.5 - 0.06 * float(i))
		orb.material_override = om
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		add_child(orb)
		_dice_trail.append(orb)


## 拖影跟随：掷骰时按轨迹留下光点，停下后立刻隐去
func _update_dice_trail() -> void:
	if _dice == null or _dice_trail.is_empty():
		return
	if _rolling:
		_dice_trail_pts.push_front(_dice.global_position)
		if _dice_trail_pts.size() > _dice_trail.size():
			_dice_trail_pts.pop_back()
	else:
		_dice_trail_pts.clear()
	for i in _dice_trail.size():
		var orb: MeshInstance3D = _dice_trail[i]
		if not is_instance_valid(orb):
			continue
		if _rolling and i < _dice_trail_pts.size():
			var k := 1.0 - float(i) / float(_dice_trail.size())
			orb.visible = true
			orb.global_position = _dice_trail_pts[i]
			orb.scale = Vector3.ONE * (0.3 + 0.55 * k)
		elif orb.visible:
			orb.visible = false


func _dice_rest_euler(value: int) -> Vector3:
	match value:
		1:
			return Vector3(0.0, 0.0, deg_to_rad(90.0))
		2:
			return Vector3.ZERO
		3:
			return Vector3(deg_to_rad(-90.0), 0.0, 0.0)
		4:
			return Vector3(deg_to_rad(90.0), 0.0, 0.0)
		5:
			return Vector3(deg_to_rad(180.0), 0.0, 0.0)
		_:
			return Vector3(0.0, 0.0, deg_to_rad(-90.0))


func dice_world_position() -> Vector3:
	if _dice == null:
		return Vector3.ZERO
	return _dice.global_position


func is_dice_rolling() -> bool:
	return _rolling


## 掷骰：从悬浮位砸进棋盘中央，弹跳三次后亮出点数，再飘回原位
func roll_dice(value: int) -> void:
	if _rolling:
		return
	_rolling = true
	var rest := _dice_rest_euler(value)
	rest.y = randf_range(-0.3, 0.3)
	var land := DICE_LAND + Vector3(randf_range(-34.0, 34.0), 0.0, randf_range(-34.0, 34.0))

	var spin := create_tween()
	spin.tween_property(_dice, "rotation", rest + Vector3(TAU * 3.0, TAU * 4.0, TAU * 2.0), 0.72) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var drop := create_tween()
	# 抛掷弧线：先抬手蓄力，再朝镜头方向甩出，最后加速砸向中心
	drop.tween_property(_dice, "position", _dice_home + Vector3(0.0, 110.0, 0.0), 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drop.tween_property(_dice, "position", land + Vector3(190.0, 150.0, 250.0), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop.tween_property(_dice, "position", land, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(_dice, "position:y", land.y + 108.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop.tween_property(_dice, "position:y", land.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(_dice, "position:y", land.y + 48.0, 0.09)
	drop.tween_property(_dice, "position:y", land.y, 0.09)

	await drop.finished
	if spin.is_valid():
		spin.kill()
	_dice.position = land
	_dice.rotation = rest
	# 落地挤压：骰子砸下来瞬间压扁再弹回，撞击才有重量
	var squash := create_tween()
	squash.tween_property(_dice, "scale", Vector3(DICE_SCALE * 1.2, DICE_SCALE * 0.8, DICE_SCALE * 1.2), 0.07).set_trans(Tween.TRANS_QUAD)
	squash.tween_property(_dice, "scale", Vector3.ONE * DICE_SCALE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact(land, Color("ffe6b0"))
	await get_tree().create_timer(0.55).timeout

	var back := create_tween()
	back.set_parallel(true)
	back.tween_property(_dice, "position", _dice_home, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_dice, "rotation", Vector3(0.0, rest.y, 0.0), 0.5)
	await back.finished
	_dice.position = _dice_home
	_rolling = false


# ---------------------------------------------------------------- 高亮与特效

func mark_tiles(positions: Array, color: Color) -> void:
	clear_marks()
	var k := _tile_size / 100.0
	for p in positions:
		var mi := _glow_ring(color, 34.0 * k, 40.0 * k)
		mi.position = Vector3(p.x, TILE_TOP + 2.0, p.z)
		_marks.append(mi)


func clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()


func mark_piece(node: Node3D) -> void:
	if node == null or node.has_node("Mark"):
		return
	var mi := _glow_ring(Color(1, 0.93, 0.7), 40.0, 46.0)
	mi.name = "Mark"
	mi.position.y = 5.0
	node.add_child(mi)
	_piece_marks.append(mi)


func clear_piece_marks() -> void:
	for m in _piece_marks:
		if is_instance_valid(m):
			m.queue_free()
	_piece_marks.clear()


func _glow_ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	return mi


func pulse(pos: Vector3, color: Color) -> void:
	var mi := _glow_ring(color, 30.0, 38.0)
	mi.position = Vector3(pos.x, TILE_TOP + 3.0, pos.z)
	mi.scale = Vector3(0.4, 1.0, 0.4)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(2.4, 1.0, 2.4), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.6)
	t.chain().tween_callback(mi.queue_free)


func burst(pos: Vector3, color: Color, count := 14) -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 5.0
		sm.height = 10.0
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mi.material_override = mat
		mi.position = pos + Vector3(0, 30, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(mi)
		var a := TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var dist := randf_range(45.0, 110.0)
		var target := mi.position + Vector3(cos(a) * dist, randf_range(30.0, 90.0), sin(a) * dist)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3(0.1, 0.1, 0.1), 0.55)
		t.tween_property(mat, "albedo_color:a", 0.0, 0.55)
		t.chain().tween_callback(mi.queue_free)


func flash_piece(node: Node3D) -> void:
	if node == null:
		return
	var t := create_tween()
	t.tween_property(node, "scale", Vector3(1.18, 1.18, 1.18), 0.12)
	t.tween_property(node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func finish_beam(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 16.0
	cm.bottom_radius = 22.0
	cm.height = 420.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos + Vector3(0, 210, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	var t := create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 1.2).set_delay(0.3)
	t.chain().tween_callback(mi.queue_free)


# ---------------------------------------------------------------- 可移动 / 选中提示

## 可走的棋子：放大 + 头顶旋转箭头 + 脚下光环
func show_movable(nodes: Array, color: Color) -> void:
	clear_movable()
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var node3d: Node3D = node
		var arrow := Node3D.new()
		arrow.name = "MoveArrow"
		arrow.position = Vector3(0, 172.0, 0)
		node3d.add_child(arrow)

		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 30.0
		cm.height = 52.0
		cm.radial_segments = 10
		cone.mesh = cm
		cone.rotation.z = PI
		var mat := _unshaded(color.lightened(0.15), 1.7)
		cone.material_override = mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.add_child(cone)

		var stem := MeshInstance3D.new()
		var sm2 := CylinderMesh.new()
		sm2.top_radius = 4.0
		sm2.bottom_radius = 4.0
		sm2.height = 30.0
		sm2.radial_segments = 8
		stem.mesh = sm2
		stem.position.y = -40.0
		stem.material_override = _unshaded(color, 2.6)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.add_child(stem)

		var halo := _glow_ring(color, 50.0, 60.0)
		var hp: Node = halo.get_parent()
		if hp:
			hp.remove_child(halo)
		halo.position = Vector3(0, 9.0, 0)
		node3d.add_child(halo)
		_movable_halos.append(halo)
		_movable_fx.append(arrow)

		var tw := create_tween()
		tw.tween_property(node3d, "scale", Vector3(1.16, 1.16, 1.16), 0.18).set_trans(Tween.TRANS_BACK)


func clear_movable() -> void:
	for fx in _movable_fx:
		if is_instance_valid(fx):
			var parent: Node = fx.get_parent()
			if parent is Node3D:
				var p3: Node3D = parent
				var tw := create_tween()
				tw.tween_property(p3, "scale", Vector3.ONE, 0.16)
			fx.queue_free()
	_movable_fx.clear()
	for h in _movable_halos:
		if is_instance_valid(h):
			h.queue_free()
	_movable_halos.clear()


## 选中的棋子：金色双环 + 三颗环绕光球
func select_piece(node: Node3D) -> void:
	clear_selection()
	if node == null or not is_instance_valid(node):
		return
	_selected = node
	var r1 := _add_torus(node, 44.0, 50.0, Vector3(0, 10.0, 0), _gold)
	r1.name = "SelRing"
	var r2 := _add_torus(node, 34.0, 39.0, Vector3(0, 26.0, 0), _gold)
	r2.name = "SelRing2"
	_sel_rings.append(r1)
	_sel_rings.append(r2)
	for k in 3:
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 5.0
		sm.height = 10.0
		sm.radial_segments = 6
		sm.rings = 3
		orb.mesh = sm
		orb.material_override = _unshaded(Color("ffd98a"), 3.0)
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(orb)
		_sel_orbs.append(orb)


func clear_selection() -> void:
	for r in _sel_rings:
		if is_instance_valid(r):
			r.queue_free()
	_sel_rings.clear()
	for o in _sel_orbs:
		if is_instance_valid(o):
			o.queue_free()
	_sel_orbs.clear()
	_selected = null


func _unshaded(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## 吃棋：双层冲击波 + 碎片飞散 + 中心闪光
func capture_blast(pos: Vector3, color: Color) -> void:
	_shockwave(pos, color, 0.0, 3.2, 0.55)
	_shockwave(pos, color.lightened(0.4), 0.14, 4.6, 0.62)

	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 34.0
	sm.height = 68.0
	sm.radial_segments = 12
	sm.rings = 6
	flash.mesh = sm
	flash.material_override = _unshaded(Color(1.0, 0.96, 0.86), 4.0)
	flash.position = pos + Vector3(0, 46.0, 0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(flash)
	var ft := create_tween()
	ft.set_parallel(true)
	ft.tween_property(flash, "scale", Vector3(2.4, 1.6, 2.4), 0.28)
	ft.tween_property(flash, "scale", Vector3.ZERO, 0.22).set_delay(0.28)
	ft.chain().tween_callback(flash.queue_free)

	burst(pos, color, 18)
	finish_beam(pos, color)


## 踩成一滩：地面上的独立圆盘（挂在 _fx 下，不跟随棋子），扩散同时淡出
func puddle(pos: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.name = "Puddle"
	root.position = Vector3(pos.x, TILE_TOP + 0.6, pos.z)
	root.scale = Vector3(0.25, 1.0, 0.25)
	_fx.add_child(root)
	# 主体：比棋子颜色暗一档的扁平圆盘
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := color.darkened(0.25)
	body_mat.albedo_color = Color(dark.r, dark.g, dark.b, 0.85)
	var disc := _add_cyl(root, 26.0, 26.0, 1.2, Vector3.ZERO, body_mat, 32)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 外圈：略大一圈的亮色边，勾出“一滩”的轮廓
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bright := color.lightened(0.15)
	rim_mat.albedo_color = Color(bright.r, bright.g, bright.b, 0.55)
	var rim := _add_cyl(root, 29.0, 29.0, 0.8, Vector3(0.0, -0.15, 0.0), rim_mat, 32)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(root, "scale", Vector3(1.7, 1.0, 1.7), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body_mat, "albedo_color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(rim_mat, "albedo_color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(root.queue_free)


func _shockwave(pos: Vector3, color: Color, delay: float, target: float, life: float) -> void:
	var mi := _glow_ring(color, 30.0, 40.0)
	mi.position = Vector3(pos.x, TILE_TOP + 3.0, pos.z)
	mi.scale = Vector3(0.35, 1.0, 0.35)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(mi, "scale", Vector3(target, 1.0, target), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(mi.queue_free)


## 事件/道具的扩散光环
func event_ring(pos: Vector3, color: Color) -> void:
	_shockwave(pos, color, 0.0, 2.6, 0.7)
	_shockwave(pos, color.lightened(0.35), 0.1, 3.4, 0.8)


## 道具生效：从棋子向外扩散的环
func item_aura(node: Node3D, color: Color) -> void:
	if node == null:
		return
	for k in 3:
		var mi := _glow_ring(color, 34.0 + float(k) * 8.0, 40.0 + float(k) * 8.0)
		mi.position = Vector3(node.position.x, TILE_TOP + 2.0, node.position.z)
		mi.scale = Vector3(0.4, 1.0, 0.4)
		var t := create_tween()
		t.tween_interval(0.09 * float(k))
		t.tween_property(mi, "scale", Vector3(2.2, 1.0, 2.2), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(mi.queue_free)


## 骰子落地的小冲击
func impact(pos: Vector3, color: Color) -> void:
	var mi := _glow_ring(color, 30.0, 38.0)
	mi.position = Vector3(pos.x, TILE_TOP + 3.0, pos.z)
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(2.0, 1.0, 2.0), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.34)
	t.chain().tween_callback(mi.queue_free)
	burst(Vector3(pos.x, 0.0, pos.z), color, 8)


## 获得道具：光柱 + 上升火花 + 光环
func item_pickup(pos: Vector3, color: Color) -> void:
	finish_beam(pos, color)
	_shockwave(pos, color, 0.0, 2.2, 0.5)
	burst(Vector3(pos.x, 24.0, pos.z), color, 14)
	for i in 10:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.4
		sm.height = 6.8
		sm.radial_segments = 4
		sm.rings = 2
		mi.mesh = sm
		mi.material_override = _unshaded(color.lightened(0.4), 3.0)
		var a := TAU * float(i) / 10.0
		mi.position = Vector3(pos.x + cos(a) * 34.0, 10.0, pos.z + sin(a) * 34.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(mi)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:y", 150.0, 0.7).set_delay(0.03 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.7)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.7)
		t.chain().tween_callback(mi.queue_free)


## 使用道具：每种道具有自己的专属表现，不再统一套冲击波
func item_cast(node: Node3D, color: Color, kind: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var p := node.global_position
	var g := Vector3(p.x, TILE_TOP + 2.0, p.z)
	# 每种道具有独立音色，棋子本体同时给出对应力道的弹压反馈
	fx_sound("it_" + kind)
	_cast_pop(node, kind)
	match kind:
		"boost":
			item_aura(node, color)
			_fx_arrows(g, color)
		"double":
			item_aura(node, color)
			_fx_arrows(g, color.lightened(0.25))
			_shockwave(g, color, 0.0, 3.0, 0.5)
			_shockwave(g, color.lightened(0.3), 0.12, 4.4, 0.6)
		"warp":
			_fx_portal(g, color)
		"teleport":
			_fx_portal(g, color.lightened(0.2))
			finish_beam(g, color)
		"snipe":
			_fx_reticle(g, color)
		"swap":
			_fx_link(g, color)
		"freeze":
			freeze_burst(g, color)
		"frostlock":
			freeze_burst(g, color)
			_fx_chains(g, color.lightened(0.2))
		"inferno":
			_fx_geysers(g, color)
		"moonstep":
			_fx_moon(g, color)
		"vortex":
			_fx_spiral(g, color, 22, 96.0, 150.0, true)
		"steal":
			_fx_slashes(g, color, 2)
			_fx_coins(g, color, 8)
		"bomb":
			_fx_bomb(g, color)
		"gale":
			_fx_wind(g, color, 22)
		"jadeguard":
			_fx_dome(g, color, 96.0, 0.9)
			_fx_runes(g, color, 60.0, 10)
		"shield":
			_fx_dome(g, color, 78.0, 0.75)
			_fx_runes(g, color, 46.0, 6)
		"voidstep":
			_fx_rift(g, color)
			_fx_spiral(g, color, 14, 72.0, 110.0, true)
		_:
			item_aura(node, color)
			_shockwave(g, color, 0.0, 2.2, 0.45)


# ---------------------------------------------------------------- 专属特效零件

func _fx_mesh(mesh: Mesh, pos: Vector3, color: Color, energy := 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _unshaded(color, energy)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	return mi


## 上升箭头（加速类道具）
func _fx_arrows(g: Vector3, color: Color) -> void:
	for k in 3:
		var arrow := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 16.0
		cm.height = 34.0
		cm.radial_segments = 8
		arrow.mesh = cm
		arrow.material_override = _unshaded(color.lightened(0.35), 3.2)
		var a := TAU * float(k) / 3.0
		arrow.position = Vector3(g.x + cos(a) * 40.0, g.y + 18.0, g.z + sin(a) * 40.0)
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(arrow)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(arrow, "position:y", g.y + 188.0, 0.62).set_delay(0.06 * float(k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(arrow, "scale", Vector3(0.2, 0.2, 0.2), 0.62)
		t.tween_property(arrow.material_override, "albedo_color:a", 0.0, 0.62)
		t.chain().tween_callback(arrow.queue_free)


## 传送门：三重光环从外向内塌缩，带一点旋转
func _fx_portal(g: Vector3, color: Color) -> void:
	for k in 3:
		var ring := _glow_ring(color, 38.0 + float(k) * 12.0, 46.0 + float(k) * 12.0)
		ring.position = g + Vector3(0, 3.0, 0)
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3(2.4, 2.4, 2.4)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector3(0.1, 0.1, 0.1), 0.55).set_delay(0.08 * float(k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(ring, "rotation:y", 7.0, 0.55)
		t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.55)
		t.chain().tween_callback(ring.queue_free)


## 狙击准星：落地光环 + 十字刻度 + 中心亮点
func _fx_reticle(g: Vector3, color: Color) -> void:
	var ring := _glow_ring(color, 46.0, 54.0)
	ring.position = g + Vector3(0, 3.0, 0)
	ring.scale = Vector3(1.6, 1.6, 1.6)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(0.4, 0.4, 0.4), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.1)
	t.chain().tween_callback(ring.queue_free)
	for k in 4:
		var a := TAU * float(k) / 4.0
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 34.0, 3.0)
		var tick := _fx_mesh(bm, g + Vector3(cos(a) * 78.0, 16.0, sin(a) * 78.0), color, 3.4)
		tick.rotation.y = -a
		var t2 := create_tween()
		t2.set_parallel(true)
		t2.tween_property(tick, "position", g + Vector3(cos(a) * 30.0, 16.0, sin(a) * 30.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(tick.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.1)
		t2.chain().tween_callback(tick.queue_free)


## 换位：两个相互咬合旋转的光环
func _fx_link(g: Vector3, color: Color) -> void:
	for k in 2:
		var ring := _glow_ring(color if k == 0 else color.lightened(0.3), 34.0, 42.0)
		ring.position = g + Vector3(0, 46.0 + float(k) * 26.0, 0)
		ring.rotation.x = PI * 0.5
		ring.rotation.z = 0.5 if k == 0 else -0.5
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "rotation:y", 8.0 if k == 0 else -8.0, 0.6)
		t.tween_property(ring, "position:y", g.y + 120.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6).set_delay(0.2)
		t.chain().tween_callback(ring.queue_free)


## 月步：三层月牙向上抬升
func _fx_moon(g: Vector3, color: Color) -> void:
	for k in 3:
		var cres := _glow_ring(color.lightened(0.3), 36.0 + float(k) * 10.0, 42.0 + float(k) * 10.0)
		cres.position = g + Vector3(0, 26.0 + float(k) * 34.0, 0)
		cres.scale = Vector3(0.3, 1.0, 0.3)
		var t := create_tween()
		t.tween_property(cres, "scale", Vector3(1.5, 1.0, 1.5), 0.45).set_delay(0.08 * float(k))
		t.parallel().tween_property(cres, "position:y", g.y + 150.0, 0.5).set_delay(0.08 * float(k))
		t.parallel().tween_property(cres.material_override, "albedo_color:a", 0.0, 0.45).set_delay(0.08 * float(k))
		t.chain().tween_callback(cres.queue_free)


## 炸弹：先亮引信，再炸成碎块与火点
func _fx_bomb(g: Vector3, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 16.0
	sm.height = 32.0
	sm.radial_segments = 10
	sm.rings = 6
	var bomb := _fx_mesh(sm, g + Vector3(0, 18.0, 0), Color("3a3f4a"), 0.6)
	(bomb.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fuse := _fx_mesh(sm, g + Vector3(0, 40.0, 0), Color("ffd166"), 4.0)
	fuse.scale = Vector3(0.18, 0.18, 0.18)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(fuse, "position:y", g.y + 52.0, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(fuse, "scale", Vector3(0.05, 0.05, 0.05), 0.5)
	t.chain().tween_callback(func():
		bomb.visible = false
		fuse.visible = false
		burst(g, color, 22)
		_fx_shards(g, color.lightened(0.2), 16, 110.0, 130.0, 7.0, 0.55)
		_fx_fire_puffs(g, color, 6)
		bomb.queue_free()
		fuse.queue_free())


## 火球烟团
func _fx_fire_puffs(g: Vector3, color: Color, count := 6) -> void:
	for i in count:
		var sm := SphereMesh.new()
		sm.radius = 22.0
		sm.height = 44.0
		sm.radial_segments = 8
		sm.rings = 5
		var a := TAU * float(i) / float(count) + randf() * 0.4
		var mi := _fx_mesh(sm, g + Vector3(cos(a) * 26.0, 24.0, sin(a) * 26.0), color if i % 2 == 0 else Color("ffb347"), 2.4)
		mi.scale = Vector3(0.4, 0.4, 0.4)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", g + Vector3(cos(a) * 88.0, 70.0, sin(a) * 88.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3(1.5, 1.5, 1.5), 0.6)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.6)
		t.chain().tween_callback(mi.queue_free)


## 飞散碎屑
func _fx_shards(g: Vector3, color: Color, count := 12, spread := 90.0, up := 120.0, size := 6.0, life := 0.6) -> void:
	for i in count:
		var bm := BoxMesh.new()
		bm.size = Vector3(size, size, size)
		var mi := _fx_mesh(bm, g + Vector3(0, 8.0, 0), color, 2.6)
		var a := TAU * randf()
		var r := spread * randf_range(0.4, 1.0)
		var end := Vector3(g.x + cos(a) * r, g.y + randf_range(6.0, up), g.z + sin(a) * r)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", end, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), life)
		t.tween_property(mi, "scale", Vector3.ONE * 0.1, life)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, life)
		t.chain().tween_callback(mi.queue_free)


## 地面尖刺
func _fx_spikes(g: Vector3, color: Color, count := 8, radius := 32.0, height := 60.0) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + randf() * 0.2
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 10.0
		cm.height = height
		cm.radial_segments = 6
		var mi := _fx_mesh(cm, Vector3(g.x + cos(a) * radius, g.y - height * 0.5, g.z + sin(a) * radius), color, 2.8)
		mi.rotation.z = randf_range(-0.2, 0.2)
		var t := create_tween()
		t.tween_property(mi, "position:y", g.y + height * 0.34, 0.18).set_delay(0.03 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.24)
		t.set_parallel(true)
		t.tween_property(mi, "position:y", g.y - height, 0.3)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3)
		t.chain().tween_callback(mi.queue_free)


## 半透明护罩
func _fx_dome(g: Vector3, color: Color, radius := 90.0, life := 0.7) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 20
	sm.rings = 10
	var mi := _fx_mesh(sm, g + Vector3(0, 4.0, 0), color, 1.4)
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, life).set_delay(0.2)
	t.chain().tween_callback(mi.queue_free)


## 金币雨
func _fx_coins(g: Vector3, color: Color, count := 14) -> void:
	for i in count:
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 7.0
		cm.height = 1.6
		cm.radial_segments = 10
		var off := Vector3(randf_range(-72.0, 72.0), 0.0, randf_range(-72.0, 72.0))
		var mi := _fx_mesh(cm, Vector3(g.x + off.x, g.y + 250.0, g.z + off.z), color, 2.2)
		mi.rotation.x = PI * 0.5
		var d := 0.04 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:y", g.y + 4.0, 0.45 + randf() * 0.3).set_delay(d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(mi, "rotation:z", randf_range(-9.0, 9.0), 0.75)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.22).set_delay(d + 0.42)
		t.chain().tween_callback(mi.queue_free)


## 风：横向掠过的气刃
func _fx_wind(g: Vector3, color: Color, count := 20, speed := 250.0) -> void:
	for i in count:
		var bm := BoxMesh.new()
		bm.size = Vector3(52.0, 1.4, 1.4)
		var mi := _fx_mesh(bm, Vector3(g.x + randf_range(-50.0, 30.0), g.y + randf_range(8.0, 96.0), g.z + randf_range(-46.0, 46.0)), color, 2.4)
		mi.rotation.y = randf_range(-0.45, 0.45)
		var d := 0.025 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:x", mi.position.x + speed, 0.32).set_delay(d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3(1.6, 1.0, 1.0), 0.32).set_delay(d)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.32).set_delay(d)
		t.chain().tween_callback(mi.queue_free)


## 刀光
func _fx_slashes(g: Vector3, color: Color, count := 3) -> void:
	for i in count:
		var bm := BoxMesh.new()
		bm.size = Vector3(190.0, 2.4, 5.0)
		var mi := _fx_mesh(bm, g + Vector3(0, 56.0 + float(i) * 26.0, 0), color, 3.4)
		mi.rotation.y = TAU * float(i) / float(count) + 0.4
		mi.scale = Vector3(0.1, 1.0, 1.0)
		var d := 0.06 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "scale:x", 1.0, 0.16).set_delay(d).set_trans(Tween.TRANS_QUAD)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3).set_delay(d + 0.18)
		t.chain().tween_callback(mi.queue_free)


## 环绕符文
func _fx_runes(g: Vector3, color: Color, radius := 56.0, count := 8) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 14.0, 4.0)
		var mi := _fx_mesh(bm, Vector3(g.x + cos(a) * radius, g.y + 8.0, g.z + sin(a) * radius), color, 3.0)
		var t := create_tween()
		t.tween_property(mi, "position:y", g.y + 42.0, 0.5).set_delay(0.03 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.set_parallel(true)
		t.tween_property(mi, "rotation:y", 2.0, 0.5)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.5)
		t.chain().tween_callback(mi.queue_free)


## 螺旋（inward = 吸入，否则上旋外扩）
func _fx_spiral(g: Vector3, color: Color, count := 20, radius := 70.0, height := 150.0, inward := false) -> void:
	for i in count:
		var a := TAU * 2.0 * float(i) / float(count)
		var h := height * float(i) / float(count)
		var sm := SphereMesh.new()
		sm.radius = 4.0
		sm.height = 8.0
		sm.radial_segments = 6
		sm.rings = 3
		var start_r := radius if not inward else 5.0
		var end_r := 5.0 if not inward else radius
		var start_y := g.y + 10.0 + h
		var end_y := (g.y + height + 24.0) if not inward else (g.y + 10.0)
		var mi := _fx_mesh(sm, Vector3(g.x + cos(a) * start_r, start_y, g.z + sin(a) * start_r), color, 3.0)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", Vector3(g.x + cos(a + 3.4) * end_r, end_y, g.z + sin(a + 3.4) * end_r), 0.55).set_delay(0.02 * float(i))
		t.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.55)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.55)
		t.chain().tween_callback(mi.queue_free)


## 空间裂隙：竖立的暗色裂缝 + 被吸入的碎光
func _fx_rift(g: Vector3, color: Color) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(96.0, 240.0)
	var mi := _fx_mesh(qm, g + Vector3(0, 120.0, 0), color, 2.6)
	var mat := mi.material_override as StandardMaterial3D
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(color.r * 0.35, color.g * 0.25, color.b * 0.55, 0.85)
	mi.rotation.y = randf_range(-0.5, 0.5)
	mi.scale = Vector3(0.05, 0.5, 1.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "rotation:y", mi.rotation.y + 1.8, 0.8)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_delay(0.3)
	t.chain().tween_callback(mi.queue_free)


## 铁链（诅咒/霜锁）
func _fx_chains(g: Vector3, color: Color) -> void:
	for i in 5:
		var tm := TorusMesh.new()
		tm.inner_radius = 7.0
		tm.outer_radius = 13.0
		tm.rings = 12
		tm.ring_segments = 5
		var a := TAU * float(i) / 5.0
		var mi := _fx_mesh(tm, Vector3(g.x + cos(a) * 40.0, g.y + 210.0 + float(i) * 26.0, g.z + sin(a) * 40.0), color, 2.6)
		mi.rotation.y = a
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:y", g.y + 6.0, 0.42).set_delay(0.05 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(mi, "rotation:x", 6.0, 0.42)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.35 + 0.05 * float(i))
		t.chain().tween_callback(mi.queue_free)


## 彩色混沌球
func _fx_chaos(g: Vector3, count := 12) -> void:
	var palette := [Color("ff6b6b"), Color("ffd93d"), Color("6bcb77"), Color("4d96ff"), Color("c77dff")]
	for i in count:
		var sm := SphereMesh.new()
		sm.radius = 6.0
		sm.height = 12.0
		sm.radial_segments = 8
		sm.rings = 4
		var a := TAU * float(i) / float(count)
		var mi := _fx_mesh(sm, g + Vector3(cos(a) * 30.0, 20.0, sin(a) * 30.0), palette[i % palette.size()], 3.2)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", g + Vector3(cos(a + 4.2) * 92.0, 40.0 + randf_range(-20.0, 110.0), sin(a + 4.2) * 92.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.7)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.7)
		t.chain().tween_callback(mi.queue_free)


## 星辉：菱形星光缓缓飘落
func _fx_stars(g: Vector3, color: Color, count := 18) -> void:
	for i in count:
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 12.0, 3.0)
		var off := Vector3(randf_range(-100.0, 100.0), 0.0, randf_range(-100.0, 100.0))
		var mi := _fx_mesh(bm, g + off + Vector3(0, 240.0, 0), color.lightened(0.35), 3.4)
		mi.rotation = Vector3(0.6, randf_range(0.0, TAU), 0.6)
		var d := 0.03 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:y", g.y + randf_range(6.0, 40.0), 0.55).set_delay(d).set_trans(Tween.TRANS_SINE)
		t.tween_property(mi, "rotation:y", randf_range(2.0, 6.0), 0.55)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3).set_delay(d + 0.3)
		t.chain().tween_callback(mi.queue_free)


## 暴风雪：雪花 + 冰晶
func _fx_snow(g: Vector3, color: Color) -> void:
	freeze_burst(g, color)
	for i in 22:
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 3.0, 3.0)
		var off := Vector3(randf_range(-110.0, 110.0), 0.0, randf_range(-110.0, 110.0))
		var mi := _fx_mesh(bm, g + off + Vector3(0, 260.0, 0), Color("dff2ff"), 2.0)
		var d := 0.04 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position", Vector3(mi.position.x + randf_range(-60.0, 60.0), g.y + 4.0, mi.position.z + randf_range(-60.0, 60.0)), 0.8).set_delay(d).set_trans(Tween.TRANS_SINE)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.25).set_delay(d + 0.6)
		t.chain().tween_callback(mi.queue_free)


## 火山喷发：三股岩浆柱 + 火星
func _fx_geysers(g: Vector3, color: Color) -> void:
	_shockwave(g, color, 0.0, 3.6, 0.55)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var base := g + Vector3(cos(a) * 44.0, 0.0, sin(a) * 44.0)
		var cm := CylinderMesh.new()
		cm.top_radius = 26.0
		cm.bottom_radius = 8.0
		cm.height = 130.0
		cm.radial_segments = 10
		var col := _fx_mesh(cm, base + Vector3(0, 20.0, 0), color, 2.6)
		col.scale = Vector3(0.35, 0.1, 0.35)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(col, "scale", Vector3(0.85, 1.6, 0.85), 0.42).set_delay(0.06 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(col.material_override, "albedo_color:a", 0.0, 0.4).set_delay(0.3 + 0.06 * float(i))
		t.chain().tween_callback(col.queue_free)
		_fx_shards(base, color.lightened(0.25), 6, 38.0, 130.0, 5.0, 0.6)


## 地震：放射状地裂 + 尘土
func _fx_quake(g: Vector3, color: Color) -> void:
	_shockwave(g, color.darkened(0.25), 0.0, 7.0, 0.65)
	_shockwave(g, color, 0.1, 9.0, 0.75)
	for i in 10:
		var a := TAU * float(i) / 10.0 + randf() * 0.22
		var len := randf_range(70.0, 150.0)
		var bm := BoxMesh.new()
		bm.size = Vector3(3.6, 1.2, len)
		var mi := _fx_mesh(bm, g + Vector3(cos(a) * len * 0.5, 1.0, sin(a) * len * 0.5), Color("8a6a4a"), 0.5)
		mi.rotation.y = -a
		mi.scale = Vector3(1.0, 1.0, 0.05)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "scale:z", 1.0, 0.16).set_delay(0.03 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.4).set_delay(0.35)
		t.chain().tween_callback(mi.queue_free)
	_fx_shards(g, Color("a08a6c"), 14, 120.0, 60.0, 8.0, 0.7)


## 翠蛇：盘旋而上的蛇形链条
func _fx_serpent(g: Vector3, color: Color) -> void:
	for i in 18:
		var a := 0.55 * float(i)
		var tm := TorusMesh.new()
		tm.inner_radius = 7.0
		tm.outer_radius = 13.0
		tm.rings = 10
		tm.ring_segments = 5
		var mi := _fx_mesh(tm, Vector3(g.x + cos(a) * 54.0, g.y + 12.0 + float(i) * 9.0, g.z + sin(a) * 54.0), color, 2.6)
		mi.rotation.y = a
		var d := 0.02 * float(i)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(mi, "position:y", g.y + 200.0 + float(i) * 4.0, 0.55).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.55).set_delay(d)
		t.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.55).set_delay(d)
		t.chain().tween_callback(mi.queue_free)
	_shockwave(g, color, 0.0, 3.0, 0.5)


## 陨石：真实落石砸地
func _fx_meteor(g: Vector3, color: Color) -> void:
	_shockwave(g, color, 0.0, 3.4, 0.55)
	for i in 3:
		var sm := SphereMesh.new()
		sm.radius = 22.0
		sm.height = 44.0
		sm.radial_segments = 8
		sm.rings = 5
		var rock := MeshInstance3D.new()
		rock.mesh = sm
		rock.material_override = _pbr(Color("5a3a26"), 0.1, 0.9)
		var a := randf() * TAU
		var target := Vector3(g.x + cos(a) * randf_range(18.0, 72.0), g.y + 14.0, g.z + sin(a) * randf_range(18.0, 72.0))
		rock.position = target + Vector3(randf_range(-30.0, 30.0), 540.0 + float(i) * 70.0, randf_range(-30.0, 30.0))
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(rock)
		var t := create_tween()
		t.tween_property(rock, "position", target, 0.34 + 0.1 * float(i)).set_delay(0.07 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func():
			impact(target, color)
			_fx_shards(target, Color("8a6a4a"), 8, 56.0, 70.0, 7.0, 0.5)
			rock.queue_free())


## 轮盘大奖的天空法阵：细光柱 + 缓慢旋转的符文环，取代满屏核爆
func sky_sigil(pos: Vector3, color: Color) -> void:
	fx_sound("ev_sigil")
	var ring := _glow_ring(color, 150.0, 168.0)
	ring.position = Vector3(pos.x, 300.0, pos.z)
	ring.rotation.x = PI * 0.5
	ring.scale = Vector3(0.2, 0.2, 0.2)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "rotation:y", 3.2, 1.1)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6).set_delay(0.6)
	t.chain().tween_callback(ring.queue_free)
	var bcm := CylinderMesh.new()
	bcm.top_radius = 10.0
	bcm.bottom_radius = 42.0
	bcm.height = 900.0
	bcm.radial_segments = 16
	bcm.cap_top = false
	bcm.cap_bottom = false
	var beam := _fx_mesh(bcm, Vector3(pos.x, 450.0, pos.z), color, 1.2)
	(beam.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.16)
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(beam, "scale", Vector3(0.15, 1.0, 0.15), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.tween_property(beam.material_override, "albedo_color:a", 0.0, 0.5).set_delay(0.4)
	tb.chain().tween_callback(beam.queue_free)


## 每个随机事件一套独立视觉
func event_fx(id: String, pos: Vector3, color: Color) -> void:
	var g := Vector3(pos.x, TILE_TOP + 2.0, pos.z)
	fx_sound("ev_" + id)
	match id:
		"treasure":
			_fx_runes(g, color, 44.0, 8)
			_fx_coins(g, color, 10)
		"meteor":
			_fx_meteor(g, color)
		"tailwind":
			_fx_wind(g, color, 22)
		"trap":
			_fx_spikes(g, color, 8, 30.0, 64.0)
			_shockwave(g, color, 0.12, 2.4, 0.4)
		"portal":
			_fx_portal(g, color)
		"chaos":
			_fx_chaos(g, 12)
		"bless":
			_fx_dome(g, color, 84.0, 0.8)
			_fx_runes(g, color, 40.0, 6)
		"starlight":
			_fx_stars(g, color)
		"blizzard":
			_fx_snow(g, color)
		"eruption":
			_fx_geysers(g, color)
		"ambush":
			_fx_slashes(g, color, 4)
			_fx_shards(g, color, 10, 80.0, 90.0, 5.0, 0.5)
		"goldrain":
			_fx_coins(g, color, 24)
			_shockwave(g, color, 0.0, 2.2, 0.5)
		"earthquake":
			_fx_quake(g, color)
		"curse":
			_fx_spikes(g, color.darkened(0.1), 6, 26.0, 52.0)
			_fx_chains(g, color)
		"jadeserpent":
			_fx_serpent(g, color)
		"voidrift":
			_fx_rift(g, color)
			_fx_spiral(g, color, 16, 82.0, 130.0, true)
		_:
			_shockwave(g, color, 0.0, 2.6, 0.5)


## 冰晶爆发（时长整体放慢 1.4 倍，看得清结冰过程）
func freeze_burst(pos: Vector3, color: Color) -> void:
	var k := 1.4
	for i in 9:
		var a := TAU * float(i) / 9.0
		var spire := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 9.0
		cm.height = 46.0
		cm.radial_segments = 5
		spire.mesh = cm
		spire.material_override = _unshaded(color.lightened(0.25), 2.4)
		spire.position = Vector3(pos.x + cos(a) * 38.0, 18.0, pos.z + sin(a) * 38.0)
		spire.rotation.z = cos(a) * 0.35
		spire.rotation.x = sin(a) * 0.35
		spire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(spire)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(spire, "position:y", 62.0, 0.36 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(spire, "scale", Vector3(0.1, 0.1, 0.1), 0.5 * k).set_delay(0.5 * k)
		t.tween_property(spire.material_override, "albedo_color:a", 0.0, 0.5 * k).set_delay(0.5 * k)
		t.chain().tween_callback(spire.queue_free)
	_shockwave(pos, color, 0.0, 3.6, 0.55 * k)


## 荆棘：六根细锥从地下窜起 → 停留 → 缩回，带一点横向散开
func spike_burst(pos: Vector3, color: Color) -> void:
	fx_sound("cap_slam", -4.0)
	var start_y := TILE_TOP - 20.0
	var end_y := TILE_TOP + 14.0
	for i in 6:
		var a := TAU * float(i) / 6.0
		var off := Vector3(cos(a) * 15.0, 0.0, sin(a) * 15.0)
		var mi := _add_cyl(_fx, 0.0, 6.5, 44.0,
			Vector3(pos.x + off.x, start_y, pos.z + off.z), _unshaded(color, 2.6), 6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 每根锥略微歪斜，避免整齐得像栅栏
		mi.rotation.z = randf_range(-0.16, 0.16)
		mi.rotation.x = randf_range(-0.16, 0.16)
		var t := create_tween()
		t.tween_property(mi, "position:y", end_y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.12)
		t.tween_property(mi, "position:y", start_y - 10.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(mi.queue_free)


## 狙击：从施法者到目标的能量射线
func snipe_streak(from: Vector3, to: Vector3, color: Color) -> void:
	var a := Vector3(from.x, 70.0, from.z)
	var b := Vector3(to.x, 70.0, to.z)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0
	cm.bottom_radius = 4.0
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _unshaded(color, 4.0)
	mi.position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(mi)
	var t := create_tween()
	t.tween_property(mi, "scale", Vector3(0.2, 1.0, 0.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3)
	t.chain().tween_callback(mi.queue_free)
	impact(Vector3(to.x, 0.0, to.z), color) 


## 俄罗斯轮盘触发事件时的全屏炸裂：天空光柱 + 多重冲击波 + 碎片 + 穹顶闪光
func roulette_blast(pos: Vector3, color: Color) -> void:
	var ground := Vector3(pos.x, TILE_TOP + 2.0, pos.z)
	# 三重地面冲击波
	for k in 3:
		_shockwave(ground, color if k != 1 else color.lightened(0.45), 0.0, 9.0 + float(k) * 5.0, 0.7 + 0.12 * float(k))
	# 天降巨型光柱
	var beam := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 42.0
	bcm.bottom_radius = 120.0
	bcm.height = 1500.0
	bcm.radial_segments = 20
	bcm.cap_top = false
	bcm.cap_bottom = false
	beam.mesh = bcm
	beam.material_override = _unshaded(color, 1.8)
	(beam.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.28)
	beam.position = Vector3(pos.x, 740.0, pos.z)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(beam)
	var tb := create_tween()
	tb.tween_property(beam, "scale", Vector3(0.1, 1.0, 0.1), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.parallel().tween_property(beam.material_override, "albedo_color:a", 0.8, 0.18)
	tb.tween_property(beam.material_override, "albedo_color:a", 0.0, 0.4)
	tb.chain().tween_callback(beam.queue_free)
	# 穹顶闪光
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 100.0
	dm.height = 200.0
	dm.radial_segments = 24
	dm.rings = 12
	dome.mesh = dm
	dome.material_override = _unshaded(color.lightened(0.5), 4.0)
	(dome.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.55)
	dome.position = ground + Vector3(0, 40.0, 0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(dome)
	var td := create_tween()
	td.set_parallel(true)
	td.tween_property(dome, "scale", Vector3(9.0, 5.0, 9.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	td.tween_property(dome.material_override, "albedo_color:a", 0.0, 0.7)
	td.chain().tween_callback(dome.queue_free)
	# 8 道冲天火柱
	for k in 8:
		var a := TAU * float(k) / 8.0
		var pillar := MeshInstance3D.new()
		var pcm := CylinderMesh.new()
		pcm.top_radius = 6.0
		pcm.bottom_radius = 24.0
		pcm.height = 260.0
		pcm.radial_segments = 10
		pillar.mesh = pcm
		pillar.material_override = _unshaded(color.lightened(0.3), 3.2)
		pillar.position = Vector3(pos.x + cos(a) * 96.0, 130.0, pos.z + sin(a) * 96.0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(pillar)
		var tp := create_tween()
		tp.set_parallel(true)
		tp.tween_property(pillar, "position:y", 420.0, 0.62).set_delay(0.05 * float(k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(pillar, "scale", Vector3(0.15, 1.8, 0.15), 0.62)
		tp.tween_property(pillar.material_override, "albedo_color:a", 0.0, 0.62)
		tp.chain().tween_callback(pillar.queue_free)
	# 碎片飞散
	for i in 34:
		var shard := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := randf_range(6.0, 18.0)
		bm.size = Vector3(sz, sz, sz)
		shard.mesh = bm
		shard.material_override = _unshaded(color.lightened(randf_range(0.1, 0.5)), 2.6)
		shard.position = ground + Vector3(0, 30.0, 0)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.add_child(shard)
		var a2 := randf() * TAU
		var dist := randf_range(110.0, 320.0)
		var target := shard.position + Vector3(cos(a2) * dist, randf_range(90.0, 330.0), sin(a2) * dist)
		var ts := create_tween()
		ts.set_parallel(true)
		ts.tween_property(shard, "position", target, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ts.tween_property(shard, "rotation", Vector3(randf() * 12.0, randf() * 12.0, randf() * 12.0), 1.0)
		ts.tween_property(shard.material_override, "albedo_color:a", 0.0, 1.0).set_delay(0.35)
		ts.chain().tween_callback(shard.queue_free)
	burst(ground, color, 26)
	impact(ground, color)


## 主题强调色（轮盘、事件、UI 光效统一取色）
func theme_accent() -> Color:
	match theme_id:
		"frost":
			return Color("aef0ff")
		"ember":
			return Color("ff9a3c")
		"jade":
			return Color("8ff0c0")
		"void":
			return Color("b8a0ff")
		_:
			return Color("ffd166")


