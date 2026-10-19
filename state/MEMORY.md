# LightAndDarkness 当前记忆

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、墙门遮光、随身灯、场景灯损坏/维修、故障氛围、地区环境光、弹丸拖尾、机器和关键设施散光。入口LightAndDarknessMod.init(main:*)，正式路径release/LightAndDarknessMod.swf。当前0.5.0沿原生弹形照亮周围，并降低常见弹幕的绘制开销。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。已持续授权本机验证后部署，不重复确认；已明确授权相关开发会话协调。其他模组最小只读，工具用Sandevistan/build/tools；不操作真实pfe存储或用户进程，不用Ghost。测试唯一AIR身份、私有后台桌面、ModLoader精确选组。性能测试必须明确交还时段并在启动前/中检测其它AIR，不能把两轮间隙当空闲授权。本轮没有新建子代理。

## 3. 当前状态
**0.5.0于2026-10-20 00:47:27部署，正式回读35项通过。** SHA256 4291B8250D607EA1C6B5BE48DED48BB5FA42AF37BFE0CB3ED7A2E7C84EFBBF90，37,009字节，20自身类，无fe存根/探针。冻结build/out/trails-v050；源码7df08c9包含机器/终端60118c8及缓存1cefa04。旧0.4.2候选不单独部署，已验证的缓存改动纳入本版。
00:47本模组发布时组合为宿主02BFABE6、CS241E48EA、RV76314B81、WB0BD209A1、MLBD71B6F3；该轮仅更新LAD，描述符/配置/清单保持原值。最终35拖尾＋131弹丸＋4冷档＋173机器＋217地标环境终端＋385像素照度＋101回归＋11冷档＝1057项通过；正式文件再35项。两个独占ABBA性能轮原始数据完整保留。报告tests/trails-verification-2026-10-20.md；回执state/trail-deployment-2026-10-20.json。
02:11后CS任务更新三项正式依赖，已报告598门禁＋51安装后复验；本会话实际回读其deployment-v082.json状态verified及文件指纹：宿主81C1BFB5、CS0.8.2/CD65CEC6、WB0.5.9-scene/14112DA0。LAD仍4291；全值见journal对应条目。原1057项与性能数据仍只证明旧依赖组合，不改写历史冻结回执冒充新组合验收。0.5.1需基于新组合冻结和复验，旧tools/deploy-trails.py会因源/依赖不一致拒绝重发，这是预期保护。
普通弹改为细长渐暗光带、火箭弯曲尾焰、能量/火焰/电弧/冰片各自短余辉、激光连续真实全长。修正ttnavod绿球、gren50法术及等离子蓝白/红紫色。机器/地标半径和强度提升；六类终端未破解64/.30，原生成功破解saveLock=101后42/.10，无锁/失败不误判。环境/地形缓存和同帧重复绘制修复保留原像素。

## 4. 正在进行与卡点
正式0.5.0实现、验证和部署完成，性能任务继续。AIR/JVM窗口已明确交还CS；后续必须等明确交还，不能抢空隙。共享机器内存偏紧，性能驱动有起始2GiB/运行512MiB可提交余量守卫，只停止自身实例。
独立性能会话01a13fea-c2ca-7b41-8a5b-a3192bc3b3be继续整体灯光接近原版目标，入口tests/performance-2026-10-20.md。4291全14组合ABBA通过17检查：普通图开39/43ms、关33/33.5，大图开88/85.5、关77/79.5；灯光simulation本身5/7ms，89模拟=89绘制。首轮Pip自动暂停污染作废，驱动现用原生onoff(-1)关闭菜单并断言实际模拟。三因素suite104项通过：灯具cacheAsBitmap与代理invis无稳定收益，均不采用；隐藏照明位图省约2–3ms。
02:05接续：未发布0.5.1稳定场景光前缀合成缓存已构建至build/out/perf-v051-static2，1F5B83906B1433C79145A7846F60CE733D96352D6C04230CD566EA03777FF797，37,496字节。387严格像素检查与完整组合普通房间staticlights ABBA 12项通过；光场均值约4.1–4.5→3.3ms，但四阶段帧时间均34ms，不能声称FPS提升。首版perf-v051-static像素失败1404点/max13，禁止部署。修订使用原路径同尺寸/坐标目标，视口稳定后才缓存。
与CS明确顺序：CS保持正式4291先完成宿主更新、部署及回读，再交回AIR/JVM；之后以新宿主冻结依赖，用同一1F5B字节复验387像素、全14组合灯光开关、101回归/11冷档/35拖尾，完成门禁再部署。发布脚本准备曾被保护钩子拦截，已按精确调用自动审批完成脚本创建；不绕过/关闭护栏，正式SWF未变。正式仍4291，不把源码版本号当已部署版本。
背景调查已完成但未实施：design/background-lighting-investigation-2026-10-20.md、tests/background-audit-2026-10-20.md，基线严格0.4.1/94A2，不能当4291实测。重点为透明窗墙漏接、实体表面不接天空光，之后再谨慎调基础值；勿在本次版本记录中声称已修复。
备份build/backups/trails-20261020-004727-123219/LightAndDarknessMod.v0.4.1.swf（94A2F086）。仅当正式仍4291时恢复该文件并重启；不动宿主、其他模组、配置或真实存档。旧版本部署脚本不可覆盖较新文件。

## 5. 已知问题与边界
两轮受控收集＋绘制：普通弹下降47–79%、192弹密集射击46–68%、光束33–37%；96等离子中位数均5ms，但新版约100ms收集尖峰使均值增加9–20%。不删异常样本、不声称所有弹种提速或整体FPS改善；可能回收干扰但因果未证，已交性能任务接续。光带最多192跟踪/96短光/24可见源、96段/65536候选像素；预算不等于墙钟时限。
只认证本机1.02及LAD/ML/CS/RV/WB组合，未认证DLC、联机、全模组、全639模板或前台战斗FPS。大场景预载与整体性能问题仍在独立调查。清单1/1/1保留不代表DLC认证。
地区基础光：据点.58、维护.44、室内.38、废城.36、地下.28、断电.18、露天.70；环境倍率.5–1.5与感知开关仍为本次启动偏好。氛围、弹丸、机器、地标/终端开关、单灯状态随槽保存。旧auto-v1迁移保留HP/开关/维修；自动暗角只限合适废弃/断电遮蔽角落，避关键交互。RealisticVision视野遮罩维持原规则。
随身灯尚无独立装备/电池/掉落；地火/持续附身燃烧未实现。拖尾用实际已观察路径，首帧历史不足会短；不改弹头图像、伤害、轨迹、寿命。地标32、机器32可见源；不为关键设施增加可损坏代理。黑色doorout无发光标志保持原样。

## 6. 下一步
用户保存退出并重启加载0.5.0。后续既定性能任务按上述报告接续；背景调查方案尚未实施，保持其事实与版本边界。新发布重新冻结源码/依赖，用最终同一文件复验与部署，不能发布旧缓存/局部光实验候选。无自动定时任务。

## 7. 深入了解
本版design/projectile-shapes-v0.5.md；tests/trails-verification-2026-10-20.md；tests/evidence/2026-10-20/trails-v050/；state/trail-deployment-2026-10-20.json。原版弹形公共结论shared-knowledge/rendering/discoveries/native-projectile-shapes-2026-10-20.md（从游戏根）。完整武器目录design/projectile-light-catalog-2026-10-15.md。
构建build/build.ps1 -OutputDirectory <独立候选目录>；冻结工具tools/freeze-trails.py仅本版且拒绝覆盖已有目录。tools/run-trail-tests.py --candidate <SWF> --mixed --mode verify/perf/legacy/cold；cold加--seed-storage本轮私有storage。tools/verify-final-trails.py串行本版六轮，tools/deploy-trails.py固定本次指纹门禁，后续版本不可盲用。正式复验--candidate release/LightAndDarknessMod.swf。
局部光design/local-glow-2026-10-20.md、tests/local-glow-2026-10-20.md；性能tests/performance-2026-10-20.md。历史环境design/environment-v0.4.md、地图调查design/map-lighting-investigation-2026-10-19.md；地标design/landmark-lighting-v0.4.1.md；原生总调查design/native-lighting-survey.md、氛围规则atmosphere.json。journal与decisions/changelog.md保存历程。
