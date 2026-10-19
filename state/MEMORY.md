# LightAndDarkness 当前记忆

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、实时墙门遮光、随身灯、场景灯损坏/维修、故障氛围、弹丸短光和机器微光。0.4.0修复地图普遍偏暗，增加分地区基础光、天空/窗洞补光及场景暗角。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户2026-10-19明确要求按调查四项建议修复；治理持续授权本机验证后部署，不重复确认。其他模组最小范围只读，工具使用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。测试经ModLoader启动器精确选组、唯一AIR身份及私有后台桌面；本轮没有新建子代理。用户已授权跨会话协调，已与微光会话确认先完成0.3.2，再接续本版。

## 3. 当前状态
**0.4.0已于2026-10-19 18:39:56部署**。正式SHA256 9177513F1A927DE82039CFE0B5444ECCF6C14B61BA2B765A96A7C2686A9C75E5，31,559字节；冻结build/out/environment-v040/LightAndDarknessMod.swf。FFDec18个本模组类，无fe存根/测试类。生产源码、测试、文档在本轮提交；不要重新构建后冒充同一已测字节。
宿主02BFABE6、CS B5E8110E、RV 76314B81、WB 0BD209A1、ML BD71B6F3；application.xml和清单未改。精确组合含LAD/四接口模组/测试探针。最终31专项＋九场景27截图、25/12分区原生拼接、99回归、9跨进程读档通过；正式回读再通过31专项＋三场景。完整证据tests/environment-verification-2026-10-19.md及state/environment-deployment-2026-10-19.json，测试进程全部结束。
保留0.3.2机器微光、0.3弹丸、迟到分块边框修复。173机器/131弹丸专项为历史版结果，不冒称本版全量重跑。当前源是在已部署3835/提交5197cc2基础上的本轮改动。

## 4. 正在进行与卡点
本轮实现、验证、部署、正式回读已完成，无待部署候选。中间测试失败与修正见报告：旅行遭遇重定向、旧固定闪烁差值、跨域CS访问；最后预检的回执相对路径错误在任何安装写入前修复。最终版本收窄关键交互保护、逐行扫描地板，实际下水道生成2处暗角。
备份build/backups/environment-20261019-183956-631162/LightAndDarknessMod.v0.3.2.swf（3835827D）。仅当正式release仍9177513F时，用此备份恢复本模组并重启；保留宿主、清单、其它模组及真实存档。旧版本回退脚本不能直接覆盖新文件。

## 5. 已知问题与边界
地区基础光是乘法照度层：据点0.58、维护设施0.44、普通室内0.38、废弃城市0.36、地下0.28、明确断电0.18、露天0.70。环境亮度倍率0.5–1.5默认1，与感知开关仍为本次启动偏好；氛围/弹丸/机器开关和灯具状态随槽保存。旧auto-v1迁移保留稳定灯和HP/开关，新维修记录repaired。
自动暗角只限废弃/断电、有顶和侧墙的地面角落，避开入口及关键交互；不按棋盘压黑全图。六类原生窗洞，每视口最多24采样点。RealisticVision自己的视野黑幕不改；截图揭开的是原生探索黑幕，不是RV视野。普通视觉发现使用同一照度场，听觉/开火暴露/AI记忆保持。
随身灯尚无独立装备、电池或掉落。机器32可见源；弹丸192跟踪/96脉冲/24可见源，不改伤害与寿命；地火/持续附身燃烧未实现。只认证本机1.02及列明组合，未认证DLC、联机、全14模组或全639模板。清单1/1/1保持原值，不代表DLC认证。原生预载和大场景长帧仍存在，本轮不声称整体FPS改善。
此前ContinuousScene完整帧/遮光缓存实验已撤回生产源且未部署，不要发布旧872/314候选；其历史证据留ContinuousScene任务原址。

## 6. 下一步
用户保存并重启加载0.4.0；设置「模组 → 光与暗 → 环境亮度倍率」可调总体强度。后续按实际游玩反馈再调整区域数值或特殊房间规则，无自动后续任务。新发布核对全部依赖指纹，候选冻结后测试与部署使用同一文件。

## 7. 深入了解
设计design/environment-v0.4.md；原始调查design/map-lighting-investigation-2026-10-19.md；验证tests/environment-verification-2026-10-19.md；证据tests/evidence/2026-10-19/environment-v040/。原生字段事实在shared-knowledge/rendering/discoveries/native-map-lighting-coverage-2026-10-19.md（从游戏根）。
构建build/build.ps1 -OutputDirectory <候选目录>；测试tools/run-environment-tests.py --mixed --mode survey/large/regression/cold，cold加--seed-storage本轮测试存储；正式读回加--candidate release/LightAndDarknessMod.swf。部署工具tools/deploy-environment.py仅针对本版冻结指纹，下一版须更新并重新验证，不可盲用。
历史机器design/machine-glow-v0.3.2.md与tests/machine-glow-2026-10-19.md；弹丸design/projectile-light-catalog-2026-10-15.md、design/projectile-lighting-v0.3.md及tests/projectile-verification-2026-10-15.md；原生灯光design/native-lighting-survey.md，规则atmosphere.json。
