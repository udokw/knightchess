# -*- coding: utf-8 -*-
"""
骑士飞行棋3 -> Godot 4 素材管线
  * B3D  -> glb (带贴图)
  * 3DS  -> 棋盘点位 JSON
  * MD2  -> glb (取第一帧静态姿态)
  * BMP  -> PNG
  * 复制音频 / 文本

用法:
  python build_assets.py [--src DIR] [--dst DIR]
"""
import os
import sys
import json
import struct
import argparse
import shutil

from PIL import Image

SRC_DEFAULT = r"C:\Users\udokw\AppData\Local\Temp\knight_extract"
DST_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ----------------------------------------------------------------------------
# 基础
# ----------------------------------------------------------------------------


class Reader:
    def __init__(self, data, pos=0):
        self.d = data
        self.p = pos

    def eof(self):
        return self.p >= len(self.d)

    def remaining(self):
        return len(self.d) - self.p

    def tag(self):
        t = self.d[self.p:self.p + 4]
        self.p += 4
        return t.decode('latin1')

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]
        self.p += 4
        return v

    def f32(self):
        v = struct.unpack_from('<f', self.d, self.p)[0]
        self.p += 4
        return v

    def f32s(self, n):
        v = list(struct.unpack_from('<%df' % n, self.d, self.p))
        self.p += 4 * n
        return v

    def cstr(self):
        e = self.d.index(b'\x00', self.p)
        s = self.d[self.p:e].decode('latin1')
        self.p = e + 1
        return s


def chunk(r):
    tag = r.tag()
    size = r.i32()
    data = r.d[r.p:r.p + size]
    r.p += size
    return tag, Reader(data)


def log(*a):
    print(*a, flush=True)


# ----------------------------------------------------------------------------
# 坐标转换: Blitz3D 左手 (Y上, Z前) -> glTF/Godot 右手 (Y上, -Z前)
# ----------------------------------------------------------------------------

def conv_pos(x, y, z):
    return (x, y, -z)


def conv_normal(x, y, z):
    return (x, y, -z)


# ----------------------------------------------------------------------------
# B3D
# ----------------------------------------------------------------------------

class Mesh:
    def __init__(self):
        self.brushes = []       # [(n_texs, [tex ids], name)]
        self.verts = []         # [(x,y,z, nx,ny,nz, u,v, (r,g,b,a))]
        self.tris = []          # [(v0,v1,v2)]
        self.tri_brush = []
        self.vflags = 0
        self.tcs = 0
        self.tcsize = 0


class Node:
    def __init__(self, name):
        self.name = name
        self.pos = [0, 0, 0]
        self.scale = [1, 1, 1]
        self.rot = [1, 0, 0, 0]  # w,x,y,z
        self.mesh = None
        self.children = []


def parse_b3d(path):
    data = open(path, 'rb').read()
    r = Reader(data)
    tag = r.tag()
    assert tag == 'BB3D', tag
    size = r.i32()
    version = r.i32()
    assert version == 1, version
    texs = []
    roots = []
    while not r.eof():
        tag, sub = chunk(r)
        if tag == 'TEXS':
            # 本作的 TEXS 无数量前缀, 条目一直重复到块结束
            while sub.remaining() >= 4:
                name = sub.cstr()
                flags = sub.i32()
                blend = sub.i32()
                xp, yp, xs, ys, rot = sub.f32s(5)
                texs.append({'name': name, 'flags': flags, 'blend': blend})
        elif tag == 'NODE':
            roots.append(parse_node(sub))
        else:
            pass
    return texs, roots


def parse_node(r):
    name = r.cstr()
    n = Node(name)
    n.pos = r.f32s(3)
    n.scale = r.f32s(3)
    n.rot = r.f32s(4)
    while not r.eof():
        tag, sub = chunk(r)
        if tag == 'MESH':
            n.mesh = parse_mesh(sub)
        elif tag == 'NODE':
            n.children.append(parse_node(sub))
        elif tag == 'BONE':
            pass
        elif tag == 'KEYS':
            pass
        elif tag == 'ANIM':
            pass
    return n


def parse_mesh(r):
    m = Mesh()
    brush_id = r.i32()
    while not r.eof():
        tag, sub = chunk(r)
        if tag == 'BRUS':
            n_texs = sub.i32()
            ids = [sub.i32() for _ in range(n_texs)]
            bname = sub.cstr()
            m.brushes.append({'n_texs': n_texs, 'tex': ids, 'name': bname})
        elif tag == 'VRTS':
            flags = sub.i32()
            tc_sets = sub.i32()
            tc_size = sub.i32()
            m.vflags, m.tcs, m.tcsize = flags, tc_sets, tc_size
            nrm = bool(flags & 1)
            col = bool(flags & 2)
            per = 3 + (3 if nrm else 0) + tc_sets * tc_size + (4 if col else 0)
            if per <= 0 or sub.remaining() % (per * 4) != 0:
                # 自适应尝试
                ok = False
                for nrm2 in (True, False):
                    for col2 in (True, False):
                        per2 = 3 + (3 if nrm2 else 0) + tc_sets * tc_size + (4 if col2 else 0)
                        if per2 > 0 and len(sub.d) % (per2 * 4) == 0:
                            nrm, col, per = nrm2, col2, per2
                            ok = True
                            break
                    if ok:
                        break
            count = len(sub.d) // (per * 4) if per else 0
            vals = sub.f32s(count * per)
            for i in range(count):
                o = i * per
                x, y, z = vals[o:o + 3]
                o += 3
                if nrm:
                    nx, ny, nz = vals[o:o + 3]
                    o += 3
                else:
                    nx, ny, nz = 0, 1, 0
                u, v = 0.0, 0.0
                if tc_sets > 0 and tc_size >= 2:
                    u, v = vals[o], vals[o + 1]
                    o += tc_sets * tc_size
                if col:
                    rgba = tuple(vals[o:o + 4])
                else:
                    rgba = (1, 1, 1, 1)
                m.verts.append((x, y, z, nx, ny, nz, u, v, rgba))
        elif tag == 'TRIS':
            bid = sub.i32()
            n = sub.remaining() // 12
            idx = struct.unpack_from('<%di' % (n * 3), sub.d, 4)
            for i in range(n):
                m.tris.append((idx[i * 3], idx[i * 3 + 1], idx[i * 3 + 2]))
                m.tri_brush.append(bid)
    return m


# ----------------------------------------------------------------------------
# glTF 构建
# ----------------------------------------------------------------------------

class GLTFBuilder:
    def __init__(self, tex_map, alpha_tex=None):
        self.tex_map = tex_map          # b3d 名字 -> 相对 png 路径
        self.alpha_tex = alpha_tex or set()
        self.nodes = [{'name': 'root', 'children': []}]
        self.meshes = []
        self.materials = []
        self.mat_index = {}
        self.images = []
        self.textures = []
        self.tex_index = {}
        self.accessors = []
        self.views = []
        self.bin = bytearray()
        self.root_children = self.nodes[0]['children']

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin.extend(data)
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target:
            v['target'] = target
        self.views.append(v)
        return len(self.views) - 1

    def _acc(self, view, ctype, count, atype, mn=None, mx=None):
        a = {'bufferView': view, 'componentType': ctype, 'count': count, 'type': atype}
        if mn is not None:
            a['min'] = mn
            a['max'] = mx
        self.accessors.append(a)
        return len(self.accessors) - 1

    def texture(self, b3d_name):
        if b3d_name in self.tex_index:
            return self.tex_index[b3d_name]
        rel = self.tex_map.get(os.path.splitext(os.path.basename(b3d_name))[0].lower())
        if rel is None:
            return None
        if rel not in self.images:
            self.images.append(rel)
        img = self.images.index(rel)
        self.textures.append({'source': img, 'sampler': 0})
        idx = len(self.textures) - 1
        self.tex_index[b3d_name] = idx
        return idx

    def material(self, brush_id, texs, brushes, blend):
        # 本作 B3D 无 BRUS 块, TRIS 的 brush id 直接就是 TEXS 索引
        if brush_id < 0 or brush_id >= len(texs):
            key = ('none', brush_id)
            if key in self.mat_index:
                return self.mat_index[key]
            mat = {'name': 'default', 'pbrMetallicRoughness': {
                'metallicFactor': 0.0, 'roughnessFactor': 0.9,
                'baseColorFactor': [0.75, 0.78, 0.6, 1.0]}, 'doubleSided': True}
            self.materials.append(mat)
            self.mat_index[key] = len(self.materials) - 1
            return self.mat_index[key]
        name = texs[brush_id]['name']
        key = (name, blend)
        if key in self.mat_index:
            return self.mat_index[key]
        ti = self.texture(name)
        mat = {'name': os.path.basename(name), 'pbrMetallicRoughness': {
            'metallicFactor': 0.0, 'roughnessFactor': 0.9,
            'baseColorFactor': [1.0, 1.0, 1.0, 1.0]}}
        if ti is not None:
            mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': ti}
            base = os.path.splitext(os.path.basename(name))[0].lower()
            if base in self.alpha_tex:
                mat['alphaMode'] = 'MASK'
                mat['alphaCutoff'] = 0.35
            mat['doubleSided'] = True
        else:
            mat['pbrMetallicRoughness']['baseColorFactor'] = [0.6, 0.6, 0.6, 1.0]
            mat['doubleSided'] = True
        self.materials.append(mat)
        self.mat_index[key] = len(self.materials) - 1
        return self.mat_index[key]

    def add_mesh(self, mesh, texs, blend, planar_uv=False):
        if not mesh.verts or not mesh.tris:
            return None
        # 按 brush 分组三角形
        groups = {}
        for tri, b in zip(mesh.tris, mesh.tri_brush):
            groups.setdefault(b, []).append(tri)
        prims = []
        lb = [min(v[k] for v in mesh.verts) for k in range(3)]
        ub = [max(v[k] for v in mesh.verts) for k in range(3)]
        for b, tris in groups.items():
            used = sorted({i for t in tris for i in t})
            if not used:
                continue
            remap = {orig: i for i, orig in enumerate(used)}
            pos = [conv_pos(*mesh.verts[i][0:3]) for i in used]
            nrm = [conv_normal(*mesh.verts[i][3:6]) for i in used]
            uvs = [(mesh.verts[i][6], 1.0 - mesh.verts[i][7]) for i in used]
            if planar_uv:
                # 棋盘底面: 原 UV 退化(全为同一值), 用平面映射铺满整张图
                w = max(1e-6, ub[0] - lb[0])
                h = max(1e-6, ub[2] - lb[2])
                uvs = []
                for i in used:
                    vx, vz = mesh.verts[i][0], mesh.verts[i][2]
                    uvs.append(((vx - lb[0]) / w, (vz - lb[2]) / h))
            cols = [mesh.verts[i][8] for i in used]

            pb = b''.join(struct.pack('<3f', *p) for p in pos)
            nb = b''.join(struct.pack('<3f', *n) for n in nrm)
            tb = b''.join(struct.pack('<2f', *t) for t in uvs)
            mn = [min(p[k] for p in pos) for k in range(3)]
            mx = [max(p[k] for p in pos) for k in range(3)]
            a_pos = self._acc(self._view(pb, 34962), 5126, len(pos), 'VEC3', mn, mx)
            a_nrm = self._acc(self._view(nb, 34962), 5126, len(nrm), 'VEC3')
            a_uv = self._acc(self._view(tb, 34962), 5126, len(uvs), 'VEC2')
            attrs = {'POSITION': a_pos, 'NORMAL': a_nrm, 'TEXCOORD_0': a_uv}
            # 顶点里多出来的 4 个浮点并非颜色(疑似光照贴图 UV), 不使用, 避免出现花屏

            idx = []
            for t in tris:
                # 反转绕序以补偿 Z 翻转
                idx.extend([remap[t[0]], remap[t[2]], remap[t[1]]])
            big = len(pos) > 65535
            ib = struct.pack('<%d%s' % (len(idx), 'I' if big else 'H'), *idx)
            a_idx = self._acc(self._view(ib, 34963), 5125 if big else 5123, len(idx), 'SCALAR')

            prim = {'attributes': attrs, 'indices': a_idx,
                    'material': self.material(b, texs, mesh.brushes, blend)}
            prims.append(prim)
        if not prims:
            return None
        self.meshes.append({'name': 'mesh%d' % len(self.meshes), 'primitives': prims})
        return len(self.meshes) - 1

    def add_node(self, node, parent, texs, blend):
        gl = {'name': node.name}
        gl['translation'] = list(conv_pos(*node.pos))
        gl['scale'] = list(node.scale)
        w, x, y, z = node.rot
        gl['rotation'] = [x, -y, -z, w]  # 与 Z 翻转一致的四元数变换
        if node.mesh:
            mi = self.add_mesh(node.mesh, texs, blend,
                               planar_uv=node.name.lower().startswith('layout'))
            if mi is not None:
                gl['mesh'] = mi
        self.nodes.append(gl)
        idx = len(self.nodes) - 1
        self.nodes[parent].setdefault('children', []).append(idx)
        for c in node.children:
            self.add_node(c, idx, texs, blend)

    def write(self, path):
        gltf = {
            'asset': {'version': '2.0', 'generator': 'knight-b3d2gltf'},
            'scene': 0,
            'scenes': [{'nodes': [0]}],
            'nodes': self.nodes,
            'meshes': self.meshes,
            'materials': self.materials,
            'accessors': self.accessors,
            'bufferViews': self.views,
            'buffers': [{'byteLength': len(self.bin), 'uri': os.path.basename(path) + '.bin'}],
        }
        if self.images:
            gltf['images'] = [{'uri': u} for u in self.images]
            gltf['textures'] = self.textures
            gltf['samplers'] = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}]
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(gltf, f, indent=1)
        with open(path + '.bin', 'wb') as f:
            f.write(self.bin)
        return len(self.bin)


# ----------------------------------------------------------------------------
# 3DS
# ----------------------------------------------------------------------------

def parse_3ds(path):
    data = open(path, 'rb').read()
    objs = []

    def walk(off, end, cur):
        while off + 6 <= end:
            cid, clen = struct.unpack_from('<HI', data, off)
            body = off + 6
            cend = off + clen
            if cid == 0x4000:
                e = data.index(b'\x00', body)
                cur = data[body:e].decode('latin1')
                walk(e + 1, cend, cur)
            elif cid == 0x4100:
                walk(body, cend, cur)
            elif cid == 0x4110:
                n = struct.unpack_from('<H', data, body)[0]
                verts = [struct.unpack_from('<3f', data, body + 2 + i * 12) for i in range(n)]
                objs.append({'name': cur, 'verts': verts, 'matrix': None})
            elif cid == 0x4160:
                m = struct.unpack_from('<12f', data, body)
                for o in reversed(objs):
                    if o['name'] == cur and o['matrix'] is None:
                        o['matrix'] = m
                        break
            elif cid == 0x4D4D or cid == 0x3D3D:
                walk(body, cend, cur)
            off = cend

    walk(0, len(data), None)
    return objs


# ----------------------------------------------------------------------------
# MD2
# ----------------------------------------------------------------------------

MD2_NORMALS = [
    (-0.525731, 0.000000, 0.850651), (-0.442863, 0.238856, 0.864188), (-0.295242, 0.000000, 0.955423),
    (-0.309017, 0.500000, 0.809017), (-0.162460, 0.262866, 0.951056), (0.000000, 0.000000, 1.000000),
    (0.000000, 0.850651, 0.525731), (-0.147621, 0.716567, 0.681718), (0.147621, 0.716567, 0.681718),
    (0.000000, 0.525731, 0.850651), (0.309017, 0.500000, 0.809017), (0.525731, 0.000000, 0.850651),
    (0.295242, 0.000000, 0.955423), (0.442863, 0.238856, 0.864188), (0.162460, 0.262866, 0.951056),
    (-0.681718, 0.147621, 0.716567), (-0.809017, 0.309017, 0.500000), (-0.587785, 0.425325, 0.688191),
    (-0.850651, 0.525731, 0.000000), (-0.864188, 0.442863, 0.238856), (-0.716567, 0.681718, 0.147621),
    (-0.688191, 0.587785, 0.425325), (-0.500000, 0.809017, 0.309017), (-0.238856, 0.864188, 0.442863),
    (-0.425325, 0.688191, 0.587785), (-0.716567, 0.681718, -0.147621), (-0.500000, 0.809017, -0.309017),
    (-0.525731, 0.850651, 0.000000), (0.000000, 0.850651, -0.525731), (-0.238856, 0.864188, -0.442863),
    (0.000000, 0.955423, -0.295242), (-0.262866, 0.951056, -0.162460), (0.000000, 1.000000, 0.000000),
    (0.000000, 0.955423, 0.295242), (-0.262866, 0.951056, 0.162460), (0.238856, 0.864188, 0.442863),
    (0.262866, 0.951056, 0.162460), (0.500000, 0.809017, 0.309017), (0.238856, 0.864188, -0.442863),
    (0.262866, 0.951056, -0.162460), (0.500000, 0.809017, -0.309017), (0.850651, 0.525731, 0.000000),
    (0.716567, 0.681718, 0.147621), (0.716567, 0.681718, -0.147621), (0.525731, 0.850651, 0.000000),
    (0.425325, 0.688191, -0.587785), (0.864188, 0.442863, -0.238856), (0.688191, 0.587785, -0.425325),
    (0.809017, 0.309017, -0.500000), (0.681718, 0.147621, -0.716567), (0.442863, 0.238856, -0.864188),
    (0.587785, 0.425325, -0.688191), (0.309017, 0.500000, -0.809017), (0.147621, 0.716567, -0.681718),
    (0.000000, 0.525731, -0.850651), (-0.309017, 0.500000, -0.809017), (-0.442863, 0.238856, -0.864188),
    (-0.162460, 0.262866, -0.951056), (-0.147621, 0.716567, -0.681718), (-0.525731, 0.850651, 0.000000),
    (-0.442863, 0.238856, -0.864188), (-0.295242, 0.000000, -0.955423), (-0.309017, 0.500000, -0.809017),
    (-0.162460, 0.262866, -0.951056), (0.000000, 0.000000, -1.000000), (0.000000, 0.850651, -0.525731),
    (0.000000, -0.850651, -0.525731), (-0.309017, -0.500000, -0.809017), (0.000000, -0.525731, -0.850651),
    (0.000000, -1.000000, 0.000000), (-0.147621, -0.716567, -0.681718), (0.147621, -0.716567, -0.681718),
    (0.309017, -0.500000, -0.809017), (0.000000, -0.525731, -0.850651), (0.525731, -0.850651, 0.000000),
    (0.681718, -0.147621, -0.716567), (0.850651, 0.000000, -0.525731), (0.442863, -0.238856, -0.864188),
    (0.500000, -0.809017, -0.309017), (0.716567, -0.681718, -0.147621), (0.295242, 0.000000, -0.955423),
    (0.850651, -0.525731, 0.000000), (0.688191, -0.587785, -0.425325), (0.587785, -0.425325, -0.688191),
    (0.425325, -0.688191, -0.587785), (0.442863, -0.238856, -0.864188), (0.309017, -0.500000, -0.809017),
    (-0.147621, -0.716567, -0.681718), (-0.425325, -0.688191, -0.587785), (-0.688191, -0.587785, -0.425325),
    (-0.147621, -0.716567, 0.681718), (-0.309017, -0.500000, 0.809017), (-0.525731, -0.850651, 0.000000),
    (-0.442863, -0.238856, 0.864188), (-0.681718, -0.147621, 0.716567), (-0.295242, 0.000000, 0.955423),
    (-0.809017, -0.309017, 0.500000), (-0.587785, -0.425325, 0.688191), (-0.716567, -0.681718, 0.147621),
    (-0.442863, -0.238856, -0.864188), (-0.716567, -0.681718, -0.147621), (-0.688191, -0.587785, -0.425325),
    (-0.309017, -0.500000, -0.809017), (-0.162460, -0.262866, -0.951056), (-0.425325, -0.688191, -0.587785),
    (-0.525731, -0.850651, 0.000000), (-0.587785, -0.425325, 0.688191), (-0.162460, -0.262866, 0.951056),
    (0.000000, -0.850651, 0.525731), (0.000000, -0.525731, 0.850651), (0.000000, -0.955423, 0.295242),
    (0.144046, -0.846125, 0.513603), (0.000000, -1.000000, 0.000000), (0.000000, -0.955423, -0.295242),
    (0.000000, -0.525731, -0.850651), (0.000000, -0.850651, -0.525731), (-0.144046, -0.846125, -0.513603),
]


def parse_md2(path):
    d = open(path, 'rb').read()
    magic = d[:4]
    assert magic == b'IDP2', magic
    (version, skinw, skinh, framesize, num_skins, num_verts, num_sts, num_tris,
     num_glcmds, num_frames, off_skins, off_st, off_tris, off_frames,
     off_glcmds, off_end) = struct.unpack_from('<16i', d, 4)
    sts = [struct.unpack_from('<2h', d, off_st + i * 4) for i in range(num_sts)]
    tris = [struct.unpack_from('<3h', d, off_tris + i * 12)[0::2] +
            struct.unpack_from('<3h', d, off_tris + i * 12)[1::2] for i in range(num_tris)]
    # 修正: MD2 tri = 3*vertidx + 3*stidx
    tris = []
    for i in range(num_tris):
        v = struct.unpack_from('<3h', d, off_tris + i * 12)
        t = struct.unpack_from('<3h', d, off_tris + i * 12 + 6)
        tris.append((v, t))
    frame0 = off_frames
    scale = struct.unpack_from('<3f', d, frame0)
    trans = struct.unpack_from('<3f', d, frame0 + 12)
    fname = d[frame0 + 24:frame0 + 40].split(b'\x00')[0].decode('latin1')
    vbase = frame0 + 40
    verts = []
    for i in range(num_verts):
        x, y, z, ni = struct.unpack_from('<4B', d, vbase + i * 4)
        px = x * scale[0] + trans[0]
        py = y * scale[1] + trans[1]
        pz = z * scale[2] + trans[2]
        n = MD2_NORMALS[ni] if ni < len(MD2_NORMALS) else (0.0, 1.0, 0.0)
        verts.append((px, py, pz, n[0], n[1], n[2]))
    return {'skin': (skinw, skinh), 'sts': sts, 'tris': tris, 'verts': verts, 'frame': fname}


def md2_to_glb(path, out, mat_name, texture_rel=None, scale=1.0):
    m = parse_md2(path)
    sw, sh = m['skin']
    g = GLTFBuilder({})
    pos, nrm, uv, idx = [], [], [], []
    # 展开为逐三角形顶点 (保证 uv 正确)
    for vi, ti in m['tris']:
        for k in range(3):
            x, y, z, nx, ny, nz = m['verts'][vi[k]]
            # Quake (X前, Y左, Z上) -> Godot (Y上, -Z前)
            pos.append((x * scale, z * scale, -y * scale))
            nrm.append((nx, nz, -ny))
            s, t = m['sts'][ti[k]]
            uv.append((s / sw, 1.0 - t / sh))
        idx.extend([len(idx), len(idx) + 1, len(idx) + 2])
    pb = b''.join(struct.pack('<3f', *p) for p in pos)
    nb = b''.join(struct.pack('<3f', *n) for n in nrm)
    tb = b''.join(struct.pack('<2f', *p) for p in uv)
    mn = [min(p[k] for p in pos) for k in range(3)]
    mx = [max(p[k] for p in pos) for k in range(3)]
    a_pos = g._acc(g._view(pb, 34962), 5126, len(pos), 'VEC3', mn, mx)
    a_nrm = g._acc(g._view(nb, 34962), 5126, len(nrm), 'VEC3')
    a_uv = g._acc(g._view(tb, 34962), 5126, len(uv), 'VEC2')
    ib = struct.pack('<%dH' % len(idx), *idx) if len(pos) <= 65535 else \
        struct.pack('<%dI' % len(idx), *idx)
    a_idx = g._acc(g._view(ib, 34963), 5123 if len(pos) <= 65535 else 5125, len(idx), 'SCALAR')
    mat = {'name': mat_name, 'pbrMetallicRoughness': {'metallicFactor': 0.0, 'roughnessFactor': 0.8,
                                                      'baseColorFactor': [1, 1, 1, 1]},
           'doubleSided': True}
    images = []
    if texture_rel:
        mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
        mat['alphaMode'] = 'MASK'
        mat['alphaCutoff'] = 0.4
        images = [{'uri': texture_rel}]
        g.textures = [{'source': 0, 'sampler': 0}]
        g.samplers = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}]
    g.materials = [mat]
    g.meshes = [{'name': mat_name, 'primitives': [
        {'attributes': {'POSITION': a_pos, 'NORMAL': a_nrm, 'TEXCOORD_0': a_uv},
         'indices': a_idx, 'material': 0}]}]
    g.nodes = [{'name': 'root', 'children': [1]}, {'name': mat_name, 'mesh': 0}]
    gltf = {
        'asset': {'version': '2.0', 'generator': 'knight-md2toglb'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': g.nodes,
        'meshes': g.meshes, 'materials': g.materials,
        'accessors': g.accessors, 'bufferViews': g.views,
        'buffers': [{'byteLength': len(g.bin), 'uri': os.path.basename(out) + '.bin'}],
    }
    if images:
        gltf['images'] = images
        gltf['textures'] = g.textures
        gltf['samplers'] = g.samplers
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(gltf, f, indent=1)
    with open(out + '.bin', 'wb') as f:
        f.write(g.bin)
    return m


# ----------------------------------------------------------------------------
# 贴图
# ----------------------------------------------------------------------------

def bmp_to_png(src, dst, max_size=1024):
    im = Image.open(src)
    if im.mode not in ('RGB', 'RGBA'):
        im = im.convert('RGBA' if 'A' in im.getbands() else 'RGB')
    w, h = im.size
    if max(w, h) > max_size:
        s = max_size / max(w, h)
        im = im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, 'PNG', optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default=SRC_DEFAULT)
    ap.add_argument('--dst', default=DST_DEFAULT)
    ap.add_argument('--scene', default='1')
    args = ap.parse_args()

    src = args.src
    dst = args.dst
    sc = 'Scene%s' % args.scene
    scene_dir = os.path.join(src, sc)
    out_tex = os.path.join(dst, 'assets', 'textures')
    out_lvl = os.path.join(dst, 'assets', 'levels')
    out_fig = os.path.join(dst, 'assets', 'figures')
    out_data = os.path.join(dst, 'assets', 'data')
    out_snd = os.path.join(dst, 'assets', 'sounds')
    for d in (out_tex, out_lvl, out_fig, out_data, out_snd):
        os.makedirs(d, exist_ok=True)

    # --- 贴图 ---
    tex_map = {}
    alpha_tex = set()
    log('== 转换贴图 ==')
    seen = set()
    for base in (scene_dir, os.path.join(src, 'Models'), os.path.join(src, 'Figures')):
        if not os.path.isdir(base):
            continue
        for fn in os.listdir(base):
            low = fn.lower()
            if not low.endswith('.bmp'):
                continue
            root, _ = os.path.splitext(low)
            if root in seen:
                continue
            seen.add(root)
            png = os.path.join(out_tex, root + '.png')
            try:
                bmp_to_png(os.path.join(base, fn), png)
                tex_map[root] = '../textures/%s.png' % root
                im = Image.open(png)
                if im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] < 250:
                    alpha_tex.add(root)
            except Exception as e:
                log('  贴图失败', fn, e)
    log('  贴图数量:', len(tex_map), '带透明:', len(alpha_tex))

    # 场景里原本就是 png 的贴图, 直接复制
    for base in (scene_dir, os.path.join(src, 'Models')):
        if not os.path.isdir(base):
            continue
        for fn in os.listdir(base):
            low = fn.lower()
            if not low.endswith('.png'):
                continue
            root, _ = os.path.splitext(low)
            if root in tex_map:
                continue
            shutil.copy2(os.path.join(base, fn), os.path.join(out_tex, root + '.png'))
            tex_map[root] = '../textures/%s.png' % root
            im = Image.open(os.path.join(out_tex, root + '.png'))
            if im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] < 250:
                alpha_tex.add(root)

    # --- 关卡 ---
    log('== 转换 B3D 关卡 ==')
    b3d = os.path.join(scene_dir, 'layout1.b3d')
    texs, roots = parse_b3d(b3d)
    log('  TEXS:', len(texs), '根节点:', len(roots))
    total_mesh = 0
    for n in roots:
        stack = [n]
        while stack:
            x = stack.pop()
            if x.mesh:
                total_mesh += 1
            stack.extend(x.children)
    log('  网格节点:', total_mesh)
    g = GLTFBuilder(tex_map, alpha_tex)
    g.nodes[0]['name'] = 'scene1'
    for n in roots:
        g.add_node(n, 0, texs, 0)
    size = g.write(os.path.join(out_lvl, 'scene1.gltf'))
    log('  glb 写出: %.1f KB, 材质 %d' % (size / 1024, len(g.materials)))

    # --- 棋盘点位与路径 ---
    log('== 转换 3DS 点位 ==')
    objs = parse_3ds(os.path.join(scene_dir, 'layout1.3ds'))
    pts = {}
    for o in objs:
        if o['matrix'] is None:
            continue
        m = o['matrix']
        tx, ty, tz = m[9], m[10], m[11]
        vs = o['verts']
        if vs:
            cx = sum(v[0] for v in vs) / len(vs)
            cy = sum(v[1] for v in vs) / len(vs)
            cz = sum(v[2] for v in vs) / len(vs)
        else:
            cx = cy = cz = 0.0
        px = m[0] * cx + m[1] * cy + m[2] * cz + tx
        py = m[3] * cx + m[4] * cy + m[5] * cz + ty
        pz = m[6] * cx + m[7] * cy + m[8] * cz + tz
        pts[o['name'].rstrip('_')] = (px, py, pz)

    # 棋盘在世界中的位置: B3D 中 Layout 节点 (平面 800x800, scale 1.40288)
    layout_half = 400.0 * 1.402880072593689
    board_y = 1.0
    s = layout_half / 1000.0

    # 3DS: Z 向上, 点位半径 1000; 转 world = (x*s, board_y, -y*s)
    points = {}
    for k, (x, y, z) in pts.items():
        points[k] = [round(x * s, 2), round(board_y, 2), round(-y * s, 2)]

    # 路径
    paths = {}
    dat_path = os.path.join(scene_dir, 'layout1.dat')
    cur = None
    for line in open(dat_path, encoding='latin1'):
        t = line.strip()
        if t.startswith('[') and t.endswith(']'):
            cur = t[1:-1]
            if cur.startswith('TEAMPATH'):
                paths[cur] = []
        elif cur and cur.startswith('TEAMPATH') and t and not t.startswith('[/'):
            paths[cur].append(t)
    fields = 40
    for line in open(dat_path, encoding='latin1'):
        if line.strip().upper().startswith('FIELDS_TO_GO'):
            try:
                fields = int(line.split('=')[1].strip())
            except Exception:
                pass
    data = {
        'board': {'center': [0.0, board_y, 0.0], 'half_size': round(layout_half, 2),
                  'fields': fields},
        'points': points,
        'paths': {k: v[:fields] for k, v in paths.items()},
    }
    with open(os.path.join(out_data, 'board.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    log('  点位: %d, 路径: %s' % (len(points), {k: len(v) for k, v in paths.items()}))
    for nm in ('PT01', 'PT10', 'PT40', 'HM1_1', 'GL1_1'):
        log('   ', nm, points.get(nm))

    # --- 棋子模型 ---
    log('== 转换棋子 MD2 ==')
    fig_dir = os.path.join(src, 'Figures')
    ok_fig = 0
    for i in range(1, 15):
        p = os.path.join(fig_dir, '%d.md2' % i)
        if not os.path.exists(p):
            continue
        bmp = os.path.join(fig_dir, '%d.bmp' % i)
        tex_rel = None
        if os.path.exists(bmp):
            png = os.path.join(out_tex, 'fig%d.png' % i)
            if not os.path.exists(png):
                bmp_to_png(bmp, png, 512)
            tex_rel = '../textures/fig%d.png' % i
        try:
            md2_to_glb(p, os.path.join(out_fig, 'fig%d.gltf' % i), 'fig%d' % i, tex_rel, 1.0)
            ok_fig += 1
        except Exception as e:
            log('  棋子失败', i, e)
    log('  棋子模型:', ok_fig)

    # --- 音频 (只保留用到的几个) ---
    log('== 复制音频 ==')
    KEEP_SOUNDS = {'ambient.ogg', 'dice_move.wav', 'button_click.wav', 'cant_move.wav'}
    cnt = 0
    src_snd = os.path.join(src, 'Sounds')
    if os.path.isdir(src_snd):
        for fn in os.listdir(src_snd):
            if fn.lower() in KEEP_SOUNDS:
                shutil.copy2(os.path.join(src_snd, fn), os.path.join(out_snd, fn))
                cnt += 1
    log('  音频:', cnt)
    log('完成')


if __name__ == '__main__':
    main()
