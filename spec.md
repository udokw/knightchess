# 1.0.5 局域网表现归属修复 Spec

## 背景
1.0.4 真机联机复测发现两处“表现归属”问题：
1. 当前行动棋子的凸显标记在客机端落到了主机一方棋子上，两端不一致。
2. 命运事件转盘在客机端起播严重滞后/被整段吞掉；房主代替客机显示并操作转盘。

## 现状与根因（代码事实）
### 1. 行动凸显
- 棋子头顶“旋转箭头 + 脚下光环”由 `Arena.show_movable(nodes, color)` 生成（[Arena.gd#L3579](file:///g:/AI/app%E9%80%86%E5%90%91/KnightChessGodot/src/Arena.gd#L3579)）。
- 唯一玩法调用点是 `Main._show_move_pick(legal, total)`（[Main.gd#L2977](file:///g:/AI/app%E9%80%86%E5%90%91/KnightChessGodot/src/Main.gd#L2977)），只在**权威端**执行；客机 `_apply_net` 只同步 HUD 选项，不生成 3D 凸显。
- `_show_move_pick` 未校验 `p["team"] == current_team`，`_pick_pool` 若含陈旧索引，箭头会挂到别队棋子；客机端无“清箭头”路径，状态变化后可能残留。
- 两端共同的“当前回合”信息只有 `current_team`（客机来自快照 `net.team`），`Arena.set_active_team` 只影响基地灯光。

### 2. 命运轮盘
- 轮盘结果 `roulette_result` 在房主**本地动画播放完毕**后才广播（[Main.gd#L4703-L4713](file:///g:/AI/app%E9%80%86%E5%90%91/KnightChessGodot/src/Main.gd#L4703-L4713)），客机因此晚 3.3s 才起播。
- 客机收到 `roulette_hide` 后固定等 2.4s 直接隐藏（[Main.gd#L1885-L1889](file:///g:/AI/app%E9%80%86%E5%90%91/KnightChessGodot/src/Main.gd#L1885-L1889)），会砍断客机刚开始的 2.5s 旋转 → 只剩音效。
- 客机轮盘按钮被 `hud.lock_roulette()` 永久禁用（[Main.gd#L1882](file:///g:/AI/app%E9%80%86%E5%90%91/KnightChessGodot/src/Main.gd#L1882)），且点击不会向房主发意图。
- `_run_roulette` 只在房主端运行，房主无论轮到谁都自己点。

## 方案
### A. 行动凸显改为“快照驱动 + 双方渲染”
文件：`src/Main.gd`
1. `_show_move_pick`：
   - 计算 `dest` 时保留到 option（新增 `"dest": dest`），并对 `legal` 做硬过滤：仅接受 `pieces[i]["team"] == current_team` 的棋子。
   - 继续在权威端绘制箭头/落点；客机端由快照补绘。
2. `_net_payload`：`pick` 每条增加 `"dest": int(o.get("dest", 0))`。
3. `_apply_net`：
   - 解析 `pick` 时同步收集 `nodes` / `dests`（`_pt_pos(_path_point(p["team"], dest))`，仅取 `p["team"] == current_team`）。
   - 当 `current_team == net_guest_team && awaiting_pick && !_pick_pool.is_empty()`：`arena.show_movable(nodes, TEAM_COLORS[current_team])` + `arena.mark_tiles(dests, TEAM_COLORS[current_team])`。
   - 否则：`arena.clear_movable()` + `arena.clear_marks()`，避免陈旧箭头留在别队棋子上。
   - 凸显颜色/对象只由快照 `current_team` 决定，不使用 `net_guest_team`、不写死 0。
4. `_update_all` 已按快照 `current_team` 调 `arena.set_active_team`，保持不变。

### B. 轮盘双端同步起播 + 当前回合玩家点击
文件：`src/Hud.gd`
1. 新增 `signal roulette_spin_request`；按钮 pressed 改为 `_request_spin()`，只发信号，不本地起转。
2. `show_roulette(segments, kind, can_spin := true, actor_name := "")`：按 `can_spin` 决定按钮可用与提示文案；不变的部分保持原样。
3. `lock_roulette(text := "等待对手转动轮盘…")`：禁用按钮 + 文案。
4. 隐藏改为可延迟：新增 `_roulette_hide_pending` 与 `request_hide_roulette()`；旋转中只记标记，在 `_roulette_reveal` 的 0.8s 亮相结束后再隐藏，保证不中断。
5. `spin_roulette(force)` 保持动画（2.5s 旋转 + 0.8s 亮相），重复调用在旋转中直接忽略。

文件：`src/Main.gd`
1. 新增 `var _roulette_spin_pending := false`。
2. `_run_roulette(kind, p)` 重写为“房主权威 + 统一发令”：
   - 先 `hud.show_roulette(segments, kind, can_spin, TEAM_NAMES[actor])`，`can_spin = _is_local_actor(actor) and not _is_ai(actor)`。
   - `_net_fx("roulette", {"kind", "segs", "actor"})`。
   - 等待起转：AI/auto/`_lan_testplay>0` 自动；否则轮询 `_roulette_spin_pending`（本地点击或客机 intent 置位），20s 超时兜底自动起转，避免断线卡死。
   - 房主用 `randi() % n` 选结果，先广播 `roulette_result {"idx","delay":260}`，再按同一延迟本地起播；客机收到后同样延迟 260ms 起播 → 两端同一起播点（误差≈单程网络延迟）、时长一致。
   - **不能广播绝对时间戳**：两端进程的 `Time.get_ticks_msec()` 各自从启动计时、不同源，客机会算成几十秒的等待。
   - `await hud.roulette_done` 后再发 `roulette_hide`（客机不再用固定 2.4s）。
3. 新增 `_on_roulette_spin_pressed()` 并连接 `hud.roulette_spin_request`：
   - 客机：`lan.send_intent({"a":"spin"})` 并 `hud.lock_roulette()`；
   - 房主/单机：`_roulette_spin_pending = true`。
4. `_on_lan_intent` 新增 `"spin"`：`actor == current_team && roulette_open` 时置位 `_roulette_spin_pending`。
5. `_on_lan_fx`：
   - `"roulette"`：按 `actor` 判断客机是否可点（`actor == net_guest_team` 则不禁用），否则 `lock_roulette(TEAM_NAMES[actor])`。
   - `"roulette_result"`：按 `delay` 延迟后 `hud.spin_roulette(idx)`。
   - `"roulette_hide"`：`hud.request_hide_roulette()`（不再定时器硬切）。

### C. 自测
- 新增/扩展 `--selftest-lanfix`：校验 `net_role="guest"/net_guest_team=1` 时，`current_team=1` 的凸显与轮盘可点归属为客机、`current_team=0` 不可点；`_is_local_actor` 在两端座位映射正确。
- 运行 `--selftest-lanfix / --selftest-rules / --selftest-swap / --selftest-duel / --selftest-save`。
- 双进程 `--lan-host/--lan-join --lan-testplay=8 --lan-autoquit` 对拍：状态签名一致、无卡死；轮盘用例两端都能走完。

### D. 版本与发布
- `project.godot` → 1.0.5；`export_presets.cfg` → name 1.0.5 / code 6（iOS short_version 1.0.5 / version 6）。
- `.github/workflows/build-mobile.yml` → `VERSION_NAME 1.0.5`、`VERSION_CODE 6`、Release 说明更新。
- 提交推送后 `gh workflow run`（移除 `GH_TOKEN`，用 keyring 凭据），核验 APK/IPA 与 Release。

## 影响面
- 存档：无字段变化。
- 联机协议：`net.pick[]` 增加 `dest`；新增 intent `spin` 与 fx 字段 `actor`/`delay`。旧版本客机与新主机混用不在支持范围（双端同包发布）。
- 单机/热座：轮盘改为“点击后房主统一发令”，本地行为不变。

## 验收
1. 客机回合：两端箭头都只出现在客机（蓝队）可行动棋子上。
2. 客机踩事件格：轮盘两端同时出现、同时起转、时长一致；客机可点击；房主端只展示不可点，结算由房主广播。
3. 房主回合：反向成立。
4. headless 自测与双进程对拍全绿；双端包版本 1.0.5/6。
