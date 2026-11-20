extends Node3D
## 8 个场景的世界构建器：地形 / 远景体量 / 近景道具 / 专属光源 / 环境动画。
## 由 Arena 持有；切换主题时整组重建。棋盘、棋子、相机不在本文件内。

const GY := -70.0          # 草地/冰面/沙地等地面高度，与 Arena.SCENE_GROUND 一致
const CAM_YAW := 34.0      # 默认相机方位角：该方向留空，避免远景挡住棋盘

var arena: Node3D
var theme_id := "cozy"
var th: Dictionary = {}
var grow := 1.0

var _t := 0.0
var _spin: Array = []      # {n, axis, s}
var _bob: Array = []       # {n, y, f, a, p}
var _drift: Array = []     # {n, v, lim, axis}
var _rise: Array = []      # {n, s, top, bot}
var _orbit: Array = []     # {n, r, a, s, y, b, bp}
var _pulse: Array = []     # {n, base, amp, f, p}
var _sway: Array = []      # {n, f, a, p, axis} 摆动（摆锤 / 吊灯）


func _ready() -> void:
	name = "World"


func build(a: Node3D, id: String, board_scale: float) -> void:
	arena = a
	theme_id = id
	th = arena.THEMES.get(id, {})
	grow = maxf(board_scale, 0.001)
	match id:
		"dusk": _dusk()
		"frost": _frost()
		"ember": _ember()
		"jade": _jade()
		"void": _void()
		"dune": _dune()
		"clock": _clock()
		_: _cozy()


func _process(delta: float) -> void:
	_t += delta
	for d in _spin:
		var n: Node3D = d["n"]
		if not is_instance_valid(n):
			continue
		if String(d["axis"]) == "z":
			n.rotation.z += delta * float(d["s"])
		elif String(d["axis"]) == "x":
			n.rotation.x += delta * float(d["s"])
		else:
			n.rotation.y += delta * float(d["s"])
	for b in _bob:
		var bn: Node3D = b["n"]
		if is_instance_valid(bn):
			bn.position.y = float(b["y"]) + sin(_t * float(b["f"]) + float(b["p"])) * float(b["a"])
	for dr in _drift:
		var dn: Node3D = dr["n"]
		if not is_instance_valid(dn):
			continue
		var v: Vector3 = dr["v"]
		dn.position += v * delta
		var lim: Vector3 = dr["lim"]
		if lim.x > 0.0 and absf(dn.position.x) > lim.x:
			dn.position.x = -signf(dn.position.x) * lim.x
		if lim.z > 0.0 and absf(dn.position.z) > lim.z:
			dn.position.z = -signf(dn.position.z) * lim.z
	for r in _rise:
		var rn: Node3D = r["n"]
		if not is_instance_valid(rn):
			continue
		rn.position.y += delta * float(r["s"])
		if rn.position.y > float(r["top"]):
			rn.position.y = float(r["bot"])
	for o in _orbit:
		var on: Node3D = o["n"]
		if not is_instance_valid(on):
			continue
		var ang := float(o["a"]) + _t * float(o["s"])
		on.position.x = cos(ang) * float(o["r"])
		on.position.z = sin(ang) * float(o["r"])
		on.position.y = float(o["y"]) + sin(_t * float(o["b"]) + float(o["bp"])) * 40.0
	for p in _pulse:
		var pn: Node3D = p["n"]
		if is_instance_valid(pn):
			var s: float = float(p["base"]) + sin(_t * float(p["f"]) + float(p["p"])) * float(p["amp"])
			pn.scale = Vector3(s, s, s)
	for w in _sway:
		var wn: Node3D = w["n"]
		if is_instance_valid(wn):
			var ang: float = sin(_t * float(w["f"]) + float(w["p"])) * float(w["a"])
			if String(w["axis"]) == "x":
				wn.rotation.x = ang
			else:
				wn.rotation.z = ang


# ---------------------------------------------------------------- 通用工具

func _mat(c: Color, rough := 1.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, e := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _alpha(c: Color, a := 0.3, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _shader_mat(code: String, params := {}) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	return arena._add_box(self, size, pos, mat, yaw)


func _cyl(rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg := 20) -> MeshInstance3D:
	return arena._add_cyl(self, rt, rb, h, pos, mat, seg)


func _torus(inner: float, outer: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return arena._add_torus(self, inner, outer, pos, mat, rot)


func _sphere(r: float, pos: Vector3, mat: Material, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 3)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _cone(rb: float, h: float, pos: Vector3, mat: Material, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _plane(size: float, y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.position = Vector3(0, y, 0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _disc(r: float, h: float, y: float, mat: Material, seg := 48) -> MeshInstance3D:
	return _cyl(r, r, h, Vector3(0, y, 0), mat, seg)


func _no_shadow(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 相机方向留空
func _blocked(a: float) -> bool:
	return absf(wrapf(a - deg_to_rad(CAM_YAW), -PI, PI)) < 0.34


func _ring(count: int, radius: float, seed_v: int, jitter := 0.12) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-jitter, jitter)
		out.append({"a": a, "x": cos(a) * radius, "z": sin(a) * radius,
			"r": rng.randf(), "r2": rng.randf()})
	return out


func _tree(pos: Vector3, h: float, rng: RandomNumberGenerator, leaf_a: Material, leaf_b: Material, trunk: Material) -> void:
	var tht := h * 0.44
	_cyl(9.0, 22.0, tht, pos + Vector3(0, tht * 0.5, 0), trunk, 7)
	for c in 3:
		var cr := rng.randf_range(h * 0.15, h * 0.23)
		var p := pos + Vector3(rng.randf_range(-h * 0.05, h * 0.05), tht + c * h * 0.14, rng.randf_range(-h * 0.05, h * 0.05))
		_sphere(cr, p, leaf_a if c % 2 == 0 else leaf_b, 9).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## 沿圆弧砌一段石墙：一块块独立石块拼出厚度，jag>0 时高度参差（残墙 / 崖壁）
func _arc_wall(a0: float, a1: float, radius: float, y: float, h: float, thick: float,
		mat: Material, segs: int, jag := 0.0) -> void:
	var span := a1 - a0
	var seg_len := absf(span) * radius / float(maxi(segs, 1)) * 1.10
	for i in segs:
		var a := a0 + span * (float(i) + 0.5) / float(segs)
		var hh := h
		if jag > 0.0:
			hh = h * (1.0 - jag * absf(sin(float(i) * 2.37 + a * 3.1)))
		_box(Vector3(thick, hh, seg_len), Vector3(cos(a) * radius, y + hh * 0.5, sin(a) * radius), mat, -a)


## 从广场边缘向外铺一条石板道（轴向构图：神庙神道 / 桥面）
func _causeway(a: float, r0: float, r1: float, width: float, y: float, mat: Material, slabs: int) -> void:
	var dir := Vector3(cos(a), 0, sin(a))
	var seg_len := (r1 - r0) / float(maxi(slabs, 1))
	for i in slabs:
		var r := r0 + seg_len * (float(i) + 0.5)
		_box(Vector3(seg_len * 0.90, 24.0, width), dir * r + Vector3(0, y, 0), mat, -a)


func _light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	add_child(l)
	return l


# ---------------------------------------------------------------- 1 晴日牧野

func _cozy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6172
	var grass := _mat(Color(th.get("ground", "8fbf6a")), 1.0)
	var grass_dark := _mat(Color(th.get("ground", "8fbf6a")).darkened(0.12), 1.0)
	var road := _mat(Color(th.get("soil", "9a7a4e")).lightened(0.04), 1.0)

	# 地形：广场坐落在草坡顶上，坡面向外缓降；远处再接一层更低的地面
	_plane(16000.0, GY - 150.0, grass_dark)
	_cyl(3000.0 * grow, 5600.0 * grow, 160.0, Vector3(0, GY - 80.0, 0), grass, 56)

	# 环形草埂：只砌在远半圈，把广场围成院落，远侧地平线被抬起的草坡挡住
	for i in 26:
		var a := 1.22 + 3.72 * float(i) / 25.0
		if _blocked(a):
			continue
		var r := (1760.0 + rng.randf_range(-50.0, 60.0)) * grow
		var s := rng.randf_range(120.0, 190.0)
		var m := _sphere(s, Vector3(cos(a) * r, GY + rng.randf_range(40.0, 90.0), sin(a) * r), grass if i % 3 else grass_dark, 9)
		m.scale = Vector3(1.45, 0.58, 1.30)
		m.rotation.y = rng.randf() * TAU
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 院墙：远侧两道低石墙，中间留出大门
	var wall := _mat(Color("b8ab90"), 0.95)
	var gate_a := 3.73
	_arc_wall(gate_a + 0.16, gate_a + 1.05, 1622.0 * grow, GY + 46.0, 112.0, 46.0, wall, 8, 0.18)
	_arc_wall(gate_a - 1.05, gate_a - 0.16, 1622.0 * grow, GY + 46.0, 112.0, 46.0, wall, 8, 0.18)
	# 门柱 + 门楣：整套场景的视线焦点
	var pillar_mat := _mat(Color("9c8f74"), 0.92)
	for side in 2:
		var a := gate_a + 0.155 * (1.0 if side == 0 else -1.0)
		var p := Vector3(cos(a) * 1630.0 * grow, GY + 112.0, sin(a) * 1630.0 * grow)
		_box(Vector3(96.0, 224.0, 96.0), p, pillar_mat, -a).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_box(Vector3(130.0, 30.0, 130.0), p + Vector3(0, 118.0, 0), pillar_mat, -a)
		_no_shadow(_sphere(26.0, p + Vector3(0, 152.0, 0), _glow(Color("ffd88a"), 1.5), 7))
	var gate_p := Vector3(cos(gate_a) * 1630.0 * grow, GY + 240.0, sin(gate_a) * 1630.0 * grow)
	_box(Vector3(70.0, 46.0, 520.0), gate_p, _mat(Color("7a5a36"), 0.9), -gate_a).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# 门外的土路：穿过草埂缺口伸向牧场
	_causeway(gate_a, 1670.0 * grow, 2700.0 * grow, 300.0, GY + 2.0, road, 7)

	# 远山：低矮连绵，给地平线一条柔和起伏
	var hill_mat := _mat(Color(th.get("leaf_c", "7ea86a")), 1.0)
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.37
		var dist := rng.randf_range(4300.0, 5800.0) * grow
		var hr := rng.randf_range(820.0, 1250.0) * grow
		var hill := _sphere(hr, Vector3(cos(a) * dist, GY - hr * 0.34, sin(a) * dist), hill_mat, 14)
		_no_shadow(hill)
		hill.scale.y = 0.62

	# 院外树林：树冠浮在草埂之上，形成第二层遮挡
	for i in 18:
		var a := TAU * float(i) / 18.0 + rng.randf_range(-0.09, 0.09)
		if _blocked(a):
			continue
		var dist := rng.randf_range(2050.0, 2700.0) * grow
		_tree(Vector3(cos(a) * dist, GY + 10.0, sin(a) * dist), rng.randf_range(460.0, 720.0), rng, arena._leaf_a, arena._leaf_b, arena._wood)
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.14, 0.14)
		if _blocked(a):
			continue
		var dist := rng.randf_range(1850.0, 2250.0) * grow
		var rock := _sphere(rng.randf_range(40.0, 82.0), Vector3(cos(a) * dist, GY + 26.0, sin(a) * dist), _mat(Color("9c9484"), 0.9), 7)
		rock.scale = Vector3(1.2, 0.7, 1.0)
		rock.rotation.y = rng.randf() * TAU

	# 棋盘嵌合：草皮从广场石缝里漫出来，边缘不再是一条干净的圆
	var turf := _mat(Color(th.get("leaf_c", "78a85c")).darkened(0.05), 1.0)
	for i in 16:
		var a := TAU * float(i) / 16.0 + 0.13
		if _blocked(a):
			continue
		var r := (1490.0 + float(i % 3) * 20.0) * grow
		var patch := _sphere(rng.randf_range(70.0, 120.0), Vector3(cos(a) * r, 2.0, sin(a) * r), turf, 8)

		patch.scale = Vector3(1.5, 0.20, 1.2)
		patch.rotation.y = -a
		_no_shadow(patch)
	var tuft_mat := _mat(Color(th.get("leaf_b", "78a85c")), 1.0)
	for i in 34:
		var a := TAU * float(i) / 34.0 + 0.13
		var r := (1450.0 + float(i % 4) * 20.0) * grow
		var tuft := _cone(9.0, 22.0, Vector3(cos(a) * r, 9.0, sin(a) * r), tuft_mat, 5)
		_no_shadow(tuft)
		tuft.rotation.z = sin(float(i) * 2.1) * 0.22
	for i in 22:
		var a := TAU * float(i) / 22.0 + 0.4
		var r := rng.randf_range(1540.0, 1760.0) * grow
		var c: Color = [Color("ffd75e"), Color("ff8fb0"), Color("fff3d6")][i % 3]
		_no_shadow(_sphere(9.0, Vector3(cos(a) * r, GY + 96.0, sin(a) * r), _glow(c, 0.8), 5))


# ---------------------------------------------------------------- 2 暮色浮岛

func _dusk() -> void:
	# 悬空岩体：不留石柱，只把广场底部削成一圈破碎的岩唇 + 垂下的岩齿
	var rock := _mat(Color("5a4a52"), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in 20:
		var a := TAU * float(i) / 20.0 + 0.1
		var r := rng.randf_range(1440.0, 1530.0) * grow
		var s := rng.randf_range(60.0, 120.0)
		var tooth := _cone(s * 0.55, rng.randf_range(150.0, 300.0),
			Vector3(cos(a) * r, -150.0, sin(a) * r), rock, 6)
		tooth.rotation.z = PI
		_no_shadow(tooth)
	# 底缘：一圈断裂的厚石板，让"切面"有厚度
	_arc_wall(0.0, TAU, 1498.0 * grow, -46.0, 44.0, 54.0, rock, 40, 0.45)

	# 云海：紧贴广场底部，让"悬空"直接可从边缘读出来
	var cloud_low := _alpha(Color("ffd0b0"), 0.22)
	var cloud_up := _alpha(Color("ffe6d2"), 0.15)
	_no_shadow(_disc(6400.0, 5.0, -430.0, cloud_low, 48))
	_no_shadow(_disc(5200.0, 4.0, -270.0, cloud_up, 48))
	# 远侧云墙：云一直堆到广场檐口以上，远侧的"地"其实是云
	for i in 22:
		var a := 1.30 + 3.60 * float(i) / 21.0
		if _blocked(a):
			continue
		var r := (1620.0 + rng.randf_range(-40.0, 120.0)) * grow
		var bank := _sphere(rng.randf_range(150.0, 280.0), Vector3(cos(a) * r, rng.randf_range(-80.0, 40.0), sin(a) * r), _alpha(Color("ffdcc8"), 0.30), 8)
		bank.scale = Vector3(1.7, 0.55, 1.4)
		_no_shadow(bank)
	var puff := _alpha(Color("ffe2cc"), 0.16)
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(2100.0, 4200.0) * grow
		var y := rng.randf_range(-420.0, -240.0)
		var c := _sphere(rng.randf_range(260.0, 520.0), Vector3(cos(a) * r, y, sin(a) * r), puff, 10)
		c.scale = Vector3(1.8, 0.28, 1.4)
		_no_shadow(c)
		_drift.append({"n": c, "v": Vector3(6.0, 0, 3.0), "lim": Vector3(5200.0, 0, 0)})

	# 断裂石拱：不是围成一圈，而是沿一条斜向远处退去的线排布，形成斜向景深与框景
	var stone := _mat(Color("b2a2ac"), 0.85)
	var arch_line := [{"a": 2.26, "r": 1476.0, "h": 300.0, "broken": true},
		{"a": 2.94, "r": 1670.0, "h": 410.0, "broken": false},
		{"a": 3.56, "r": 1890.0, "h": 520.0, "broken": true}]
	for k in 3:
		var a: float = arch_line[k]["a"]
		var r: float = float(arch_line[k]["r"]) * grow
		var hh: float = arch_line[k]["h"]
		var c := Vector3(cos(a) * r, -40.0, sin(a) * r)
		var dir := Vector3(-sin(a), 0, cos(a))
		for side in 2:
			var h := hh if side == 0 else hh * (0.50 if bool(arch_line[k]["broken"]) else 0.96)
			var off := dir * (146.0 * (1.0 if side == 0 else -1.0))
			_box(Vector3(92.0, h, 92.0), c + off + Vector3(0, h * 0.5, 0), stone, -a)
		if bool(arch_line[k]["broken"]):
			# 断掉的拱石倒在地上，缺口朝天
			_box(Vector3(100.0, 58.0, 300.0), c + dir * 215.0 + Vector3(0, 20.0, 0), stone, -a + 0.36)
		else:
			_box(Vector3(112.0, 66.0, 380.0), c + Vector3(0, hh + 33.0, 0), stone, -a)

	# 远端残塔：给地平线一个明确剪影
	var tower_a := 3.73
	var tower_p := Vector3(cos(tower_a) * 2750.0, 0, sin(tower_a) * 2750.0)
	var tower_mat := _mat(Color("7a6a74"), 0.9)
	_no_shadow(_cyl(190.0, 240.0, 1150.0, tower_p + Vector3(0, 505.0, 0), tower_mat, 8))
	_no_shadow(_cyl(230.0, 200.0, 90.0, tower_p + Vector3(0, 1100.0, 0), tower_mat, 8))
	_no_shadow(_box(Vector3(150.0, 120.0, 150.0), tower_p + Vector3(0, 1200.0, 0), tower_mat, 0.4))
	for w in 3:
		_no_shadow(_box(Vector3(34.0, 70.0, 8.0), tower_p + Vector3(0, 620.0 + float(w) * 170.0, 232.0), _glow(Color("ffb066"), 1.6), 0.0))

	# 边缘火盆 + 灯光
	var bowl := _mat(Color("3c333a"), 0.8, 0.2)
	var flame := _glow(Color("ff9a3c"), 2.2)
	var brazier_angles := [1.30, 2.72, 3.58, 5.30]
	for k in 4:
		var a: float = brazier_angles[k]
		var r := 1575.0 * grow
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		_no_shadow(_cyl(26.0, 40.0, 46.0, p + Vector3(0, 118.0, 0), bowl, 8))
		_no_shadow(_cyl(14.0, 58.0, 18.0, p + Vector3(0, 80.0, 0), bowl, 8))
		_no_shadow(_cyl(14.0, 20.0, 90.0, p + Vector3(0, 40.0, 0), bowl, 6))
		var f := _cone(26.0, 74.0, p + Vector3(0, 172.0, 0), flame, 7)
		_no_shadow(f)
		_pulse.append({"n": f, "base": 1.0, "amp": 0.22, "f": 6.4, "p": float(k)})
		if k % 2 == 0:
			_light(p + Vector3(0, 210.0, 0), Color("ff9a4c"), 1.5, 760.0)

	# 浮空碎岩：两枚大的出现在金字塔上方，其余散在中景
	var float_rock := _mat(Color("6a5a60"), 0.95)
	var hero_rocks := [{"a": 3.73, "r": 1690.0, "y": 110.0, "s": 170.0},
		{"a": 2.30, "r": 2120.0, "y": 330.0, "s": 110.0},
		{"a": 4.92, "r": 2380.0, "y": 520.0, "s": 100.0}]
	for h in hero_rocks:
		var p := Vector3(cos(float(h["a"])) * float(h["r"]) * grow, float(h["y"]), sin(float(h["a"])) * float(h["r"]) * grow)
		var chunk := _sphere(float(h["s"]), p, float_rock, 7)
		chunk.scale = Vector3(1.25, 0.85, 1.05)
		_no_shadow(chunk)
		_bob.append({"n": chunk, "y": p.y, "f": 0.45, "a": 26.0, "p": float(h["a"])})
	for i in 10:
		var a := TAU * float(i) / 10.0 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(2050.0, 2700.0) * grow
		var s := rng.randf_range(50.0, 110.0)
		var p := Vector3(cos(a) * r, rng.randf_range(160.0, 620.0), sin(a) * r)
		var chunk := _sphere(s, p, float_rock, 7)
		chunk.scale = Vector3(1.2, 0.9, 1.0)
		_no_shadow(chunk)
		_bob.append({"n": chunk, "y": p.y, "f": rng.randf_range(0.5, 1.0), "a": rng.randf_range(18.0, 46.0), "p": rng.randf() * TAU})

	# 远方的云山
	var far := _alpha(Color("ffc8a8"), 0.12)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		var r := 5200.0 * grow
		var m := _sphere(1500.0, Vector3(cos(a) * r, -700.0, sin(a) * r), far, 8)
		m.scale = Vector3(1.6, 0.3, 1.6)
		_no_shadow(m)

	# 棋盘融合：金色镶边 + 云从边缘流过
	_no_shadow(_torus(1480.0 * grow, 1508.0 * grow, Vector3(0, 3.0, 0), _glow(Color("ffc06a"), 1.0), Vector3.ZERO))
	# 与棋盘同高的云带：让"悬空"在画面里成立
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.12
		var r := 1570.0 * grow
		var cloud := _sphere(rng.randf_range(160.0, 260.0), Vector3(cos(a) * r, rng.randf_range(-10.0, 50.0), sin(a) * r), _alpha(Color("ffe8d8"), 0.24), 8)
		cloud.scale = Vector3(1.9, 0.26, 1.35)
		_no_shadow(cloud)
		_drift.append({"n": cloud, "v": Vector3(-sin(a) * 12.0, 0, cos(a) * 12.0), "lim": Vector3(0, 0, 0)})
	for i in 18:
		var a := TAU * float(i) / 18.0
		var r := 1620.0 * grow
		var w := _alpha(Color("ffe6d2"), 0.10)
		var s := _sphere(rng.randf_range(90.0, 150.0), Vector3(cos(a) * r, 12.0, sin(a) * r), w, 8)
		s.scale = Vector3(1.6, 0.22, 1.0)
		_no_shadow(s)
		_drift.append({"n": s, "v": Vector3(cos(a + 1.57) * 10.0, 0, sin(a + 1.57) * 10.0), "lim": Vector3(2100.0, 0, 2100.0)})


# ---------------------------------------------------------------- 3 霜封冰湖

const ICE_CODE := """
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 ice_color : source_color = vec4(0.55, 0.72, 0.88, 1.0);
uniform vec4 crack_color : source_color = vec4(0.86, 0.97, 1.0, 1.0);
varying vec3 wpos;
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float nn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
		mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz * 0.0011;
	float n = nn(uv * 7.0) * 0.55 + nn(uv * 2.6) * 0.45;
	float crack = smoothstep(0.60, 0.66, n) * smoothstep(0.80, 0.72, n);
	float big = smoothstep(0.66, 0.70, nn(uv * 1.35 + vec2(11.0, 7.0)));
	float sheen = nn(uv * 1.4 + vec2(TIME * 0.02, 0.0));
	ALBEDO = mix(ice_color.rgb * 0.82, crack_color.rgb, crack * 0.9 + big * 0.35);
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	EMISSION = crack_color.rgb * (crack * 0.9 + big * 0.5) + ice_color.rgb * sheen * 0.14;
}
"""

const AURORA_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 col_a : source_color = vec4(0.35, 1.0, 0.72, 1.0);
uniform vec4 col_b : source_color = vec4(0.45, 0.68, 1.0, 1.0);
varying vec2 uv;
void vertex() {
	uv = UV;
}
void fragment() {
	float wob = sin(uv.x * 9.0 + TIME * 0.32) * 0.06 + sin(uv.x * 4.0 - TIME * 0.21) * 0.08;
	float band = smoothstep(0.18, 0.46, uv.y) * (1.0 - smoothstep(0.72, 0.98, uv.y));
	float ribbon = smoothstep(0.26, 0.02, abs(uv.y - 0.55 - wob));
	ALBEDO = mix(col_a.rgb, col_b.rgb, uv.x);
	ALPHA = band * ribbon * 0.45;
}
"""


func _frost() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311
	# 冰湖
	_no_shadow(_plane(12000.0, GY, _shader_mat(ICE_CODE)))
	# 冰面下的暗水色环，增加层次
	_no_shadow(_disc(3400.0 * grow, 2.0, GY - 2.0, _alpha(Color("2a5a7a"), 0.20), 40))

	# 远侧冰崖：一整面参差的崖壁把地平线封死，空间从"开阔冰原"变成"冰穴"
	var cliff := _mat(Color("7fa8c4"), 0.42)
	var cliff_dark := _mat(Color("4f7a9a"), 0.50)
	_arc_wall(2.34, 5.06, 1790.0 * grow, GY, 660.0, 170.0, cliff, 15, 0.34)
	_arc_wall(2.50, 4.90, 1690.0 * grow, GY, 360.0, 120.0, cliff_dark, 12, 0.40)
	# 崖壁中央的垂直冰隙：整场的唯一亮源与视线焦点
	for side in 2:
		var ca := 3.73 + 0.055 * (1.0 if side == 0 else -1.0)
		var cp := Vector3(cos(ca) * 1660.0 * grow, GY + 330.0, sin(ca) * 1660.0 * grow)
		var shard := _cone(70.0, 660.0, cp, _mat(Color("b8e4f6"), 0.25), 5)
		shard.rotation.z = 0.10 * (1.0 if side == 0 else -1.0)
	_no_shadow(_box(Vector3(10.0, 520.0, 70.0), Vector3(cos(3.73) * 1712.0, GY + 300.0, sin(3.73) * 1712.0), _glow(Color("a8f0ff"), 2.4), -3.73))
	_light(Vector3(cos(3.73) * 1600.0, 160.0, sin(3.73) * 1600.0), Color("9fe8ff"), 2.2, 900.0)

	# 冰峰：贴近边缘的大簇 + 中景散点
	var ice := _mat(Color("a8c8dc"), 0.32, 0.0)
	var ice_deep := _mat(Color("6f9ab8"), 0.42, 0.0)
	var hero_spikes := [{"a": 2.28, "r": 1592.0, "h": 520.0}, {"a": 3.73, "r": 1604.0, "h": 585.0},
		{"a": 5.12, "r": 1588.0, "h": 470.0}, {"a": 1.20, "r": 1570.0, "h": 360.0},
		{"a": 2.95, "r": 1610.0, "h": 420.0}, {"a": 4.45, "r": 1600.0, "h": 400.0}]
	for h in hero_spikes:
		var a: float = h["a"]
		var dist: float = h["r"] * grow
		var hh: float = h["h"]
		var p := Vector3(cos(a) * dist, GY + hh * 0.5, sin(a) * dist)
		var cone := _cone(96.0, hh, p, ice, 6)
		cone.rotation.z = rng.randf_range(-0.06, 0.06)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_no_shadow(_cone(52.0, hh * 0.66, p + Vector3(90.0, -hh * 0.16, 40.0), ice_deep, 6))
	for i in 12:
		var a := TAU * float(i) / 12.0 + rng.randf_range(-0.12, 0.12)
		if _blocked(a):
			continue
		var dist := rng.randf_range(1850.0, 2600.0) * grow
		var hh := rng.randf_range(240.0, 560.0)
		var p := Vector3(cos(a) * dist, GY + hh * 0.5, sin(a) * dist)
		var cone := _cone(rng.randf_range(42.0, 84.0), hh, p, ice if i % 2 == 0 else ice_deep, 6)
		cone.rotation.z = rng.randf_range(-0.08, 0.08)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 冻结的树
	var frozen_leaf := _mat(Color("e8f6ff"), 0.6)
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.5
		if _blocked(a):
			continue
		var dist := rng.randf_range(2300.0, 3000.0) * grow
		var p := Vector3(cos(a) * dist, GY, sin(a) * dist)
		var h := rng.randf_range(340.0, 520.0)
		_cyl(7.0, 16.0, h * 0.5, p + Vector3(0, h * 0.25, 0), _mat(Color("5a4a44"), 0.9), 6)
		for c in 3:
			_sphere(rng.randf_range(60.0, 96.0), p + Vector3(rng.randf_range(-30, 30), h * 0.55 + c * 46.0, rng.randf_range(-30, 30)), frozen_leaf, 8)
	# 冰拱
	var arch_mat := _mat(Color("b8dcee"), 0.25)
	for k in 2:
		var a := 1.1 + float(k) * 2.6
		var r := 2200.0 * grow
		var c := Vector3(cos(a) * r, GY, sin(a) * r)
		for side in 2:
			var dir := Vector3(-sin(a), 0, cos(a)) * (130.0 * (1.0 if side == 0 else -1.0))
			_no_shadow(_box(Vector3(64.0, 380.0, 64.0), c + dir + Vector3(0, 190.0, 0), arch_mat, -a))
		_no_shadow(_box(Vector3(330.0, 62.0, 80.0), c + Vector3(0, 400.0, 0), arch_mat, -a))

	# 冰盖：只在远半圈压下来的洞顶，把天空遮掉大半，空间变得封闭
	var roof := _mat(Color("5f88a8"), 0.55)
	_arc_wall(1.86, 5.34, 2420.0 * grow, GY + 800.0, 90.0, 1250.0, roof, 16, 0.16)
	# 洞顶垂冰：内缘一排倒挂冰锥，压低画面的上沿
	var icicle := _mat(Color("cfeaf8"), 0.30)
	for i in 14:
		var a := 1.92 + 3.34 * float(i) / 13.0
		if _blocked(a):
			continue
		var r := (1840.0 + rng.randf_range(-40.0, 60.0)) * grow
		var hh := rng.randf_range(140.0, 340.0)
		var ic := _cone(rng.randf_range(22.0, 44.0), hh, Vector3(cos(a) * r, GY + 800.0 - hh * 0.5, sin(a) * r), icicle, 5)
		ic.rotation.z = PI
		_no_shadow(ic)

	# 冰脊：两条斜穿冰面的挤压脊，把同心圆构图切成斜向
	for ridge in 2:
		var base_a := 1.95 + float(ridge) * 1.52
		for i in 7:
			var a := base_a + float(i) * 0.105
			var r := (1600.0 + float(i) * 132.0) * grow
			var slab := _box(Vector3(214.0, 66.0, 76.0), Vector3(cos(a) * r, GY + 26.0, sin(a) * r), ice_deep, -a + 0.5)
			slab.rotation.z = rng.randf_range(-0.30, 0.30)
			slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 雪堆
	var snow := _mat(Color("eef8ff"), 0.95)
	for i in 20:
		var a := TAU * float(i) / 20.0 + rng.randf_range(-0.15, 0.15)
		if _blocked(a):
			continue
		var r := rng.randf_range(1560.0, 1820.0) * grow
		var m := _sphere(rng.randf_range(130.0, 240.0), Vector3(cos(a) * r, GY - 30.0, sin(a) * r), snow, 9)
		m.scale = Vector3(1.7, 0.30, 1.5)
		_no_shadow(m)

	# 棋盘融合：边缘冰晶冠
	for i in 30:
		var a := TAU * float(i) / 30.0
		var r := (1478.0 + rng.randf_range(-8.0, 16.0)) * grow
		var h := rng.randf_range(46.0, 142.0)
		var crystal := _cone(rng.randf_range(9.0, 18.0), h, Vector3(cos(a) * r, h * 0.5 + 2.0, sin(a) * r), ice, 5)
		crystal.rotation.z = rng.randf_range(-0.16, 0.16)
		_no_shadow(crystal)
	# 踏石积雪
	for i in 24:
		var a := TAU * float(i) / 24.0 + 0.1
		var r := rng.randf_range(420.0, 1400.0) * grow
		var cap := _sphere(rng.randf_range(20.0, 44.0), Vector3(cos(a) * r, 6.5, sin(a) * r), snow, 6)
		cap.scale = Vector3(1.4, 0.16, 1.2)
		_no_shadow(cap)


# ---------------------------------------------------------------- 4 熔火裂谷

const LAVA_CODE := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 hot : source_color = vec4(1.0, 0.62, 0.14, 1.0);
uniform vec4 deep : source_color = vec4(0.72, 0.12, 0.02, 1.0);
uniform vec4 crust : source_color = vec4(0.16, 0.06, 0.05, 1.0);
varying vec3 wpos;
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}
float nn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
		mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz * 0.00085;
	float a = nn(uv + vec2(TIME * 0.035, TIME * 0.018));
	float b = nn(uv * 2.6 - vec2(TIME * 0.052, TIME * 0.024));
	float v = a * 0.66 + b * 0.34;
	vec3 c = mix(deep.rgb, hot.rgb, smoothstep(0.38, 0.86, v));
	c = mix(crust.rgb, c, smoothstep(0.30, 0.52, v));
	ALBEDO = c;
	EMISSION = c * 1.25;
}
"""


func _ember() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5519
	# 熔岩：贴着广场底部，从边缘就能看见流动的光
	_no_shadow(_plane(14000.0, -84.0, _shader_mat(LAVA_CODE)))

	# 玄武岩柱：从熔岩里立起来，顶面略低于广场
	var basalt := _mat(Color("2e2626"), 0.92)
	var basalt_top := _mat(Color("3a3030"), 0.9)

	# 峡谷两壁：左右各一道纵向岩壁，把广场夹在中间，构图从"环形广场"变成"桥"
	_arc_wall(1.02, 1.98, 1770.0 * grow, -84.0, 360.0, 230.0, basalt, 9, 0.26)
	_arc_wall(4.30, 5.28, 1770.0 * grow, -84.0, 330.0, 230.0, basalt, 9, 0.30)
	# 桥身：从广场远侧继续向外延伸，下承两座桥墩，脚下就是熔岩
	var bridge := _mat(Color("4a3a34"), 0.85)
	_causeway(3.73, 1500.0 * grow, 2380.0 * grow, 560.0, 6.0, bridge, 9)
	for i in 3:
		var br := (1760.0 + float(i) * 240.0) * grow
		_cyl(92.0, 160.0, 240.0, Vector3(cos(3.73) * br, -120.0, sin(3.73) * br), basalt, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# 远端火山口壁 + 两道熔岩瀑布：给出明确的地平线与焦点
	_arc_wall(2.52, 4.96, 2980.0 * grow, -84.0, 430.0, 320.0, basalt, 14, 0.24)
	for k in 2:
		var fa := 3.30 + float(k) * 0.72
		var fp := Vector3(cos(fa) * 2840.0 * grow, -84.0 + 260.0, sin(fa) * 2840.0 * grow)
		_no_shadow(_box(Vector3(26.0, 420.0, 110.0), fp, _glow(Color("ff8a3a"), 2.2), -fa))
	for i in 18:
		var a := TAU * float(i) / 18.0 + rng.randf_range(-0.14, 0.14)
		if _blocked(a):
			continue
		var r := rng.randf_range(1560.0, 2320.0) * grow
		var top := rng.randf_range(-46.0, -18.0)
		var h := top + 84.0
		var cr := rng.randf_range(70.0, 140.0)
		_cyl(cr * 0.92, cr, h, Vector3(cos(a) * r, -84.0 + h * 0.5, sin(a) * r), basalt, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_cyl(cr * 0.98, cr * 0.9, 8.0, Vector3(cos(a) * r, top, sin(a) * r), basalt_top, 6)
	# 近景大石柱：撑起右侧与左下的体量
	var hero_pillars := [{"a": 2.30, "r": 1630.0}, {"a": 5.10, "r": 1650.0}, {"a": 3.73, "r": 1780.0}]
	for hp in hero_pillars:
		var ha: float = hp["a"]
		var hr: float = hp["r"] * grow
		_cyl(150.0, 190.0, 96.0, Vector3(cos(ha) * hr, -36.0, sin(ha) * hr), basalt, 7).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_cyl(130.0, 160.0, 16.0, Vector3(cos(ha) * hr, 8.0, sin(ha) * hr), basalt_top, 7)

	# 熔岩喷口
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.55
		var r := rng.randf_range(1900.0, 2800.0) * grow
		var p := Vector3(cos(a) * r, -66.0, sin(a) * r)
		_no_shadow(_cone(rng.randf_range(90.0, 150.0), rng.randf_range(80.0, 140.0), p, basalt, 7))
		var glow := _sphere(rng.randf_range(34.0, 58.0), p + Vector3(0, 80.0, 0), _glow(Color("ff7a2c"), 2.4), 7)
		_no_shadow(glow)
		_pulse.append({"n": glow, "base": 1.0, "amp": 0.16, "f": 2.4 + float(i) * 0.3, "p": float(i)})
	# 边缘喷火口：左右两侧各一，给画面加两根火柱
	for g in 2:
		var ga: float = [1.25, 5.15][g]
		var gr := 1555.0 * grow
		var gp := Vector3(cos(ga) * gr, -30.0, sin(ga) * gr)
		_no_shadow(_cyl(46.0, 70.0, 60.0, gp, basalt, 7))
		var fire := _cone(52.0, 210.0, gp + Vector3(0, 130.0, 0), _glow(Color("ff8636"), 2.6), 7)
		_no_shadow(fire)
		_pulse.append({"n": fire, "base": 1.0, "amp": 0.26, "f": 4.2, "p": float(g)})
		_light(gp + Vector3(0, 190.0, 0), Color("ff7a2c"), 1.7, 900.0)

	# 烟柱
	var smoke := _alpha(Color("3a2e2c"), 0.20, false)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.2
		var r := rng.randf_range(2200.0, 3000.0) * grow
		var p := Vector3(cos(a) * r, 300.0, sin(a) * r)
		var col := _sphere(180.0, p, smoke, 8)
		col.scale = Vector3(0.7, 3.4, 0.7)
		_no_shadow(col)
		_drift.append({"n": col, "v": Vector3(0, 9.0, 0), "lim": Vector3(0, 0, 0)})

	# 黑曜石尖刺
	var obsidian := _mat(Color("1c1418"), 0.42, 0.3)
	for i in 12:
		var a := TAU * float(i) / 12.0 + rng.randf_range(-0.2, 0.2)
		if _blocked(a):
			continue
		var r := rng.randf_range(1600.0, 2100.0) * grow
		var h := rng.randf_range(90.0, 240.0)
		var shard := _cone(rng.randf_range(26.0, 52.0), h, Vector3(cos(a) * r, h * 0.5, sin(a) * r), obsidian, 5)
		shard.rotation.z = rng.randf_range(-0.22, 0.22)
		_no_shadow(shard)

	# 地底光：熔岩把广场底部照亮
	_light(Vector3(0, -110.0, 0), Color("ff5c22"), 3.0, 2500.0)
	_light(Vector3(1500.0, -130.0, 900.0), Color("ff7a2c"), 1.8, 1500.0)
	_light(Vector3(-1400.0, -130.0, -1100.0), Color("ff6a28"), 1.6, 1400.0)

	# 棋盘融合：边缘裂缝透光 + 两道斜切广场的熔岩裂口
	for i in 26:
		var a := TAU * float(i) / 26.0 + 0.05
		var r := 1478.0 * grow
		var crack := _box(Vector3(48.0, 4.0, 6.0), Vector3(cos(a) * r, 3.0, sin(a) * r), _glow(Color("ff8a34"), 1.8), -a)
		_no_shadow(crack)
		crack.rotation.z = 0.0
	for k in 2:
		var a := 2.06 + float(k) * 2.86
		var p := Vector3(cos(a), 0, sin(a)) * (1330.0 * grow)
		_no_shadow(_box(Vector3(280.0, 6.0, 46.0), Vector3(p.x, 9.4, p.z), _mat(Color("1c1418"), 0.5), -a + 0.42))
		_no_shadow(_box(Vector3(250.0, 4.0, 12.0), Vector3(p.x, 10.6, p.z), _glow(Color("ff7a2c"), 2.0), -a + 0.42))


# ---------------------------------------------------------------- 5 翠玉雨林

func _jade() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	# 两级台地：广场是一座高出泻湖两百多单位的雨林台地，水在脚下而不在四周
	var lagoon := _mat(Color("14484a"), 0.08, 0.40)
	lagoon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lagoon.albedo_color = Color(0.07, 0.28, 0.26, 0.92)
	lagoon.emission_enabled = true
	lagoon.emission = Color("1f8a80")
	lagoon.emission_energy_multiplier = 0.12
	_plane(15000.0, -210.0, lagoon)
	_no_shadow(_disc(4600.0 * grow, 4.0, -206.0, lagoon, 52))
	# 台地岩壁：广场外沿直接垂落进水里
	var mesa := _mat(Color("42543f"), 0.96)
	var moss := _mat(Color("5f8a50"), 0.95)
	_cyl(1556.0 * grow, 1636.0 * grow, 214.0, Vector3(0, -108.0, 0), mesa, 56)
	_no_shadow(_torus(1524.0 * grow, 1584.0 * grow, Vector3(0, -6.0, 0), moss, Vector3.ZERO))

	# 远端雨林崖壁：唯一焦点是一座从崖顶跌进泻湖的瀑布
	var cliff_mat := _mat(Color("38483a"), 0.96)
	_arc_wall(2.44, 5.04, 2080.0 * grow, -210.0, 800.0, 280.0, cliff_mat, 14, 0.26)
	var fall := _glow(Color("d8fff6"), 0.55)
	_no_shadow(_box(Vector3(26.0, 700.0, 190.0), Vector3(cos(3.73) * 1900.0, -210.0 + 350.0, sin(3.73) * 1900.0), fall, -3.73))
	_no_shadow(_box(Vector3(22.0, 600.0, 84.0), Vector3(cos(3.58) * 1930.0, -210.0 + 300.0, sin(3.58) * 1930.0), fall, -3.58))
	for i in 9:
		var t := float(i) / 8.0
		var mist := _sphere(rng.randf_range(70.0, 140.0),
			Vector3(cos(3.73) * 1860.0 + rng.randf_range(-140, 140), -170.0 + t * 80.0,
				sin(3.73) * 1860.0 + rng.randf_range(-140, 140)), _alpha(Color("d8fff4"), 0.15), 7)
		mist.scale = Vector3(1.7, 0.7, 1.3)
		_no_shadow(mist)
	_light(Vector3(cos(3.73) * 1760.0, 240.0, sin(3.73) * 1760.0), Color("b8ffe8"), 1.6, 1100.0)
	# 浮萍
	for i in 24:
		var a := TAU * float(i) / 24.0 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(1700.0, 1970.0) * grow
		var pad := _cyl(rng.randf_range(40.0, 80.0), rng.randf_range(40.0, 80.0), 2.0, Vector3(cos(a) * r, -204.0, sin(a) * r), _mat(Color("4f8a3f"), 1.0), 9)
		_no_shadow(pad)

	# 石柱廊
	var stone := _mat(Color("9a9a84"), 0.9)
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.24
		if _blocked(a):
			continue
		var r := 1665.0 * grow
		var h := rng.randf_range(260.0, 430.0)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		_no_shadow(_box(Vector3(96.0, 22.0, 96.0), p + Vector3(0, 11.0, 0), stone, -a))
		_cyl(36.0, 46.0, h, p + Vector3(0, h * 0.5 + 22.0, 0), stone, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if i % 2 == 0:
			_no_shadow(_box(Vector3(120.0, 26.0, 120.0), p + Vector3(0, h + 34.0, 0), stone, -a))
		# 藤蔓
		for v in 2:
			var vine := _box(Vector3(8.0, h * 0.7, 8.0), p + Vector3(rng.randf_range(-40, 40), h * 0.45, rng.randf_range(-40, 40)), moss, -a)
			_no_shadow(vine)

	# 巨树：只种在远半圈，避免树冠怼到镜头糊成一块
	for i in 7:
		var a := 2.00 + 2.70 * float(i) / 6.0
		var dist := rng.randf_range(1900.0, 2200.0) * grow
		_tree(Vector3(cos(a) * dist, -2.0, sin(a) * dist), rng.randf_range(620.0, 900.0), rng, arena._leaf_a, arena._leaf_b, arena._wood)

	# 近岸蕨叶：贴着广场边缘向外张开，深绿剪影让雨林一眼可辨
	var fern := _mat(Color("2f6a34"), 0.95)
	for i in 26:
		var a := TAU * float(i) / 26.0 + 0.09
		var r := (1520.0 + float(i % 3) * 26.0) * grow
		var blade := _cone(34.0, rng.randf_range(120.0, 210.0), Vector3(cos(a) * r, 6.0, sin(a) * r), fern, 5)
		blade.rotation = Vector3(rng.randf_range(0.5, 0.9), -a, rng.randf_range(-0.2, 0.2))
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 残破雕像
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.66
		var r := 1555.0 * grow
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		_no_shadow(_box(Vector3(130.0, 60.0, 130.0), p + Vector3(0, 30.0, 0), stone, -a))
		_no_shadow(_box(Vector3(80.0, 150.0, 80.0), p + Vector3(0, 135.0, 0), stone, -a))
		_no_shadow(_sphere(52.0, p + Vector3(0, 236.0, 0), moss, 8))

	# 树冠：远侧高位压下来的叶团，在画面上沿形成天然遮幅
	for i in 10:
		var a := 2.00 + 2.70 * float(i) / 9.0
		if _blocked(a):
			continue
		var r := (1680.0 + rng.randf_range(-60.0, 200.0)) * grow
		var leaf := _sphere(rng.randf_range(180.0, 300.0),
			Vector3(cos(a) * r, rng.randf_range(520.0, 760.0), sin(a) * r), arena._leaf_b, 8)
		leaf.scale = Vector3(1.5, 0.65, 1.3)
		_no_shadow(leaf)

	# 前景框叶：近侧左下方压过来的深色叶团，为构图加一层前景遮挡
	var frame_leaf := _mat(Color("2b5530"), 0.95)
	for i in 5:
		var a := 4.86 + float(i) * 0.16
		var r := (1720.0 + float(i) * 55.0) * grow
		var fl := _sphere(rng.randf_range(210.0, 300.0),
			Vector3(cos(a) * r, rng.randf_range(70.0, 210.0), sin(a) * r), frame_leaf, 8)
		fl.scale = Vector3(1.45, 0.52, 1.25)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 板根：粗壮的气根从广场外沿爬上石面，成为"棋盘长在林子里"的实证
	var root_mat := _mat(Color("4a3a24"), 0.95)
	for i in 7:
		var a := 1.45 + 3.90 * float(i) / 6.0
		var r := 1510.0 * grow
		var root := _cyl(30.0, 62.0, 190.0, Vector3(cos(a) * r, 70.0, sin(a) * r), root_mat, 6)
		root.rotation.y = -a
		root.rotation.z = 0.95
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 棋盘融合：藤蔓爬上广场边缘 + 萤火
	var vine_mat := _mat(Color("4f8040"), 0.95)
	for i in 28:
		var a := TAU * float(i) / 28.0
		var r := 1492.0 * grow
		var h := rng.randf_range(16.0, 62.0)
		var v := _box(Vector3(10.0, h, 10.0), Vector3(cos(a) * r, 4.0 - h * 0.5, sin(a) * r), vine_mat, -a)
		_no_shadow(v)
	for i in 14:
		var a := TAU * float(i) / 14.0 + 0.21
		var r := rng.randf_range(1580.0, 2100.0) * grow
		var f := _sphere(8.0, Vector3(cos(a) * r, rng.randf_range(30.0, 200.0), sin(a) * r), _glow(Color("b6ff8a"), 1.6), 5)
		_no_shadow(f)
		_bob.append({"n": f, "y": f.position.y, "f": rng.randf_range(0.8, 1.6), "a": rng.randf_range(10.0, 34.0), "p": rng.randf() * TAU})
	_light(Vector3(0, 520.0, 0), Color("a8ffc0"), 0.9, 2400.0)


# ---------------------------------------------------------------- 6 虚空星海

func _void() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	# 没有地面：广场是一块被切下来的漂浮石板，底缘只剩一圈断裂的岩齿
	var rock := _mat(Color("2a2438"), 0.9)
	var shard_mat := _mat(Color("342c4a"), 0.85)
	for i in 18:
		var a := TAU * float(i) / 18.0 + 0.1
		var r := rng.randf_range(1300.0, 1490.0) * grow
		var s := rng.randf_range(60.0, 150.0)
		var shard := _cone(s * 0.60, rng.randf_range(120.0, 330.0),
			Vector3(cos(a) * r, -140.0, sin(a) * r), shard_mat, 5)
		shard.rotation.z = PI
		_no_shadow(shard)
	_arc_wall(0.0, TAU, 1492.0 * grow, -58.0, 56.0, 64.0, rock, 44, 0.50)

	# 巨环：一道断裂的星环从远侧斜穿画面，是全场的构图主轴
	var ring_holder := Node3D.new()
	ring_holder.position = Vector3(0, 360.0, 0)
	ring_holder.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(26.0), deg_to_rad(-14.0))
	add_child(ring_holder)
	var ring_r := 2300.0 * grow
	var ring_mat := _glow(Color("9a7cff"), 1.15)
	var seg_count := 26
	var seg_len := ring_r * TAU / float(seg_count) * 0.94
	for i in seg_count:
		if i >= 8 and i <= 12:
			continue
		var a := TAU * float(i) / float(seg_count)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(64.0, 64.0, seg_len)
		seg.mesh = bm
		seg.material_override = ring_mat
		seg.position = Vector3(cos(a) * ring_r, 0.0, sin(a) * ring_r)
		seg.rotation.y = -a
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_holder.add_child(seg)
		if i % 3 == 0:
			var stud := _sphere(46.0, Vector3.ZERO, _glow(Color("d8c8ff"), 1.8), 6)
			stud.reparent(seg)
			stud.position = Vector3.ZERO
			_pulse.append({"n": stud, "base": 1.0, "amp": 0.28, "f": 1.4, "p": float(i)})

	# 远方黑洞：吸积盘是画面里唯一的暖色亮点
	var bh_a := 3.73
	var bh_p := Vector3(cos(bh_a) * 4600.0, 620.0, sin(bh_a) * 4600.0)
	_no_shadow(_sphere(360.0, bh_p, _mat(Color("05030a"), 1.0), 24))
	_no_shadow(_torus(400.0, 620.0, bh_p, _glow(Color("ffb27a"), 1.6), Vector3(PI * 0.5, -bh_a, 0)))
	_no_shadow(_torus(690.0, 748.0, bh_p, _glow(Color("8a6cff"), 1.3), Vector3(PI * 0.5, -bh_a, 0)))

	# 星云层
	var neb_a := _alpha(Color("6a4cff"), 0.10)
	var neb_b := _alpha(Color("2a6aff"), 0.09)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var r := rng.randf_range(2600.0, 4200.0) * grow
		var m := _sphere(rng.randf_range(900.0, 1600.0), Vector3(cos(a) * r, rng.randf_range(-1100.0, -600.0), sin(a) * r), neb_a if i % 2 == 0 else neb_b, 8)
		m.scale = Vector3(1.8, 0.16, 1.8)
		_no_shadow(m)

	# 环绕浮岩
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(1760.0, 2700.0) * grow
		var s := rng.randf_range(46.0, 120.0)
		var m := _sphere(s, Vector3(0, 0, 0), shard_mat, 6)
		m.scale = Vector3(1.2, 0.9, 1.05)
		_no_shadow(m)
		_orbit.append({"n": m, "r": r, "a": a, "s": 0.03 + rng.randf() * 0.04, "y": rng.randf_range(-140.0, 520.0), "b": rng.randf_range(0.4, 0.9), "bp": rng.randf() * TAU})

	# 虚空裂隙
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.9
		var dist := 3400.0 * grow
		var p := Vector3(cos(a) * dist, 620.0 + float(k) * 140.0, sin(a) * dist)
		var rift := _torus(230.0, 260.0, p, _glow(Color("b48cff"), 1.8), Vector3(PI * 0.5, -a, 0))
		_no_shadow(rift)
		_spin.append({"n": rift, "axis": "z", "s": 0.20 + float(k) * 0.05})
		var core := _cyl(225.0, 225.0, 3.0, p, _mat(Color("120c1e"), 1.0), 32)
		core.rotation = Vector3(PI * 0.5, -a, 0)
		_no_shadow(core)

	# 棋子台面：符文线路
	var rune := _glow(Color("a58cff"), 1.4)
	for k in 3:
		var rr := (720.0 + float(k) * 300.0) * grow
		_no_shadow(_torus(rr - 3.0, rr + 3.0, Vector3(0, 2.0, 0), rune, Vector3.ZERO))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var r := 1400.0 * grow
		var stone := _box(Vector3(36.0, 90.0, 36.0), Vector3(cos(a) * r, 56.0, sin(a) * r), _mat(Color("3a3050"), 0.7), -a)
		_no_shadow(stone)
		_bob.append({"n": stone, "y": 56.0, "f": 0.7, "a": 12.0, "p": float(i)})
		_no_shadow(_sphere(14.0, Vector3(cos(a) * r, 112.0, sin(a) * r), rune, 6))

	_light(Vector3(0, 260.0, 0), Color("9a7cff"), 1.2, 2200.0)
	_light(Vector3(0, -220.0, 0), Color("5a3cff"), 1.4, 1800.0)


# ---------------------------------------------------------------- 7 沙海神庙

func _dune() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4423
	var sand := _mat(Color(th.get("ground", "d8b878")), 1.0)
	var sand_dark := _mat(Color("8e6a38"), 1.0)
	_plane(13000.0, GY, sand)

	# 中轴阶梯金字塔：全场唯一的对称体量，神道从塔脚直指广场
	var pyramid := _mat(Color("b59a6e"), 0.92)
	var pyr_a := 3.73
	var pyr_dir := Vector3(cos(pyr_a), 0, sin(pyr_a))
	var pyr_c := pyr_dir * (2920.0 * grow)
	for tier in 5:
		var half := (940.0 - float(tier) * 142.0) * grow
		var y := GY + 62.0 + float(tier) * 94.0
		var step := _box(Vector3(half * 2.0, 94.0, half * 2.0), pyr_c + Vector3(0, y, 0), pyramid, -pyr_a)
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# 塔顶祭台与长明光点
	var top_y := GY + 62.0 + 5.0 * 94.0
	_no_shadow(_box(Vector3(320.0, 58.0, 320.0), pyr_c + Vector3(0, top_y + 29.0, 0), pyramid, -pyr_a))
	_no_shadow(_sphere(22.0, pyr_c + Vector3(0, top_y + 72.0, 0), _glow(Color("ffd88a"), 1.9), 7))
	# 神道：广场到塔脚的石板路，两侧跪立方尖碑
	_causeway(pyr_a, 1500.0 * grow, 2000.0 * grow, 300.0, GY + 8.0, _mat(Color("c8b084"), 0.95), 8)
	for side in 2:
		for k in 3:
			var off := Vector3(-sin(pyr_a), 0, cos(pyr_a)) * (300.0 * (1.0 if side == 0 else -1.0))
			var p := pyr_dir * ((1600.0 + float(k) * 160.0) * grow) + off
			var hh := 186.0 - float(k) * 24.0
			_no_shadow(_box(Vector3(54.0, hh, 54.0), Vector3(p.x, GY + hh * 0.5, p.z), _mat(Color("9a7c50"), 0.9), -pyr_a))

	# 沙丘：近景用锥形沙脊（有明确的向光/背光面），中远景用扁球
	for ring_i in 3:
		var count := 9 + ring_i * 4
		var base_r := (1700.0 + float(ring_i) * 560.0) * grow
		for i in count:
			var a := TAU * float(i) / float(count) + rng.randf_range(-0.09, 0.09)
			if _blocked(a) and ring_i == 0:
				continue
			var r := base_r + rng.randf_range(-140.0, 140.0)
			var s := rng.randf_range(280.0, 520.0) * (1.0 + float(ring_i) * 0.3)
			var mat_i: Material = sand if i % 2 == 0 else sand_dark
			if ring_i < 2:
				var h := s * rng.randf_range(0.42, 0.62)
				var dune := _cone(s, h, Vector3(cos(a) * r, GY - 40.0 + h * 0.5, sin(a) * r), mat_i, 7)
				dune.scale = Vector3(1.9, 1.0, 1.35)
				dune.rotation.y = rng.randf() * TAU
				dune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				var m := _sphere(s, Vector3(cos(a) * r, GY - s * 0.72, sin(a) * r), mat_i, 8)
				m.scale = Vector3(1.75, 0.30, 1.5)
				_no_shadow(m)

	# 散落黑砂岩：给大片浅沙压出重色点
	var basalt := _mat(Color("5a4630"), 0.92)
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.12, 0.12)
		if _blocked(a):
			continue
		var r := rng.randf_range(1560.0, 2100.0) * grow
		var rock := _sphere(rng.randf_range(38.0, 86.0), Vector3(cos(a) * r, GY + 16.0, sin(a) * r), basalt, 6)
		rock.scale = Vector3(1.3, 0.75, 1.05)
		rock.rotation.y = rng.randf() * TAU
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 半埋方尖碑：两根主碑贴着广场边缘，逆光立成剪影
	var stone := _mat(Color("9a7c50"), 0.9)
	var hero_obs := [{"a": 2.30, "r": 1600.0, "h": 470.0}, {"a": 5.10, "r": 1640.0, "h": 410.0}]
	for h in hero_obs:
		var a: float = h["a"]
		var r: float = float(h["r"]) * grow
		var hh: float = h["h"]
		var p := Vector3(cos(a) * r, GY + hh * 0.5 - 60.0, sin(a) * r)
		var ob := _cone(96.0, hh, p, stone, 4)
		ob.rotation.y = rng.randf() * TAU
		ob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_no_shadow(_box(Vector3(190.0, 40.0, 190.0), p + Vector3(0, -hh * 0.5 + 22.0, 0), stone, 0.0))
		_no_shadow(_sphere(26.0, p + Vector3(0, hh * 0.5 - 12.0, 0), _glow(Color("ffcf7a"), 1.4), 6))
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.35
		if _blocked(a):
			continue
		var r := rng.randf_range(1780.0, 2150.0) * grow
		var hh := rng.randf_range(360.0, 620.0)
		var p := Vector3(cos(a) * r, GY + hh * 0.5 - 80.0, sin(a) * r)
		var ob := _cyl(26.0, 62.0, hh, p, stone, 4)
		ob.rotation.y = rng.randf() * TAU
		ob.rotation.z = rng.randf_range(-0.07, 0.07)
		ob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_no_shadow(_box(Vector3(96.0, 26.0, 96.0), p + Vector3(0, -hh * 0.5 + 18.0, 0), stone, 0.0))

	# 断柱
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.1
		if _blocked(a):
			continue
		var r := rng.randf_range(1800.0, 2100.0) * grow
		var h := rng.randf_range(90.0, 320.0)
		_cyl(34.0, 42.0, h, Vector3(cos(a) * r, GY + h * 0.5, sin(a) * r), stone, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# 残墙
	for k in 4:
		var a := TAU * float(k) / 4.0 + 1.2
		if _blocked(a):
			continue
		var r := 2600.0 * grow
		var p := Vector3(cos(a) * r, GY, sin(a) * r)
		var w := rng.randf_range(420.0, 720.0)
		var hh := rng.randf_range(120.0, 240.0)
		_no_shadow(_box(Vector3(w, hh, 60.0), p + Vector3(0, hh * 0.5, 0), stone, -a))
		for t in 5:
			_no_shadow(_box(Vector3(60.0, 46.0, 60.0), p + Vector3(-w * 0.4 + float(t) * w * 0.2, hh + 23.0, 0), stone, -a))

	# 棋盘融合：沙堆漫上边缘
	for i in 18:
		var a := TAU * float(i) / 18.0 + 0.17
		var r := 1470.0 * grow
		var m := _sphere(rng.randf_range(70.0, 130.0), Vector3(cos(a) * r, -2.0, sin(a) * r), sand, 8)
		m.scale = Vector3(1.5, 0.30, 1.4)
		_no_shadow(m)
		# 沙脊
		var ridge := _box(Vector3(40.0, 3.0, 220.0), Vector3(cos(a) * (1360.0 * grow), 5.0, sin(a) * (1360.0 * grow)), sand_dark, -a)
		_no_shadow(ridge)


# ---------------------------------------------------------------- 8 齿轮高塔

func _clock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8803
	var brass := _mat(Color("b07a3c"), 0.42, 0.75)
	var brass_dark := _mat(Color("6e4a24"), 0.55, 0.65)
	var iron := _mat(Color("3a3028"), 0.7, 0.4)

	# 黄铜地板
	_no_shadow(_disc(4200.0 * grow, 12.0, GY, brass_dark, 52))
	_no_shadow(_disc(3600.0 * grow, 8.0, GY + 5.0, _mat(Color("8a5c2c"), 0.6, 0.5), 52))
	for k in 3:
		var rr := (1500.0 + float(k) * 700.0) * grow
		var ring := _torus(rr - 14.0, rr + 14.0, Vector3(0, GY + 12.0, 0), brass, Vector3.ZERO)
		_no_shadow(ring)

	# 钟楼内壁：远侧一圈黄铜板墙，把天空彻底关在外面，空间变成真正的室内
	var wall_mat := _mat(Color("5a4426"), 0.62, 0.55)
	_arc_wall(1.62, 5.10, 1880.0 * grow, GY, 780.0, 110.0, wall_mat, 20, 0.05)
	# 三段拱窗：唯一的外部光，等距错开
	var win_glow := _glow(Color("ffcf8a"), 1.5)
	for k in 3:
		var wa := 2.28 + float(k) * 0.98
		var wp := Vector3(cos(wa) * 1818.0 * grow, GY + 470.0, sin(wa) * 1818.0 * grow)
		_no_shadow(_box(Vector3(14.0, 400.0, 190.0), wp, win_glow, -wa))
		_no_shadow(_box(Vector3(22.0, 40.0, 250.0), wp + Vector3(0, 220.0, 0), brass, -wa))
	# 天顶齿轮环：远半圈压下来的齿轮，封住画面上沿
	var ceil_holder := Node3D.new()
	ceil_holder.position = Vector3(0, GY + 1010.0, 0)
	add_child(ceil_holder)
	for i in 16:
		var a := 1.62 + 3.48 * float(i) / 15.0
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(150.0, 96.0, 320.0)
		tooth.mesh = bm
		tooth.material_override = brass_dark
		tooth.position = Vector3(cos(a) * 1520.0 * grow, 0.0, sin(a) * 1520.0 * grow)
		tooth.rotation.y = -a
		tooth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ceil_holder.add_child(tooth)
	_spin.append({"n": ceil_holder, "axis": "y", "s": 0.05})

	# 巨摆：从远侧天顶垂到广场边缘，缓慢摆动，是全场唯一的大幅动态
	var pen := Node3D.new()
	pen.position = Vector3(cos(2.62) * 1700.0 * grow, GY + 980.0, sin(2.62) * 1700.0 * grow)
	add_child(pen)
	var rod := MeshInstance3D.new()
	var rcm := CylinderMesh.new()
	rcm.top_radius = 16.0
	rcm.bottom_radius = 16.0
	rcm.height = 620.0
	rcm.radial_segments = 8
	rod.mesh = rcm
	rod.material_override = iron
	rod.position = Vector3(0, -310.0, 0)
	pen.add_child(rod)
	var bob := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 96.0
	bsm.height = 192.0
	bsm.radial_segments = 14
	bsm.rings = 7
	bob.mesh = bsm
	bob.material_override = brass
	bob.position = Vector3(0, -620.0, 0)
	pen.add_child(bob)
	_sway.append({"n": pen, "f": 1.10, "a": 0.30, "p": 0.0, "axis": "z"})

	# 地面齿轮（转动）：齿露在地板上，转动可见
	_gear_floor(1750.0 * grow, GY + 14.0, 28, brass, 0.10)
	_gear_floor(2500.0 * grow, GY + 14.0, 36, brass_dark, -0.07)
	_gear_floor(3200.0 * grow, GY + 14.0, 44, brass, 0.05)

	# 立式巨齿轮：面向中心，绕自身轴旋转
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.7
		var r := rng.randf_range(2050.0, 2400.0) * grow
		var y := rng.randf_range(520.0, 1000.0)
		_gear_wall(a, r, y, rng.randf_range(300.0, 520.0), brass if k % 2 == 0 else brass_dark, 18 + k * 4, 0.18 if k % 2 == 0 else -0.13)

	# 钟面背板
	var back_a := deg_to_rad(212.0)
	var back_p := Vector3(cos(back_a) * 4300.0, 1450.0, sin(back_a) * 4300.0)
	var face := _cyl(1250.0, 1250.0, 40.0, back_p, _mat(Color("4a3418"), 0.6, 0.4), 48)
	face.rotation = Vector3(PI * 0.5, -back_a, 0)
	_no_shadow(face)
	var rim := _torus(1226.0, 1268.0, back_p, brass, Vector3(PI * 0.5, -back_a, 0))
	_no_shadow(rim)
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var dir := Vector3(cos(ang), sin(ang), 0.0)
		var mark := _box(Vector3(46.0, 120.0, 18.0), back_p + Vector3(dir.x * 1080.0, dir.y * 1080.0, 0), brass, 0.0)
		mark.rotation.z = ang - PI * 0.5
		_no_shadow(mark)
	var hands := Node3D.new()
	hands.position = back_p
	hands.rotation.y = -back_a
	add_child(hands)
	var h1 := _box(Vector3(26.0, 620.0, 10.0), Vector3(0, 270.0, 30.0), iron)
	h1.reparent(hands)
	h1.position = Vector3(0, 270.0, 30.0)
	_spin.append({"n": hands, "axis": "z", "s": 0.06})

	# 蒸汽管与气孔
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		if _blocked(a):
			continue
		var r := 1660.0 * grow
		var p := Vector3(cos(a) * r, GY, sin(a) * r)
		_no_shadow(_cyl(46.0, 60.0, 150.0, p + Vector3(0, 75.0, 0), iron, 10))
		_no_shadow(_cyl(64.0, 64.0, 16.0, p + Vector3(0, 158.0, 0), brass, 10))
		for s in 3:
			var puff := _sphere(rng.randf_range(40.0, 70.0), p + Vector3(rng.randf_range(-30, 30), 190.0 + float(s) * 80.0, rng.randf_range(-30, 30)), _alpha(Color("d8d0c0"), 0.10, false), 7)
			_no_shadow(puff)
			_rise.append({"n": puff, "s": rng.randf_range(26.0, 46.0), "top": 620.0, "bot": 180.0})

	# 壁灯
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.15
		if _blocked(a):
			continue
		var r := 1800.0 * grow
		var p := Vector3(cos(a) * r, GY, sin(a) * r)
		_no_shadow(_cyl(16.0, 22.0, 260.0, p + Vector3(0, 130.0, 0), iron, 8))
		_no_shadow(_sphere(34.0, p + Vector3(0, 286.0, 0), _glow(Color("ffc46a"), 2.0), 8))
		if i % 2 == 0:
			_light(p + Vector3(0, 300.0, 0), Color("ffbe62"), 1.8, 1100.0)

	# 棋盘融合：黄铜镶边 + 齿轮齿沿边走
	_no_shadow(_torus(1470.0 * grow, 1520.0 * grow, Vector3(0, 4.0, 0), brass, Vector3.ZERO))
	var teeth := Node3D.new()
	add_child(teeth)
	for i in 26:
		var a := TAU * float(i) / 26.0
		var t := _box(Vector3(44.0, 18.0, 30.0), Vector3(cos(a) * 1500.0 * grow, 8.0, sin(a) * 1500.0 * grow), brass, -a)
		t.reparent(teeth)
		t.position = Vector3(cos(a) * 1500.0 * grow, 8.0, sin(a) * 1500.0 * grow)
	_spin.append({"n": teeth, "axis": "y", "s": 0.12})
	# 刻度光弧
	for i in 3:
		var a0 := TAU * float(i) / 3.0 + 0.5
		var arc := _torus(760.0, 778.0, Vector3(0, 2.0, 0), _glow(Color("ffd28a"), 1.3), Vector3.ZERO)
		arc.rotation.y = a0
		_no_shadow(arc)

	_light(Vector3(0, 700.0, 0), Color("ffca80"), 1.6, 2800.0)


func _gear_floor(r: float, y: float, teeth: int, mat: Material, speed: float) -> void:
	var node := Node3D.new()
	add_child(node)
	_no_shadow(_torus(r - 80.0, r + 80.0, Vector3(0, y, 0), mat))
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		var t := _box(Vector3(96.0, 20.0, 120.0), Vector3(cos(a) * r, y, sin(a) * r), mat, -a)
		t.reparent(node)
		t.position = Vector3(cos(a) * r, y, sin(a) * r)
	_spin.append({"n": node, "axis": "y", "s": speed})


func _gear_wall(angle: float, dist: float, y: float, r: float, mat: Material, teeth: int, speed: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
	holder.rotation.y = -angle
	add_child(holder)
	var ring := _torus(r - 40.0, r + 40.0, Vector3.ZERO, mat, Vector3(PI * 0.5, 0, 0))
	ring.reparent(holder)
	ring.position = Vector3.ZERO
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		var t := _box(Vector3(70.0, 90.0, 60.0), Vector3(cos(a) * r, sin(a) * r, 0), mat, 0.0)
		t.reparent(holder)
		t.position = Vector3(cos(a) * r, sin(a) * r, 0)
		t.rotation.z = a
	var hub := _cyl(90.0, 90.0, 70.0, Vector3.ZERO, mat, 12)
	hub.reparent(holder)
	hub.rotation.x = PI * 0.5
	hub.position = Vector3.ZERO
	_spin.append({"n": holder, "axis": "z", "s": speed})
