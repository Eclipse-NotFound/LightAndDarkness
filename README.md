# LightAndDarkness

为 Remains 增加能影响战斗的明暗区域、可装备灯具，以及场景灯的破坏和维修。用户于 2026-10-15 确认：**战术光暗与生存探索并重，兼顾氛围**。

当前为 **0.1.0 已部署版本**：动态遮光、随身灯、原版场景灯损坏/维修/保存已实现。正式文件为 `release/LightAndDarknessMod.swf`，已加入通用加载名单，重启游戏生效。部署记录与回退办法见 [部署记录](state/deployment-2026-10-15.md)。

## 当前可用功能

- 场景灯与随身锥形灯实时合成照度，墙体和门遮挡光线。照度层独立于原版探索黑幕。
- 支持 10 类原版灯具；40 点耐久，原版子弹/爆炸可打坏，灯灭后不再提供照明。
- `Alt+L` 开关随身灯；`Alt+E` 切换最近的完整灯；受损灯按住 `Alt+E` 两秒维修，消耗背包废金属 ×2。松键、走开、受伤或暂停会中断。
- 灯具耐久、开关与随身灯开关随原版存档保存。关闭模组恢复原版显示，重新开启恢复模组状态。
- 普通视觉发现按玩家所在照度调整；原版听觉、开火暴露、探索格与 SATS 不重新定义。
- ModLoader 的“光与暗”页可调整开关、暗区底亮度、随身灯和视觉发现影响。

随身灯目前是验证玩法的内置灯，还没有新增背包装备、装备槽、电量或灯具道具。暗区底亮度等设置暂为本次启动偏好；随身灯与场景灯状态随存档保存。

## 构建与验证

在游戏根目录运行 `mods/LightAndDarkness/build/build.ps1 -Tests` 构建候选及独立测试驱动；工具路径可用 `-Java`、`-Tools` 覆盖。依赖只读的本机 Sandevistan 工具链，不复制其源码。

`mods/LightAndDarkness/tests/run.ps1 -SkipBuild -Mixed` 在模组自己的副本中运行，使用唯一 `remains-lad-test-*` AIR 身份。它不使用正式 `pfe` 存储；测试结束只清理自己启动的进程及临时描述符。运行 AIR 需允许创建独立测试存储。`build/build.ps1 -TestsOnly` 可只更新探针、保持已测候选字节不变。

加 `-Installed` 从正式release回读文件及本模组的加载行，并核对测试副本字节；此模式不重编译。组合测试只包含下述已列明的四个接口模组。

最终混装检查 **47 项通过**，另有 **4 项冷启动读档检查通过**；含 192×75 格、88 盏灯的大场景。见 [验证记录](tests/verification-2026-10-15.md)及[实现说明](design/implementation-v0.1.md)。

## 阅读入口

- [原版光源与光照系统调查](design/native-lighting-survey.md)：先读此文，了解原版能力、限制和实现路线。
- [战术光暗与生存探索草案](design/vision-and-options.md)：玩法候选、装备与维修循环、推荐原型及验收。
- [渲染证据](knowledge/discoveries/rendering-audit.md)、[灯具与维修证据](knowledge/discoveries/fixtures-audit.md)、[战斗感知证据](knowledge/discoveries/combat-audit.md)：源码符号、行号与未验边界。
- [当前状态](state/MEMORY.md)与[开发日志](state/journal.md)：下次接手入口。

## 项目参数与当前限制

入口为 `LightAndDarknessMod.init(main:*)`，正式路径为 `release/LightAndDarknessMod.swf`，治理沿游戏根 `../../GOVERNANCE.md`。用户授权的 `AGENT_SCOPE.md` 已创建。

当前仅认证本机 1.02 宿主及本轮列明组合；未认证 DLC、联机、全部生产模组同时启用或全部敌种。大场景转换会触发原版预载，实测仍有秒级停顿；逐帧照明耗时与这段预载分开记录。
