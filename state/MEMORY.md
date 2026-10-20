# LightAndDarkness 当前记忆

> 2026-10-20 背景光实施中：源码候选0.6.0已补窗墙/圆窗/室外破洞、实体表面受光与封闭区域基础值+0.04；正式仍是下述0.5.1。当前只通过静态复审，**未编译、未实测、未部署**，等待RC明确交还AIR/JVM独占窗口。来源任务01a154dc-b4c2-7f42-837a-ce7541e37297；不要把旧0.4.1调查或0.5.1门禁当作0.6.0验收。设计design/background-lighting-v0.6.md；新驱动tools/run-background-lighting-tests.py，发布门禁tools/release-background.py。三个子代理仅负责源码、测试与只读复审，不启动测试进程。

## 1. 模组定位
为Remains 1.02增加战术光暗、墙门遮光、随身灯、场景灯损坏/维修、故障氛围、环境光、弹丸拖尾及机器/关键设施散光。入口LightAndDarknessMod.init(main:*)，正式路径release/LightAndDarknessMod.swf。当前0.5.1减少稳定灯和地形扫描开销，消除画面外弹丸导致的无效补绘。

## 2. 用户偏好与边界
中文，战术光暗与生存探索并重，兼顾氛围。已持续授权验证后本机部署、相关弹丸/CS/机器会话协调，不重复确认。其他模组最小只读，工具用Sandevistan/build/tools；不动真实pfe存储或用户进程、不用Ghost。本线程没有新建子代理。RC未获直接人类消息授权，测试排期经已授权整合会话转交。
性能测试使用唯一AIR身份、私有后台桌面/存储、精确ModLoader选组，必须明确交还时段，不能把两轮间隙当空闲。起始2GiB/运行512MiB可提交余量及并发AIR守卫，仅停止自有实例。

## 3. 当前正式状态
**0.5.1于2026-10-20 02:58:06部署，02:59:26正式回读43项通过。** SHA256 BAFE52B9145194C2E9D3A08A3331236FEE5F1B6A3E1F016A46D9BC288C04C47A，37,793字节、21自身类，无fe存根/探针。冻结build/out/perf-v051-visible，未重编译后覆盖测试字节。
门禁579（387严格像素/照度、21完整组合宽屏、16稳定缓存ABBA、101回归、11冷档、43拖尾/可见更新）＋安装43＝622。回执state/performance-deployment-2026-10-20.json，restartSmoke.status=PASS；归档tests/evidence/2026-10-20/performance-v051/（187文件）。
当前宿主81C1BFB552AA8EFBB20CCF15CB404AB5D879F58515B466FF788A079F5F0EC015；CS0.8.2/CD65CEC6C763EF18B345BCC1208BAAA4911E02BDB1F557FE316EBBABFF9BD856；WB0.5.9-scene/14112DA06214BCA51C6875D2527E73246DCB4C985CAADDA719EB4F77F1C0920D；RV76314B81/MLBD71B6F3。CS在本轮前部署三项依赖并验证；本轮只替换LAD，配置、清单和真实存档未改。
备份build/backups/performance-20261020-025805-967767/LightAndDarknessMod.v0.5.0.swf（4291B825）。仅在正式仍BAFE时按发布流程恢复此备份并重启，不回滚宿主/其他模组。

## 4. 实现与验收结论
稳定场景光只缓存连续前缀，沿原顺序/尺寸/坐标预合成，视口稳定后复用；变化立即失效。地形逐列复用和原生Tile类型化访问，快照为LadTileState。可见弹丸完整签名过滤屏外changed：保留轨迹/寿命、屏内新光、颜色/亮度/轨迹变化及消失；需要时仍补绘。cell12、平滑、射线、颜色、闪烁频率不变。
严格像素最初带边距候选失败1404点/max13，已拒绝；正式同视口方法387通过。渐变模板DBEF单项无稳定收益且全组合轮低内存中止，已撤回。旧测试的Object瓦片替身不适配类型化路径，统一使用原生Tile，断言未删，101/11随后通过。详见tests/performance-2026-10-20.md。

## 5. 尚未解决的目标与已知边界
**“接近原版”整体目标未完全达成。** 最终完整14模块且RV/WB开启、实际2544×955：普通图灯开P50 43/46.5ms、关33/33；25区大图开102/95、关84/86，开启均89模拟89绘制，lateRenders=0。原无效补绘曾89步177绘制；不把跨轮随机战斗/负载差异当精确FPS提升率。
类型化扫描同输入大图100次移动251/243→176/173ms；稳定灯光场约3.8→3.1ms，仅函数减负。关灯大图也有明显长帧；未单独归因其它模组。不得用CS较小窗口且RV/WB关闭的数据外推。既有密集等离子收集尖峰/均值问题保留在拖尾报告，不声称本版全部解决。
仅验证本机1.02、已列功能与测试组合；DLC、联机、全639模板和所有前台战斗未认证。真实游戏需保存退出并重启。
随身灯仍是内置验证玩法，无独立装备/电池/掉落；地火/持续附身燃烧未实现。背景光漏接调查已完成但未实施，见design/background-lighting-investigation-2026-10-20.md，不能记作本版修复。
氛围/弹丸/机器/地标开关、单灯状态随槽保存；环境倍率和感知开关为本次启动偏好。旧auto-v1迁移保留HP、开关、维修。RealisticVision遮罩规则保持自身行为。

## 6. 接续点
本轮实现/部署/复验已完成，AIR/JVM已明确交还整合会话再交RC，不再开实例。后续继续性能工作先协调独占时段，围绕完整组合剩余显示复合/实际模拟成本取证；不要重复已验证项或部署旧中间候选。无定时任务。
本版源码、工具和报告在当前模组提交；不要用固定0.5.0的deploy-trails.py覆盖0.5.1。新版本重新冻结并走门禁。

## 7. 深入入口
本轮tests/performance-2026-10-20.md；state/performance-deployment-2026-10-20.json；tools/freeze-performance.py、deploy-performance.py、archive-performance-release.py。性能驱动run-lighting-perf.py，--reference可指定同字节函数对照，测试均私有身份；正式文件复验使用run-trail-tests.py --candidate release/LightAndDarknessMod.swf --expected-version 0.5.1 --mixed --mode verify。
历史0.5.0原生弹形/机器终端：design/projectile-shapes-v0.5.md、tests/trails-verification-2026-10-20.md、state/trail-deployment-2026-10-20.json；仅证明其当时02BF宿主组合，不冒充新版。环境规则design/environment-v0.4.md、原生调查design/native-lighting-survey.md。journal与decisions/changelog.md保留历程。
