# LightAndDarkness 当前记忆

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、动态墙门遮光、随身灯、场景灯损坏/维修、氛围灯和黑暗区。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。0.3.0新增原生弹丸、光束和爆炸的短时照明。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户明确授权实现和部署，并于本轮允许向相关会话协调部署。其他模组仅最小范围只读，工具用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。部署顺序：ContinuousScene四文件事务 → 本模组0.3.0 → PermanentInjury基于新宿主重建。相关会话身份见本版验证记录/会话上下文。

## 3. 当前状态
2026-10-16 02:20:29已安装0.3.0，正式SHA256 3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C（26,298字节）。此前CS于02:14安装的488兼容版已备份；本次仅替换自己的release，部署时宿主11B、CS F6ED、RV BAA、WB3B、MLBD71和清单6B669未动。完整指纹和正式回读记录state/projectile-deployment-2026-10-15.json。测试实例已结束，窗口已交还其他任务。
随后PermanentInjury按协调顺序完成安装：当前宿主08A96759720C7A2AA489FCEEDB209C6E704500FDE7B1A4A49146BD578E99A8BC，清单778B8D1E551E69F4A16B3F4131141FBE4B1E35E9E9EFF2F360593182B5C07D6C；LAD仍3BA。其负责人回执正式158+5项通过、状态installed-verified，并承诺不再更改本轮宿主/清单；已转达RConnect。LAD本轮131项仍绑定此前11B，不能冒充新08A或联机认证。
0.3.0生产源码已提交84aa51b；冻结build/out/projectiles-v030/LightAndDarknessMod.swf，26,298字节，SHA256 3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C。16个自身类，无fe存根/测试探针。后续3338a37/706d385边缘验证已确认冻结3BA保留平滑修复；无需重编。
弹丸专项131项、独立进程冷读档4项已通过；边缘实际生产类13项通过；源码独立复核无阻断问题。213武器定义/68弹丸视觉/49弹药+7其他装填物品已调查，但不是213武器逐款实射。

## 4. 正在进行与卡点
2026-10-16用户反馈进图即有上方/右方黑块。已从正式3BA+08A字节在隔离实例确认LadSceneBake.redraw调用Grafon.drawLoc后漏恢复相机边框；普通房间转换和禁用恢复都把四边缩放重置2。三档缩放19项归因检查通过，仅setZoom()即可恢复画面且镜头档位/位置不变。本轮是原因排查，生产代码和release未改，缺陷仍待修复；临时触发原版缩放键（默认单引号）可重算边框。证据tests/evidence/2026-10-16/black-border-diagnosis/README.md。
此前弹丸研究、实现、协调及部署已完成。最终3BA+11B/F6ED/BAA/3B/BD71通过81灯光及7冷读档、21公共改键、131弹丸及4冷读档、13边缘检查；正式路径回读remains-lad-projectile-20261016022047545再通过131项，有v0.3.0 loaded与持续心跳。详细身份和证据见tests/projectile-verification-2026-10-15.md。
用户保存进度并重启游戏后加载新版。本轮未改其实际存档或关闭用户游戏。RConnect和PermanentInjury会基于新组合继续各自验证；它们后续宿主变动不是本次认证范围，届时先核对指纹。
回退备份build/backups/projectiles-20261016-022028-930/LightAndDarknessMod.v0.2.2-scene.swf（488BDC73…97F1）。仅当当前release仍3BA时恢复该文件并重启，不回退其他模组或宿主；旧CS四文件事务不能覆盖后来版本。部署脚本保留为本次已完成事务，基线锁定488，不能拿它强制覆盖未来版本。

## 5. 已知问题与边界
进图黑块为已确认的生产缺陷，详见第4节；既有光照位图检查未覆盖重绘后的原生边框，不能把此前通过视作此问题已验收。隔离实例已关闭，真实存档未改。
弹丸临时光最多192跟踪对象/96脉冲/24可见光，暂停冻结、切图/读档清理，不改伤害或弹丸寿命。最多只识别原版严格类白名单；地火/附身燃烧持续照明不在本轮范围。普通视觉发现使用同一照度栅格，听觉/开火暴露/AI记忆不改。
随身灯尚无独立装备/电池/掉落。原暗区底亮度/感知偏好仍为本次启动；氛围/弹丸开关与倍率随存档槽保存，按键即时本机保存。未认证DLC、联机、全部敌种或所有生产模组一起战斗；131专项不是整体帧率保证。
旧9987大场景重绘#2015曾阻止上线；最终11B宿主已通过相关回归。大场景全图常驻仍有首载与长帧成本，不承诺稳定30帧。正式安装只支持加载行1/0/0。

## 6. 下一步
优先处理LadSceneBake场景重绘后的相机边框恢复，回归进图/禁用/换图/三档缩放及大场景；当前只完成诊断，无待执行部署。其余弹种明暗、独立装备/电量及持续地火按后续需求。新发布先核对宿主和依赖，使用独立AIR身份验证，保持测试类不进入生产SWF。不要重编后冒充既有冻结产物。

## 7. 深入了解
原版调查design/native-lighting-survey.md；玩法design/vision-and-options.md；氛围design/atmosphere-v0.2.md与atmosphere.json。
弹种目录design/projectile-light-catalog-2026-10-15.md；实现design/projectile-lighting-v0.3.md；机制knowledge/discoveries/projectile-light-hooks-2026-10-15.md；最终证据tests/projectile-verification-2026-10-15.md。
边缘修复state/edge-fix-2026-10-15.md；快捷键state/keybind-deployment-2026-10-15.md；场景兼容tests/scene-compat-2026-10-15.md。历史0.1/0.2部署回退已过时，不可直接覆盖后续release。
