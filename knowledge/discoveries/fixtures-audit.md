---
domain: world-objects
type: discoveries
game-version:
  - "1.02"
confidence: high
verified: false
discovered-by: LightAndDarkness
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.graph.BackObj; fe.graph.Grafon.drawLoc; fe.loc.Location.lightAll/allon/alloff/createObj/saveObjs; fe.loc.Box; fe.serv.Interact"
    summary: "沿场景装饰构造、背景合成、物体命中、维修互动和存档调用链核对；未启动游戏。"
  - kind: local-resource-inspection
    summary: "只读解压安装目录 texture1.swf，解析 SymbolClass/ExportAssets 与 DefineSprite 标签，核对光晕导出符号和时间轴帧数。"
date-updated: 2026-10-15
---

# 灯具、携带光源与破坏修复接入调查

这是 LightAndDarkness 的设计输入，不是已实现功能，也不是运行实测报告。`verified: false` 表示没有在游戏中验证视觉、战斗和保存恢复。源码结论与本地资源标签结果在各处分别说明。

源码根目录统一为 `D:/Program Files/Steam/steamapps/common/Remains/game-reference/decompiled/1.02/src102/scripts/`。以下 `fe/...:行` 均相对此目录。资源目录为游戏根。未进入其他模组。

## 已确认：必须区分的五类东西

| 类型 | 原版实际作用 | 是否天然可打坏/修理 |
|---|---|---|
| `BackObj` 灯具（light1 等） | 灯壳 `_t`、擦除图 `_e`、光晕 `_l`；进入房间时合成到背景位图 | 否；没有 HP、碰撞、互动、存档码 |
| `Box.light` | 地图 XML 带 `light` 的物体，在进房时提供额外揭开黑幕的采样点 | 不是灯具类别；门、冰箱、沙发、训练设施都可能带此标志 |
| `Location.darkness/color/lightOn` | 房间整体亮度、调色、装饰灯初始帧与整房通断电表现 | 全房状态；`allon` 还带开锁/激活互动副作用 |
| 发光角色、枪口火花、火焰 | 动态显示树中的特效，可能视觉上发亮 | 大多数不调用 `Location.lighting`，不等于提供逻辑照明 |
| `lamp` 物品、`PipBuck.light`、`infravis` | 分别是坏台灯杂物、简化界面模式、红外视觉效果 | 都不是现成的可装备手电系统 |

## 已确认：灯具目录与资源接口

原版明确列为照明的背景灯具共 10 种，定义在 `fe/AllData.as:6736–6746`。表中尺寸是 XML 格数，不是最终像素碰撞框；`BackObj.scX/scY` 默认是缩放倍数，**不是** `Box.scX/scY` 的实体宽高。

| id | 含义 | 尺寸（格） | 层 `s` | XML 开/关帧 | 本地 `_t` / `_l` 帧数 |
|---|---|---:|---:|---:|---:|
| `light1` | 圆灯 | 1×1 | 1 | 1 / 2 | 2 / 2 |
| `stlight1` | 马厩圆灯 | 1×1 | 1 | 1 / 2 | 3 / 3 |
| `light2` | 矩形灯罩 | 2×1 | 1 | 1 / 3 | 3 / 3 |
| `light3` | 圆角灯罩 | 2×1 | 1 | 1 / 2 | 2 / 2 |
| `stlight3` | 马厩圆角灯罩 | 2×1 | 1 | 1 / 3 | 3 / 3 |
| `light4` | 吊顶灯 | 2×1 | 3 | 1 / 2 | 2 / 2 |
| `stlight4` | 马厩吊顶灯 | 2×1 | 3 | 1 / 3 | 3 / 3 |
| `light5` | 红指示灯 | 1×1 | 1 | 未定义 | 2 / 3 |
| `light6` | 基地灯 | 1×1 | 1 | 1 / 2 | 2 / 3 |
| `light7` | 英克雷灯 | 1×1 | 1 | 1 / 2 | 2 / 3 |

另有：

- `bar`：酒吧招牌，XML 是开 1 / 关 2（`AllData.as:6864`），但实际 `back_bar_t` 和 `back_bar_l` 都只有 **1 帧**。因此不能断言原版 `onoff(-1)` 能将其熄灭，须视觉验证或另做关灯资源。
- `exit_light`：出口光，10×7 格、`s=2`、`nope=1`（`:6863`），是特殊引导光，应默认排除破坏。
- `lwhite/lred/lorange/lyellow/lacid/lgreen/lcyan/lblue/lpurple/lpink`：同用 `tid=lcolor` 的第 1–10 帧、`alpha=0.5`（`:6840–6849`），属于布景彩光，不代表可维修灯具。
- `shadow`：阴影装饰、`alpha=0.9`（`:6839`），虽然资源名有 `_l`，仍不能解释成正光源。
- `generator` 是背景装饰（`:6763`）；`generat` 才是 Box 实体（`:5035`）。二者不能按名称混为一体。

实际 `texture1.swf` 共导出 14 个 `back_*_l`：上述 10 种灯具，加 `bar`、`exit_light`、`lcolor`、`shadow`。本次只读检查得到 `_l` 帧数分别为：bar=1、exit_light=1、lcolor=10、light1=2、light2=3、light3=2、light4=2、light5=3、light6=3、light7=3、shadow=1、stlight1=3、stlight3=3、stlight4=3。

资源指纹：`texture1.swf` SHA-256 = `6646CCF91F912A7384875A5ED40A33C907041645F558A79277FC5F2DC8164678`，长度 8,367,667 字节。读取 CWS 解压后的 SymbolClass/ExportAssets 与 DefineSprite；没有修改、运行或渲染该文件。帧数只能证明资源结构，不能证明某帧有光、全黑或破损。

`Grafon.texUrl[1] = "texture1.swf"`、`numbBack=1`（`fe/graph/Grafon.as:27,33`）；`BackObj` 通过 `getObj("back_" + tid或id + "_t/_e/_l", numbBack)` 取得三个资源（`BackObj.as:86–88`）。`Grafon.getObj` 是公开的资源获取入口（`Grafon.as:305–307`）。

## 已确认：背景灯如何生成、开关与烘焙

`Location` 从 `nroom.back` 逐个构造 `BackObj`，坐标为 XML x/y × Tile 大小，存入公开 `loc.backobjs`（`Location.as:702–704`）。`BackObj` 是独立类，并不继承 `Obj`（`BackObj.as:8`），公开状态仅包括 id、坐标、缩放、三个显示资源、帧、层、混合和透明度。

初始帧优先序是：资源 XML 固定 `fr` → 房间 `lightOn>0` 的 `lon` → `lightOn<0` 的 `loff` → 从灯壳总帧数随机选一帧（`BackObj.as:89–109`）。随后地图实例 XML 的尺寸、alpha、fr、lon 可覆盖。注意源码的实例 `lon` 判断是 `>1` 选开、`<1` 选关（`:144–150`），不能按直觉当成任意 `lon=1` 强制开。

`BackObj.onoff(正数/负数)` 仅选择 `frameOn/frameOff`，并对 `vis/erase/light` 执行 `gotoAndStop`（`:177–202`）。它不改碰撞、不改 Tile 逻辑照度、不写存档、不主动重绘背景。没有 `frameOff` 的 `light5` 不会靠普通 `onoff(-1)` 自动关掉。

`Grafon.drawLoc` 会清空前景、背景、第二背景、水和 SATS 位图，随后按层遍历 `backobjs`：

1. 灯壳画进 `backBmp` 或 `backBmp2`；有 `light` 资源时灯壳采用不同亮度系数（`:557–599`）。
2. `_e` 进 `satsBmp` 擦除通道（`:601–604`）。
3. `_l` 进 `colorBmp`（`:605–607`）。
4. `colorBmp` 最终以 `hardlight` 合成进 `backBmp`，再加入阴影（`:643–644`）。

因此，运行中只改灯的 MovieClip 帧、`visible` 或移除本体显示引用，不能自动擦掉已经画入背景的旧灯晕。最直接的原生刷新路径是 `World.redrawLoc()`，它调用 `grafon.drawLoc(loc)`、重置相机房间并刷新 HUD（`World.as:1102–1108`）。`drawLoc` 末尾还调用 `drawAllObjs`（`Grafon.as:681`），全房位图默认规模为 1920×1000（`:135–137`）。这适合低频开关/破坏后的重绘候选，不适合每帧移动手电；实际耗时尚未测量。

已有共享知识关于 `setLight→drawAllObjs` 的历史说法已经纠正：`setLight()` 仅根据 `space[x][y].visi` 重写小黑幕位图（`:685–700`），不会重绘背景灯，也不会重建物体层。参见 `shared-knowledge/knowledge-validation/conflicts/grafon-drawallobjs-callchain.md` 和 `rendering/discoveries/render-resource-lifecycle-source-audit-2026-09-09.md`。本次源码核对同向。

## 已确认：整房通断电与逻辑揭幕不是单灯照明

`Location.allon()`（`:2920–2950`）会将 color 改 yellow、darkness 改 -20、lightOn 改 1、更新玩家和所有对象调色、打开 `lockTip==4` 的物体并激活所有互动，最后对所有 BackObj 开灯并全房重绘。

`Location.alloff()`（`:2952–2973`）把 color 改 black、darkness 改 20、lightOn 改 -1、更新调色、所有 BackObj 关灯并重绘。**不能直接拿这两个方法当普通灯开关**，否则会把关灯动作扩成剧情式整房改造，开灯时还可能解除任务锁。

`Box.light` 只由地图实例 XML `@light` 是否存在设为 true（`Box.as:377–379`），即使字面是 `light="0"` 也满足存在判断。`Location.lightAll()` 遍历 `loc.objs`，每个 true 物体按其中心及左右 10 像素调用三次 `lighting`（`Location.as:3094–3105`）。它从 `Land.ativateLoc()` 进房末尾调用（`Land.as:1273`）。

这组标志用于让某些重要物体附近先可见：源码房间实例包括冰箱、门、橱柜、沙发、训练设施、地图、机关、奖励箱等（例如 `RoomsCamp.as:268–296`、`RoomsSerial2.as:2141`、`RoomsProb.as:142`）。它不是背景 10 类灯的自动逻辑映射，也不是每帧汇总的真实光源表。

关掉 `Box.light` 只会阻止以后 `lightAll()` 从它揭幕，不能自动收回已揭开的 Tile；`lighting` 在 `retDark` 分支才会逐渐压低目标可见度（`Location.as:3235–3247`）。新模组需要自己的可撤销光源贡献，而不能把旧探索可见度当累加后可逐项减去的照度。

## 已确认：破坏并不是给背景灯补一个 hp 字段

`BackObj` 没有 HP、damage/die、互动或碰撞包围盒，子弹逻辑也不遍历 `backobjs`。要让它被子弹/近战/爆炸打坏，需要新增玩法实体或由模组处理专门的命中检测。

原生 `Box` 提供 HP、thre、mat、dead、壁面/门/物理信息（`Box.as:48–72`），`damage` 是扣门槛后减 HP、归零调用 die（`:776–786`）。但 Box 也不是“放入数组便能被所有攻击命中”的万能靶：

- 玩家拆除入口是 `Bullet` 检查 `loc.celObj is Box && crack && owner.player`，再调用 `udarBullet(bullet,1)`（`Bullet.as:564–583`）；Box 还要求 `bulPlayer`（`Box.as:745–755`）。
- 敌方弹击玩家念力举起的 Box 走 `udarBullet(...,0)` 和 `bulChance`（`Bullet.as:585–595`；`Box.as:757` 起）。
- 门/墙依靠 Tile 参与物理和破坏。爆炸 `explBlast` 在 `loc.units` 造冲击弹（`Bullet.as:797–839`），并不把所有背景/Box 装饰视为对象；瓦片破坏另走 `explDestroy`。
- `actdam` 对象可绑定 `VirtualUnit`（`Box.as:410–419,1227` 起）；原版 `knop2` 就是“可被子弹触发的按钮”（`AllData.as:4908`）。这是进一步研究的命中接入点，不是已验证的可修灯方案。
- `Box.die` 不总是删除对象：门改变 Tile 并关互动；绑定单位的 Box 隐身并禁用单位；其余 Box 主要关闭 `bulPlayer`、降低 `bulChance`（`:789–887`）。不存在统一的 `reviveLamp()`。

因此推荐首轮验证使用灯具白名单、独立 `LampState` 和小型命中代理，先证明枪弹与爆炸能稳定改变同一盏灯的状态，再决定是否接原生 VirtualUnit。碰撞轮廓应以灯壳资源 bounds 配合坐标/缩放生成，而不是用大范围光晕；必须避免给背景灯添加会挡玩家行走的实体墙。

## 已确认：原版维修有可复用交互，但没有逐灯修理

原版提供一个整房发电机修理案例：

- 地图 `RoomsProb.as:2641` 的 `obj id="generat" ... fun="generator"`。
- `Box.initFun("generator")` 创建/设置 `Interact`，`action=100`、`active=true`、`knop=1`、`t_action=45`、`needSkill="repair"`、`needSkillLvl=4`、`userAction="repair"`，回调 `actFun=funGenerator`（`Box.as:1277–1295`）。
- 玩家交互时从 `pers.getSkillLevel(needSkill)` 设置 unlock（`UnitPlayer.as:1946–1948`）；`Interact.act` 检查技能门槛（`Interact.as:907–909`）。
- `funGenerator` 停用互动并运行 `fixGenerator`（`Box.as:1298–1302`）。脚本调用 `locon`（`GameData.as:1176–1183`）；`Script` 将它转到 `Location.allon`（`Script.as:402`）。

已有“需维修按钮” `knop3` 用 `locktip=5`（`AllData.as:4909`），`Pers.getLockTip(4/5)` 返回 repair（`Pers.as:2332–2338`）。因此维修既有技能门槛和原生进度互动可以复用，不必凭空加一种技能。

材料消费接口是 `Interact.cons:String`（`:74`）：`actOsn()` 检查该物品库存，成功减一个，再调用 `actFun`（`:1265–1283`）。其原生形态是**单一种材料一个单位**，多种/不同数量配方需在自有逻辑中明确检查和原子扣除，不能假设已有通用配方事务。原版发电机上述初始化没有设置 `cons`，因此该例不能证明修理必需材料。

设计上应分开“暂时关灯”“灯泡损坏”“线路/电源失效”；否则每次战斗打灭都强迫玩家维修。维修完成后更新自有状态、灯壳帧和光源贡献，避免调用带剧情副作用的 allon。

## 已确认：装备光源与可复用物品

- `lamp`：`AllData.as:4335` 定义 `tip='stuff'`、重量 5、价格 25、出售 5；`text_en.xml:3125–3127` 将其明确描述为已经损坏、无法工作的旧台灯。`Location.createSur` 在 biom=2 时把它作为桌面杂物生成（`Location.as:1299–1325`），`GameData.as:2051` 有收集十个的任务。它适合作为修灯材料/翻新来源的设计候选，但不能直接当现成装备，并要避免消耗导致既有收集任务受影响。
- `lighter`：是 `tip=compw` 武器制造组件（`AllData.as:4298`），不是随身照明开关。
- `PipBuck.light`：构造时 true，隐藏界面 skin/fon（`PipBuck.as:85–98`）；`toNormalMode()` 设置 false 并恢复完整界面（`:161–178`）。这是简化模式命名，不能作为哔哔小马灯状态读取/改写。
- `potion_infra`：效果设置 `infravis=1`（`AllData.as:6170–6171`）。`Grafon.warShadow` 据此把 visLight 调成红色偏移与 multiply（`Grafon.as:359–367`）。`infravis` 还用于识破部分隐身单位（例如 `UnitAlicorn.as:343,555`、`UnitZebra.as:102`）；新模组不能为了临时开灯而修改它。
- 对 `fe` 源码中 `lighting(...)` 的调用核对，除 Location 自身之外出现 Land 的进房/出生揭幕以及 `UnitSpectre.command("show")`（`UnitSpectre.as:65–70`）。没有找到玩家手持或头戴灯的现成调用路径。
- 发光僵尸是 `new visZombieLight` 添加到单位 visual，使用 `screen` 混合（`UnitZombie.as:110–116`），没有对应 `lighting` 调用；其死亡隐藏该视觉（`:407–409`）。枪弹 flare 主要调用 `Emitter.emit`（`Bullet.as:361–382`），也没有实际改场景照度的调用。因此“发光怪、枪口火、火焰能照亮周围并暴露角色”属于新功能。

装备设计可以先选独立挂灯状态（开关、亮度/半径、是否消耗电），以玩家身上小图标和光圈验证；原生护甲/武器槽、库存保存及说明页联动另做专项接入，不应在本报告里假定已经具备头部附件槽。

## 已确认：跨房和存档边界

1. `backobjs` 不加入 `loc.saves`，`BackObj` 没有 code 和 save，地图 `<back>` 构造也不读取对应存档。因此每灯 HP/开关/修理状态必须由模组保存。
2. 原生对象带 `xml.@code` 才加入 `loc.saves`，且 `obj.code=xml.@code`（`Location.as:2057–2060`）；`createObj` 根据此 code 从 `World.w.game.objs` 找旧状态（`:1997–1999`）。
3. `Location.saveObjs` 逐个调用 `saves` 中对象的 save，按 code 存储（`:3552–3561`）；`Land.saveObjs` 遍历已存在的各房（`Land.as:1200–1208`）；`Game.save` 复制到存档（`Game.as:101–111`）。
4. `Box.save` 只写 `dead` 以及 `Interact.save` 的内容（`Box.as:432–443`），并不保存当前 HP、light 或自定义灯状态。`Interact.save` 写 lock、lockLevel、mine、loot、open、expl、dif、sign（`Interact.as:599–608`）。不能给 Box 附状态后就期待原生 save 自动保存。
5. `Game.objs` 是 internal（`Game.as:51`），外载模组不能当公开 API 使用。直接复用原生保存表需要另证接入，独立 sidecar 存储也必须与存档身份、载入/死亡回档同步。
6. 同一 Land 内房间对象通常继续存在，来回房间可以保有 BackObj 的内存帧；但离开场景后的重建、读档和新周目不等于跨房缓存。`Land.locN` 是激活计数（`Land.as:1261`），不可当永久房间 ID。

可用房间定位字段有 `Location.landX/landY/landZ/landProb`（`:37–43`），加地图/关卡身份、原始模板和镜像信息做稳定 key 的候选。灯实例还需区分同位置同类型重叠、缩放以及随机镜像。不要只用当前 `backobjs` 下标：运行时还可能附加血迹等 BackObj（`Location.as:1237`），随机房间重建也不能默认同序。固定剧情房间和随机关卡应分别设计持久化策略。

## 观察到与推测

**观察到（静态检查）：** 场景灯与可见度系统原生就已分离；房间通电脚本把两者间接协调，但没有通用逐灯模型。实际本地纹理的部分帧数与 XML 开关假设不完全匹配。背景彩光有独立色块资源，直接按 `_l` 统一算“可破坏正光源”会把阴影也计入。

**推测/建议（未实现）：** 用 `LampState`（健康/开关/供电）→ 自有亮度场 → 玩家/敌人暴露计算；另由 `LampVisual` 处理原版灯壳与烘焙清除。首版仅白名单 10 类灯中经帧图验证可用的类别，排除出口光、剧情招牌和纯色环境光。第一次进房抽取灯资料、按需低频重绘，移动灯用自有动态层。这样的拆分能让“打灯”和“修灯”成为同一状态变化，减少视觉与战斗分别失灵的风险。

## 尚未验证与调查限制

- 没有启动游戏、没有打补丁、没有部署。灯开/关/破损各帧的实际像素、资源 bounds、光晕半径、原版 off 帧是否真的全暗均待渲染检查。
- `bar` 时间轴仅 1 帧与 XML loff=2 的不匹配，必须核验实际 gotoAndStop 后结果；本报告不将其先判成运行 bug。
- 所有地图灯实例数量未完成统计：一次批量只读计数命令被 PreToolUse 的 read-only-reference 保护规则拒绝，未关闭保护或换工具绕过；已有源码例证和 10 类定义不受影响。`Rooms/` 外置 XML 与编译进主 SWF 的房间类不是自动等价的当前实际加载来源。
- 背景局部修复绘制的可行性、整房重绘耗时、与现存覆盖层的关系需隔离运行验证；本轮未访问其他模组。
- `VirtualUnit` 命中代理的所有子弹、近战、持续伤害、爆炸及玩家/敌人来源覆盖，尚未做原型。
- 维修时暂停/打断、扣料时点、与原生手动/自动存档及死亡回档同步尚未设计完成。
- 按地图层和剧情类型维护灯具白名单/保护名单需要玩家体验取舍；上述建议不是用户已拍板的规格。
