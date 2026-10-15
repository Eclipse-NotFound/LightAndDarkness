---
domain: entities
type: discoveries
game-version:
  - "1.02"
confidence: high
verified: false
discovered-by: LightAndDarkness
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.unit::Unit.look/findCel/listen/step; fe.unit::UnitPlayer.actions/observation/attach; fe.loc::Location.step/allon/alloff; fe.inter::Sats.getUnits/getPrec"
    summary: "逐条回读视觉、听觉、暴露、命中、灯光相关状态及公开子对象调用链；将源码确认与未实测的模组接入方案分开。"
date-updated: 2026-10-15
---

# 光暗与战斗：原版机制及 LightAndDarkness 接入候选

## 范围与结论

本篇针对 LightAndDarkness 的战术光暗与生存探索设计，复核原版参考代码，不是模组实现说明。源码根 `S/` 指游戏根的 `game-reference/decompiled/1.02/src102/scripts/`，以下路径、行号均相对该根。本次未运行游戏、未读取其他模组、未重新反编当前宿主、未修改游戏或原始资料。`verified: false` 表示尚无本轮运行验证，不否认已列出的源码证据。

已先查阅共享知识中的 `stealth-skills-and-exposure-2026-10-14.md`、`enemy-ai-source-audit-2026-09-09.md` 与 `enemy-ai-drive-interfaces.md`，再回读下述原件。重复机制以本篇的光暗设计约束为目的，不重复晋升公共事实。

**核心判断：原版有环境明暗、探索可见范围、单位视觉发现等几套系统，但普通敌人的视觉发现不采样某位置是否被灯照亮。关灯目前不会自动给黑暗中的玩家增加隐蔽。新模组须明确建立这条联系。**

## 已确认：源码机制

### 1. 必须分开的五种量

| 量 | 原版含义及消费者 | 对新模组的约束 |
|---|---|---|
| `Location.darkness` | 场景底色/静态光照绘制输入；`Grafon.drawLoc:427–436` 从 `170+darkness` 生成色层。 | 画面变暗本身不代表敌人变盲。 |
| `Location.visMult` | 地区/房间级统一视觉系数；初始化还缩放 `lDist1/2`。 | 不是每个位置的实时照度；改它会影响全房间及双方视觉。 |
| `Tile.visi` | 原版探索/可见范围状态；`getTileVisi`、SATS、传送等消费。 | 不宜直接拿来保存新照度，可能改变传送、锁定与噪声提示。 |
| `Unit.visibility` | 目标被看见的基础距离尺度，默认 1000，玩家每步为 2000/1500，藏身再减半。 | 不是 0–1 开关；玩家值每步重写。 |
| `Unit.vision` | 观察者视觉距离倍率。 | 不同敌种、警戒状态会重算；不是夜视能力的独立标志。 |

`Location:193–201、385–387、458–480` 独立读取 `vis/dark/lon/retdark`；`:643–644` 将初始探索距离乘 `visMult`。`allon:2920–2949` 与 `alloff:2952–2972` 改调色、`lightOn`、`darkness` 并切换背景灯、重绘，**没有修改 `visMult`**。两者不能当作已有的全房间潜行开关。

### 2. 普通敌人如何看见玩家

`Unit.look(target, overLook=true, visionOverride=0, distanceOverride=0)` 是公开方法，`Unit:4560–4640`：

```text
R = (target.visibility × target.stealthMult × loc.visMult + target.demask)
    × (visionOverride 或 observer.vision)
```

调用者传正 `distanceOverride` 时直接用该距离。随后执行方向/视锥检查与实体瓦片遮挡采样：`phis==1` 且采样落在实体边界内才阻断。无锥角且不允许向后看时另有朝下距离折扣与背后门槛；有 `vKonus` 时即使 `overLook=true` 也要检查锥角。结果：距离超过 `4R` 为 0；无遮挡且进入**目标的** `detecting` 范围返回 20；`d<R` 返回 4；其余返回 `4R²/d²`。

该方法不读 `darkness`、`Tile.visi`、背景灯或光照位图。`invis/isVis` 也不是这个共用方法的统一拒绝条件；各调用者另有筛选。

`Unit.findCel:4643–4700` 不是全场最近敌人搜索：优先 `priorUnit`，否则尝试玩家。对玩家先听觉再视觉，分别进入 `UnitPlayer.observation`；视觉强度正且共享 `obs≥maxObs` 才锁定；仅听觉时可写模糊位置，或只返回“听到”。非玩家候选主要以 `look>0.5` 锁定，不走玩家共享暴露条。

`UnitPlayer.observation:3106–3146` 以 `max(0,sneak-demask/20)` 对抗观察者 `observ`，再乘 `pers.visiMult×stealthMult`，藏身/蹲伏抵消，累计 `obs`。**听觉输入也乘这两个隐蔽倍率。** 因此为了黑暗而修改 `pers.visiMult/stealthMult` 会连听觉暴露一起改，无法满足“只让暗处更难被看见、声音仍危险”的首个验证目标。

**距离响应非线性**：基准静止玩家 `visibility=1500`、其他倍率为 1、无暴露，600 像素处 `look=4`。若仅将 visibility 乘 0.1，R=150，此处降为 0.25；100 像素处仍是 4；80 像素内还可能为 20。较小的倍率改动若仍使目标落在 R 内，发现强度根本不变。此为公式演算，不是实测发现时间。

### 3. 开火、脚步、报警与脱战不能被照度覆盖

- `Unit.listen:4532–4557` 半径为 `target.noise×ear×loc.earMult`，强度 `4×(1-d²/R²)`；无墙体采样。
- `Unit.makeNoise:3240–3264` 取已有噪声与新噪声的最大值，原生后续衰减。音效播放不等同于感知噪声。
- `Weapon.shoot:1574–1576` 用 `shine` 抬高 `owner.demask`；其在视觉公式中位于隐蔽乘积外。`demask` 同时减少有效潜行点。若保留这一路，黑暗中开火自然比静止藏匿更容易暴露；不要把整个 R 一起乘到接近零而意外抹掉枪口暴露。
- `Unit.budilo:4271–4295` 向一定范围的同阵营同伴报警；`Location.budilo:2859–2882` 的筛选不同。受击与死亡可独立触发报警，不能假定暗处一击致死就无人得知。
- `UnitRaider.control:794–867` 在成功锁定时缓存 `celUnit2` 和 `t_chCel=6`；接下来数次寻敌失败仍会 `setCel(celUnit2)`。内部记忆不因灯熄灭自动归零。
- `UnitRaider.attack:1507–1535` 允许无实体目标时向保存位置开火；暗处仍受追击/盲射是原生机制能支持的合理结果。直接每步清 `celUnit` 会干扰原生目标记忆、作战与潜行暴击，不是中性的视觉降级操作。

### 4. 哪些敌人不能按统一“黑暗降低视觉”处理

| 家族/分支 | 已核对的差异 | 设计含义 |
|---|---|---|
| 掠夺者及衍生 | `UnitRaider:999–1007` 平静/警戒 vision 为 `1/1.5×visionMult`；雇佣兵、英克雷、斑马另改 visionMult。 | 首个自然发现对照的合适对象，但要测刚发现与已有目标两种状态。 |
| 尸鬼 | `UnitZombie:428–438、698–704` 不同状态改 vision/ear，埋伏、出土另有生命周期。 | 不可把埋地或睡眠当光暗造成。 |
| 地狱犬 | `UnitHellhound:12、599–605` 玩家在 `nuh=400` 内，直接返回视觉强度 20，先于基类视线与倍率。 | 原生近距特殊感知会绕过普通暗处修正；适合作为明确的反潜行种类。 |
| 炮塔 | `UnitTurret:638–643` 视锥方向来自炮口；`:121–124、525–533` 某类 absVis 直接锁定同房玩家。 | 普通炮塔与绝对感知炮塔必须分层，后者不靠降低 vision 解决。 |
| 改编程炮塔/NPC | `UnitTurret:534–555`、`UnitNPC:444–459` 自行遍历目标并筛 invis；改编程炮塔有效 priorUnit 可直接锁定。 | 友军观察敌人的规则不完全等于敌人观察玩家。 |
| 天角兽 | `UnitAlicorn:717–734` vision 随警戒/区域警报变化；`telepat:403–413` 向同阵营、无目标者直接传实体目标，无逐接收者视线测试；`:671–678` 发现后定期调用。 | 一个看见玩家的天角兽可以让暗处同伴获得目标，黑暗不应被描述为绝对安全。 |
| 宠物 | `UnitPet.findCel:375–410` 有自身范围、伤害价值及专用视线筛选；`goto:421` 另查 Tile.visi。 | 首轮别把宠物行为变化解释为统一新照度结果。 |

源码内 `look/listen/findCel` 的 override 搜索覆盖 Unit 文件族；上表只是已追踪的重要分支，不宣称全部 Boss 技能和控制状态已穷尽。

### 5. 命中、伤害、玩家所见与夜视相关效果

**没有发现“站在灯下伤害更高/暗处直接加闪避”的普通命中公式。** `Unit.udarBullet:4067–4072` 用子弹 accuracy、miss、目标 dexter/dexterPlus/dodge；`Bullet.accuracy:311–321` 主要用 precision 与距离。`UnitPlayer.actions:1181–1199` 根据移动、腾空、站稳、背向等改精度。`Sats.getPrec:323–357` 用武器精度、技能、距离、敌方闪避和枪口误差，也没有局部灯光项。

潜行暴击由 `Unit.damage:3652–3664` 检查目标的 `celUnit != bullet.owner` 后按 `critInvis` 概率额外翻倍；它不读照度。黑暗若影响目标发现，会间接改变潜行暴击机会，不应另行假定黑暗必定暴击。

原版确实存在探索可见度的战斗/能力关联：

- `Unit.getTileVisi:4527–4529` 返回目标中心 `Tile.visi>0.3`。
- `Sats.getUnits:464–475` 排除 invis；远程还要求玩家 `look>0` 且目标 `getTileVisi()`，近战走单独固定距离分支。
- `UnitPlayer.checkPort:1690–1707` 非天空传送目的地要求 `Tile.visi≥0.8`；天角兽传送在 `1668–1674` 有同门槛。
- `Unit.makeNoise:3253–3261` 目标在未见区时可发噪声提示粒子。

原版明确的侦测/夜视相关效果是 `potion_infra`，`AllData:6170–6173`：基础 30 秒、`infravis=1`、`visiTrap×10`。它不只是照亮地图：

1. `Grafon.warShadow:357–368` 改探索遮罩的颜色变换与 multiply 混合；不是新建照度网格。
2. `UnitZebra.control:102–110` 把 shine 提到 100，继而改变其 invis 与动画显示。
3. `UnitAlicorn.animate:343` 在 infravis 存在时显形；其 `control:554–562` 还令 dexter=1，原无侦测时为 `2-curA/100`。
4. 天角兽显形不自动清除所有 invis/isVis 标志；SATS 仍有独立 invis 门槛。普通天角兽已有共享知识实测支持“看见但标志仍隐形”，本轮未重跑。

未在本次限定消费者搜索中找到独立原生“装备灯具”属性；不能把搜不到此字段泛化为全资源无相关美术/道具。应由物品与光源调查进一步核对。`blindness` 效果在 `AllData:5927–5929` 是精度乘 0.4，不是动态暗区或通用关闭 AI 视觉；不要复用名称就当作完整黑暗状态。

## 已确认：公开接口与时序边界

### 6. 不把方法重写当作插件能力

`Unit:21`、`UnitPlayer:16`、`UnitRaider:10`、`Location:18` 均为普通 `public class`，不是 `dynamic` 类。`look/findCel/control/actions` 是类方法，不是可替换的 Function 槽。非 final 不意味着可给已经存在的宿主实例重新赋方法；单独编译一个子类也不会改变现有对象的类型。`aiState/aiSpok` 为 `Unit:356/360` internal，`celUnit2` 为 `UnitRaider:95` internal；外部动态访问不会使这些字段变成公开。

可直接读写的相关字段：`Unit.visibility/stealthMult/detecting/demask/noise/vision/ear/vAngle/vKonus`（`:460–492`）、`celX/celY/celUnit/priorUnit`（`:364–378`）、`childObjs:Array`（`:344`）；`Location.visMult/darkness`（`:193–197`）；`Pers.visiMult/infravis`（`:305/393`）。可调用 `look/listen/makeNoise/setCel`。字段可写只证明访问能力，不证明下一次原生消费前不会被重算。

### 7. 单纯每帧写玩家 visibility 会被覆盖

`Location.step:3352` 先执行整个 `gg.step()`，再于 `3363–3378` 遍历原生 `Pt` 对象链。`Unit.step:1807–1827` 先 forces/control，再移动，后 actions。`UnitPlayer.actions:1093–1127` 每步重设 visibility 为 2000/1500/藏身折半。

因此在常规模组 ENTER_FRAME 尾部乘玩家 visibility，下一世界步可能先被玩家 actions 还原，敌人实际观察时看不到修正。`Location.unitCoord.step` 在 `3386–3388`，同样已晚于对象链执行；不能以其存在证明能插入当前步发现之前。该字段还应进一步确认宿主来源，不能自动当作所有原版版本的稳定插件接口。

`vision` 也会由各敌人控制重写。掠夺者本次读到的寻敌在 `794`、重写 vision 在 `999`，其时序有不同于玩家的可能性，但按每类逐帧实证前不列为通用方案。

### 8. 候选：玩家 childObjs 的步进适配器

以下为**源码推导的待验证方案，不是本轮实现或实测**：

`Unit.childObjs` 是公开 Array。`Unit.step:1846–1856` 在 actions、动画后对其中每个元素调用 `step()`。玩家走完整个这段以后，`Location.step` 才开始其他对象。故若能安全注册自有子对象，其 `step` 可在玩家原版 visibility 重算后、敌人寻敌前应用当前玩家照度系数，保留原版听觉与 demask。

必要生命周期已经逐条回读：

| 原版触点 | 行号 | 候选适配器必须处理 |
|---|---|---|
| `UnitPlayer.attach` 重建数组 | `UnitPlayer:401、433` | 不能只安装一次；新玩家/attach 后核对数组身份并重新注册。 |
| 初始武器、拳击 | `UnitPlayer:433` | 保留 `[0]` 与 `[1]`。 |
| 武器更换 | `UnitPlayer:3683、3688` | 原版覆盖 `[0]`；不要占用这个槽位。 |
| 初始宠物、召唤/召回 | `UnitPlayer:479、3922、3937、3958`，`UnitPet:502` | 原版覆盖/清空 `[2]`；不要占用。 |
| 子对象显示挂接 | `Unit:2904–2912` | 读取每项 `.vis`，非空则调用 `addVisual()`；纯适配器可显式提供 `vis=null`。 |
| 子对象显示移除 | `Unit:2924–2932` | 不论 vis 是否为空都会调用 `remVisual()`，必须有安全实现。 |
| 子对象步进失败 | `Unit:1850–1856` | catch 中再调用 `.err()`，必须存在且不得把错误吞成静默成功。 |
| 燃烧分解 | `Unit.initBurn:4475–4478` | 先 remVisual，再 `childObjs=[]`；不要往正在终结的旧玩家持续重挂。 |
| 单位禁用/出场 | `Unit:1766–1768、1770–1788` | step 早退，不会进入适配器；停用时不能用旧照度外推运行。 |

注册时不覆盖固定下标，可研究唯一自有键或安全追加并保留对象引用；原版使用 `for in`，会遍历可枚举项，但键冲突、顺序及同场其他扩展仍需实测。完整数组相关搜索未见其他原版玩家重建点；这不包括未知部署差异或其他模组的写入。

该时点适合“玩家被敌人发现”的最小闭环。玩家武器/宠物本身也是 childObjs，**不能保证任意追加项在武器发射之前运行**；若以后用同一入口处理玩家射击精度、闪光事件、友方目标照度，要另查执行顺序。不要把这条候选扩写成全战斗无补丁钩子。

## 观察到

本轮观察限于本地参考代码与可读共享知识。共享潜行文档记录了 2026-10-14 正式宿主关键类对照；本文没有重新证明今日宿主、所有模组组合或实际玩家参数与之相同。没有采集新的游戏日志、帧轨迹或画面。

## 推测：适合当前用户方向的玩法

- 暗区主要改变被发现的距离和速度；脚步、枪声、近距特殊感知、警戒记忆继续危险。玩家点灯换取看清路线/威胁，却提高被发现机会，形成战术与探索共用的取舍。
- 首轮不必加“黑暗直接减伤/加伤”；画面信息、发现距离、已有目标的续追、枪口暴露和潜行暴击间接效果已经足以构成玩法。
- 敌人保留差异：普通枪手怕失去视觉，地狱犬近距仍能找人，部分炮塔/天角兽共享需要特殊说明，避免所有敌人关灯即失能。
- 侦测药剂应显式兼容既有显形和闪避效果。新灯具若只是照明，不宜直接套用 infravis，否则意外赠送反隐能力。
- 保存独立的局部照度值，供画面、玩家暴露与未来灯具玩法共同读取；不要污染原版探索 `Tile.visi`。场景灯的开关/损坏/修复由光源与交互专题接续。

## 尚未验证：最小实验与验收

1. **先证明接入时序。** 在隔离测试中给玩家 childObjs 放无视觉适配器，只记录当前帧、玩家位置、visibility原值/改后值、噪声与敌人的自然发现结果；开关后确认改值确实在原生玩家 actions 后、敌人寻敌前被消费。不能以“字段写入成功”代替行为证据。
2. **固定场景 A/B。** 同一普通掠夺者、同位置/朝向/技能/姿态/距离，明暗切换只改玩家照度；对比原生 obs 轨迹、首次获得 celUnit 的时刻。测试距离应同时落入 R 内、R 外、4R 外，避免恒定返回4误判无效。
3. **听觉保持。** 固定同一次脚步/枪声噪声与距离，明暗的 `listen` 输入和返回一致。自然 obs 仍可能与视觉混合，需同时记录两个通道；不能只比较最终共享条。
4. **进入暗处与已经被发现。** 证明暗处首次发现变慢，同时已有目标仍按原版记忆追击；记录照度切换不擅自清理 celUnit/priorUnit/警报或房间 detecting。
5. **生命周期。** 切武器、召唤/召回宠物、换房、读档/玩家替换、死亡/分解、禁用、暂停后恢复。适配器不重复挂接，不替换固定槽，不多步进武器/宠物，无悬空旧玩家引用。
6. **对照例外。** 地狱犬400内、普通/特殊炮塔、天角兽共享、隐形药剂、侦测药剂及藏身。预期不一致必须可解释，不以统一成功率作为通过标准。
7. **玩家可操作性。** 独立照度启用前后，原版 Tile.visi、传送门槛、SATS列表、噪声提示不应因借用存储而发生未设计改变；新界面可解释“看不清”与“未被敌人发现”的差别。

若 childObjs 候选失败，应先报告失败的具体生命周期或时序，再比较独立控制器/明确宿主扩展等后续路线；本次不授权或执行宿主方法替换。
