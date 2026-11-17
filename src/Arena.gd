class_name Arena
extends Node3D
## 天空竞技场：程序化生成的全部场景美术（不依赖原版贴图）
##  - 暮色全景天空 + ACES 色调映射 + 辉光
##  - 悬浮石台 / 40 格环道 / 四条终点跑道 / 四角阵地 / 中央高台
##  - 程序化棋子（车削网格）、3D 骰子、落点与吃子特效

const TILE_SIZE := 100.0
const TILE_TOP := 8.0
const DECK_HALF := 890.0
const DICE_HOME := Vector3(0, 300, 0)
const DICE_LAND := Vector3(0, 216, 0)

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
		"ambient": 0.46, "exposure": 1.0, "saturation": 0.96, "glow": 0.72,
		"sun_color": "e6f4ff", "sun_energy": 2.2, "sun_rot": Vector3(-48, -20, 0),
		"fill_color": "7fb0ff", "fill_energy": 0.40,
		"fog_color": "cfe6ff", "fog_energy": 0.5, "fog_density": 0.00009,
		"center_color": "bfe6ff", "center_energy": 1.7,
		"stone_a": "d6e4f2", "stone_b": "c2d4e6", "stone_dark": "7f93aa", "deck": "8fa3b8",
		"tint_a": 0.94, "tint_b": 0.94, "tint_dark": 0.78, "tint_deck": 0.62,
		"gold": "d8ecff", "gold_em": "4fa8dc",
		"chevron": "8fb6c9", "chevron_em": "9fe4ff",
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
var _noise_tex: NoiseTexture2D
var _stone_alb: Texture2D
var _stone_rgh: Texture2D
var _pawn_mesh: ArrayMesh

var _dice: Node3D
var _fx: Node3D
var _motes: MultiMeshInstance3D
var _marks: Array = []
var _piece_marks: Array = []
var _time := 0.0
var _rolling := false
var _dice_locked := false

# 事件格 / 安全格 3D 标记
var _chests: Array = []
var _safe_marks: Array = []
# 棋子拟人动画数据
var _actors: Array = []


func build(points: Dictionary, ring: Array, colors: Array, theme := "dusk") -> void:
	team_colors = colors
	theme_id = theme if THEMES.has(theme) else "dusk"
	_build_environment()
	_make_materials()
	_build_platform()
	_build_track(points, ring)
	_build_goal_lanes(points)
	_build_bases(points)
	_build_center()
	_build_motes()
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
	if _dice and not _rolling:
		_dice.position.y = DICE_HOME.y + sin(_time * 1.6) * 5.0
		_dice.rotation.y += delta * 0.55
		_dice.rotation.x = sin(_time * 0.9) * 0.16

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

	# 棋子待机拟人动画
	for a in _actors:
		if not is_instance_valid(a["body"]):
			continue
		var body: Node3D = a["body"]
		var ph: float = a["phase"]
		body.position.y = sin(_time * 2.2 + ph) * 2.4
		body.rotation.z = sin(_time * 1.7 + ph) * 0.022
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

func _build_environment() -> void:
	var th: Dictionary = THEMES[theme_id]
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_path: String = th["sky"]
	if ResourceLoader.exists(sky_path):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(sky_path)
		pano.energy_multiplier = th["sky_energy"]
		sky.sky_material = pano
	else:
		var ps := ProceduralSkyMaterial.new()
		ps.sky_top_color = Color("0b1026")
		ps.sky_horizon_color = Color("ffa06a")
		ps.sky_curve = 0.12
		ps.ground_bottom_color = Color("1a2036")
		ps.ground_horizon_color = Color("c98a72")
		sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = th["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = th["exposure"]
	env.glow_enabled = true
	env.glow_intensity = th["glow"]
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 0.7)
	env.adjustment_enabled = true
	env.adjustment_saturation = th["saturation"]
	env.adjustment_contrast = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color(th["fog_color"])
	env.fog_light_energy = th["fog_energy"]
	env.fog_density = th["fog_density"]
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = th["sun_rot"]
	sun.light_energy = th["sun_energy"]
	sun.light_color = Color(th["sun_color"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3200.0
	add_child(sun)
	_sun = sun

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 148, 0)
	fill.light_energy = th["fill_energy"]
	fill.light_color = Color(th["fill_color"])
	add_child(fill)
	_fill_light = fill

	var center_light := OmniLight3D.new()
	center_light.position = Vector3(0, 260, 0)
	center_light.light_color = Color(th["center_color"])
	center_light.light_energy = th["center_energy"]
	center_light.omni_range = 900.0
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

	if ResourceLoader.exists("res://assets/textures/stone_albedo.png"):
		_stone_alb = load("res://assets/textures/stone_albedo.png")
	if ResourceLoader.exists("res://assets/textures/stone_rough.png"):
		_stone_rgh = load("res://assets/textures/stone_rough.png")

	var th: Dictionary = THEMES[theme_id]
	_stone_a = _pbr(Color(th["stone_a"]), 0.22, 0.62)
	_recolor_stone(_stone_a, Color(th["stone_a"]), float(th["tint_a"]), 0.0014, 0.22, 0.62)

	_stone_b = _pbr(Color(th["stone_b"]), 0.22, 0.56)
	_recolor_stone(_stone_b, Color(th["stone_b"]), float(th["tint_b"]), 0.0014, 0.22, 0.56)

	_stone_dark = _pbr(Color(th["stone_dark"]), 0.3, 0.5)
	_recolor_stone(_stone_dark, Color(th["stone_dark"]), float(th["tint_dark"]), 0.0011, 0.3, 0.5)

	_deck_top = _pbr(Color(th["deck"]), 0.26, 0.58)
	_recolor_stone(_deck_top, Color(th["deck"]), float(th["tint_deck"]), 0.0009, 0.26, 0.58)

	_gold = _pbr(Color(th["gold"]), 0.72, 0.3)
	_gold.emission_enabled = true
	_gold.emission = Color(th["gold_em"])
	_gold.emission_energy_multiplier = 0.55
	_gold.rim_enabled = true
	_gold.rim = 0.4

	_trim = _pbr(Color("101820"), 0.4, 0.3)
	_trim.emission_enabled = true
	_trim.emission = Color(th["trim"])
	_trim.emission_energy_multiplier = 1.8

	_chevron = _pbr(Color(th["chevron"]), 0.55, 0.38)
	_chevron.emission_enabled = true
	_chevron.emission = Color(th["chevron_em"])
	_chevron.emission_energy_multiplier = 0.5

	for c in team_colors:
		var m := _pbr(Color(c).darkened(0.12), 0.78, 0.26)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.16
		m.rim_enabled = true
		m.rim = 0.5
		_team_metal.append(m)

		var g := _pbr(Color(c).darkened(0.55), 0.2, 0.35)
		g.emission_enabled = true
		g.emission = c
		g.emission_energy_multiplier = 1.7
		_team_glow.append(g)

		var s := _pbr(Color(c).darkened(0.45), 0.32, 0.5)
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = 0.16
		s.rim_enabled = true
		s.rim = 0.35
		_apply_stone(s, 1.0, 0.0012)
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
	if _stone_alb:
		m.albedo_texture = _stone_alb
	if _stone_rgh:
		m.roughness_texture = _stone_rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = _noise_tex
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tri, tri, tri)


func _recolor_stone(m: StandardMaterial3D, base: Color, tint: float, tri: float, metallic: float, rough: float) -> void:
	if m == null:
		return
	m.albedo_color = Color(base.r * tint, base.g * tint, base.b * tint)
	m.metallic = metallic
	m.roughness = rough
	m.albedo_texture = _stone_alb
	if _stone_rgh:
		m.roughness_texture = _stone_rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = _noise_tex
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tri, tri, tri)


## 运行时切换主题：只改环境与材质，不重建几何
func set_theme(id: String) -> void:
	if not THEMES.has(id):
		return
	theme_id = id
	var th: Dictionary = THEMES[id]

	if _env:
		_env.ambient_light_energy = th["ambient"]
		_env.tonemap_exposure = th["exposure"]
		_env.glow_intensity = th["glow"]
		_env.adjustment_saturation = th["saturation"]
		_env.fog_light_color = Color(th["fog_color"])
		_env.fog_light_energy = th["fog_energy"]
		_env.fog_density = th["fog_density"]
		var sky_path: String = th["sky"]
		if ResourceLoader.exists(sky_path) and _env.sky:
			var pano := PanoramaSkyMaterial.new()
			pano.panorama = load(sky_path)
			pano.energy_multiplier = th["sky_energy"]
			_env.sky.sky_material = pano
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
	_recolor_stone(_deck_top, Color(th["deck"]), float(th["tint_deck"]), 0.0009, 0.26, 0.58)

	if _gold:
		_gold.albedo_color = Color(th["gold"])
		_gold.emission = Color(th["gold_em"])
	if _trim:
		_trim.emission = Color(th["trim"])
	if _chevron:
		_chevron.albedo_color = Color(th["chevron"])
		_chevron.emission = Color(th["chevron_em"])
	if _motes_mat:
		_motes_mat.albedo_color = Color(th["motes"])
		_motes_mat.emission = Color(th["motes"])


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
	var under := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1240.0
	cm.bottom_radius = 560.0
	cm.height = 460.0
	cm.radial_segments = 4
	under.mesh = cm
	under.material_override = _stone_dark
	under.rotation.y = deg_to_rad(45.0)
	under.position.y = -260.0
	add_child(under)

	var deck := _add_box(self, Vector3(DECK_HALF * 2.0, 34.0, DECK_HALF * 2.0), Vector3(0, -17, 0), _stone_dark)
	deck.name = "Deck"

	var top := _add_box(self, Vector3(DECK_HALF * 2.0 - 40.0, 8.0, DECK_HALF * 2.0 - 40.0), Vector3(0, -4, 0), _deck_top)
	top.name = "DeckTop"

	var eh := DECK_HALF
	for i in 4:
		var size := Vector3(eh * 2.0 - 6.0, 5.0, 10.0)
		var pos := Vector3.ZERO
		match i:
			0:
				pos = Vector3(0, 1.0, -eh + 8.0)
			1:
				pos = Vector3(0, 1.0, eh - 8.0)
			2:
				pos = Vector3(-eh + 8.0, 1.0, 0)
				size = Vector3(10.0, 5.0, eh * 2.0 - 6.0)
			3:
				pos = Vector3(eh - 8.0, 1.0, 0)
				size = Vector3(10.0, 5.0, eh * 2.0 - 6.0)
		var trim := _add_box(self, size, pos, _gold)
		trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 台面内圈的一圈暗刻线
	var ring := _add_torus(self, 690.0, 700.0, Vector3(0, 1.5, 0), _gold)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_track(points: Dictionary, ring: Array) -> void:
	var n := ring.size()
	if n == 0:
		return
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

		var team := i / 10
		var is_start := i % 10 == 0
		var base_mat := _stone_b if i % 2 == 0 else _stone_a
		var slab := _add_box(tile, Vector3(TILE_SIZE - 8.0, TILE_TOP, TILE_SIZE - 8.0), Vector3(0, -TILE_TOP * 0.5, 0), base_mat)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		# 金色凸框：让每一格从台面上清晰地"切"出来
		var fw := 4.5
		var edge := (TILE_SIZE - fw) * 0.5
		var rim_far := _add_box(tile, Vector3(TILE_SIZE, 2.6, fw), Vector3(0, -0.4, edge), _gold)
		var rim_near := _add_box(tile, Vector3(TILE_SIZE, 2.6, fw), Vector3(0, -0.4, -edge), _gold)
		var rim_left := _add_box(tile, Vector3(fw, 2.6, TILE_SIZE - fw * 2.0), Vector3(-edge, -0.4, 0), _gold)
		var rim_right := _add_box(tile, Vector3(fw, 2.6, TILE_SIZE - fw * 2.0), Vector3(edge, -0.4, 0), _gold)
		for r in [rim_far, rim_near, rim_left, rim_right]:
			var rmi: MeshInstance3D = r
			rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 缝隙下的暗色底
		_add_box(tile, Vector3(TILE_SIZE, 4.0, TILE_SIZE), Vector3(0, -TILE_TOP + 2.0, 0), _stone_dark, 0.0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 方向箭头（尖端指向行进方向）
		var local_yaw := wrapf(yaw_next - yaw_avg, -PI, PI)
		var chev := Node3D.new()
		chev.rotation.y = local_yaw
		chev.position.y = 0.8
		tile.add_child(chev)
		for side in [-1, 1]:
			var bar := _add_box(chev, Vector3(10.0, 2.4, 34.0), Vector3(12.0 * side, 0, 3.0), _chevron, deg_to_rad(-32.0 * side))
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 格子标记：宝箱格 / 安全格
		if i % 10 == 5:
			_make_chest(tile)
		elif i % 10 == 0:
			_make_safe_pad(tile)

		if is_start and team >= 0 and team < _team_glow.size():
			_add_box(tile, Vector3(TILE_SIZE - 22.0, 2.0, TILE_SIZE - 22.0), Vector3(0, 0.4, 0), _team_soft[team]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var halo := _add_torus(tile, 34.0, 38.0, Vector3(0, 1.0, 0), _team_glow[team])
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
	cm.top_radius = 30.0
	cm.bottom_radius = 16.0
	cm.height = 320.0
	cm.radial_segments = 18
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm := _unshaded(Color("ffd166"), 1.3)
	(bm as StandardMaterial3D).albedo_color = Color(1.0, 0.82, 0.4, 0.13)
	beam.material_override = bm
	beam.position.y = 96.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(beam)

	var halo := _add_torus(tile, 26.0, 32.0, Vector3(0, 1.6, 0), _unshaded(Color("ffd166"), 1.8))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 头顶「？」招牌：远处也能一眼看出这是事件格
	var sign_l := _billboard_label("？", Color("fff6dd"), 96.0)
	sign_l.position = Vector3(0, 108.0, 0)
	chest.add_child(sign_l)


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
			_add_box(pad, Vector3(88, 6, 88), Vector3(0, -3, 0), _stone_b).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_add_box(pad, Vector3(74, 2, 74), Vector3(0, 1.2, 0), _team_soft[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_torus(pad, 31.0, 34.0, Vector3(0, 2.6, 0), _team_glow[t])
			if s == 3:
				_add_torus(pad, 26, 31, Vector3(0, 2.4, 0), _gold)

		# 跑道两侧的发光条
		var lane_mid := (outer + inner) * 0.5
		var length := d.length() + 80.0
		for side in [-1, 1]:
			var sd := float(side)
			var off: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 56.0 * sd
			_add_box(self, Vector3(4, 2, length), Vector3(lane_mid.x + off.x, 2.0, lane_mid.z + off.z), _team_glow[t], yaw).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 终点门拱：两根立柱 + 横梁 + 队色宝石
		var arch := Node3D.new()
		arch.position = inner - d.normalized() * 8.0
		arch.rotation.y = yaw
		arch.name = "GoalArch%d" % t
		add_child(arch)
		for side in [-1, 1]:
			var sd2 := float(side)
			_add_box(arch, Vector3(16, 118, 16), Vector3(52.0 * sd2, 59.0, 0), _stone_b).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_add_box(arch, Vector3(10, 104, 10), Vector3(52.0 * sd2, 55.0, 10.0), _team_metal[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_box(arch, Vector3(120, 14, 16), Vector3(0, 120.0, 0), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	for t in 4:
		var c := Vector3.ZERO
		for i in 4:
			c += _pt(points, "HM%d_%d" % [t + 1, i + 1])
		c /= 4.0
		var outward := Vector3(c.x, 0, c.z).normalized()

		var plat := _add_box(self, Vector3(310, 22, 310), Vector3(c.x, -3, c.z), _stone_dark)
		plat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_add_box(self, Vector3(300, 3, 300), Vector3(c.x, 7.0, c.z), _team_soft[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# 阵地四周的队伍色灯带
		for sd in [-1.0, 1.0]:
			_add_box(self, Vector3(300, 2.0, 7.0), Vector3(c.x, 9.0, c.z + 146.0 * sd), _team_metal[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_box(self, Vector3(7.0, 2.0, 300), Vector3(c.x + 146.0 * sd, 9.0, c.z), _team_metal[t]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		for i in 4:
			var p := _pt(points, "HM%d_%d" % [t + 1, i + 1])
			_add_cyl(self, 33.0, 35.0, 2.4, Vector3(p.x, 8.6, p.z), _team_metal[t], 28).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_torus(self, 30.0, 35.0, Vector3(p.x, 9.4, p.z), _gold)

		# 阵地外圈呼吸环（当前回合高亮）
		var halo := _add_torus(self, 142.0, 152.0, Vector3(c.x, 9.6, c.z), _team_glow[t])
		halo.name = "BaseHalo%d" % t
		_base_rings.append(halo)

		# 队伍方尖碑
		var ob_pos := Vector3(c.x, 0, c.z) + outward * 175.0
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

		# 旗帜：旗杆 + 队伍色旗面（当前回合会摆动）
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
	_add_box(self, Vector3(150, 24, 150), Vector3(0, 0, 0), _stone_dark)
	_add_cyl(self, 52.0, 62.0, 30.0, Vector3(0, 27, 0), _stone_a, 32)
	_add_torus(self, 40.0, 46.0, Vector3(0, 42.0, 0), _gold)
	_add_torus(self, 60.0, 64.0, Vector3(0, 1.5, 0), _gold)

	var orb := Node3D.new()
	orb.name = "CenterOrb"
	orb.position = Vector3(0, 118, 0)
	add_child(orb)
	_center_orb = orb

	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 40.0
	sm.height = 80.0
	sm.radial_segments = 6
	sm.rings = 2
	gem.mesh = sm
	gem.material_override = _gold
	gem.name = "CenterGem"
	orb.add_child(gem)

	_add_torus(orb, 62.0, 66.0, Vector3.ZERO, _gold, Vector3(deg_to_rad(28), 0, 0))
	_add_torus(orb, 78.0, 81.0, Vector3.ZERO, _trim, Vector3(deg_to_rad(-32), deg_to_rad(20), 0))
	_add_torus(orb, 92.0, 95.0, Vector3.ZERO, _trim, Vector3(deg_to_rad(66), 0, deg_to_rad(18)))

	for t in 4:
		var a := TAU * t / 4.0 + deg_to_rad(45.0)
		var p := Vector3(cos(a) * 100.0, 62.0, sin(a) * 100.0)
		var g := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = 9.0
		s2.height = 18.0
		s2.radial_segments = 4
		s2.rings = 2
		g.mesh = s2
		g.material_override = _team_glow[t]
		g.position = p
		g.name = "CenterCrystal%d" % t
		add_child(g)


func _build_motes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7788
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 140
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
	mat.emission_energy_multiplier = 1.8
	_motes_mat = mat
	sm.material = mat
	mm.mesh = sm
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 980.0
		var y := rng.randf_range(20.0, 520.0)
		var xf := Transform3D(Basis(), Vector3(cos(a) * r, y, sin(a) * r))
		mm.set_instance_transform(i, xf)
	_motes = MultiMeshInstance3D.new()
	_motes.multimesh = mm
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


# ---------------------------------------------------------------- 棋子

func make_piece(team: int) -> Node3D:
	if _pawn_mesh == null:
		_pawn_mesh = _build_pawn_mesh()
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

	# 拟人化身体：所有部件挂在 Body 下，可独立做呼吸 / 出剑 / 受击动画
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var torso := MeshInstance3D.new()
	torso.mesh = _pawn_mesh
	torso.material_override = _team_metal[team]
	body.add_child(torso)

	var belt := _add_torus(body, 16.0, 20.0, Vector3(0, 34.0, 0), _gold)
	belt.name = "Belt"
	var crest := _add_box(body, Vector3(15.0, 20.0, 4.0), Vector3(0, 62.0, 19.0), _team_glow[team])
	crest.name = "Crest"
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(body, Vector3(7.0, 10.0, 3.0), Vector3(0, 62.0, 21.5), _gold).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 头盔 + 面罩
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
	var visor := _add_box(body, Vector3(22.0, 6.0, 4.0), Vector3(0, 105.0, 14.0), _pbr(Color("141a24"), 0.4, 0.3))
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(body, Vector3(6.0, 3.0, 2.0), Vector3(0, 105.0, 17.0), _team_glow[team]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 肩甲
	for sd in [-1.0, 1.0]:
		var pauldron := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 11.0
		ps.height = 20.0
		ps.radial_segments = 12
		ps.rings = 6
		pauldron.mesh = ps
		pauldron.material_override = _gold
		pauldron.position = Vector3(22.0 * sd, 76.0, 0)
		pauldron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(pauldron)

	# 头盔羽饰（会摆动）
	var plume := Node3D.new()
	plume.name = "Plume"
	plume.position = Vector3(0, 112.0, -4.0)
	body.add_child(plume)
	var pc := MeshInstance3D.new()
	var pcm := CylinderMesh.new()
	pcm.top_radius = 0.0
	pcm.bottom_radius = 6.0
	pcm.height = 30.0
	pcm.radial_segments = 6
	pc.mesh = pcm
	pc.material_override = _team_glow[team]
	pc.position = Vector3(0, 12.0, -4.0)
	pc.rotation.x = -0.35
	pc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.add_child(pc)

	# 披风（会飘动）
	var cape := Node3D.new()
	cape.name = "Cape"
	cape.position = Vector3(0, 86.0, -16.0)
	body.add_child(cape)
	var cape_mat := _pbr(team_colors[team].darkened(0.45), 0.08, 0.7)
	var cape_box := _add_box(cape, Vector3(33.0, 54.0, 3.0), Vector3(0, -27.0, 0), cape_mat)
	cape_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.rotation.x = 0.12

	# 佩剑
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = Vector3(27.0, 56.0, 6.0)
	sword.rotation.z = -0.22
	body.add_child(sword)
	_add_box(sword, Vector3(4.0, 42.0, 9.0), Vector3.ZERO, _pbr(Color("dfe8f6"), 0.7, 0.28))
	_add_box(sword, Vector3(12.0, 4.0, 6.0), Vector3(0, -21.0, 0), _gold)
	_add_box(sword, Vector3(4.0, 12.0, 5.0), Vector3(0, -29.0, 0), _pbr(Color("4a2f1c"), 0.1, 0.7))

	# 背旗
	var banner := Node3D.new()
	banner.name = "Banner"
	banner.position = Vector3(0, 70.0, -20.0)
	body.add_child(banner)
	var pole := MeshInstance3D.new()
	var pcm2 := CylinderMesh.new()
	pcm2.top_radius = 1.6
	pcm2.bottom_radius = 1.6
	pcm2.height = 62.0
	pcm2.radial_segments = 6
	pole.mesh = pcm2
	pole.material_override = _gold
	pole.position.y = 14.0
	banner.add_child(pole)
	var flag := _add_box(banner, Vector3(1.6, 18.0, 24.0), Vector3(0, 34.0, 11.0), _team_glow[team])
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 头顶阵营信标
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.0
	sm.height = 8.0
	sm.radial_segments = 4
	sm.rings = 2
	gem.mesh = sm
	gem.position.y = 146.0
	gem.material_override = _team_glow[team]
	gem.name = "Gem"
	body.add_child(gem)

	_actors.append({
		"root": root, "body": body, "cape": cape, "plume": plume, "banner": banner,
		"phase": randf() * TAU,
	})
	return root


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
	_dice.position = DICE_HOME
	_dice.scale = Vector3(0.95, 0.95, 0.95)
	add_child(_dice)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(96, 96, 96)
	body.mesh = bm
	var mat := _pbr(Color("f4efe4"), 0.05, 0.34)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_dice.add_child(body)

	var pip_mat := _pbr(Color("141821"), 0.25, 0.42)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 8.0
	pip_mesh.height = 16.0
	pip_mesh.radial_segments = 10
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
		var face: Dictionary = DIE_FACES[value]
		var nrm: Vector3 = face["n"]
		var uax: Vector3 = face["u"]
		var vax: Vector3 = face["v"]
		for cell in layouts[value]:
			var off: Vector3 = nrm * 48.0 + uax * (float(cell.x) * 21.0) + vax * (float(cell.y) * 21.0)
			var pip := MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.position = off
			pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_dice.add_child(pip)


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
	drop.tween_property(_dice, "position", land, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(_dice, "position:y", land.y + 54.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop.tween_property(_dice, "position:y", land.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(_dice, "position:y", land.y + 24.0, 0.09)
	drop.tween_property(_dice, "position:y", land.y, 0.09)

	await drop.finished
	if spin.is_valid():
		spin.kill()
	_dice.position = land
	_dice.rotation = rest
	impact(land, Color("ffe6b0"))
	await get_tree().create_timer(0.55).timeout

	var back := create_tween()
	back.set_parallel(true)
	back.tween_property(_dice, "position", DICE_HOME, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_dice, "rotation", Vector3(0.0, rest.y, 0.0), 0.5)
	await back.finished
	_dice.position = DICE_HOME
	_rolling = false


# ---------------------------------------------------------------- 高亮与特效

func mark_tiles(positions: Array, color: Color) -> void:
	clear_marks()
	for p in positions:
		var mi := _glow_ring(color, 34.0, 40.0)
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


## 使用道具：棋子专属光效（按道具类型分支）
func item_cast(node: Node3D, color: Color, kind: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var p := node.global_position
	item_aura(node, color)
	burst(Vector3(p.x, 0.0, p.z), color, 16)
	finish_beam(Vector3(p.x, 0.0, p.z), color)

	match kind:
		"boost", "double":
			# 三道上升箭头
			for k in 3:
				var arrow := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 16.0
				cm.height = 34.0
				cm.radial_segments = 8
				arrow.mesh = cm
				arrow.material_override = _unshaded(color.lightened(0.35), 3.2)
				var a2 := TAU * float(k) / 3.0
				arrow.position = Vector3(p.x + cos(a2) * 40.0, 20.0, p.z + sin(a2) * 40.0)
				arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_fx.add_child(arrow)
				var t2 := create_tween()
				t2.set_parallel(true)
				t2.tween_property(arrow, "position:y", 190.0, 0.62).set_delay(0.06 * float(k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t2.tween_property(arrow, "scale", Vector3(0.2, 0.2, 0.2), 0.62)
				t2.tween_property(arrow.material_override, "albedo_color:a", 0.0, 0.62)
				t2.chain().tween_callback(arrow.queue_free)
		"warp", "teleport":
			# 地面传送门 + 逆向漩涡
			for k in 2:
				var ring := _glow_ring(color, 40.0 + float(k) * 12.0, 48.0 + float(k) * 12.0)
				ring.position = Vector3(p.x, TILE_TOP + 3.0, p.z)
				ring.rotation.x = deg_to_rad(90.0)
				var t3 := create_tween()
				t3.set_parallel(true)
				t3.tween_property(ring, "scale", Vector3(0.2, 0.2, 0.2), 0.7).set_delay(0.1 * float(k))
				t3.tween_property(ring, "rotation:z", 6.0, 0.7)
				t3.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.7)
				t3.chain().tween_callback(ring.queue_free)
		"freeze", "frostlock":
			freeze_burst(Vector3(p.x, 0.0, p.z), color)
		"inferno":
			_shockwave(Vector3(p.x, 0.0, p.z), color, 0.0, 4.0, 0.5)
			_shockwave(Vector3(p.x, 0.0, p.z), color.lightened(0.4), 0.08, 5.2, 0.55)
			for k in 4:
				var a3 := TAU * float(k) / 4.0
				var col := MeshInstance3D.new()
				var cm2 := CylinderMesh.new()
				cm2.top_radius = 20.0
				cm2.bottom_radius = 6.0
				cm2.height = 120.0
				cm2.radial_segments = 12
				col.mesh = cm2
				col.material_override = _unshaded(color, 2.2)
				col.position = Vector3(p.x + cos(a3) * 52.0, 60.0, p.z + sin(a3) * 52.0)
				col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_fx.add_child(col)
				var t4 := create_tween()
				t4.set_parallel(true)
				t4.tween_property(col, "scale", Vector3(0.2, 1.6, 0.2), 0.6)
				t4.tween_property(col.material_override, "albedo_color:a", 0.0, 0.6)
				t4.chain().tween_callback(col.queue_free)
		"moonstep":
			for k in 3:
				var cres := _glow_ring(color.lightened(0.3), 36.0 + float(k) * 10.0, 42.0 + float(k) * 10.0)
				cres.position = Vector3(p.x, 26.0 + float(k) * 34.0, p.z)
				cres.scale = Vector3(0.3, 1.0, 0.3)
				var t5 := create_tween()
				t5.tween_property(cres, "scale", Vector3(1.5, 1.0, 1.5), 0.45).set_delay(0.08 * float(k))
				t5.parallel().tween_property(cres.material_override, "albedo_color:a", 0.0, 0.45).set_delay(0.08 * float(k))
				t5.chain().tween_callback(cres.queue_free)
		"swap":
			_shockwave(Vector3(p.x, 0.0, p.z), color, 0.0, 3.4, 0.5)
		_:
			_shockwave(Vector3(p.x, 0.0, p.z), color, 0.0, 3.0, 0.5)


## 冰晶爆发
func freeze_burst(pos: Vector3, color: Color) -> void:
	for k in 9:
		var a := TAU * float(k) / 9.0
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
		t.tween_property(spire, "position:y", 62.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(spire, "scale", Vector3(0.1, 0.1, 0.1), 0.5).set_delay(0.5)
		t.tween_property(spire.material_override, "albedo_color:a", 0.0, 0.5).set_delay(0.5)
		t.chain().tween_callback(spire.queue_free)
	_shockwave(pos, color, 0.0, 3.6, 0.55)


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

