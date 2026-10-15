# LightAndDarkness 当前记忆

## 1. 这个模组是什么

增强 Remains 1.02 的光照：可持续存在的黑暗区影响战斗，玩家可装备灯具，场景灯可破坏和维修。拟用入口 LightAndDarknessMod.init(main:*)，当前仅调查与设计。

## 2. 用户偏好与协作约定

2026-10-15 用户选择“战术光暗＋生存探索”，更强氛围也是好事。用户要求全面调查原版并头脑风暴，尚未拍板具体数值、装备槽或全部功能。沿本区中文沟通、隔离模组权限。

## 3. 当前状态

- 2026-10-15 完成源码/资源结构调查与方案草案；无 SWF、无游戏内验证、无部署。
- 独立仓库位于本模组目录；源码、构建与发布目录暂为空占位。
- 正式宿主本轮指纹 BEBEEA8B…D4011F，含 ContinuousScene 渲染扩展，不能当成原版源码逐字一致。

## 4. 正在进行与卡点

调查已归档，待用户决定进入原型。AGENT_SCOPE.md 创建被 protected-governance 钩子拦截，尚未建立；未绕过。参数暂见 README，治理正本在 ../../GOVERNANCE.md。

## 5. 已知问题

原版背景灯晕、探索黑幕和敌人感知分离；Tile.visi 耦合地图/传送/SATS，不宜作新照度。背景灯无HP/交互/存档，整房allon会开锁。普通帧后改visibility可能被actions覆盖；childObjs更新时点是待验候选。当前混装/大场景与全敌种尚未验证。

## 6. 下一步

优先验证公开更新时点能否只改变视觉感知，再做两灯一头灯的单房原型；机制成立后才加电量、材料、维修与存档。源码/资源全面调查不等于可玩性验收；任何部署另按发布门禁执行。

## 7. 深入了解

- 总览：../design/native-lighting-survey.md
- 玩法：../design/vision-and-options.md
- 证据：../knowledge/discoveries/{rendering,fixtures,combat}-audit.md
- 公共沉淀：../../../shared-knowledge/rendering/discoveries/native-lighting-vs-illumination-2026-10-15.md
- 本轮经过：journal.md 首条。构建/测试/部署入口尚未创建；不要照抄旧专属loader流程，当前使用 mods/loader-manifest.txt。
