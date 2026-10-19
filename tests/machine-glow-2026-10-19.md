被测技能：remains-runtime-debug / remains-auto-testing 2026-10-19.1→.2；remains-mod-build / remains-release-gate / remains-mod-memory / remains-knowledge-contribution
技能归属：Remains工作区级 `.agents/skills`
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness

# 0.3.2 微光调查、验证与部署

## 任务与实现

用户要求各种炮塔和蜘蛛地雷微光，授权依据原版图像决定效果。调查8型炮塔、7种炮管、地雷休眠/展开/行走8帧/跳跃、四向安装和独立雷霆炮座。生产实现及参数见[设计](../design/machine-glow-v0.3.2.md)。未新增碰撞体、伤害或AI钩子，未调用internal状态。

冻结候选：`build/out/machines-v032/LightAndDarknessMod.swf`，27,734字节，SHA256 `3835827D0D2702EC55AB13721DCED7D8463C3A69780C6C37B5816BBD72164B46`，生产源码提交7c6ae97。反编译17个自身类，版本、机器灯与边框保护均存在，无fe存根或测试类。FFDec日志锁被沙箱拒绝，17类导出成功；未扩大其权限。

## 已完成证据与失败保留

- 正确原版图集：`remains-lad-machine-20261019164122257`。第一次ncid参数使用错误的图集不作八种造型依据。
- 初版D250候选单开170项：`remains-lad-machine-20261019165247821`；组合173项：`remains-lad-machine-20261019170134494`。后者含Stage开/关对照，已目视确认小范围黄/红散光。它们不是最终3835的通过证据。
- D250组合回归：`20261019170300408`、`20261019171305109`在大场景边框断言失败，第二次记录四边均+2，镜头档位2、scaleV=0.6583333。未部署失败候选。
- 正式514A基线：`20261019171643862`单纯旅行时边框正常、相机对照新增可见像素0；`20261019171854058`完整序列边框也正常，但旧测试硬编码“预载必须开启”失败。不能把这两组称为稳定重现了同一边框故障。当前宿主反编译确认drawLoc在分块绘制中确实重置边框为+2，因此最终候选增加无效方向保护；测试保留方向断言并增加整幅Stage原版相机对照。
- 预载检查已改为比较切换前后的实际值，验证用户选择保持；不再强制要求开启。其余断言保留。
- 调查失败：缺少测试副本supported-mods.txt、探针名不以Mod结尾、误写internal aiState、兄弟加载域不能直接getDefinitionByName解析LAD类。分别按启动器接口补目录、使用合法探针入口、读取公共时间线、从运行实例constructor取得真正生产类。未把测试类编入生产包。

## 环境与方法

正式清单只读，测试副本用RemainsModLauncher精确选组；保存selection.json并读取本轮SharedObject加载session，核对requested/ok严格相等、无err、时间落在本次进程寿命内。单开=LAD+探针；组合另含ModLoader、ContinuousScene、RealisticVision、WallBlend。前期组合绑定以下实际字节：

| 文件 | SHA256 |
|---|---|
| pfe.swf | 2A4662488BA3B690EB23ACFE4B79ACA3F0D9AE114E5E2DEE7595AF3CABFFB3EA |
| ContinuousScene | 70C06879A2CFFE85901E5C8E19FC1715028D5C38934975E970569468737309D5 |
| RealisticVision | 76314B819151FBA6F67F6D740B21030A9EEC8359AF4C9C9DDEB83D4CAF5C46B7 |
| WallBlend | DF9AA07265E2538E115A5F048D272B85FC1C34D00EC4BC81585CD40D96648F76 |
| ModLoader | BD71B6F31774B97841D4C158451DA0353B53BC46AC72F8E2A7FE2C3F3F4908B1 |

3835在此前组合通过99项回归（20261019172129540）与173项微光（20261019172548299）。部署预检检测到其他任务已更新宿主/CS/WB，主动拒绝旧基线，未执行替换。随后保留新文件补验：宿主A61EA4A30F0E4978173F2B92B5F33A02960098D706B810FC6196105278EFA73F；CS B5E8110E11FE2DF8A748B223DFFA6E0EC42E4F61A931D4D4E065CC199EFA2F1B；WB 0BD209A1763D1C08BCEEAA6415DC768AB3D18AD99BAD377B4D8C188EBD48DE5A；RV与ML保持上表值。当前组合99项回归20261019172954512通过。

每次使用唯一remains-lad-machine-* AIR ID、独立存储。早期图集沿原有Hidden窗口流程；技能更新后专用驱动改用ModLoader的HiddenProcess私有Windows桌面，不切换输入桌面，失败不退回前台；不使用Ghost。只停止自己的进程，不读写真实pfe存档。运行器不产生其他模组的Python缓存。

本次自然任务实际采用了新启动器选择和专用驱动迁移，最终部署按持续授权执行。静态构建、加载、行为/像素、部署回读分别留证。未测试失败回滚实际执行、联机、DLC或全14模组组合；不作整体性能提高结论。调查图集和像素验证不是原生显卡屏幕捕获。

## 最终组合、安装与回读

其他任务随后将宿主更新为`02BFABE6A3B4881DFA1227515E71F2A8EA863D4B1B468FBE1D8008AEBA7D9240`，CS B5E8 / WB 0BD2 / RV 7631 / ML BD71不变。未复用A61E的结果作为新宿主认证；冻结3835再次通过如下检查：

| 实际文件来源 | 独立AIR身份后缀 | 结果 |
|---|---|---|
| 最终候选 | 20261019173524794 | 99项灯具/存读档/大场景回归，包括8次整幅Stage与原版相机逐像素对照 |
| 最终候选 | 20261019173634395 | 173项微光专项、实际场景开关像素对照 |
| 正式release读回 | 20261019173853199 | 再次173项，0.3.2标记、持续心跳、精确加载集合通过 |

完整前缀均为`remains-lad-machine-`。最终证据归档于[evidence](evidence/2026-10-19/machines-v032/)，含原版图集、初期失败、基线、最终组合与安装后图像。已目视核对原版形态、微光前后和大场景截图；原生关机与致死伤害确实使光消失。地雷四向与镜像使用显示变换测试，不冒称逐张天然墙挂地图实战；其它状态通过实际原生动画/公开方法与受控状态验证。

2026-10-19 17:38:43单文件原子安装3835，27,734字节；备份`build/backups/machines-20261019-173843-193/LightAndDarknessMod.v0.3.1.swf`，SHA256 `514A7671D4DA517A31045AEAF8FFAD3089AA66705FE58D14DC339F849589A7F6`。回执[state/machine-deployment-2026-10-19.json](../state/machine-deployment-2026-10-19.json)。只恢复此备份可回退，前提是正式release仍为3835，避免覆盖后续版本；保留宿主、其他模组、清单和真实存档，重启才生效。

正式加载清单当前已由启动器保存为`LightAndDarkness|LightAndDarknessMod|1|1|1`，本任务只认证当前application.xml指向的1.02，不修改用户选择，也不把其它版本的勾选视为兼容认证。部署脚本最初沿用旧版1/0/0精确断言，核对实际恒定33DE清单后改为匹配现有行，未改清单文件。部署前后均复核受保护文件指纹，无覆盖他人更新。

发布门禁：候选构建、版本、最终99+173项、持续授权、依赖/清单核对、唯一备份、同一文件替换、正式回读173项、回退和状态记录均完成。没有操作玩家实例或存档；用户保存并重启游戏后生效。地图普遍偏暗的另项调查只作独立记录，未混入本次生产调整。
