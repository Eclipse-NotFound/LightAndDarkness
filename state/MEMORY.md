# LightAndDarkness 当前记忆

## 1. 模组定位
为Remains 1.02增加战术光暗、墙门遮光、随身灯、场景灯损坏/维修、故障氛围、环境光、弹丸拖尾及机器/关键设施散光。入口LightAndDarknessMod.init(main:*)，正式路径release/LightAndDarknessMod.swf。当前0.6.0修复背景补光并小幅调整封闭地区基础亮度，保留0.5.1缓存与可见弹丸优化。

## 2. 用户偏好与边界
中文，战术光暗与生存探索并重，兼顾氛围。用户本轮指定调整背景光和地区基础亮度，谨慎改变原视觉风格；持续授权验证后本机部署及相关会话协调。其他模组最小只读，工具用Sandevistan/build/tools；不动真实pfe存储或用户进程、不用Ghost。
2026-10-20用户新增测试登记规则：先读ModLoader/docs/TEST-REGISTRY.md并刷新共享表，专用驱动经Registration申请game占用，自行等待/写回，不再逐次人工交窗。入口tools/registered-lighting-test.py覆盖background/landmark/trail/perf/release。唯一AIR身份、私有桌面/存储、只停自有实例。功能/暂停像素测试允许离线JVM并行，仍记录并发AIR与2GiB启动/512MiB运行可提交余量；真正性能测量单独控制负载。不能以空表认定旧进程不存在。

## 3. 当前正式状态
**0.6.0于2026-10-20 10:26:27部署，10:27:26正式回读66项通过。** SHA256 E3233F78D7F9AF8F0AC4F99AA78ABB1F9FA0D4931B272D7D551B62C7C36E796E，40,881字节、22自身类，无fe存根/测试类。冻结build/out/background-v060-r2，验收后未重编译。
六组门禁556（背景普通102/大图82、地标217、灯具101、冷档11、曳光43）＋安装66＝622。回执state/background-deployment-2026-10-20.json，restartSmoke.status=PASS。归档tests/evidence/2026-10-20/background-v060/含13轮217文件，成功/失败日志均保留，gallery.html为原始前后图。
宿主81C1BFB552AA8EFBB20CCF15CB404AB5D879F58515B466FF788A079F5F0EC015；CS0.8.2/CD65CEC6C763EF18B345BCC1208BAAA4911E02BDB1F557FE316EBBABFF9BD856；WB0.5.9-scene/14112DA06214BCA51C6875D2527E73246DCB4C985CAADDA719EB4F77F1C0920D；RV76314B81/MLBD71B6F3。本轮只替换LAD；宿主、依赖、配置、清单和真实存档未改。
旧0.5.1/BAFE备份build/backups/background-20261020-102627-818378/LightAndDarknessMod.v0.5.1.swf。仅在正式仍E323时按发布工具回滚本文件并重启，不回滚宿主/其他模组。

## 4. 实现与验收结论
新增LadBackdrop借用原生前/后景位图alpha，兼容CS原生分块，不复制整张地图。室外语境下的窗墙、圆窗、破洞成为环境补光来源；地下装饰洞不会凭空产生天光。原生实体表面按半高/斜面几何受光，完整墙门仍阻断传播。几何快照检测phis/zForm/diagon/phY1，保持缓存可正确失效。
仅封闭非安全/非停电地区基础值+0.04：维护设施.44→.48，一般室内.38→.42，废墟.36→.40，地下.28→.32；安全.58、停电.18、已有日光地区不统一抬高。现有灯功率/颜色/闪烁、原图、弹形、保存格式不变。
6普通场景和马哈顿25/工厂12区大图实际对照；候选和冻结0.5.1类在同暂停场景/机位/灯源/视野状态下比较。确认类分离和共享原生Tile，8帧场/相机稳定；是环境/光场对照，不是独立完整版本双开。马哈顿窗洞更清楚、地下轻微提升，营地不变，无新增严重泛白/光漏。
曾发现r1 Runtime版本标识遗漏、首图RV每30帧注册而探针读取过早、旧JVM守卫过严，均记录后修正重跑。曳光旧驱动一轮启动超时无done；补CS就绪等待/心跳、非perf不加载未使用基线后43通过，未单独确证其根因。源码及测试由主代理与子代理协作，发布只由主代理执行。

## 5. 已知边界与未完成目标
12像素平滑场在极薄表面仍有羽化；半高地形沿用原生opac=0透光语义。贴花revision不单独触发背景重采样，小弹孔轮廓等下一次环境刷新同步；未击穿实体仍挡光。未认证DLC、联机、全部639模板逐一游玩、前台GPU或FPS。
0.5.1完整14模组宽屏历史帧中位：普通开43–46.5ms/关33ms，大图开95–102ms/关84–86ms；不是0.6.0的新性能认证。“接近原版”整体性能目标未完全达成，密集等离子尖峰保留。当前仅保留其优化，不声称背景补光提高FPS。
随身灯仍为内置验证玩法，无独立装备/电池/掉落；地火/持续附身燃烧未实现。氛围/弹丸/机器/地标开关、单灯耐久维修随槽保存，环境倍率/感知开关仍为本次启动偏好。RealisticVision遮罩沿自身规则，补光不揭开不可见区域。

## 6. 接续点
本轮实现、测试、部署与正式复验已完成，不再开AIR/JVM；共享登记d89977f8f08e46c5b5bc009e7c56eaff已PASS。已告知整合与CS会话新正式SHA，后续测试需按新LAD冻结依赖。真实游戏保存退出并重启后生效。
后续调整用当前0.6.0源码；不要运行写死旧版的部署脚本。tools/release-background.py校验源码/素材/运行副本/正式依赖，install-background-and-smoke.py将安装与复验包在同一次登记，任何失败按实际目标SHA回滚。无定时任务。

## 7. 深入入口
tests/background-lighting-2026-10-20.md；design/background-lighting-v0.6.md；state/background-deployment-2026-10-20.json；tests/evidence/2026-10-20/background-v060/gallery.html；tools/run-background-lighting-tests.py及registered-lighting-test.py。
原调查design/background-lighting-investigation-2026-10-20.md；历史性能tests/performance-2026-10-20.md，历史拖尾tests/trails-verification-2026-10-20.md；环境规则design/environment-v0.4.md。journal与decisions/changelog.md保留历程。
