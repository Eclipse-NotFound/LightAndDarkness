# 0.4.1 原版风格地标照明验证

被测技能：remains-runtime-debug / remains-auto-testing 2026-10-19.2；remains-release-gate / remains-swf-patching 2026-10-19.1；remains-mod-build / remains-mod-memory在册版；test-report 2026-09-16.1。
技能归属：Remains/.agents/skills，维护驻地mods/ModLoader；test-report为用户级。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness。

## 输入与效果

用户要求为存档点、出口与试炼入口添加符合原始图像风格的光源。以正式0.4.0为基线，原版1.02的CheckPoint/Location/Land/Box源码和实际AIR图像为证据。按照紫色星形屏幕/传送柱、绿色Exit、绿色问号、红色牛头安排散光；没有随机闪烁或改图，原生黑色返回门doorout没有发光标志，保持原状。参数与边界见[设计说明](../design/landmark-lighting-v0.4.1.md)。

唯一生产候选94A2F0861B9757815F1554D5FBF3C216F403053D1EBCF4B546F9F7A2868A21BD（32,707字节），冻结build/out/landmarks-v041/LightAndDarknessMod.swf。实际FFDec导出19个自身类，无fe存根/测试探针；默认FFDec日志位置受沙箱限制，但导出成功。宿主02BFABE6，CS B5E8110E、RV 76314B81、WB 0BD209A1、ML BD71B6F3。

## 最终验证

全部使用唯一remains-lad-landmark-* AIR身份、独立副本/存储与私有后台桌面。精确组合为LAD、LandmarkProbeMod、ModLoader、ContinuousScene、RealisticVision、WallBlend；本轮session的requested/ok集合相等，无err，版本0.4.1、roomsLoad=1和持续心跳正常，冻结输入在运行后未变。

| 运行后缀 | 内容 | 结果 |
|---|---|---|
| 20261019194703918726 | 原图导出、93地标专项＋31环境回归 | 124 PASS |
| 20261019194923206381 | 既有99回归＋新开关跨槽恢复 | 101 PASS |
| 20261019195120813090 | 独立新进程读取上轮测试.sol | 11 PASS |
| 20261019195250173861 | 从正式release读回，重复专项及环境回归 | 124 PASS |

专项实际创建六种CheckPoint（含锁、雷、损坏标记）和原版exit/doorprob/doorboss/doorout；检查关闭、重开、激活、传送柱、used及hide，调用原生activate/deactivate验证状态联动。8种旋转/镜像组合的星形位置对照原图变换；图像隐藏、透明、移除，门对象损坏/零HP及视口外停止光源。去重、32源上限、清理、墙门开合遮光、照度实际像素变化、设置写入原生保存数据均通过。93中含实际营地检查点发现和全画面对比；31环境检查为上一版规则回归，不是另93项。

101回归含原生弹丸/爆炸打灯、维修消耗和中断、存档不串槽、闪烁与修复、192×75大场景、8次Stage原生相机对照。两槽分别关闭/启用地标光；冷进程逐槽再次恢复对应开关，既有灯具耐久、开关、维修和材料数量同时通过。

已查看原生八格图集、开启光照后的六格效果图；配色与原图吻合，光晕局限于设施附近。效果图刻意采用0.14底光便于观察，是测试展板，不冒充自然房间。营地截图为实际游戏场景。截图来自后台软件绘制，不代表前台GPU或全部地图认证。

## 过程问题和边界

- 只读搜索正则被钩子误判成写参考区，沿既有授权登记短时精确调用后成功；未修改game-reference、未关闭护栏。一处测试文件旧命名读取不存在后改读真实文件。
- 首次原图导出（20261019194155678550）已产出图与树，但结果封装误读runtime.private main，未产生done。通过该运行的stop-request让持有句柄的runner停止自己的进程；修正为根对象的公开carrier后，最终124专项完整重导出并通过。该首次运行不记成功。
- 20261019194754390344的99项初次回归通过；补上新开关的跨槽和冷读档断言后，重跑101＋11。候选生产字节未变。
- 新照明不改原版存档点激活、锁/雷、传送条件、试炼进度或地图可见性，不赋予关键设施额外可破坏/可修复属性。保留原有RealisticVision遮罩。未测试DLC、联机、全生产模组组合、自定义入口、全部自然图或整体FPS。

## 部署与证据

2026-10-19 19:52:42只原子替换本模组release文件，回读与冻结候选一致；0.4.0的9177513F备份于build/backups/landmark-20261019-195242-311028/LightAndDarknessMod.v0.4.0.swf。宿主、其他模组、清单、配置与真实存档未改。正式回读20261019195250173861再次通过124项，安装后版本、当轮loader和实际功能均核对；已查看正式文件营地截图，紫色星屏和周围墙地可见柔光。

门禁按序完成：候选构建、版本更新与功能检查；持续授权及当前宿主/依赖指纹核对；唯一备份、同一字节安装/回读；正式文件功能冒烟、回退说明；MEMORY/journal/changelog与本轮提交收尾。测试进程和后台桌面均结束，未干扰用户实例。

回退仅在正式仍为94A2F086时恢复上述9177513F备份并保存退出后重启；不要用旧回退脚本覆盖后续版本。完整安装指纹和源文件哈希见[state/landmark-deployment-2026-10-19.json](../state/landmark-deployment-2026-10-19.json)。

本次新增证据：原生地标显示树、原生activate/deactivate联动、真实画面变化和新设置跨进程恢复。既有隔离/精确选组/备份流程沿在册技能，无技能规则修改；驱动私有字段误读属实现错误，已修正，不提升为通用工具限制。报告、设计、候选、驱动与图像为本次产物；待维护按台账核对吸收。

最终四轮的日志/loader/指纹/图像与进程信息归档于[证据索引](evidence/2026-10-19/landmarks-v041/index.json)。[原版图集](evidence/2026-10-19/landmarks-v041/installed/native-atlas.png)、[效果展板](evidence/2026-10-19/landmarks-v041/installed/landmarks-after.png)、[实际营地](evidence/2026-10-19/landmarks-v041/installed/camp-after.png)；完整临时原件在build/evidence同应用ID目录，未把测试存档归档入git。

已查重追加统一测试报告台账第619行并回读确认，状态待吸收。
