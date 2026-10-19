# 局部光源增强与终端微光验证

被测技能：remains-auto-testing / remains-runtime-debug 2026-10-19.2，remains-mod-build / remains-mod-memory在册版，test-report 2026-09-16.1；最终发布门禁由整合会话执行。
技能归属：Remains/.agents/skills（调试/发布维护在ModLoader）；test-report为C:/Users/hello/.agents/skills/test-report。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness。

## 输入与候选

增强机器、存档点、出口和试炼入口的局部光；新增六类终端的未破解亮/已破解暗。参数与原版状态依据见[设计](../design/local-glow-2026-10-20.md)。原版图像已实看，配色沿主屏幕；不改基础环境光或玩家交互。

工作树存在暂缓验证的0.4.2缓存候选及并行0.5.0拖尾工作。独立对照候选通过`tools/build-local-glow.py`从已发布源码c5a04c4导出，只叠加两个collector，标记0.4.1-glow；不会发布该候选或覆盖他人修改。冻结SHA256 **590C8AEEA95AFCE6118A271F7476D2E0A675F00A662320DAC132532590F19254**，32927字节，源码清单`build/out/local-glow/source.json`。

## 独立候选结果

| 本轮独立AIR身份后缀 | 检查 | 结果 |
|---|---|---|
| machine-20261020001101006 | 机器原生状态、位置、八类炮塔、蜘蛛动画、力场、真实像素/遮挡、开关 | 173 PASS |
| landmark-20261020001100734319 | 既有地标93＋环境31＋新增终端93 | 217 PASS |

同一冻结文件，精确组合LAD/ModLoader/ContinuousScene/RealisticVision/WallBlend/对应探针。本轮新loader session的requested/ok一致、无err，0.4.1-glow版本和心跳正常；唯一AIR ID、独立副本/存储、私有后台桌面，未读写用户pfe存档。

终端每类15项：原图颜色、只读采样、弱于炮塔、原本无锁/失败锁死不误判、真实原生hack变暗、原生保存101、重建Box载入后继续暗、透明度、隐藏/损毁/零HP/视口外/摘图关闭；另3项像素检查验证实际照明、墙体遮光和破解后像素下降。此处“载入”是使用原生保存对象重新构造，不冒充跨进程冷读档。

已实看机器12格、地标6格效果图，六种终端原图及破解前后图。光色在物体附近更清晰，远处仍暗。展板使用0.10/0.14底光帮助比较，不冒充自然地图；实际营地及机器场景截图另留。软件Stage截图不等于前台GPU认证。

## 过程问题与边界

- 第一次导出终端图集通过。第一轮地标217功能检查通过，但包装版本检查发现隔离构建只改入口常量，Runtime仍有两个0.4.1字面量；机器相同版本断言提前失败。修正导出脚本后重编，再跑上述两轮，失败轮不计完整通过。
- Windows旧powershell子进程编译成功后缺少Get-FileHash命令，导致构建脚本非零退出；末尾改为.NET SHA256，并把编译配置移到各输出目录，避免并行候选共用candidate.xml。最终重编和验证成功。
- 未获知其他会话的性能时段即启动两个纯功能实例。实际重叠区间为2026-10-20 00:11:02.993–00:11:40.087（UTC+8），发现后已把精确起止告知性能负责人，要求剔除受影响样本。自己的进程/桌面正常结束；本轮不声称性能提升，后续AIR须协调。属于协作时段信息缺失，不是功能测试失败或性能改善证据。
- 独立候选阶段未替换正式文件；最终0.5.0同字节复验及统一安装已完成，见下节。DLC、联机、全部自然地图与整体FPS未由本轮认证。

## 产物与交接

本次自然选用技能完成任务，未启动新子代理。证据归档`tests/evidence/2026-10-20/local-glow/local/`；原件在build/evidence对应ID。生产源码两文件、设计、参数化机器测试、终端探针及本报告为本次产物。报告新证据为终端原生破解标记、重建恢复和实际像素变化；待维护吸收，无技能行为修改。

整合会话`01a13e52-3948-7cd1-af6f-7e7462e29b4a`为唯一部署方。机器最终复验：`tests/run-machines.ps1 -Mixed -Candidate <冻结SWF> -Mode verify -ExpectedVersion 0.5.0 -ProbePath build/out/local-glow/LightMachineProbeMod.swf`。地标与终端：`tools/run-landmark-tests.py --candidate <冻结SWF> --mode verify --mixed --expected-version 0.5.0 --terminals`，要求217而非仅124。最终字节与部署回执补在本记录。

本轮实现与独立证据已精确提交60118c8。代码差异检查通过，原生stderr的CRCRLF按原件保留，未为消除文本空白提示而改写日志。报告已查重登记全局测试报告台账第624行并回读确认，状态待吸收。

## 最终整合候选准备

00:26已回读`build/out/trails-v050/LightAndDarknessMod.swf`与`freeze.json`，SHA256为**4291B8250D607EA1C6B5BE48DED48BB5FA42AF37BFE0CB3ED7A2E7C84EFBBF90**。冻结的Machine/Landmark源码哈希分别为9E964A8A/A33AB324，与本轮已验源码相同；菜单文字已包含终端。这里只证明整合内容和字节身份，不能把独立590C的173/217当成4291运行结果。

AIR时段由整合/性能/大场景会话协调，等待明确释放后再启动；00:26时正式release仍94A2F086。没有把任何其他会话的背景摄影或性能实例计入自己的验证。

## 最终4291同字节复验

整合会话明确移交窗口后，两轮串行验证已完整通过，未并行AIR：

| 本轮身份后缀 | 结果 | 生产SHA256 |
|---|---|---|
| machine-20261020004055861 | 173 PASS | 4291B8250D607EA1C6B5BE48DED48BB5FA42AF37BFE0CB3ED7A2E7C84EFBBF90 |
| landmark-20261020004205791353 | 217 PASS（93地标＋31环境＋93终端） | 同上 |

两轮均加载0.5.0，心跳正常，实际loader新session与精确选组一致，没有err或运行异常。宿主02BF、CS241E、RV7631、WB0BD2、MLBD71；终端新版逻辑、颜色、破解后变暗、原生保存对象重建及墙体遮挡均再次执行。已查看最终机器与地标展板、终端破解后图，效果与独立候选一致。

机器进程结束于00:41:28.403、地标进程结束于00:42:32.094，私有桌面均关闭，已明确把AIR窗口交回整合会话继续其余回归。两轮原件在build/evidence对应ID，完整精选归档在`tests/evidence/2026-10-20/local-glow/final-v050/`。本节证明最终候选的本批功能，不代替安装回执或其他会话负责的回归。

## 已部署并回读确认

整合会话于**2026-10-20 00:47:27（UTC+8）**仅替换正式`release/LightAndDarknessMod.swf`，回执`state/trail-deployment-2026-10-20.json`。00:48:30完成安装后35项拖尾冒烟，独立实例`remains-lad-projectile-trails-20261020004744143051`。本会话随后自行回读正式SWF，SHA256确为最终4291B825全指纹；读取该正式冒烟原件确认0.5.0、35项、roomsLoad=1、error为空，并核对回执restartSmoke=PASS。

本批机器173及地标/环境/终端217来自安装前的同一4291文件；安装后执行的是35项功能冒烟，不能表述为安装后又重跑了173/217。整合会话还负责其它弹丸、保存回归与发布门禁，具体结果归其最终报告。

备份为`build/backups/trails-20261020-004727-123219/LightAndDarknessMod.v0.4.1.swf`（94A2F0861B9757815F1554D5FBF3C216F403053D1EBCF4B546F9F7A2868A21BD）。回退只在正式文件仍为本次4291时恢复这一备份；保留其它模组、宿主、配置及真实存档，并重启游戏。不要直接运行历史0.3/0.4部署脚本覆盖新版本。

本轮请求已实现、验证、随0.5.0部署并确认正式文件。用户保存退出、重启后生效；终端与地标共用「存档点、出口、试炼入口与终端照明」开关。主MEMORY/journal/changelog由整合会话统一更新，本会话保留本报告与精确功能证据，避免并发覆盖。
