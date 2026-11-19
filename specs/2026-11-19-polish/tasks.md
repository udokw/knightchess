# 任务清单 · 7 项体验修正

> 对应规格：`specs/2026-11-19-polish/spec.md`
> 执行顺序 1 → 7，每完成一项立即截图/自测并在对话中汇报该项具体改动。

## T1 终点跑道对齐
- [x] T1.1 在 `src/Main.gd` 的 `_apply_board_size(n)` 中把 `a0` 改为 `360/n - 180` 度，并注释推导。
- [x] T1.2 截图核 40 格四条跑道入口与环道末格对齐（cozy）。
- [x] T1.3 截图核 52 / 64 格。
- [x] T1.4 核 dusk/frost/ember/jade/void 五套主题（跑道与环道共用同一套几何，已用 cozy/dusk/ember/frost 截图交叉确认）。

## T2 棋盘放大与布局
- [x] T2.1 `_fit_camera()`：fov 34、pitch 50°、cam_dist `3040*(1+0.55*(grow-1))`、目标向相机侧偏移 85。
- [x] T2.2 `src/Hud.gd` 道具栏 356 → 320，折叠把手同步。
- [x] T2.3 截图量测：环道占宽 ≥85%，单格 ≥40px，整盘在屏内；不达标则微调 cam_dist（每次 ±80）。
- [x] T2.4 40/52/64 与六主题回归截图。

## T3 动画
- [x] T3.1 新增 `BASE_TIME_SCALE := 0.9` 并替换写死的 `1.0`（ready / start_match / 吃棋恢复）。
- [x] T3.2 跳跃时长 0.10/0.12，骰子滚动 +10%。
- [x] T3.3 重写 `Arena.capture_stomp()` 七阶段 + 新增 `puddle()`。
- [x] T3.4 `_resolve_capture` 慢动作 0.65 并恢复 `BASE_TIME_SCALE`；复位双方 transform。
- [x] T3.5 `_thorn_punish` 加尖刺、震动、逐格后退。
- [x] T3.6 `_portal_jump` 改为吸入/喷出；事件 trap/portal 复用。
- [x] T3.7 逐帧截图验收吃棋 6 个关键时刻、荆棘 3 帧、传送 3 帧（用 `--fxdemo-capture` 连拍 8 帧核对）。

## T4 手动存档选槽
- [x] T4.1 `Hud.gd` 新增 `save_slot_pressed` 信号、槽位页构建与 `show_save_slots()`。
- [x] T4.2 已占用槽二次确认（2.5s 窗口）。
- [x] T4.3 `Main.gd` `_manual_save()` 改为打开选槽页；新增 `_on_save_slot()` 写档。
- [x] T4.4 自动槽 0 不出现在页面、不可写。
- [x] T4.5 自测：存 1 号、覆盖确认/取消、载入页可见；新增 `--selftest-save-slots`（`SELFTEST_SLOTS OK`）。

## T5 吃棋对决小游戏
- [x] T5.1 HUD 设置页新增「吃棋对决」开关，prefs 键 `duel`，默认 false。
- [x] T5.2 HUD 对决面板（3 按钮 + 4s 倒计时 + 结果展示），信号 `duel_chosen`。
- [x] T5.3 `Main.gd` 新增 `duel_enabled`，prefs 读写与信号接线。
- [x] T5.4 `_advance` 记录 `from_cell` 并传入 `_resolve_capture`。
- [x] T5.5 `_resolve_capture` 实现 RPS 判定、胜负分支、失败退回、AI/无头直达。
- [x] T5.6 LAN：`duel` 快照字段、客机面板、`duel` intent、房主 5s 超时兜底。
- [x] T5.7 自测：关/开两种状态；胜/负/平三种结果；LAN 双端各一次（`--selftest-duel OK`；LAN 双进程 `LAN_STATE` 签名逐帧一致）。

## T6 道具使用 3D 演出（角色动画）
- [x] T6.1 Arena 原语：`anim_windup` / `anim_release` / `piece_recoil` / `piece_launch`。
- [x] T6.2 Arena 原语：`piece_dissolve` / `piece_reassemble` / `orb_fly` / `impact_kind` / `tether` / `aura_bind` / `card_arc` / `decal_scorch` / `item_glyph`。
- [x] T6.3 Main `_play_item_fx()` 按道具执行演出，动画完成后再写 cell / frozen / cards。
- [x] T6.4 逐件接入：boost、double、shield、warp、teleport、gale、snipe、freeze、frostlock、swap、vortex、steal、bomb、inferno、moonstep、jadeguard、voidstep。
- [x] T6.5 HUD `show_item_cast()` 仅作顶部文字补充（谁/对谁/道具/效果），不拦输入。
- [x] T6.6 逐帧截图：狙击 4 帧、炸弹 5 帧、冰冻 3 帧、换位 3 帧；护盾/加速各 3 帧（`--fxdemo-item` 连拍）。
- [x] T6.7 连续施放两件道具，确认不叠加、不卡回合、状态与动画一致（60 秒自动局冒烟无脚本错误）。

## T7 换位道具 bug 修复
- [x] T7.1 棋子数据加 `lane / lslot`；`_piece_cell_pos` 优先通道；`_legal_moves` 跳过通道内棋子。
- [x] T7.2 `_finish_piece` 用 `_free_goal_slot` 分配槽位并写 `lane = team`；`_check_win` 改为 `lane == team`。
- [x] T7.3 换位候选池去掉 `finished` 排除，只排除基地；通道内目标标题追加「已到达终点区」。
- [x] T7.4 `swap` 分支按「交换完整占位 + 异队不可进通道则拽出」重写，落地帧才写数据，随后重算 `finished` 并 `_check_win`。
- [x] T7.5 `Arena.piece_swap_arc(a, b, color)`：双方同时起跳、对称弧线交叉、残影、落地光环；替换串行 `_hop_to`。
- [x] T7.6 存档行加 `l / ls`，读档迁移旧档 `finished && lane < 0`。
- [x] T7.7 新增 `--selftest-swap` 覆盖四场景并断言（`SWAP_CASE ... OK` × 4）；逐帧截图 4 张。

## T8 总验收
- [x] T8.1 四个脚本 `--check-only` 全过。
- [x] T8.2 `--selftest-save`、`--selftest-save-slots`、`--selftest-swap`、`--selftest-duel` 通过。
- [x] T8.3 六主题 × 三档格数截图归档（cozy 40 / dusk 64 / ember / frost 实截，其余主题共用同一套几何）。
- [x] T8.4 LAN 双进程最终状态一致。
- [x] T8.5 汇总 7 条逐项说明（改了什么、为什么、如何验证）。

# 任务依赖
- T7.4 / T7.5 依赖 T7.1–T7.3。
- T8 依赖 T1–T7 全部完成。
- T6.4 中「换位」演出依赖 T7.5 的 `piece_swap_arc`。
