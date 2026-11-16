# 骑士飞行棋 3 · Godot 4 复刻（Scene1 / 经典布局 / 经典模式）

原版是 2010 年 Mike Dogan / X-PRESSIVE 的 Blitz3D 游戏（32 位 PE + DirectDraw/D3D9），
**无法直接打包成 iOS 应用**。本工程用 Godot 4 重写玩法，并复用从原版 `DATA.BOX`
（ZipCrypto，口令 `7512FBD2123AEF3DFAD42FAB4FCCE`）解包出的关卡与棋子素材。

## 运行

1. 安装 Godot 4.3（标准版，非 .NET）。
2. 打开 `KnightChessGodot/project.godot`，按 F5。
3. 命令行方式：

```
godot --path KnightChessGodot
```

4. Windows 上可直接双击 `run.bat`（脚本里写死了本机 Godot 路径，换机器需修改 `GODOT` 变量）。

首次打开会自动导入 `assets/` 下的 glTF 与贴图。效果预览见 `preview.png`。

## 操作

- 底部「掷骰子」：当前队伍行动，掷 6 点才能把棋子从基地送上棋盘，且掷 6 点可再掷一次。
- 起始格与路径由 `assets/data/board.json`（由原版 `layout1.3ds` + `layout1.dat` 生成）驱动。
- 多枚棋子可走时，底部会出现「棋子 N」按钮供选择。
- 右键/中键拖动旋转视角，滚轮缩放；触屏拖动旋转，底部按钮也可转视角/缩放。

## 已实现的规则

- 4 队 × 4 枚，各自 40 格独立路径（共用棋盘格点）。
- 掷 6 出基地；走满 40 格且点数精确才能抵达终点；点数超出则不能移动。
- 落在对手棋子的格子上将其吃回基地（并可再掷一次）。
- 每队 4 枚全部到达终点即获胜。

## iOS 导出（需要 macOS）

Godot 的 iOS 导出器依赖 Xcode，Windows 上无法生成 ipa。两种方式：

### 方式 A：GitHub Actions（无需 Mac）

仓库里已带 `.github/workflows/ios.yml`，push 到 `main` 或手动 `workflow_dispatch`
就会在 GitHub 的 macOS 运行器上：下载 Godot 4.3 + iOS 导出模板 → 导入资源 →
导出 Xcode 工程 → `xcodebuild` 构建 → 上传 `KnightChess3-unsigned-ipa` 产物。

产物是**未签名 ipa**，下载后用 Sideloadly / AltStore 以自己的 Apple ID 重签安装
（免费账号 7 天）。想要签名版可在 workflow 里加证书与描述文件 Secrets
（`BUILD_CERTIFICATE_BASE64`、`P12_PASSWORD`、`PROVISIONING_PROFILE_BASE64`、`APPLE_TEAM_ID`），
改用 `xcodebuild -exportArchive`。

> 私有仓库的 macOS 运行器按 10 倍系数消耗 Actions 分钟；公开仓库免费。

### 方式 B：本机 macOS + Xcode

1. 在 macOS 安装 Xcode（含命令行工具）与 Godot 4.3，并在 Godot 里
   `编辑器 → 管理导出模板` 下载 4.3 模板。
2. 打开本工程，`项目 → 导出` 已经存在 `iOS` 预设（`export_presets.cfg`）。
   先改 `application/bundle_identifier`，再填 Apple Team ID。
3. 点「导出项目」，生成 Xcode 工程；在 Xcode 里选择真机或模拟器运行。
4. 自用侧载：Xcode 用免费 Apple ID 签名的 App 有效期 7 天；
   用付费开发者账号可签名 1 年，或走 TestFlight / 越狱设备 AltStore 等方式。

> 说明：App Store 上架需要开发者账号、隐私清单与原创美术，原版素材仅适合自用。

## 素材管线

```
python tools/build_assets.py            # 默认读取 %TEMP%\knight_extract
python tools/build_assets.py --src 解包目录 --dst .
```

- `B3D → glTF`：解析 Blitz3D 二进制（NODE/MESH/VRTS/TRIS/TEXS），Z 轴翻转为右手系、
  反转绕序、贴图映射到 `assets/textures/*.png`。
- `3DS → board.json`：读取 72 个命名对象（PT01–PT40、HM1..4_x、GL1..4_x）作为棋盘点位，
  并按原版 `layout1.dat` 的 `[TEAMPATH1..4]` 生成四条 40 格路径。
- `MD2 → glTF`：取第一帧作为静态棋子模型。
- `BMP → PNG`：带缩放，保留透明通道。

## 目录

```
KnightChessGodot/
├─ project.godot          # 主场景 main.tscn → src/Main.gd
├─ export_presets.cfg     # iOS / Windows 导出预设
├─ src/Main.gd            # 场景、棋子、规则、相机、HUD 全部逻辑
├─ tools/build_assets.py  # 素材转换管线
└─ assets/
   ├─ levels/scene1.gltf  # 原版 layout1.b3d 转出的整张关卡（含贴图）
   ├─ figures/fig1..4.gltf# 四队棋子（原版 Figures/*.md2）
   ├─ textures/           # 由 BMP 转出的 PNG
   ├─ data/board.json     # 棋盘格点 + 四条路径
   └─ sounds/             # 环境音与骰子音效
```

## 与原版的差异 / 待办

- 只做了场景 1、布局 1（经典）；另外 2 个场景、3 种布局、3 种额外模式未实现。
- 未实现道具卡、小游戏、联机（原版为 ENet）与 AI。
- 棋盘的「黑底草地贴花」用自定义 shader 把黑色转透明，颜色比原版偏暗一些。
- 原版 B3D 顶点里多出的 4 个浮点（疑似光照贴图 UV）未使用，场景没有烘焙光影。
