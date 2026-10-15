# 原版弹丸、曳光与短时照明目录（1.02）

日期：2026-10-15。调查范围是本地原版 1.02 反编译源码与内嵌 XML；未把其他模组新增弹种算作原版，也没有凭伤害类型推断全部视觉。当前文件中的 RGB、半径、寿命是 LightAndDarkness 的设计值，不是从原版美术逐像素测得的“原生照明参数”：原版没有对应的动态环境照明参数。

核心实现分类器：`src/lad/LadProjectileProfiles.as`。采集、遮挡、帧间衰减、合并限额、真实游戏回归和部署由同轮主任务负责，结果应以发布验证记录为准；本目录本身是源码调查，不等于全部 213 款武器都逐款实机开火测试。

## 1. 完整性与证据入口

- `fe.AllData.d` 内嵌 XML：213 个 `weapon` 定义（tip 0/1/2/3/4/5 分别为 60/29/28/48/25/23），含玩家、敌方、近战、测试项及 9 个 `sp_*` 辅助法术占位项；68 个不同 `vis/@vbul`，变体也纳入枚举。
- 49 个 `item tip='a'` 弹药定义，另有 `aero/dart/saw/acid/pcryo/spikenail`（tip=compw）与 `scrap`（tip=stuff）被武器 `<a>` 引用。49 不能误称“全部可能装入武器的物品”。
- `AllData.as` SHA256：`975B0D0E68059A288549805C960C4402B34CC88740A8309007F75B6F0E2763E2`。
- 本文源码根：`game-reference/decompiled/1.02/src102/scripts/`。关键符号：`fe.weapon::Weapon.create/getXmlParam/shoot/setBullet/setAmmo`，`Bullet.constructor/step/run/popadalo/explosion/explRun/explVis/explBullet`，`PhisBullet.step`，`WThrow.constructor/shoot`，`SmartBullet.step`，`fe.graph::Emitter.cast`，`fe.unit::Unit.explosion`。
- 复核既有资料：`shared-knowledge/weapons-projectiles/facts/explosion-blast-bullets.md`、`bullet-explosion-flow.md`，`rendering/discoveries/native-tracer-curved-texture.md`、`burning-and-surface-fire-particles.md`。

## 2. 运行链与分类准则

`Weapon.create` 选择 Weapon / WClub / WThrow / WMagic / WPunch / WPaint。普通 `Weapon.shoot` 每颗生成 Bullet，`navod` 则生成 SmartBullet；WMagic 仍复用此链。因此激光、魔法、火焰、实体弹大量共用同一个 Bullet 类，不能按类名直接决定颜色。XML `<vis vbul='laser'>` 被转为 `visbullaser`；未指定则 `visualBullet`，天角兽模式玩家的普通 `visualBullet` 可能替换为 `visualRainbow`。

发射后 `setBullet` 复制 `tipDamage/spring/flare/explRadius/explTip/explKol` 等，随后弹药 `ammoMod` 可覆盖 tipDamage。建议读取 **实际 Bullet 字段 + 实际 vis 类 + weapon.id/visexpl/ammoFire**；不能只查武器最初 XML。`plam` 升级版把 plasma 变成 plasma5，`cflamer` 升级版把 flame 变成 flame2，两种都要覆盖。

| 运行实体 / 路径 | 照明处理 | 源码依据 |
|---|---|---|
| Bullet / SmartBullet，可见普通曳光 | 当前位置与短距离实际历史的暖色闪光；不要从枪口到弹头永久拉一条光线 | Weapon.shoot；Bullet.step；SmartBullet.step |
| `spring>=2` 且明确光束视觉 | 枪口—真实碰撞终点的细长照明，命中后随原生剩余 4 步迅速消退 | Bullet.step 使用 `vis.laser.scaleX=distance/100`，命中时 `liv=min(liv,4)` |
| spring=1 的 blump、plasma、火球等 | 是移动弹头，不能因 tipDamage=laser 就把整条射程点亮 | rech/rechr XML；Bullet.step |
| PhisBullet：普通、感应、粘附手雷 | 壳体飞行不照明，仅爆炸；使用实际 tipDamage/visexpl 分色 | WThrow：`vBullet=vWeapon`，而非 visbul；PhisBullet.step 在 liv==3 引爆 |
| `throwtip=1` 地雷 | 是 Mine 世界单位，不在飞行 Bullet 清单；通过爆炸粒子入口捕获 | WThrow.shoot |
| 隐藏爆压 Bullet | 必须排除：无 vis、liv=3、damageExpl=0、explRadius=0，只负责投递伤害 | Bullet.explBullet |
| 近战扫掠、踢击、碰撞代理 | 必须排除：无 vis，部分 tipBullet=1，不是曳光 | WClub/WKick/UnitDamager/Interact |
| Trasser | 排除：这是预瞄轨迹预测器，`trass(Graphics)` 自己模拟轨迹并画线 | Trasser.trass；Weapon.setTrass。旧 `bullet-explosion-flow.md` 的“弹壳”误称已于本轮附证据更正 |
| 真弹壳 gilza / visualGilza、火花 iskr | 不独立发环境光，避免一次开火重复叠加 | Weapon.shoot→emitShell；AllData.part |
| MagSymbol、sp_*辅助法术、绘画 | 不是飞行弹，不从此功能照明 | MagSymbol/Spell/WPaint |

安全读取只使用公开字段：`X/Y/begx/begy/dx/dy/vis/loc/owner/weap/weapId/tipBullet/tipDamage/spring/flame/babah/isExpl/liv/explRadius/partEmit/inWater`。`vse` 是 protected，`expl_t` 是 internal，不可跨模块直接读取。`babah` 代表命中停止，`isExpl` 代表首次已引爆；既不写它们，也不调用 explosion/step/run。只给照度输入添加临时数据，不改变伤害、碰撞或原生弹丸寿命。

不能用“首次看见时 liv>3”作为通用真弹条件：高速弹可能在第一次采集前已经命中，原生寿命缩至 4 后又扣成 3。这里用**可见实体与类族**排除隐藏爆压代理。

## 3. 飞行与命中光设计

以下寿命均为秒，半径为世界像素；暂停、场景切换和存档读取由采集层清理/冻结，不存入存档。透明残光只保留短历史，避免慢速子弹留下一整条灯带。普通霰弹和连射按同区域限额合并，不能每颗弹片把屏幕叠到纯白。

| 类别 | 飞行半径 / 强度 | 残留 | 命中半径 / 寿命 | 建议色与节奏 |
|---|---:|---:|---:|---|
| 普通弹、AP/HP、霰弹 | 65 / 0.55 | 0.09 | 85 / 0.12 | 暖白 #FFE3AA，短促；不按每帧无限叠加 |
| 燃烧实弹 | 80 / 0.60 | 0.12 | 110 / 0.20 | 暖橙 #FFD08B，比普通弹略亮 |
| 等离子填料实弹 | 90 / 0.65 | 0.12 | 130 / 0.24 | 绿 #A0FF9C；即使外形仍普通曳光也识别 |
| 激光光束 | 110 / 0.80 | 0.12 | 130 / 0.20 | 普通红暖色；电/魔法/彩虹特型变色；线段随命中消失 |
| 充能脉冲 blump | 100 / 0.75 | 0.12 | 125 / 0.20 | 红暖色，仅移动头部 |
| 线圈/轨道 rail | 95 / 0.65 | 0.12 | 125 / 0.18 | 冷白 #C6E9FF |
| 等离子球 | 125 / 0.80 | 0.18 | 170 / 0.35 | 绿 #ACFFA2，柔边头部 |
| 火焰 / 火球 / 喷雾 | 120 / 0.80 | 0.16 | 170 / 0.35 | 橙 #FFC078；连续火焰的局部合并保持稳定 |
| 信号弹 flaregun | 150 / 0.80 | 0.22 | 170 / 0.45 | 暖橙，较慢衰减，但不会凭空变成长驻路灯 |
| 电弧 / EMP / 星能 | 110 / 0.75 | 0.12 | 150 / 0.25 | 青白 #A9E2FF，短亮脉冲 |
| 冷冻弹 / 冰片 | 105 / 0.65 | 0.14 | 140 / 0.25 | 淡蓝 #BDEFFF |
| 念动力 / 魔法刀 / 震荡波 | 100 / 0.65 | 0.14 | 140 / 0.25 | 淡紫 #D4B5FF，不因物理/刀刃伤害码而漏掉 |
| 血系魔法 | 100 / 0.65 | 0.14 | 125 / 0.22 | 暗红粉 #FF9CA9 |
| 死灵弹 | 90 / 0.55 | 0.16 | 120 / 0.25 | 淡紫 #BCA2E8，保持比普通能量弹弱 |
| 火箭 / 导弹尾焰 | 95 / 0.70 | 0.12 | 230 / 0.40 | 暖橙；rocketgas仅尾焰，气体散开后无光 |
| 魔法爆裂球 / 重型弹 | 140–150 / 0.80 | 0.18–0.20 | 250–280 / 0.50 | 按 plasma/eclipse 特型分绿/紫 |
| balefire 弹 | 105 / 0.65 | 0.14 | 300 / 0.65 | 黄绿 #D5FF89，大爆闪受限额约束 |
| 飞镖、锯片、铁路钉、刺、毒液、酸液、粉液 | 0 | 0 | 0 | 不主动发光；有色不等于自发光 |
| 手雷、粘弹、枪榴弹壳 | 0 | 0 | 按爆炸类型 | 不提前暴露未引爆炸弹位置 |

### 容易误判的实际字段组合

- `termo/turret4`：D_FIRE=3 + spring=2，真热射线，不是火球。
- `rech/rechr`：D_LASER=5 + blump + spring=1，是飞行脉冲，非全长光束。
- `prism`：laser6 + spring=3，每束各有原生视觉帧；照明只做柔和淡彩，不改原生彩虹素材。
- `friend`：D_FRIEND=101 + friend + spring=2，确实有光束；不能把大于 19 的伤害码全部过滤。
- `blaster`（laser1）、`turret10`（plasma3a）、`ttweap6`（ttmoln）、`skybolt/a_magic`（skybolt/sel）：D_ASTRO=18。
- `aliblade`（blood）与 `blades`（blade）：D_BLADE=1，仍是可发光魔法；实体 saw 和 ship 保持不亮。
- `telebul/udar`（telebullet）：D_PHIS=2，仍是念动力弹。
- `alipsy`（psy）D_SPARK=9；`alipsy2`（bloodpsy）D_EMP=8；`alimray`（laser7）D_NECRO=16。
- `cflamer` 基础/升级分别 flame/flame2，但没有 flame 数值；不能只判断 b.flame>0。
- 水会使 FIRE/LASER/PLASMA/SPARK/ACID 弹在 `Bullet.run` 中停止并发蒸汽；衰减必须响应真实 babah/位置，不按预期射程继续照亮水底。

## 4. 弹药差异

| 弹药族 / 特型 | 照明决定 |
|---|---|
| p9/p32/p10/p375/p44/p127/p145/p308/p50mg/p556/p5/p20/p12 与 AP/HP/独头等 | 基础暖白曳光；穿甲、开花、击退与多颗弹差别不自动成为不同光色 |
| p50mg_4、p12_4 | `fire=8/10`→weap.ammoFire；b.tipDamage 仍可能 0。暖橙微增强，不能只靠 damage=3 判断 |
| p556_5、p12_5 | tipdam=6→实际 b.tipDamage=6；仍可 visualBullet，给绿色短闪 |
| batt/energ/crystal 与各自 _6 | 电池由使用武器决定光型；_6 只改伤害、穿甲、磨损，不强制换色 |
| fuel、fuel_7、aero | 由火焰/信号弹实际视觉决定；fuel_7 不凭名称额外生成新光源 |
| gren40、gren40_8、gren40_9 | 仍是榴弹壳；_8 tipdam6 绿爆闪，_9 tipdam8 青白 EMP 闪；飞行不亮 |
| rocket、egg、bcell | 分别跟随火箭、balefire、对应武器视觉；不以库存物品直接造光 |
| dart/saw/spikenail/scrap/acid | 实体物品或液体不自发光；scrap由buckshot发普通可见曳光时仍沿该实际视觉处理 |
| pcryo | 冷冻弹头淡蓝微光 |
| recharg、not | 隐藏占位弹药，不是独立飞行实体 |

`Weapon.setAmmo` 的 mod 只是一类弹药标签；改变伤害类型的是 tipdam，改变燃烧附效的是 fire。不要把 `_1/_2/_3` 的数字当伤害类型，也不要让弹药换装影响已经在空中飞行弹的颜色：采集器应在首次识别时保存本弹 profile。

## 5. 爆炸、命中与粒子

正常命中优先从实体 `babah` 转换做一次短闪；普通弹不因寿命自然到期、出图或场景移除无条件模拟撞击。爆炸优先识别原生 Part，父弹 `isExpl` 仅补漏，同位置/同次事件去重。

原因：`Unit.explosion` 与 Mine 可以创建无 vis、甚至不加入更新链的临时 Bullet 立即引爆；只追踪“有视觉的飞行弹”会漏掉这些爆炸。另一方面，爆炸伤害投递的隐藏 Bullet 不能发光。

| 原生 Emitter id | 本轮照明 | 原生粒子寿命（游戏步） |
|---|---|---:|
| expl / ttexpl | 暖白橙 250/300px，0.35/0.45s | 15；ttexpl 基础 scale=2 |
| explw | 水下冷白，150px/0.25s，弱于空气爆炸 | 15 |
| fireexpl | 橙 240px/0.45s | 15 |
| plaexpl / ttplaexpl | 绿 260/300px，0.45/0.50s | 25 |
| impexpl | 青白 240px/0.30s | 25 |
| iceexpl | 淡蓝 220px/0.35s | 25 |
| balefire / baleblast | 黄绿 320px/0.65s；二者同次爆炸合并 | 60 / 30 |
| sparkleexpl | 淡紫 300px/0.50s | 25 |
| acidexpl | 极弱绿色瞬间反光，90px/0.12s；后续酸液不照明 | 10 |
| react | 小型燃烧爆点，135px/0.25s | 15 |
| eclipse | 紫色魔法爆发，260px/0.50s | 25 |
| gas / pinkgas | 不照明，不把雾变成灯 | 60，可反复产生 |
| flare / iskr / iskr_bul / gilza | 不重复计为爆炸光源 | 10 / 20–40 / 15–20 / 20–30 |

`Bullet.explVis` 先判断 `weap.visexpl` 覆盖：spgren→sparkle（实际发 expl + sparkleexpl）、incin→react、ttweap4→ttexpl、ttweap5→ttplaexpl、eclipse→eclipse。必须支持这些覆盖，不能把 ttweap5 只因 D_EXPL=4 永远做成橙爆闪。

火焰爆炸的 `explLiquid('fire')` 与酸液的 `explLiquid('acid')` 会生成地面粒子；地火原生寿命 100–130 步。此轮白名单没有将所有地火永久灯化，避免把“短时曳光”扩成未经验证的持续火灾系统。附身 burning 粒子同样保持独立后续议题。

`Emitter.cast` 没把 emitter.id 保存到 Part；`Part.vClass/blitData` 能提供身份线索，但 expl/fireexpl/ttexpl 共用 sprExpl。若采集器按视觉/贴图回推，必须明确这是可能歧义的身份映射，采用安全一致色和同位置去重，而不是把每个白名单名字都给同一贴图套一次光。禁止为照明重复调用 emit、重演爆炸或生成伤害。

## 6. 验证最低覆盖与边界

源码确定性检查：68 个 vbul 每个都有明确归类或排除；变体、14 个爆炸粒子入口、49+7 弹药物品不漏调查。功能验证应至少包含普通实弹、填料实弹、燃烧弹、springs 1/2/3、PhisBullet、枪榴弹、rocketgas、零视觉爆压代理、近战、毒液、彩虹与自定义 visexpl。

需要在正式候选字节中验证：真实原生发射/撞墙、遮挡与变暗后恢复、爆炸后清理、暂停/换场景、不改变原生伤害/寿命、密集霰弹/机枪/火焰的有界开销；若沿用大场景 WIP，还要确认原生首次绘制前接入和裁剪没有回退。不能只用新测试类里的假实现代替正式分类器。

配色限制：当前按美术语义选择柔和色，不宣称 68 种原生素材都已逐像素采色；plasma 变体、prism 与血/死灵类型尤其值得视觉抽查。第三方自定义新 Bullet 子类不在严格类白名单，未知视觉默认不发光；未来扩展按实际新增类与字段证据加入。

## 附录 A：全部原版 vbul 对应的武器

以下从内嵌 XML 枚举，类名为 `visbul` 加左列，括号内容是 weapon id。空 vbul 的普通实弹默认使用 visualBullet；WThrow 另使用 vWeapon，不在此 68 行列表中。

| vbul | weapon id |
|---|---|
| arson | antfire, arson |
| baleegg | bel |
| blade | blades |
| blood | aliblade |
| bloodlight | alilight2 |
| bloodpsy | alipsy2 |
| blump | rech, rechr |
| cryo | cryo |
| dart | dartgun |
| defwave | defwave |
| dflame | dragon, phoenix |
| dray | dray |
| eclipse | eclipse |
| fireball | fireball, incin |
| flame | cflamer, flamer, robofire |
| flame2 | cflamer, robofire2 |
| flare | flaregun |
| friend | friend |
| gren40 | aglau, glau, glau1 |
| gren50 | a_expl |
| ice | ice |
| kapl | slime |
| laser | gatl, lasr, robogatl, robolaser2, turret2 |
| laser1 | blaster, turret5 |
| laser2 | lasp, owllaser, robolaser |
| laser3 | grom, turret7 |
| laser4 | lassn |
| laser5 | nova, robonova |
| laser6 | prism |
| laser7 | alimray |
| laser8 | dronlaser |
| lightning | alilight, lightning |
| mbul | mbul |
| mray | mray |
| necrbullet | necrbullet |
| necro | zombinecro |
| pink | zombipink |
| pinkkapl | pinkslime |
| pinkplevok | pinkbloat |
| plasma | plam, plar, turret3 |
| plasma1 | plap, roboplasma |
| plasma2 | a_energ, plamg, roboplam |
| plasma3 | gatp, robogatp |
| plasma3a | robogatp2, turret10 |
| plasma4 | bfg |
| plasma5 | dronplasma, plam, roboplasma2 |
| plasma6 | quick |
| plevok | acidgun, bloat |
| psy | alipsy |
| pulse | pulsep, pulser |
| rail | rail |
| rocket | dronmlau, mlau, robomlau, robomlau2 |
| rocketgas | robogas |
| saw | sawgun |
| sel | a_magic |
| ship | ship |
| skybolt | skybolt |
| spark | dronpspark, robospark, robospark2, shok |
| sparkl | robosparkl, sparkl |
| spikenail | railway |
| telebullet | telebul, udar |
| termo | termo, turret4 |
| ttlaser | ttweap3 |
| ttmoln | ttweap6 |
| ttnavod | ttweap5 |
| ttplasma | ttweap2 |
| ttzalp | ttweap4 |
| venom | zombiacid, zombivenom |
