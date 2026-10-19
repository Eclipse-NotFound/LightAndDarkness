# LightAndDarkness 当前记忆

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、实时墙门遮光、随身灯、场景灯损坏/维修、故障氛围、弹丸短光和机器微光。0.4.0修复地图普遍偏暗，增加分地区基础光、天空/窗洞补光及场景暗角；0.4.1沿原版图像加入存档点、出口、试炼入口散光。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户2026-10-19要求环境光修复后，再为存档点/出口/试炼入口增加符合原图的光源；治理持续授权本机验证后部署，不重复确认。其他模组最小范围只读，工具使用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。测试经ModLoader启动器精确选组、唯一AIR身份及私有后台桌面；本轮没有新建子代理。用户已授权跨会话协调，已与微光会话确认先完成0.3.2，再接续本版。

## 3. 当前状态
**0.4.1已于2026-10-19 19:52:42部署**。正式SHA256 94A2F0861B9757815F1554D5FBF3C216F403053D1EBCF4B546F9F7A2868A21BD，32,707字节；冻结build/out/landmarks-v041/LightAndDarknessMod.swf。FFDec19个自身类，无fe存根/测试探针，生产源码与本轮提交对应，不可重编后冒充同一字节。
宿主02BFABE6、CS B5E8110E、RV 76314B81、WB 0BD209A1、ML BD71B6F3；描述符、清单和其它模组未改。精确组合LAD/四接口模组/探针。最终124检查（93地标＋31环境）、101回归、11冷读档通过；正式回读20261019195250173861再次124通过。实看原图、效果图、实际营地。报告tests/landmark-verification-2026-10-19.md、回执state/landmark-deployment-2026-10-19.json。
保留0.4.0全部环境修复及0.3.2机器/弹丸/边框能力。本轮未把历史九场景、173机器、131弹丸专项冒充全量重跑。

## 4. 正在进行与卡点
本轮实现、验证、部署、回读均完成，无待部署候选。初次图集已经导出但结果封装误读private main，结束自己实例后修正并重跑成功；不是正式模组错误。末轮101回归补验新设置两槽独立恢复，11冷读档再次验证开关。
备份build/backups/landmark-20261019-195242-311028/LightAndDarknessMod.v0.4.0.swf（9177513F）。仅当正式仍94A2F086时恢复这一备份并重启；保留宿主、清单、其它模组、真实存档。旧环境/机器回退脚本不可直接覆盖新版本。

## 5. 已知问题与边界
地标光仅原生CheckPoint与Box的exit/doorprob/doorboss。存档点弱侧条、紫色星屏/传送柱按真实图像发光；出口绿、试炼问号绿、战斗牛头红。黑色返回门doorout无发光标志，保持原样。隐藏/透明/移除/损毁停止光，最多32可见源；不改变关键交互或增加可损坏代理。设置「存档点、出口与试炼入口照明」默认开、随槽保存。
地区基础光是乘法照度层：据点0.58、维护设施0.44、普通室内0.38、废弃城市0.36、地下0.28、明确断电0.18、露天0.70。环境亮度倍率0.5–1.5默认1，与感知开关仍为本次启动偏好；氛围/弹丸/机器开关和灯具状态随槽保存。旧auto-v1迁移保留稳定灯和HP/开关，新维修记录repaired。
自动暗角只限废弃/断电、有顶和侧墙的地面角落，避开入口及关键交互；不按棋盘压黑全图。六类原生窗洞，每视口最多24采样点。RealisticVision自己的视野黑幕不改；截图揭开的是原生探索黑幕，不是RV视野。普通视觉发现使用同一照度场，听觉/开火暴露/AI记忆保持。
随身灯尚无独立装备、电池或掉落。机器32可见源；弹丸192跟踪/96脉冲/24可见源，不改伤害与寿命；地火/持续附身燃烧未实现。只认证本机1.02及列明组合，未认证DLC、联机、全14模组或全639模板。清单1/1/1保持原值，不代表DLC认证。原生预载和大场景长帧仍存在，本轮不声称整体FPS改善。
此前ContinuousScene完整帧/遮光缓存实验已撤回生产源且未部署，不要发布旧872/314候选；其历史证据留ContinuousScene任务原址。

## 6. 下一步
用户保存并重启加载0.4.1；设置「模组 → 光与暗 → 环境亮度倍率」可调总体强度。后续按实际游玩反馈再调整区域数值或特殊房间规则，无自动后续任务。新发布核对全部依赖指纹，候选冻结后测试与部署使用同一文件。

## 7. 深入了解
本版设计design/landmark-lighting-v0.4.1.md；验证tests/landmark-verification-2026-10-19.md；证据tests/evidence/2026-10-19/landmarks-v041/。候选构建到build/out/landmarks-v041；tools/run-landmark-tests.py --mixed --mode verify/regression/cold，cold加--seed-storage本轮storage；正式复验加--candidate release/LightAndDarknessMod.swf。tools/deploy-landmarks.py只针对本版冻结指纹，下一版重新核对，不能盲用。
设计design/environment-v0.4.md；原始调查design/map-lighting-investigation-2026-10-19.md；验证tests/environment-verification-2026-10-19.md；证据tests/evidence/2026-10-19/environment-v040/。原生字段事实在shared-knowledge/rendering/discoveries/native-map-lighting-coverage-2026-10-19.md（从游戏根）。
构建build/build.ps1 -OutputDirectory <候选目录>；测试tools/run-environment-tests.py --mixed --mode survey/large/regression/cold，cold加--seed-storage本轮测试存储；正式读回加--candidate release/LightAndDarknessMod.swf。环境旧部署工具tools/deploy-environment.py已过时，不可用于当前版本。
历史机器design/machine-glow-v0.3.2.md与tests/machine-glow-2026-10-19.md；弹丸design/projectile-light-catalog-2026-10-15.md、design/projectile-lighting-v0.3.md及tests/projectile-verification-2026-10-15.md；原生灯光design/native-lighting-survey.md，规则atmosphere.json。
