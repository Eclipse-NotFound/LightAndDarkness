# LightAndDarkness 当前记忆

## 1. 模组定位
Remains 1.02战术光暗：墙门遮光、随身灯、场景灯损坏/维修与保存、氛围暗区、机器/地标光、原生弹形拖尾。入口LightAndDarknessMod.init(main:*)，运行路径release/LightAndDarknessMod.swf。0.7.0恢复无遮挡室外背景原图亮度，新增七类地区基础亮度和灯范围滑块。

## 2. 用户偏好与边界
中文，战术光暗与生存探索并重，兼顾氛围。本轮用户明确场景仍暗，要求室外先恢复原版亮度、地区滑块及灯具配合。持续授权本机验证后部署与必要跨会话协调；其他模组最小只读，不动真实pfe存储或用户进程，不用Ghost。
游戏测试先读ModLoader/docs/TEST-REGISTRY.md、刷新共享表并用Registration占用；不逐次人工问其他会话。唯一AIR身份/私有桌面/存储，只停止自有实例。功能测试可与离线JVM并行，仍保守检查其他AIR及2GiB启动/512MiB运行提交余量；性能测量另隔离。空表不等于无其他AIR。

## 3. 当前正式状态
**0.7.0于2026-10-21 16:28:45部署，16:29:24正式回读PASS。**
SHA256 8ADBA6914DF5AADA4DF12A646B6C22DF4B95B9630A55DD05CA7F713621C7E3EF，42,209字节/23自身类，无fe存根或测试类。最终冻结build/out/brightness-v070-host3；与r2、host2候选字节完全相同，后两次只针对其他会话更新的宿主/RV重新冻结依赖。
六组588（普通165、大图143、偏好冷启125、灯具101、灯具冷档11、曳光43）＋正式回读124＝712。回执state/brightness-deployment-2026-10-21.json，安装登记a56f5e46a45240aeba143ae6fea21def已通过。
宿主7D423BD7B7DD7D2B997E692BD1E22EF520879CD42387C14653C116C15385BCD4；CS7F1F2961C6E299D949423591F3C65C610C2EAEFA7FC72E8A583A402770D6B51F；RVF2B8A973D9D2A374C9BD8F5DA9D29040266954C8F139B8C85BFA0AAAA749A561；MLBD71B6F3/WB14112DA0，完整指纹见回执。只更新LAD，其他模组和真实存档未改。
旧0.6.0/E3233F78备份build/backups/brightness-20261021-162845-623837/LightAndDarknessMod.v0.6.0.swf。仅在正式仍8ADBA时经发布工具恢复本文件并重启，不回滚宿主/其他模组。

## 4. 实现与验证结论
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
2026-10-25协调核对：RConnect根会话01a086bb-378c-7f60-b8e1-50d90ffa0996通知其负责普通新房首次灯具绘制优化，候选在RConnect独立目录实现/编译/验证。本侧只读确认HEAD 9664278无未提交改动，正式8ADBA691、Runtime C139A63C2DA131898B9D68D2A681E8D3560EEE9C11104FF83AF7B6670BE1DE2C与提案一致，已回报无冲突。本侧不另开测试或修改live源码/release；后续按该根提供的最终差异、验证和部署回执同步正式状态，不能把提案当已通过。提案入口mods/RConnect/experimental/goal-ordinary-lamp-first-raster-proposal/README.md。
本轮实现、部署及正式复验完成，不再启动测试。现有游戏须玩家保存退出重启。新工作从0.7源码继续，不运行写死旧版本的background发布脚本。
tools/release-brightness.py可验证冻结源/资产/依赖、备份部署及SHA保护回滚；install-brightness-and-smoke.py包装安装与正式回读；registered-lighting-test.py统一登记。run-brightness-suite.py目录匹配式已修正。测试不能用JSON输出顺序断言对象等价，也不能以固定8帧假定CS加载稳定。
原始工作证据build/evidence；正式归档tests/evidence/2026-10-21/brightness-v070含16轮470文件，最终测试全截图、其他尝试文本及首次ROI三图。无后台自动化或遗留测试实例。

## 7. 深入入口
tests/brightness-2026-10-21.md；design/brightness-v0.7.md；state/brightness-deployment-2026-10-21.json；tests/evidence/2026-10-21/brightness-v070/gallery.html。
历史：tests/background-lighting-2026-10-20.md、design/background-lighting-v0.6.md、design/background-lighting-investigation-2026-10-20.md、tests/performance-2026-10-20.md、design/projectile-shapes-v0.5.md、decisions/changelog.md与state/journal.md。
