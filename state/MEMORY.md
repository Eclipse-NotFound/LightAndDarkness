# LightAndDarkness 当前记忆

> 2026-10-19 ContinuousScene 性能实验已撤回生产源，**未部署**。完整照明帧复用通过21项像素/失效检查但命中少；遮光快照通过40项像素/实时查询检查，ABAB耗时48/62/68/55ms无稳定收益。源码恢复0.3.1，正式仍514A。实验补丁与结果保存在ContinuousScene/build/lad-rejected-cache-experiment.patch及其evidence，后续见 ../../ContinuousScene/state/in-progress-v08.md；不要发布872或314候选。

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、动态墙门遮光、随身灯、场景灯损坏/维修、氛围灯和黑暗区。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。0.3.0新增弹丸短时照明；当前0.3.1修复灯具重绘造成的进图黑块。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户已授权实现、部署，并于2026-10-16明确要求修复进图黑块。其他模组仅最小范围只读，工具用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。此前CS→LAD0.3.0→PermanentInjury已协调部署完毕；本次仅更新LAD0.3.1，没有另发跨任务消息。

## 3. 当前状态
2026-10-16 13:30:17已安装0.3.1，正式SHA256 514A7671D4DA517A31045AEAF8FFAD3089AA66705FE58D14DC339F849589A7F6（26,358字节）。仅替换自身release；当前08A宿主、F6ED/BAA4/3B1B/BD71依赖、778B清单及描述符未动。17项边框专项+89项灯具/存读档/大场景回归通过；正式读回remains-lad-border-20261016133033599再通过17项、v0.3.1与心跳正常。测试均结束。证据tests/border-fix-2026-10-16.md，回执state/border-deployment-2026-10-16.json。
历史0.3.0于02:20:29安装，SHA256 3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C（26,298字节），详细部署记录state/projectile-deployment-2026-10-15.json。
随后PermanentInjury曾按协调顺序完成安装，宿主更新为08A96759720C7A2AA489FCEEDB209C6E704500FDE7B1A4A49146BD578E99A8BC，清单为778B8D1E551E69F4A16B3F4131141FBE4B1E35E9E9EFF2F360593182B5C07D6C；当时LAD仍3BA。其负责人回执正式158+5项通过，已转达RConnect。历史LAD弹丸131项绑定此前11B，不能冒充新08A或联机认证。
历史0.3.0生产源码84aa51b，冻结build/out/projectiles-v030/LightAndDarknessMod.swf（3BA）；3338a37/706d385确认其保留平滑修复。当前0.3.1冻结build/out/borders-v031/LightAndDarknessMod.swf（514A），反编译16个自身类，无fe存根/测试探针；不要重编后冒充此冻结产物。
弹丸专项131项、独立进程冷读档4项已通过；边缘实际生产类13项通过；源码独立复核无阻断问题。213武器定义/68弹丸视觉/49弹药+7其他装填物品已调查，但不是213武器逐款实射。

## 4. 正在进行与卡点
进图黑块已完成修复与部署：LadSceneBake显式接收当前相机，drawLoc后、sceneTick前无参数setZoom，转换和恢复共用；档位/scaleV/镜头位置不变。正式版17项最终Stage对照通过，不再需要手动切换缩放。旧版19项仅作归因基线，修复证据见第3节。
此前弹丸研究、实现、协调及部署已完成。最终3BA+11B/F6ED/BAA/3B/BD71通过81灯光及7冷读档、21公共改键、131弹丸及4冷读档、13边缘检查；正式路径回读remains-lad-projectile-20261016022047545再通过131项，有v0.3.0 loaded与持续心跳。详细身份和证据见tests/projectile-verification-2026-10-15.md。
用户保存进度并重启游戏后加载新版。本轮未改其实际存档或关闭用户游戏；其他任务后续宿主变动不在本次认证范围，接续时先核对指纹。
本次回退备份build/backups/borders-20261016-133017-452/LightAndDarknessMod.v0.3.0.swf（3BA）；只在当前release仍514A时恢复并重启。旧0.2.2/CS回退和旧部署脚本不能覆盖当前版本；所有回退均保留宿主、清单、其他模组与真实存档。

## 5. 已知问题与边界
进图黑块在0.3.1已修复并验证。此前光照位图检查未覆盖原生边框，现已补进图/读档/普通与大场景开关/三档缩放检查。验证不是用户原存档或全部14模组组合；真实存档未改。
弹丸临时光最多192跟踪对象/96脉冲/24可见光，暂停冻结、切图/读档清理，不改伤害或弹丸寿命。最多只识别原版严格类白名单；地火/附身燃烧持续照明不在本轮范围。普通视觉发现使用同一照度栅格，听觉/开火暴露/AI记忆不改。
随身灯尚无独立装备/电池/掉落。原暗区底亮度/感知偏好仍为本次启动；氛围/弹丸开关与倍率随存档槽保存，按键即时本机保存。未认证DLC、联机、全部敌种或所有生产模组一起战斗；131专项不是整体帧率保证。
旧9987大场景重绘#2015曾阻止上线；最终11B宿主已通过相关回归。大场景全图常驻仍有首载与长帧成本，不承诺稳定30帧。正式安装只支持加载行1/0/0。

## 6. 下一步
无待执行部署。用户保存并重启游戏加载0.3.1，按实玩反馈接续；独立装备/电量及持续地火按后续需求。新发布先核对宿主和依赖，使用独立AIR身份验证，保持测试类不进入生产SWF。不要重编后冒充既有冻结产物。

## 7. 深入了解
原版调查design/native-lighting-survey.md；玩法design/vision-and-options.md；氛围design/atmosphere-v0.2.md与atmosphere.json。
弹种目录design/projectile-light-catalog-2026-10-15.md；实现design/projectile-lighting-v0.3.md；机制knowledge/discoveries/projectile-light-hooks-2026-10-15.md；最终证据tests/projectile-verification-2026-10-15.md。
边缘修复state/edge-fix-2026-10-15.md；快捷键state/keybind-deployment-2026-10-15.md；场景兼容tests/scene-compat-2026-10-15.md。历史0.1/0.2部署回退已过时，不可直接覆盖后续release。
