# LightAndDarkness

为 Remains 增加能影响战斗的明暗区域、可装备灯具，以及场景灯的破坏和维修。用户于 2026-10-15 确认：**战术光暗与生存探索并重，兼顾氛围**。

当前是调查与设计阶段，尚无可玩的 SWF。正式游戏、加载清单和存档未修改。

## 阅读入口

- [原版光源与光照系统调查](design/native-lighting-survey.md)：先读此文，了解原版能力、限制和实现路线。
- [战术光暗与生存探索草案](design/vision-and-options.md)：玩法候选、装备与维修循环、推荐原型及验收。
- [渲染证据](knowledge/discoveries/rendering-audit.md)、[灯具与维修证据](knowledge/discoveries/fixtures-audit.md)、[战斗感知证据](knowledge/discoveries/combat-audit.md)：源码符号、行号与未验边界。
- [当前状态](state/MEMORY.md)与[开发日志](state/journal.md)：下次接手入口。

## 项目参数与当前限制

项目目录就是本目录；未来入口拟为 `LightAndDarknessMod.init(main:*)`，产物拟为 `release/LightAndDarknessMod.swf`。src/build/release 目前只有目录占位，没有登记热键、日志、存储或 loader。

治理沿游戏根 `../../GOVERNANCE.md`。本次创建 `AGENT_SCOPE.md` 被现有 protected-governance 钩子拦截，尚未落盘；没有关闭护栏或改用另一工具写入。现阶段依 README 与 MEMORY 接续项目参数。

建议接续工作是隔离验证“照度只改变视觉发现而不影响听觉”的更新时点，再做单房灯具原型。此建议不代表用户已批准所有后续功能或部署。
