# 2026-10-19 地图光照调查驱动实战记录

被测技能：remains-runtime-debug 2026-10-19.2（SHA256 9BBEBA3324A3EAA6FADC672C782BFB8576C4350ED1443F2469D7F71B2C91ECA7）；remains-auto-testing 2026-10-19.2（40774E4EDF3BEFF5FF5DE8412B525E7EBD3E71AAAC88EBFA78B3D414D4D6C8EB）；test-report 2026-09-16.1。
技能归属：Remains/.agents/skills（维护驻地mods/ModLoader）；test-report为C:/Users/hello/.agents/skills/test-report。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness。

- 场景与实际采用：用户要求全面调查地图普遍偏暗。自然采用启动器只读清单、专用场景驱动、唯一AIR ID、独立副本与HiddenProcess后台桌面，未调用Ghost。没有启动14模组归因矩阵；任务针对原版布灯和正式LAD在无其他模组时的行为。
- 结果：最终应用remains-lad-survey-20261019171033934493完成5场景/15截图；roomsLoad=1，31地区模板数与全量外置扫描逐一匹配。本轮loader requested/ok精确为LightAndDarknessMod与MapLightingSurveyMod，无err。固定输入指纹在运行结束后不变。进程退出后关闭句柄和桌面。
- 证据：[调查报告](../design/map-lighting-investigation-2026-10-19.md)、[运行结果与loader](../knowledge/evidence/map-lighting-2026-10-19/runtime/survey.json)、[选组回执](../knowledge/evidence/map-lighting-2026-10-19/runtime/selection.json)、[冻结输入](../knowledge/evidence/map-lighting-2026-10-19/runtime/hashes.json)、[进程信息](../knowledge/evidence/map-lighting-2026-10-19/runtime/process.json)。源码tests/MapLightingSurveyMod.as和tools/run-map-lighting-survey.py。
- 驱动适配发现：新副本须复制ModLoader/supported-mods.txt；启动器扫描入口必须以Mod结尾；--report输出的selected位于configuration内，--list则在顶层。首次准备失败于缺少目录/读取回执路径，未启动游戏；随后按现有接口修正，未改启动器或绕过选组。
- 权限/失败：受限环境CreateDesktopW返回WinError5，经正常require_escalated流程运行成功，没有改为前台。首次实际驱动在t_exit仍大于0时发起第二次旅行，原版exitLand直接返回，留下两个样本后超时；该运行不计入有效结果。读源码后加t_exit==0门控，新ID重测完成。没有绕过正常旅行序列。
- 限制：这是单次真实业务场景调查。数值是正式照度场的地面邻近样本，不是可达性或屏幕亮度百分比；截图显式揭开探索黑幕。未测前台GPU、性能、联机及14模组组合，不能据此宣称技能全面验证通过。
- 新增证据：新版本技能的专用驱动迁移、真实视觉调查、后台桌面权限失败后正常升级成功；现有正式副本/真实存档不变。处置：待维护核对，已追加全局测试报告台账。业务发现已落盘到调查报告及shared-knowledge/rendering/discoveries/native-map-lighting-coverage-2026-10-19.md。
