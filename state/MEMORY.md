# LightAndDarkness 当前记忆

## 1. 这个模组是什么

Remains 1.02 动态光暗模组：战术光暗与生存探索并重，兼顾氛围。入口 LightAndDarknessMod.init(main:*)，正式路径预留 release/LightAndDarknessMod.swf。

## 2. 用户偏好与协作约定

2026-10-15 用户授权创建 AGENT_SCOPE.md 并实施动态灯光、命中损坏、维修、保存；另授权最小范围只读 Sandevistan/build/tools 和 ContinuousScene、RealisticVision、WallBlend、ModLoader 的工具/接口。未修改其他模组，没有正式部署授权。本轮没有新建并行委托。

## 3. 当前状态

- 0.1.0候选已实现：墙/门遮光、动态随身灯、10类灯具、原版子弹/爆炸伤害、两秒维修、原版槽保存、普通视觉适配和设置页。
- build/out/LightAndDarknessMod.swf，SHA256 DA13AA45B870C3576DEBD9CFB6098599BDA5A1A99EF1868F1872D00DA437F00C；12个自身类，无fe.*存根或测试代码。
- 最终47项通过：remains-lad-test-20261015171345633，含192×75格/88灯/240块及RV/WB/ModLoader/ContinuousScene组合；前一轮同字节也通过。精选证据 tests/evidence/2026-10-15。
- 同一专用AIR身份关闭后重启，磁盘槽7/8的4项冷启动断言通过；候选字节未变，证据cold-*.log/txt。
- AGENT_SCOPE已按授权用审阅后的精确调用创建；未关闭护栏。项目源码、构建、签名存根和隔离测试均在自己的独立仓库。
- 本任务未写正式release、宿主、加载清单或pfe存储。宿主被外部更新后，最终测试使用9987C696BEBBEB0626D8F73DA775CF867B2CED4FF626137FD9F161264270F938快照，不再是初始BEBEEA8B…D4011F。

## 4. 正在进行与卡点

候选实现和验证完成，待用户需要时正式部署；没有未解决的功能断言失败。大场景转换性能仍需改善：照明图通常1–2ms，但原生全图预载有秒级停顿。

## 5. 已知问题

- 内置随身灯尚无独立装备/电量/掉落；环境亮度和感知选项暂不跨启动保存，灯具与随身灯状态随槽保存。
- 未认证DLC、联机、全部12模组、全部敌种、随机地图重置和真人输入。维修松键/材料不足已断言；移动/受伤/暂停中断已实现但未专项验证。
- 大场景保留原生画面历史，不保证第三方绕开历史直接改像素。暗区只影响普通视觉visibility，听觉/demask/锁定记忆不变。

## 6. 下一步

用户要求正式启用时：先读release-gate，核对最新宿主/清单与候选指纹，再定向安装候选及通用清单。不要新加专属loader，不覆盖其他行；已测候选不必重编译。后续装备/电量和战斗平衡由用户选择。

## 7. 深入了解

- 总览：../design/native-lighting-survey.md
- 玩法：../design/vision-and-options.md
- 证据：../knowledge/discoveries/{rendering,fixtures,combat}-audit.md
- 公共沉淀：../../../shared-knowledge/rendering/discoveries/native-lighting-vs-illumination-2026-10-15.md
- 实现：../design/implementation-v0.1.md；验证：../tests/verification-2026-10-15.md；日志journal首条。
- build/build.ps1 -Tests构建；-TestsOnly仅更新探针。tests/run.ps1 -SkipBuild -Mixed隔离运行，AIR需审阅允许写独立测试存储，appid为remains-lad-test-*。部署仍用通用mods/loader-manifest.txt。
