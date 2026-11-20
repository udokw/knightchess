# 骑士飞行棋 3 · v1.0.4 联机三缺陷修复规格

## 1. 目标与范围

用户实测发现三个问题，本轮一并修复，逐条汇报，并对存档 / LAN 协议 / 既有自测给出影响说明，最后走 GitHub Actions 出包并发布。

| 编号 | 现象 | 验收标准 |
| --- | --- | --- |
| B1 | 局域网对局中，客机端把房主显示成 AI | 客机端房主显示为人类玩家（队伍栏、回合文本、日志一致），客机自己显示为「你」；2/3 队若为 AI 补位仍显示 AI |
| B2 | 客机端没有显示房主选定的棋盘主题；客机还能改主题 | 客机按房主下发的 theme 渲染；≡ 菜单与开局页主题入口对客机置灰；即使绕过 UI（信号/调试入口）也改不了本地主题；房主开局页选的主题能带入联机对局 |
| B3 | 客机·晴日牧原·原始 5（+1=6）弹「基地出发」后点棋子/菜单均无反应，卡死 | 客机 pick 意图被房主采纳并推进对局；晴日 5→6 与沙海 6→5 两种场景都能出基地并继续游戏；给出客机侧日志/连拍证据 |

版本：`1.0.4` / build `5`（project.godot、export_presets.cfg 的 iOS 与 Android、workflow env、Release 说明、Tag `v1.0.4`）。

## 2. 根因（已由代码确认）

### B1 客机把房主标成 AI

`src/Main.gd` `_is_ai(team)`（约 2386 行）：

```gdscript
if net_role == "host" and team != 0:
    return lan == null or not lan.is_human_seat(team)
return not (team in human_teams)
```

客机 `human_teams == [net_guest_team]`（`_apply_net` 约 1676 行写入），于是 `0 in human_teams` 为 false → `_is_ai(0) == true`。
该值被 `_update_all()`（约 5164 行）写入 `status[t]["ai"]`，HUD `set_teams()`（约 2859 行）据此渲染 `"  AI"`；`_team_display()`、回合提示同样受影响。
大厅座位表不经过该函数（`Lan._seats_public()` 自带 `host/ai` 字段），不是问题源。

### B2 客机主题

- `_apply_net()` 会带房主 theme 调 `_start_match()`，但 **HUD 的 `_theme_id` 从未被同步**：客机 ≡ 菜单「棋盘主题」高亮仍是本地默认值，看起来"没有主题"。
- 开局页 `theme_previewed` 只连到 `arena.set_theme(id)`（Main 约 852 行），**没有写回 Main.theme_id**；房主在开局页选的主题不会带入 `_lan_start_clicked()` → `_start_match(2, 1, theme_id, ...)`，房主下发的是默认主题。
- 客机可点 ≡ 菜单主题按钮 → `Hud._pick_theme` → `theme_selected` → `_theme_swap()`，直接改本地 `theme_id`；下一次房主快照因 theme 不一致触发 `_start_match` 重建，造成棋子瞬回基地再被快照覆盖的抖动。

### B3 客机选子/出基地卡死（阻断）

`_on_lan_intent()`（约 1600-1624 行）顺序：

```gdscript
if current_team != actor: return
if busy or game_over or not match_started: return   # ← 第一道：busy 恒 true
...
elif a == "pick":
    if awaiting_pick or card_mode != "":
        _on_piece_pressed(int(p.get("i", -1)))       # ← 第二道：host 且 team!=0 直接 return
```

- `_do_roll()` 在进入等待选子时 `busy` 仍为 true（`_finish_turn` 才复位），所以客机的 `pick`/`card` 意图在第一步就被丢弃。
- 即使去掉 busy，`_on_piece_pressed()` 开头 `if net_role == "host" and current_team != 0: return` 会拒绝替客机队伍走子；`_on_card_pressed()`（约 3225 行）同样写法。
- 晴日牧原原始 5 → total 6，`_legal_moves(6, false)` 含 4 枚基地棋子 → `legal.size() > 1` → `awaiting_pick = true` + 弹「基地出发」；客机点棋子/选单选子只发出 intent，房主两处全部丢弃 → 永久卡死。
- 沙海原始 6 → total 5，`_legal_moves(5, true)` 同样含基地棋子（上一轮修的是这一步的合法判定），后续同样死在这条 intent 路径。**两个场景同一根因。**

## 3. 变更清单（决策）

### 3.1 src/Main.gd

1. `_is_ai(team)`：开头新增客机分支

```gdscript
if net_role == "guest":
    return team != 0 and team != net_guest_team
```

保证客机视角：0 队（房主）与自己的队伍都是人类，其余为 AI。`_team_is_human` 保持现状（已正确）。

2. 新增 `_do_pick(idx)`：把 `_on_piece_pressed()` 中「非 guest 分支 + `card_mode` 判断 + awaiting_pick 收尾 + `_move_piece`」整段逻辑搬入；
   `_on_piece_pressed()` 只保留本地入口门禁（guest 发 intent；host 且非 0 队返回；未 waiting 返回）后调用 `_do_pick(idx)`。
   同一函数供 `_on_lan_intent` 的 `pick` 分支调用，**不再经过 host 本地门禁**。

3. 新增 `_do_card(idx)`：同理拆分 `_on_card_pressed()`，`_on_lan_intent` 的 `card` 分支调用它。

4. `_on_lan_intent(p)` 重排门禁：

```gdscript
if net_role != "host": return
var actor := int(p.get("seat", -1))
if a == "duel": ...（保持现状，先于 busy）
if current_team != actor: return
if game_over or not match_started: return
match a:
    "roll": if not busy and not awaiting_pick and card_mode == "": _do_roll()
    "pick": if awaiting_pick or card_mode != "": _do_pick(int(p.get("i", -1)))
    "card": if not awaiting_pick and card_mode == "": _do_card(int(p.get("s", -1)))
```

`pick`/`card` 不再受 `busy` 拦截；`roll` 仍要求空闲，避免重复掷骰。

5. `_theme_swap(id)`：函数最前面加 `if net_role == "guest": return`（逻辑层拒绝客机改主题，与 UI 无关）。

6. `theme_previewed` 连接改为同时写回 Main 主题：

```gdscript
hud.theme_previewed.connect(func(id: String):
    if net_role == "guest": return
    theme_id = id
    arena.set_theme(id))
```

使房主在开局页选的主题能进入 `_lan_start_clicked()` → `_start_match()` → 快照。

7. `_start_match()` 末尾（`_update_all()` 之前）同步 HUD 主题状态：

```gdscript
if hud:
    hud.set_theme_id(theme_id)
    hud.set_theme_locked(net_role == "guest")
```

`_apply_net()` 无需额外改法：需要重建时已经走 `_start_match`，重建后 HUD 主题高亮与锁定一并生效；若 `need_rebuild` 为 false（同主题连续快照）则本来已一致。

8. `_lan_leave_clicked()` 与 `_on_lan_link_lost()` 里补 `hud.set_theme_locked(false)`，离开联机后恢复本地可改主题。

9. 客机侧证据（仅 `_lan_testplay > 0` 时打印，不影响正式包日志）：
   - `_on_lan_intent` 命中 pick/card 时 `print("LAN_INTENT ", actor, " ", a, " ", i)`；
   - `_on_piece_pressed` guest 分支发送前 `print("LAN_SEND ", ...)`；
   - `_apply_net` 重建后 `print("LAN_THEME ", theme_id, " scene=", arena._scene_id)`。

### 3.2 src/Hud.gd

1. 新增 `var _theme_locked := false`。
2. 新增 `func set_theme_locked(v: bool)`：对 `_theme_btns` 与 `_start_theme_buttons` 设 `disabled = v`、`mouse_filter = MOUSE_FILTER_IGNORE`（v 时），并按锁定时置灰字色；锁定时若菜单/开局页开着直接视觉置灰。
3. 新增 `func set_theme_id(id: String)`：更新 `_theme_id`，调用 `_paint_theme_btns()` 与 `_paint_choice(_start_theme_buttons, THEME_IDS.find(id))`，不 emit 信号（避免回环）。
4. `_pick_theme(id)` 与开局页 `_select_theme(id)` 开头加 `if _theme_locked: return`（防 UI 事件被脚本/自动化触发）。

### 3.3 版本与发布文件

- `project.godot`：`config/version="1.0.4"`。
- `export_presets.cfg`：iOS `application/short_version="1.0.4"`、`application/version="5"`；Android `version/code=5`、`version/name="1.0.4"`。
- `.github/workflows/build-mobile.yml`：`VERSION_NAME: "1.0.4"`、`VERSION_CODE: "5"`，版本断言、Release 说明更新（保留签名指纹段）。

## 4. 影响评估

- **存档**：`_capture_state()` / `_apply_save()` 的 `game` 字段完全不变；无迁移。B3 修复后房主会正常推进回合并触发 `_auto_save`，存档内容更完整，格式不变。
- **LAN 协议**：报文结构、PROTO=2、`intent/state/start/fx` 类型均不变。行为变化仅限房主对既有 `pick`/`card` intent 的采纳时机（由"仅空闲"改为"等待选子/选卡时也接受"），新旧客户端混用时旧客机同样受益，无兼容性破坏。
- **既有自测**：`pounce/save/save-slots/swap/duel/rules/update/stack` 全部回归；`rules` 自测中的 `dune-exit`/`dune-lock` 保持通过。新增 `--selftest-lanintent`，覆盖 cozy 5→6 与 dune 6→5 两条出基地意图链路。

## 5. 验证方案（全部本机可执行）

1. `--headless --path <项目> -- --selftest-lanintent`，输出 `SELFTEST_LANINTENT OK cozy=... dune=...`，用例内直接调用 `_on_lan_intent({"seat":1,"a":"pick",...})`，断言棋子 `cell >= 0` 且 `awaiting_pick == false`。
2. 既有 8 个自测逐个跑，输出 `... OK`。
3. 双进程局域网实测（本机回环）：
   - 房主：`--lan-host --theme=cozy --lan-start-delay=3 --lan-testplay=12 --lan-autoquit`；
   - 客机：`--lan-join=<房号> --lan-ip=127.0.0.1 --lan-testplay=12 --lan-autoquit`；
   - 客机 stdout 需出现 `LAN_THEME cozy`、`LAN_SEND pick`、`LAN_STATE guest <sig>` 且签名在 pick 后变化（棋子离开基地）。
4. 截图对比：房主与客机同主题截图（`--shot`）色板一致；客机 ≡ 菜单主题按钮置灰的截图。
5. 构建产物回读：APK `versionCode=5 / versionName=1.0.4`、证书 SHA-256 `13fb...fbde`；IPA `CFBundleShortVersionString=1.0.4 / CFBundleVersion=5`。

## 6. 发布

提交并推送 `main` → Actions `build-mobile` → 创建/更新 `v1.0.4` Release，上传 APK 与未签名 IPA，回报下载地址、产物内版本、签名指纹。

## 7. 风险与回滚

- 拆 `_do_pick`/`_do_card` 属纯结构调整，本地热座走同一入口，回归点：热座选子、道具卡选目标、客机选子。
- 若 `_on_lan_intent` 放宽 busy 后出现重复 pick（客机连点），`_do_pick` 内部 `if not awaiting_pick and card_mode == "": return` 天然防重入，且 `_pick_pool` 已清空。
- 回滚：`git revert` 本轮提交即可，无存档/协议遗留。
