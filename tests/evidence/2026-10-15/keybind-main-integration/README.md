# 主目录改键与灯光性能WIP整合验证

候选：build/out/keybind-scene-dev/LightAndDarknessMod.swf；版本0.2.1-scene-keybind-dev；20074字节；SHA256 30BF82E8341338E48BB1B887F8FC02274064D47DE6E9FF7F55AEF1A071FC3EF0。所有成功测试使用同一候选字节。

| 模式 | 独立证据目录（主目录build/evidence下） | 结果 |
|---|---|---|
| 灯光、维修、保存与新大场景 | remains-lad-test-20261015212600255 | 81 PASS，0 FAIL，退出0 |
| 四个原版测试槽重启恢复 | remains-lad-test-20261015212600255-cold-212846 | 7 PASS，0 FAIL，退出0 |
| 真实公共改键及HUD缓存刷新 | remains-lad-keybind-20261015212839927 | 21 PASS，0 FAIL，退出0 |
| 自定义绑定重启及HUD刷新 | remains-lad-keybind-20261015212839927-cold-213013 | 6 PASS，0 FAIL，退出0 |

四轮均有SUITE_PASS。warm/cold混装使用CS隔离宿主11BCECA8…1BD4F、ContinuousScene F6ED93AF…7D8D2、RV A3E2F463…336E、WallBlend 3B1B40A6…DA96F、ModLoader BD71B6F3…908B1，完整指纹在warm/cold-candidate-hashes.json。改键单项使用正式只读宿主9987C696…270F938和同一BD71公共候选，详见keys-hashes及shared-host-hash。

大场景192×75格、88灯、240块，实际命中/维修/存档、首次绘制前灯具转换、开关模组无代理泄漏、画面历史保留与照度跟随均通过。HUD专项保持进度和布局不变，只更换headlamp或fixture提示，确认缓存没有吞掉改键文字更新。

首次remains-lad-test-20261015212329649在57项后，headlamp key repeat debounced断言失败。重跑补充诊断显示INPUT_AFTER_LOAD guiPause=false dialog=true script=false pause=false console=false：读档恢复了初始对话。探针明确关闭该对话后，原候选同字节通过；仅调整测试，无产品绕过或输入保护放宽。原失败日志保留，不能计为通过。

candidate-classes.txt包含14个自身类，无fe.*存根/测试类。merged-source-hashes.json记录实际编译的完整工作区源码指纹，其中包含尚未提交的性能WIP。提交的改键快照本身不等于该开发版完整源码；性能WIP仍由原任务保留。

未进行真人菜单鼠标操作、七模组全组合、DLC、联机、严格性能基准或发布验收。不替代主会话已认证D866稳定线；无部署、真实pfe存档写入或用户进程操作。

复跑时使用build/build.ps1的-OutputDirectory指向build/out/keybind-scene-dev；tests/run.ps1使用-SkipBuild -Mixed、-CompatibilityRoot指向只读CS/build/runtime、-CandidateDirectory指向上述开发候选、-RuntimeDirectory指向build/keybind-scene-runtime、-SharedHostCandidate指向获准公共候选。tests/run-keybind.ps1以-CandidateDirectory选择开发候选；-ResumeTestId仅使用对应独立测试身份。具体命令和原始启动身份见交接回执。
