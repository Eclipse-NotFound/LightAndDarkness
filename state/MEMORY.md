# LightAndDarkness 当前记忆

## 1. 这个模组是什么
为Remains 1.02增加战术光暗、动态墙门遮光、随身灯、场景灯损坏/维修、氛围灯和黑暗区。入口LightAndDarknessMod.init(main:*)；正式路径release/LightAndDarknessMod.swf。0.3.0新增原生弹丸、光束和爆炸的短时照明。

## 2. 用户偏好与协作约定
中文，战术光暗与生存探索并重，兼顾氛围。用户明确授权实现和部署，并于本轮允许向相关会话协调部署。其他模组仅最小范围只读，工具用Sandevistan/build/tools；不操作真实pfe存储或用户实例，不用Ghost。部署顺序：ContinuousScene四文件事务 → 本模组0.3.0 → PermanentInjury基于新宿主重建。相关会话身份见本版验证记录/会话上下文。

## 3. 当前状态
2026-10-16 02:14:08已随CS事务安装0.2.2-scene，SHA256 488BDC73A0BD843138FB9CABF6AC0B81159493838E3DAD4B2916688CE4C597F1；宿主11BCECA8…1BD4F。正式原生启动18项通过，实例已关闭，完整已验证回执ContinuousScene/state/deployment-v06.json；本模块记录deployment-scene-v06-20261016.md。下述0.3.0仍由自己的发布事务处理，本次未安装3BA。
0.3.0生产源码已提交84aa51b；冻结build/out/projectiles-v030/LightAndDarknessMod.swf，26,298字节，SHA256 3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C。16个自身类，无fe存根/测试探针。后续3338a37/706d385边缘验证已确认冻结3BA保留平滑修复；无需重编。
弹丸专项131项、独立进程冷读档4项已通过；边缘实际生产类13项通过；源码独立复核无阻断问题。213武器定义/68弹丸视觉/49弹药+7其他装填物品已调查，但不是213武器逐款实射。

## 4. 正在进行与卡点
本轮最终组合等待CS部署11BCECA8宿主/F6ED93AF入口/3B1B40A6墙面/488BDC73灯光。RV已另行更新为BAA48289，必须使用这个新版重跑受影响组合；旧E996数据仅是历史。
10月15日22:50的remains-lad-test-20261015225028070因会话中断只跑到47秒，没有SUITE_PASS，不能计为成功。10月16日最终3BA+11B/F6ED/BAA/3B/BD71全部通过：81项灯光（remains-lad-test-20261016015016374）及7冷启动（cold-015206）；21改键（remains-lad-keybind-20261016015311954）；131弹丸（remains-lad-projectile-20261016015401067）及4冷启动（cold-015453）。01:55本任务已无AIR，给CS独占性能窗口；其四文件正式冒烟成功后，本任务只更新自己的release并正式读回。
部署脚本build/deploy-projectiles-v030.ps1校验三个最终证据、兼容基线和现有488字节，先备份再原子替换3BA；默认仅预检查，-Install才写。若基线变化，先调查，不能放宽指纹绕过。

## 5. 已知问题与边界
弹丸临时光最多192跟踪对象/96脉冲/24可见光，暂停冻结、切图/读档清理，不改伤害或弹丸寿命。最多只识别原版严格类白名单；地火/附身燃烧持续照明不在本轮范围。普通视觉发现使用同一照度栅格，听觉/开火暴露/AI记忆不改。
随身灯尚无独立装备/电池/掉落。原暗区底亮度/感知偏好仍为本次启动；氛围/弹丸开关与倍率随存档槽保存，按键即时本机保存。未认证DLC、联机、全部敌种或所有生产模组一起战斗；131专项不是整体帧率保证。
旧正式9987大场景重绘#2015在本轮首次回归中复现，已经停止部署并等待CS兼容；不可用旧宿主失败与新宿主成功互相替代。正式安装只支持加载行1/0/0。

## 6. 下一步
继续最终组合验证、等CS安装并核对正式哈希、备份并部署3BA、独立身份从正式路径重启冒烟、更新发布回执和README/changelog/MEMORY/journal、选择性提交自己改动。不要重编已验收候选，不提交CS拥有的tests/run-keybind.ps1及tests/scene-compat-2026-10-15.md。最终给CS、边缘修复和永久伤害会话回传状态。

## 7. 深入了解
原版调查design/native-lighting-survey.md；玩法design/vision-and-options.md；氛围design/atmosphere-v0.2.md与atmosphere.json。
弹种目录design/projectile-light-catalog-2026-10-15.md；实现design/projectile-lighting-v0.3.md；机制knowledge/discoveries/projectile-light-hooks-2026-10-15.md；最终证据tests/projectile-verification-2026-10-15.md。
边缘修复state/edge-fix-2026-10-15.md；快捷键state/keybind-deployment-2026-10-15.md；场景兼容tests/scene-compat-2026-10-15.md。历史0.1/0.2部署回退已过时，不可直接覆盖后续release。
