# 光与暗快捷键接入与主目录整合（2026-10-15）

## 最新回执：主目录源码已整合，未部署

按主会话追加请求，已将keys、动态提示、公共输入状态与保存逻辑逐处合入主目录现有灯光性能WIP。主目录改键提交为 **8d302fb41c1c5bf9d31655b84f1242bd0d1bedaa**。提交仅包含改键实现、相应测试/构建入口和本轮记忆追加；没有把原性能WIP一起暂存提交。

continuousSceneBeforeRaster、continuousSceneResetGeneration、第一次绘制前转换灯具、sceneSynchronousRedraw、视口灯壳裁剪、平滑照明及HUD缓存均保留。HUD缓存的lastText使用当前headlampKey与fixture提示拼接，改键即使不改变进度和布局也刷新文字。LadLightField、LadSceneBake、LightCoreChecks与整合前备份逐字节相同。

本轮结束时原性能WIP仍在8个未暂存文件中：src/LightAndDarknessMod.as、src/lad/LadHud.as、src/lad/LadLightField.as、src/lad/LadRuntime.as、src/lad/LadSceneBake.as、tests/LightAndDarknessTest.as、tests/LightCoreChecks.as、tests/run.ps1。已有未跟踪的tests/scene-compat-2026-10-15.md也未纳入本次提交。MEMORY/journal仅追加本轮指针。

### 单独开发候选

路径：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/build/out/keybind-scene-dev/LightAndDarknessMod.swf

- 版本：0.2.1-scene-keybind-dev；20074字节。
- SHA256：**30BF82E8341338E48BB1B887F8FC02274064D47DE6E9FF7F55AEF1A071FC3EF0**。
- 14个自身类，无fe.*存根/测试探针。实际编译源码为8d302fb的改键内容加主目录保留的性能WIP，并非仅凭该提交即可复现的干净发布树；源码指纹在本轮证据的merged-source-hashes.json。
- 独立命名在keybind-scene-dev目录；原主build/out候选8125FD509F824E326B31CE3A6AC7D96023C9E468E84A393CA9080FC28477735B未覆盖。
- 已组合通过的D8666B4ACD9E98BC73785402F9A9A771DA5F54CC742C4D69664824ADAD1857A3稳定候选仍在原隔离工作树，字节未变。主会话回传其七模组23动作及菜单/重启/默认共300项通过；本轮没有重新执行或冒认这300项。

### 开发候选专项结果

| 验证 | 实例/证据目录 | 结果 |
|---|---|---|
| 灯光、维修、保存及新大场景 | remains-lad-test-20261015212600255 | 81 PASS，0 FAIL，退出0 |
| 四个测试存档槽重启恢复 | remains-lad-test-20261015212600255-cold-212846 | 7 PASS，0 FAIL，退出0 |
| 真实公共改键与HUD缓存 | remains-lad-keybind-20261015212839927 | 21 PASS，0 FAIL，退出0 |
| 改键保存重启与HUD | remains-lad-keybind-20261015212839927-cold-213013 | 6 PASS，0 FAIL，退出0 |

四轮均有SUITE_PASS，共115项。大场景192×75格、88灯、240块，包含首次绘制前接入、原生画面历史保留、无重复代理、照度跟随、损坏维修、故障恢复和原版存档。公共改键包含捕获隔离、按住维修、即时保存、失焦清理及两项HUD缓存刷新检查。

灯光混装使用CS隔离宿主11BCECA88365AB00A29A99511380CBAFA35F18CE9BF4465BE66FDAD16AD1BD4F、ContinuousScene F6ED93AFF2BFB76B4AE8CA2A2E01B84BBE4D24A8DD59EB4DE720847C8457D8D2、RV A3E2F4634F62CD1C2E10C4733E1CE9EEB3BF85F11FE2B385DBC47AFA8C1F336E、WallBlend 3B1B40A65D7C57E4711C3861463B3470B0DFC086A8C8C01870C91A2F413DA96F；两种测试均使用本轮只读复制的ModLoader候选 **BD71B6F31774B97841D4C158451DA0353B53BC46AC72F8E2A7FE2C3F3F4908B1**。单项改键测试宿主仍为正式只读9987C696…270F938。

首次灯光测试在57项后于读档后的切灯断言失败。补充诊断确认dialog=true而guiPause/script/pause/console均false，原版槽恢复了初始对话。探针关闭对话后同字节开发候选通过全部检查；没有修改产品输入防护。失败原日志也保留，不算通过。

证据：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/tests/evidence/2026-10-15/keybind-main-integration。完整过程在主目录build/evidence；整合前WIP与指纹备份在build/generated/keybind-merge-20261015。

### 后续边界

主目录已经含改键，不需再次整文件移植e21e914。原性能WIP由其原任务继续维护/提交。开发候选没有七模组全组合认证、真人菜单操作、DLC/联机或发布验收，不能替换稳定线作为已认证安装包。本轮不部署；正式release仍01767319…84537C，根pfe.swf仍9987C696…270F938，清单仍35A1A176…109E1F2，未写真实pfe存储或关闭用户实例。

构建可用build/build.ps1 -Tests -OutputDirectory <绝对路径到build/out/keybind-scene-dev>；构建改键探针用build/build-keybind-probe.ps1 -ProbeOnly -Tools <批准的只读工具目录> -OutputDirectory <同一目录>。灯光测试使用tests/run.ps1 -SkipBuild -Mixed，并指定-CandidateDirectory、-RuntimeDirectory build/keybind-scene-runtime、-CompatibilityRoot只读CS/build/runtime以及-SharedHostCandidate；改键测试使用tests/run-keybind.ps1 -GameRoot <实际游戏根> -CandidateDirectory <开发目录> -SharedHostCandidate <公共候选>。重启验证另加各自-ResumeTestId，所有路径实际执行时均为绝对路径。

## 以下保留上一轮D866稳定线交付记录

**完成：客户端候选已提交并验证，未部署。** 公共接口旧版的持续按住故障已解决；本轮没有剩余功能断言失败。待主会话与主工作目录的灯光性能改动合并并统一验收。

## 基线与提交

- 基线：84f1d791d021113e2ce65cb020334c7a32052f37（正式0.2.0）。
- 实现、测试及记忆提交：e21e914e68a32b9cd92c89f55c4e15c695c5f399。
- 分支：codex/lad-keybinds-20261015。
- 隔离工作树：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/build/generated/keybind-worktree。
- 委托来源：快捷键主会话01a13f40-6ca2-7872-9f9a-c1e453e80745，合同mods/ModLoader/docs/keybind-interface-v1.md。本轮仅写本模组候选/证据；主会话自行读取此报告，未主动发回跨会话消息。

## 交付文件

候选：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/build/generated/keybind-worktree/build/out/LightAndDarknessMod.swf

版本0.2.1-keybind；19504字节；SHA256：

`D8666B4ACD9E98BC73785402F9A9A771DA5F54CC742C4D69664824ADAD1857A3`

反编译包含14个自身类，无fe.*存根、KeybindProbe或测试夹具类。候选没有写入主工作目录build/out，更没有写入release。

## 行为

- 新页light-and-darkness-hotkeys，归入“光与暗 → 快捷键”，排序99；headlamp默认Alt+L，fixture默认Alt+E。每动作只注册一行权威绑定。
- 改键、清除与恢复默认立即生效；屏幕上的随身灯/维修提示同步当前绑定。精确匹配修饰键，额外Ctrl/Alt/Shift不算相同组合。
- 使用真实公共matchesKey/isKeyDown/isCapturingKey。捕获和释放隔离期间不触发动作；系统重复不反复切灯；松开完整组合、失焦、开始捕获时取消维修。
- 菜单、暂停、控制台、原版改键、可见输入框和对话界面禁止动作；隐藏输入框残留焦点不阻挡游玩。
- AIR应用自己的Local Store/LightAndDarkness.keys.json立即保存，独立于原版槽。旧数值迁为无修饰键；缺项用默认；未来/损坏配置保留不覆盖。临时文件写入替换成功后才更改运行绑定。
- 无公共服务/旧服务继续使用本地已保存绑定与默认；不向旧宿主注册未知keybind行。支持服务晚到和同一API对象版本升级。原功能页保持可用。

## 最终同字节候选验证

| 模式 | 独立实例或证据目录 | 结果 |
|---|---|---|
| 夹具及原生游戏 | remains-lad-keybind-20261015205843607 | 37 PASS、0 FAIL、SUITE_PASS；退出0 |
| 真实ModLoader公共接口 | remains-lad-keybind-20261015204946394 | 19 PASS、0 FAIL、SUITE_PASS；退出0 |
| 关闭进程后重启 | remains-lad-keybind-20261015205843607-cold-210401 | 4 PASS、0 FAIL、SUITE_PASS；退出0 |

真实公共候选SHA256：
`3C63CF100DC71DECD9148DCBCC083324C721338F73546F5DE60BE1832BE9023F`。

覆盖真实捕获、单独修饰键等待、重复键/释放隔离、冲突拒绝、Esc取消、Delete清除、默认恢复、隐藏输入框、两秒维修完成且仅扣一次材料、捕获中断维修、失焦清理、即时保存与冷启动恢复。测试使用程序化KeyboardEvent，经过真实公共监听与原生维修流程。

稳定原日志、指纹及类清单：
D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/build/generated/keybind-worktree/tests/evidence/2026-10-15/keybind。

完整过程保留在隔离工作树build/evidence。首次冷启动cold-205953在BOOT后加载停顿至190秒超时；同字节、同存储重试通过，启动停顿根因未确证。普通沙箱启动一次未产生日志，允许独立AIR存储后成功。以上未计为通过。

旧公共候选3337A331…84D2读取原版GUI.dial内部字段导致共享held=false，最初真实维修失败；主会话提供3C63CF10…9023F后复验成功。本模组没有修改公共源码或用本地按住判断绕过新服务。日志中的privateDial=ReferenceError是已捕获的诊断值，不是未处理异常。

## 合并要求与未验边界

本分支从0.2.0建立，因为主目录已有独立灯光性能WIP：LadHud、LadLightField、LadRuntime、LadSceneBake、入口及原灯光测试等；它们和主build/out均未由本轮覆盖。主目录MEMORY/journal也未写，只有本报告落在主目录，供主会话读取。

合并重点：

1. 保留主线continuousSceneBeforeRaster挂接、裁剪与HUD缓存；将本分支的keys实例/每帧状态清理/动态按键提示融入。
2. LadHud.show新增headlampKey参数，合并时让主线HUD缓存的比较键也包含该文本。
3. 保留输入防护和维修共享held判断；合并后统一入口/Carrier/日志版本。
4. 不要整文件覆盖主WIP，不要直接部署这个旧基线候选替代未来性能版。合并后的新字节需要重新做输入与灯光组合验证。

未认证：真人鼠标点选菜单、全部生产模组组合、DLC、联机，以及性能WIP合并后的结果。本轮没有运行原0.2.0的全部灯光79项回归，不将其历史成绩算进当前候选。

## 正式安装未变

- release/LightAndDarknessMod.swf：01767319A54AC88961B2BA40391F0FA79359486EE5591E6A22D90AD49F84537C。
- 根pfe.swf：9987C696BEBBEB0626D8F73DA775CF867B2CED4FF626137FD9F161264270F938。
- mods/loader-manifest.txt：35A1A1764B730C6DA1899EB9B2D622916E98FCBA27BD4FB0D973C3B67109E1F2。

未写真实pfe存储，测试只结束自己启动的进程；未关闭用户游戏。构建与复验命令见隔离分支design/keybinds.md。
