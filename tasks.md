# v1.0.4 修复任务清单

> 前置：spec.md 已获确认。

## T1 · B1 客机把房主显示成 AI
- [ ] `Main._is_ai()` 增加客机分支：`team != 0 and team != net_guest_team`
- [ ] 复查 `_team_display()`、`_update_all()` 队伍栏、回合提示在客机视角的文案
- 验收：客机队伍栏 0 队不出现「AI」，自己显示「你」；2/3 队 AI 补位仍显示 AI

## T2 · B2 主题权威与显示
- [ ] `Hud` 新增 `_theme_locked` / `set_theme_locked()` / `set_theme_id()`
- [ ] `Hud._pick_theme()`、开局页主题选择加锁定门禁
- [ ] `Main._theme_swap()` 客机直接 return
- [ ] `theme_previewed` 连接写回 `theme_id`（仅非客机）
- [ ] `_start_match()` 同步 `hud.set_theme_id/theme_locked`
- [ ] `_lan_leave_clicked()`、`_on_lan_link_lost()` 解锁
- 验收：客机 ≡ 菜单主题按钮置灰且点击无效；客机本地 `theme_id` 始终等于房主下发值；房主开局页选的主题进入对局

## T3 · B3 客机出基地卡死
- [ ] 拆出 `_do_pick(idx)` 与 `_do_card(idx)`，`_on_piece_pressed` / `_on_card_pressed` 仅作本地门禁
- [ ] `_on_lan_intent()` 重排门禁：`pick`/`card` 不受 busy 拦截，`roll` 仍要求空闲
- [ ] `_lan_testplay > 0` 时打印 `LAN_INTENT` / `LAN_SEND` / `LAN_THEME`
- 验收：晴日 raw5→6 与沙海 raw6→5 均可出基地并继续对局

## T4 · 新增自测 `--selftest-lanintent`
- [ ] 用例 A：cozy，`total=_theme_roll_total(5)`，team1 全在基地，模拟 `awaiting_pick` 后调用 `_on_lan_intent` pick，断言 `cell >= 0`
- [ ] 用例 B：dune，`total=_theme_roll_total(6)`，`_legal_moves(5, true)`，同上
- [ ] 打印 `SELFTEST_LANINTENT OK cozy=... dune=...` 并 `quit()`
- 验收：headless 输出 OK

## T5 · 回归全部自测
- [ ] `pounce` / `stack` / `duel` / `save` / `save-slots` / `swap` / `rules` / `update` / `lanintent`
- 验收：全部 `OK`

## T6 · 双进程局域网实测证据
- [ ] 房主 cozy + 客机加入，客机日志出现 `LAN_THEME cozy`、`LAN_SEND pick`、`LAN_STATE` 签名变化
- [ ] 截图：两端主题一致、客机主题按钮置灰
- 验收：日志/截图入汇报

## T7 · 版本 1.0.4 / build 5
- [ ] `project.godot`、`export_presets.cfg`（iOS/Android）、workflow env 与断言、Release 说明

## T8 · 出包与发布
- [ ] commit + push main
- [ ] 触发 Actions，等待 Android APK / iOS 未签名 IPA
- [ ] 回读 APK `versionCode=5`、`versionName=1.0.4`、证书 SHA-256；IPA 版本字段
- [ ] 创建 `v1.0.4` Release 并上传产物，回传下载地址

## T9 · 逐条汇报
- [ ] B1/B2/B3 分别说明根因、改法、对存档 / LAN 协议 / 自测的影响
