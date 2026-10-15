# 0.3.0 弹丸照明验证与发布

状态：候选专项完成，等待大场景任务安装兼容宿主后进行最终组合复核及本模组部署。本节在实际安装后更新；目前不得把候选称为已发布。

## 冻结候选

- 版本0.3.0；build/out/projectiles-v030/LightAndDarknessMod.swf，26,298字节。
- SHA256：3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C。
- 优化构建；FFDec导出16个自身类，无fe.*存根、无Probe/Test。原随身灯bitmapData更换后恢复smoothing、scene预绘接入及已发布LadKeys均保留。
- 测试使用独立AIR身份和独立探针，不使用真实pfe存储，不操作其他实例。测试类通过实际runtime对象的constructor取生产类，避免兄弟类域误解析。

## 已完成

| 身份／候选 | 检查 | 结果 |
|---|---|---|
| remains-lad-projectile-20261015221738467；3BA6 | 68原版visual与真实native弹药差异、同帧出生移除、爆炸粒子、开枪命中、彩色照度、墙遮光、长beam、暂停/开关/读档、压力 | 131 PASS |
| 同身份独立进程 cold-222007；3BA6 | 原版槽7载入、选项/亮度恢复、残光不复活 | 4 PASS |
| remains-lad-test-20261015220200272；前一候选6476 | 现有灯具/维修/保存/氛围及192×75/88灯/240块大场景，使用11B兼容宿主 | 81 PASS，作为中间证据，最终须重跑3BA6 |
| remains-lad-keybind-20261015220200399；前一候选6476 | 正式BD71公共改键服务与维修按住状态 | 21 PASS，最终须重跑3BA6 |

131项结果是68种视觉族覆盖与机制专项，不是213把武器逐把完整实战。实际Weapon.attack/actions和命中使用p10mm；另外用真实Bullet/SmartBullet/PhisBullet与实际Part构造边界。230对象的暂停压力批次采集约5ms、24盏临时光渲染约4ms，是本机单次测量，不等于整场战斗帧率保证。

原始成功证据在 [projectiles-v0.3](evidence/2026-10-15/projectiles-v0.3/)，包括完整JSON断言、68项视觉映射、日志、候选及依赖指纹、照明前后截图。专项当前混装范围是ContinuousScene、RealisticVision、WallBlend、ModLoader，不宣称联机或全部13模组已由本探针认证。

## 失败与修正记录

- remains-lad-test-20261015215721200：08EB候选在旧正式9987宿主、大场景再次绘制时原生Grafon.sceneRender #2015。发布门禁已停止；随后使用11B兼容宿主的中间候选81项通过。最终安装须等大场景事务完成，不能把候选宿主试验误称为旧正式已修复。
- remains-lad-projectile-20261015220612413：外部探针直接查询兄弟域lad类导致#1065，改成从实际runtime实例获取constructor。
- remains-lad-projectile-20261015221426312：126项已通过，探针选了超出原版saveKol=10的槽17，saveGame不保存、getSave返回null。只将探针改用独立身份中的槽7，生产字节未变；随后131+4通过。
- 源码审查修正：长beam先裁到视窗再采样；共享爆炸贴图结合混合模式/缩放；sparkle别名及较强颜色合并；非发光Part负缓存；邻近同色轨迹合并；已移除的延迟粒子及时清引用。

## 发布与回退

尚未执行。计划先保留大场景任务的11B/F6ED/3B/488四文件事务，随后本任务仅备份并更新LightAndDarkness的release文件；宿主、清单及其他模组保持部署前指纹。用户已明确授权实现与部署，并于本轮追加允许相关会话协调。最终安装时间、正式哈希、备份与回读验证将在此记录。
