# LightAndDarkness 当前记忆

> **2026-11-05 GitHub 公开**：本仓库已开源到 https://github.com/Eclipse-NotFound/LightAndDarkness（默认分支 `master`，MIT 许可证），发布 tag `v0.7.1` 与 Release 资产 `LightAndDarkness_v0.7.1.zip`（正式版）。由同步会话执行；未运行游戏、未改 `release/` 下已部署产物。

> 2026-10-28 分盘精简：本模组 1162 个历史副本文件（1.831 GiB）经逐文件核验后转入 F、G 盘；源码、release、共享工具及当前验证材料保留。查位置与恢复方法见 [archive-index.md](archive-index.md) 和[本轮记录](../../../archive/migrations/2026-10-28-01/report.md)。旧测试副本需复现时先按归档原路径恢复。

> 2026-10-25 历史资料已核验转存：B01，共12,746文件、原始显示12.16 GiB。查找与恢复从 [archive-index.md](archive-index.md) 进入；[本次结果](../../../archive/migrations/2026-10-25-01/report.md)。当前正式包、源码、作品及保留证据未纳入。

## 1. 模组定位
Remains 1.02战术光暗：墙门遮光、随身灯、场景灯损坏/维修与保存、氛围暗区、机器/地标光、原生弹形拖尾。入口LightAndDarknessMod.init(main:*)，运行路径release/LightAndDarknessMod.swf。0.7.0恢复无遮挡室外背景原图亮度，新增七类地区基础亮度和灯范围滑块。

## 2. 用户偏好与边界
中文，战术光暗与生存探索并重，兼顾氛围。本轮用户明确场景仍暗，要求室外先恢复原版亮度、地区滑块及灯具配合。持续授权本机验证后部署与必要跨会话协调；其他模组最小只读，不动真实pfe存储或用户进程，不用Ghost。
游戏测试先读ModLoader/docs/TEST-REGISTRY.md、刷新共享表并用Registration占用；不逐次人工问其他会话。唯一AIR身份/私有桌面/存储，只停止自有实例。功能测试可与离线JVM并行，仍保守检查其他AIR及2GiB启动/512MiB运行提交余量；性能测量另隔离。空表不等于无其他AIR。

## 3. 当前正式状态
**0.7.1于2026-11-02 07:02:37部署，安装后smoke 124项07:03 PASS。**
SHA256 BE12A338AEEE11DD1D61CCA6CEAA79EA83B313BB940D25CA54EACF1C34535FC4，42,817字节/23自身类。冻结build/out/perf-v071-r2（refreeze：首次部署06:57:29因并行会话改loader-manifest触发依赖保护回滚，相同字节对新依赖重冻结后重装）。
性能重构不改输出：渲染时序单帧收口、移动/旋转光光栅原地重建、环境底光setVector+瓦片级天光备忘。587功能门禁（普通165/大图142/偏好冷启125/灯具101/冷档11/曳光43）＋回读124＝711；候选vs0.7.0同输入逐像素一致387项；同输入计时大图pan≈-43%、aim-22%、idle-14%，普通房间持平。
回执state/perf-deployment-2026-11-02.json；备份build/backups/perf071-20261102-070237-094675/LightAndDarknessMod.v0.7.0.swf。仅在正式仍BE12时经release-perf-071.py回滚本文件。宽屏整帧FPS ABBA待安静窗口。

## 4. 实现与验证结论
0.7.1渲染管线：光照合成只发生在onFrame（优先级-80，晚于原生步）且每帧至多一次；simulationStep只置脏并改写visibility，照度采样用上一轮光场（滞后≤1步）。makeLight用持久化Sprite/位图在缓存条目上原地重建（半径变化才重画光晕渐变）；paint走Vector批量setVector+瓦片级天光备忘（键含瓦片字段/孔径/背景修订/contextVersion）。lateRenders=无步进帧的补绘计数，renders==steps+lateRenders不变量保持。地标与机器光仍逐帧扫描（候选缓存被探针契约否决）。
“模组 → 光与暗 · 地区亮度”：室外100%、安全82%、维护72%、一般室内68%、废墟62%、地下48%、停电24%，每项10–100/步进1。原“光与暗”页总倍率默认1、灯亮度保留已有值，新增范围0.5–1.5/默认1.10。
LadLightingPreferences在AIR应用存储LightAndDarkness.lighting.json保存地区值/总倍率/范围；关闭任一照明设置页保存，拖动只预览，跨槽使用。灯具耐久/开关/维修等世界状态仍随槽，不重置旧档。
天空上限.70→1.0，传播每格.065→.11以保留七格缓存边界。地区值进入环境缓存键，灯半径已有阴影缓存键；SCREEN叠光在高底光上增量更小、最终不超过原图RGB。原生窗洞/表面受光、12px光场、稳定灯缓存和拖尾预算保留。
同暂停场景0.6环境类/0.7/隐藏LAD光场三方对照：6普通图、马哈顿25区和工厂12区；另验原生7滑块事件、设置全新进程恢复、墙门/破坏/灯维修保存/曳光。查看原始截图无新增严重泛白/穿墙。首次马哈顿室外破口18,200像素与原图RGB完全相同，旧环境约69%；仅该ROI证明精确一致，不扩大为所有墙面/全地图。
失败记录均保留：旧门测试阈值改新预期；探针先开Pip再调路由、匿名显示对象空名防护；大图暂停初期签名变，改连续8帧稳定后取样；JSON字符串顺序比较改逐值。候选生产字节均未变。
最后六驱动均PASS，但外层旧目录匹配式收集曳光路径失败，b295登记保留未通过；发布门独立复核最后43项、全部输入与session后补清单，见suite-bookkeeping.json。安装组独立通过，不把记账失败伪造为绿灯。

## 5. 已知边界
地区百分比是乘法场参数而非物理照度。100%恢复无遮挡背景，原图本身夜色、室内遮挡、局部暗区与RealisticVision黑幕仍可能较暗。12px羽化、半高opac=0透光、小弹孔等后续环境刷新仍沿0.6边界。未认证DLC、联机、全部639模板或前台GPU/FPS。
本轮仅证明范围缓存不反复构造和功能预算，不声称提高整套14模组FPS。0.5.1历史帧耗时不是0.7性能证明。独立灯具装备/电池/掉落、地火持续燃烧仍未实现。氛围/弹丸/机器/地标和灯具状态随槽；感知开关仍本次启动偏好，地区/范围/总倍率现已跨启动保存。

## 6. 接续点
2026-11-02 0.7.1性能优化已实施、验证并部署（见上节与journal当日两条）。待办：宽屏完整组合整帧FPS ABBA在安静窗口补测（本轮只有同输入函数级A/B，不称整体FPS提升）；tests/EnvironmentChecks.as四处阈值+门洞溢流采样点已更新为0.7预期（两处既有失败有正式0.7.0对照证据）；run-brightness-suite.py的--expected-version已参数化（默认0.7.1），新增tools/release-perf-071.py与install-perf-071.py（runner键perf-release）。现游戏需玩家保存退出重启生效。
2026-10-25协调核对：RConnect根会话01a086bb-378c-7f60-b8e1-50d90ffa0996通知其负责普通新房首次灯具绘制优化，候选在RConnect独立目录实现/编译/验证。本侧只读确认HEAD 9664278无未提交改动，正式8ADBA691、Runtime C139A63C2DA131898B9D68D2A681E8D3560EEE9C11104FF83AF7B6670BE1DE2C与提案一致，已回报无冲突。本侧不另开测试或修改live源码/release；后续按该根提供的最终差异、验证和部署回执同步正式状态，不能把提案当已通过。提案入口mods/RConnect/experimental/goal-ordinary-lamp-first-raster-proposal/README.md。0.7.1部署后RConnect如需重冻结其候选输入，LAD新正式字节为BE12A338。
tools/release-perf-071.py为本版发布/回滚入口（OLD_SHA=8ADBA、BASELINE_SHA=E3233）；registered-lighting-test.py统一登记（runner含perf-release）。测试不能用JSON输出顺序断言对象等价，也不能以固定8帧假定CS加载稳定。
原始工作证据build/evidence（本日关键目录：remains-lad-brightness-202611020644*/0645*/0646*、remains-lad-landmark-202611020647*/0648*、remains-lad-projectile-trails-202611020649*、remains-lad-perf-2026110206354*/0637*/0638*、安装smoke remains-lad-brightness-202611020657*与0702*）。无后台自动化或遗留测试实例。

## 7. 深入入口
design/performance-optimization-plan.md（§6实施记录含证据登记号）；state/perf-deployment-2026-11-02.json；tests/performance-2026-10-20.md；tests/brightness-2026-10-21.md；design/brightness-v0.7.md。
历史：tests/background-lighting-2026-10-20.md、design/background-lighting-v0.6.md、design/background-lighting-investigation-2026-10-20.md、tests/performance-2026-10-20.md、design/projectile-shapes-v0.5.md、decisions/changelog.md与state/journal.md。
