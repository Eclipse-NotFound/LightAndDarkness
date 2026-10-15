# LightAndDarkness 当前记忆

> 2026-10-15 随身灯锯齿：已复现正式D866在bitmapData替换后丢失smoothing；恢复后边缘像素跳变111→10，光照/遮挡栅格逐像素不变，13项独立AIR通过。0.3.0冻结3BA候选已包含修复，按跨会话协调随该版验证与安装，暂不独立覆盖release。详见[edge-fix-2026-10-15.md](edge-fix-2026-10-15.md)；不混入或覆盖其他WIP。

> 2026-10-15 菜单改键已安装：本模组改键候选已随统一六客户端安装并从正式路径读回，七模组23项联合两进程346项通过。当前正式SHA256 D8666B4ACD9E98BC73785402F9A9A771DA5F54CC742C4D69664824ADAD1857A3。入口「模组→对应模组→快捷键」，保存后重启游戏加载新版；本机偏好即时保存。备份/回退及权限见[keybind-deployment-2026-10-15.md](keybind-deployment-2026-10-15.md)。下方候选及旧安装记忆保留历史；未发布WIP没有带入本次安装。

2026-10-15 追加：按快捷键主会话要求，改键已逐处合入主目录的灯光性能WIP，保留首次绘制前接入、裁剪、平滑照度及HUD缓存。仅改键差分单独提交，原性能WIP仍未提交。开发候选为build/out/keybind-scene-dev/LightAndDarknessMod.swf（30BF82E8…FC3EF0），81项灯光/大场景、7项存档冷启动、21项真实公共改键/HUD、6项改键冷启动通过。未部署，未替换D866稳定线或8125性能候选；完整提交/指纹/边界见state/keybind-integration-2026-10-15.md。以下原0.2.0记录保留。

## 1. 这个模组是什么

Remains 1.02 动态光暗模组：战术光暗与生存探索并重，兼顾氛围。入口 LightAndDarknessMod.init(main:*)，已部署到 release/LightAndDarknessMod.swf。

## 2. 用户偏好与协作约定

2026-10-15 用户授权创建AGENT_SCOPE.md、动态灯光/损坏/维修/保存；允许最小范围只读Sandevistan/build/tools和ContinuousScene、RealisticVision、WallBlend、ModLoader接口。随后明确“请部署”，并继续要求稳定光、多亮度、不同频率闪烁和黑暗区。本轮沿用部署授权更新0.2.0。未修改其他模组，未新建委托，未操作用户实例或pfe存储。

## 3. 当前状态

- 0.2.0已部署：保留基础动态遮光/灯具/维修/保存，新增steady/slow/fast/burst、三档亮度、室内柔边暗区、五项氛围设置和atmosphere.json定点规则。
- 正式release与已测候选同字节：SHA256 01767319A54AC88961B2BA40391F0FA79359486EE5591E6A22D90AD49F84537C，16,778字节，13个自身类，无fe.*存根/探针。
- 最终remains-lad-test-20261015193026690：79项通过，含192×75格/88灯/240块及RV/WB/ModLoader/ContinuousScene组合；关闭进程后四槽读档7项通过（cold-193333）。
- 19:36备份0.1.0并定向更新release，宿主9987C696…270F938及加载名单35A1A176…109E1F2未改，仍1/0/0。正式回读重新启动又通过7项（cold-193704），有0.2.0日志和心跳。
- 灯具样式/亮度/频率、维修及新增氛围偏好随原版槽保存；更改配置规则更新现有灯一次，同规则读档保留维修。运行时周期时钟不存盘。
- 回退旧版：build/backups/atmosphere-20261015-193655-513/LightAndDarknessMod.v0.1.0.swf（DA13AA45…37F00C）。当前验证及完整指纹见tests/atmosphere-verification-2026-10-15.md，旧安装历史state/deployment-2026-10-15.md。

## 4. 正在进行与卡点

0.2.0部署及验证完成，用户保存进度并重启游戏后生效。最终没有功能断言失败。灯光氛围阶段一般1–2ms；原生全图预载仍有秒级停顿，部署复核还观察到资源开机加载约74秒，不将其混成照明帧耗时。

## 5. 已知问题

- 内置随身灯尚无独立装备/电量/掉落；原有环境亮度/感知选项暂不跨启动保存，新增五项氛围偏好随槽保存。
- 未认证DLC、联机、全部12模组、全部敌种、随机地图重置和真人输入。维修松键/材料不足已断言；移动/受伤/暂停中断已实现但未专项验证。
- 大场景保留原生画面历史，不保证第三方绕开历史直接改像素。暗区只影响普通视觉visibility，听觉/demask/锁定记忆不变。
- ModScanner重建清单不保留手工版本开关，新发现项会变为1/1/1；本版运行时另有boxDamage==0.2守卫。未改其他模组的supported-mods；重扫后需核对本模组开关，详见部署记录。

## 6. 下一步

当前无待执行部署。按用户反馈调整氛围分布与明暗平衡，装备/电量及预载停顿仍待后续需求。以后发布先核对宿主/清单/release指纹，不覆盖他人行、不新加专属loader。

## 7. 深入了解

- 总览：../design/native-lighting-survey.md
- 玩法：../design/vision-and-options.md
- 证据：../knowledge/discoveries/{rendering,fixtures,combat}-audit.md
- 公共沉淀：../../../shared-knowledge/rendering/discoveries/native-lighting-vs-illumination-2026-10-15.md
- 实现：../design/implementation-v0.1.md；验证：../tests/verification-2026-10-15.md；日志journal首条。
- 氛围配置/频率含义：../design/atmosphere-v0.2.md、../atmosphere.json；本版证据../tests/evidence/2026-10-15/atmosphere-v0.2。
- build/build.ps1 -Tests构建；-TestsOnly仅更新探针。tests/run.ps1 -SkipBuild -Mixed隔离运行，加-Installed回读正式文件及加载行且不构建；AIR需审阅允许写独立测试存储，appid为remains-lad-test-*。部署仍用通用mods/loader-manifest.txt。
