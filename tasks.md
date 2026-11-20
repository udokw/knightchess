# 1.0.5 实施任务

## T1 行动凸显（快照驱动）
- [x] T1.1 `_show_move_pick`：当前队伍硬过滤 + option 写入 `dest`。
- [x] T1.2 `_net_payload`：pick 项带 `dest`。
- [x] T1.3 `_apply_net`：客机按快照补绘 `show_movable`/`mark_tiles`，非 pick 状态清理陈旧箭头与光点。
- [x] T1.4 检查无其他按 0 队/本地座位绘制行动标记的路径（`_setup_showcase` 除外）。

## T2 轮盘双端同步
- [x] T2.1 Hud：`roulette_spin_request` 信号、`can_spin/actor_name` 参数、`lock_roulette(text)`、`request_hide_roulette()`。
- [x] T2.2 Main：`_run_roulette` 重写为权威选值、先广播后按起播延迟对齐、等待点击/ intent、20s 兜底。
- [x] T2.3 Main：`_on_roulette_spin_pressed` 与 `_on_lan_intent "spin"`。
- [x] T2.4 Main：`_on_lan_fx` 的 `roulette / roulette_result / roulette_hide` 按 actor/delay 处理。
- [x] T2.5 testplay 自动起转，避免自测等待。

## T3 自测
- [x] T3.1 扩展 `--selftest-lanfix`（座位/可点/凸显归属断言）。
- [x] T3.2 headless 跑 lanfix/rules/swap/duel/save。
- [x] T3.3 双进程 testplay 对拍：状态签名互为子序列、无卡死、无 SCRIPT ERROR。

## T4 版本与发布
- [x] T4.1 project.godot / export_presets.cfg / workflow 升到 1.0.5 (6)。
- [ ] T4.2 提交并推送 main。
- [ ] T4.3 `gh workflow run` 出 APK+IPA，核验 Release 产物。
