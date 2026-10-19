# LightAndDarkness 当前记忆

当前正式版本0.3.2，2026-10-19 17:38安装；下面两段为此前独立调查/实验的冻结状态，当前产物以第3节为准。

> 2026-10-19 地图偏暗调查完成（本会话未改效果/部署）：原版639模板中198无灯、117仅1–2灯；安装658模板另列。`sky`实际为飞行标志，普通sky背景未获得室外底光；0.14全局底光＋自动暗区＋随机灯帧/亮度叠加。正式514A和当前2A46宿主的5场景隔离采样完成，进程已退出；31地区加载数与外置数据一致。报告 `design/map-lighting-investigation-2026-10-19.md`，证据 `knowledge/evidence/map-lighting-2026-10-19/`。建议先改环境光分类、据点/通路可读性和暗区生成，再补灯；这是建议，尚未实施。并行微光候选状态以其日志为准。

> 2026-10-19 ContinuousScene 性能实验已撤回生产源，**未部署**。完整照明帧复用通过21项像素/失效检查但命中少；遮光快照通过40项像素/实时查询检查，ABAB耗时48/62/68/55ms无稳定收益。源码恢复0.3.1，正式仍514A。实验补丁与结果保存在ContinuousScene/build/lad-rejected-cache-experiment.patch及其evidence，后续见 ../../ContinuousScene/state/in-progress-v08.md；不要发布872或314候选。

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、动态墙门遮光、随身灯、场景灯损坏/维修、氛围灯和黑暗区。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。0.3.0增加弹丸短光，0.3.1修复灯具重绘黑块，0.3.2增加炮塔与蜘蛛地雷微光及迟到分块的边框保护。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户2026-10-19要求依据原图为炮塔/地雷加入微光；当前治理持续授权本机验证后部署。其他模组最小范围只读，工具用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。测试经启动器精确选组，用唯一AIR身份与私有后台桌面。未向其它会话发送消息；收到的地图调查信息已保留，其提交8a02914独立于微光。

## 3. 当前状态
2026-10-19 17:38:43安装0.3.2，SHA256 3835827D0D2702EC55AB13721DCED7D8463C3A69780C6C37B5816BBD72164B46（27,734字节），冻结build/out/machines-v032/LightAndDarknessMod.swf，生产源码7c6ae97。17个自身类，无fe存根/测试探针；勿重编后冒充已测文件。
最终宿主02BFABE6、CS B5E8110E、RV 76314B81、WB 0BD209A1、ML BD71B6F3，清单33DE189E和application.xml未改。99项回归（20261019173524794）+173微光（20261019173634395）通过；正式读回20261019173853199再通过173项，版本、心跳、精确requested/ok集合正常，测试均结束。完整前缀remains-lad-machine-。证据tests/machine-glow-2026-10-19.md和state/machine-deployment-2026-10-19.json。
历史0.3.1为514A（17+89项），0.3.0为3BA（131弹丸、81灯具、21改键、冷读档与13平滑检查）；这些历史结果不能冒充本版全量重跑。213武器/68弹丸视觉调查不等于全部实射。

## 4. 正在进行与卡点
另会话已按用户新要求开始0.4.0环境分类/底光/天空窗洞/场景暗区修改，当前src工作区有其未提交变动；这些不是本次已部署0.3.2。不要把当前工作树重新编译后覆盖已验证的3835，0.3.2生产源码以7c6ae97为准。
微光调查、实现、当前组合验证和部署完成。初版D250因当前宿主分块重置边框被门禁拦住；3835增加无效方向恢复，8次整幅Stage相机对照通过。旧预载测试固定要求true，现改为保持切换前的实际偏好。两次并行宿主更新均重新验证后才安装，未覆盖其它任务文件。
备份build/backups/machines-20261019-173843-193/LightAndDarknessMod.v0.3.1.swf（514A）；仅当release仍3835时恢复这一文件并重启，保留宿主、清单、其它模组与真实存档。旧部署/回退脚本不能覆盖新版本。

## 5. 已知问题与边界
微光只严格支持原生UnitTurret八型、UnitMsp与UnitThunderTurret启用能量场；地雷休眠、炮塔停机/收起不发光。最多32个可见源，不改AI/伤害，遵守既有墙门遮光。开关默认开，随槽保存。实际显示树跟随已测，但不是所有天然壁挂场景逐图实战。
弹丸临时光最多192跟踪对象/96脉冲/24可见光，暂停冻结、切图/读档清理，不改伤害或弹丸寿命。最多只识别原版严格类白名单；地火/附身燃烧持续照明不在本轮范围。普通视觉发现使用同一照度栅格，听觉/开火暴露/AI记忆不改。
随身灯尚无独立装备/电池/掉落。原暗区底亮度/感知偏好仍为本次启动；氛围/弹丸开关与倍率随存档槽保存，按键即时本机保存。未认证DLC、联机、全部敌种或所有生产模组一起战斗；131专项不是整体帧率保证。
只认证当前1.02与列明组合，不认证DLC/联机/全14模组或整体帧率。当前启动器清单已为1/1/1，本任务保留其选择；勾选不代表DLC认证。地图普遍偏暗的独立调查尚未转为生产调整。大场景仍有首载和长帧成本，不承诺稳定30帧。

## 6. 下一步
本轮无待执行部署。用户保存并重启游戏加载0.3.2；设置入口「模组 → 光与暗 → 炮塔与蜘蛛地雷微光」。整体明暗调整已由另一会话接续；独立装备/电量及持续地火按后续明确需求推进。新发布先核对所有依赖指纹，使用唯一AIR身份、启动器精确选组和私有桌面；保持测试类不进入生产SWF。

## 7. 深入了解
微光design/machine-glow-v0.3.2.md；验证tests/machine-glow-2026-10-19.md；原生知识shared-knowledge/rendering/discoveries/machine-indicator-timelines.md（从游戏根）。当前测试build/build-machine-probe.ps1，tests/run-machines.ps1 -Mixed -Mode verify或regression；省略Candidate时读正式release。
原版调查design/native-lighting-survey.md；玩法design/vision-and-options.md；氛围design/atmosphere-v0.2.md与atmosphere.json。
弹种目录design/projectile-light-catalog-2026-10-15.md；实现design/projectile-lighting-v0.3.md；机制knowledge/discoveries/projectile-light-hooks-2026-10-15.md；最终证据tests/projectile-verification-2026-10-15.md。
边缘修复state/edge-fix-2026-10-15.md；快捷键state/keybind-deployment-2026-10-15.md；场景兼容tests/scene-compat-2026-10-15.md。历史0.1/0.2部署回退已过时，不可直接覆盖后续release。
