---
domain: weapons-projectiles
type: discoveries
game-version:
  - "1.02"
confidence: medium
verified: true
discovered-by: LightAndDarkness
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.loc::Location.addObj/remObj/step; fe::Pt.addVisual; fe.weapon::Bullet.step/run/popadalo/explVis; fe.graph::Emitter.cast/Part.initBlit; fe::MainMenu.mainStep; fe.unit::Unit.step"
    summary: "沿对象链插入、显示节点加入、帧推进、碰撞和移除完整回读，核对公开字段及同帧短命对象边界。"
  - kind: mod-source-review
    symbol: "lad::LadRuntime.simulationStep/onFrame; lad::LadLightField.traceRay/render"
    summary: "审阅玩家适配器、帧末绘制和照度场，提出不改宿主的接入及遮挡约束。"
  - kind: isolated-air-runtime
    path: "tests/evidence/2026-10-15/projectiles-v0.3/remains-lad-projectile-20261015221738467/projectile-report.json"
    summary: "优化候选3BA6A9C9的131项通过：68视觉、真实ADDED同帧移除、Part/blit、原生开枪伤害、遮光、暂停与重载；独立冷启动另4项通过。"
date-updated: 2026-10-15
---

# 短时弹丸照明：接入点与生命周期边界

本文调查原版 1.02 参考源码、LightAndDarkness 源码及公共知识；调查不修改宿主或其他模组。证据路径的 `S/` 指 `game-reference/decompiled/1.02/src102/scripts/`。后续隔离实测已验证关键接入和生命周期，具体边界与最终部署以 tests/projectile-verification-2026-10-15.md 为准。

运行验证补充：通用清单为每个模组建立兄弟 ApplicationDomain，外部探针直接 getDefinitionByName("lad.LadProjectiles") 会 #1065。测试通过真实 runtime.projectiles.constructor 和 runtime.field.constructor 获得生产类，只把真实原生 Bullet/Part 输入这些类，再检查灯光输出；没有复制分类器或在生产中嵌测试钩子。原版 saveKol=10，隔离保存使用有效槽7，不能凭空使用槽17。

## 已确认：显示加入事件可以覆盖同帧短命可见弹

`Location.addObj`（`S/fe/loc/Location.as:2271`）顺序为：检查 `in_chain` → 接入双向链 → `lastObj=param1` → `in_chain=true` → 活跃场景调用 `param1.addVisual()`。`Pt.addVisual`（`S/fe/Pt.as:36`）把 `vis` 加入 `World.w.grafon.visObjs[sloy]`。这些图层位于 `World.main` 的显示子树中（`World.as:430`、`Grafon.as:193`）。

因此可以在主显示容器捕获 `Event.ADDED`，仅当当前 `loc.lastObj.vis === event.target` 时记录候选对象引用。不要把子 MovieClip 的 ADDED 或模组自身光层的 ADDED 当成射击。事件处理只记录引用，不调用原对象 `step/run/explosion`，不改伤害、坐标或寿命。

`Bullet` 构造函数（`Bullet.as:134`）创建 `vis` 并立即 `loc.addObj(this)`；此时 `Weapon.shoot`（`Weapon.as:1466`）尚未写入 `weap/tipDamage/explRadius/flame/dx/dy`。在 ADDED 回调内按伤害类型分类会误读默认值，正确做法是保存引用、在本帧后部分类和采样。出生位置可先保存，后续参数必须延迟读取。

`Location.remObj`（`:2295`）会清掉 `in_chain/nobj/pobj` 并移除 `vis`，不会抹掉 `X/Y/begx/begy/tipDamage/isExpl/babah`。因此已经捕获的强引用即使在同帧被移除，仍可为短暂尾迹和冲击提供末位置。只在帧末扫描现存链则会漏掉这类对象。

`Grafon.drawAllObjs`（`Grafon.as:702`）重建图层并再次 `addVisual()`。捕获器必须按对象身份去重，重挂同一对象不应重放枪口或爆炸闪光。场景切换应清空身份集合及短时光，避免上一房间残光。

## 已确认：帧先后与公开状态

原版调用链为：

```text
stage ENTER_FRAME → MainMenu.mainStep（默认优先级 0）
  → World.step → Land.step
    → 当前 Location.step
      → gg.step
        → Unit.forces/control/run/actions/动画
        → for(in childObjs) 调用每个 child.step
      → Location.firstObj 链逐对象 step（包括敌人、子弹和粒子）
      → unitCoord、视野、重建等
    → 前房间 stepInvis（条件成立时）
  → 相机及 GUI
stage ENTER_FRAME → 本模组 onFrame（优先级 -80）
```

对应 `MainMenu.as:85,804`、`World.as:1227,1269`、`Land.as:1567`、`Location.as:3348`、`Unit.as:1761,1846`。玩家 `childObjs` 用 `for(in ...)` 枚举，不应假定某个字符串键总在武器子对象之后；但该阶段确实早于 Location 对象链的整体推进。

建议玩家适配器负责模拟时钟和上一帧短时光老化，帧末处理新事件及最终位置再绘制。这样暂停期间不会按墙钟耗尽光效，也能看到玩家和敌人本帧新弹。新光对已在同帧先运行的 AI 可能晚一次模拟，不能宣称所有敌人零延迟感知。

| 可公开读取 | 含义与用法 |
|---|---|
| `loc, in_chain, X, Y, dx, dy, vis` | 所属场景、入链状态、位置/速度和显示对象；来自 `Pt` |
| `begx,begy,vel,dist,rot,spring` | 发射点、速度、路程、方向及原生伸长方式 |
| `weap,weapId,owner,tipDamage,tipDecal,flame,flare` | 最终弹种/武器线索；ADDED 后再读取 |
| `liv,babah,tilehit,isExpl,explRadius,inWater,inWall` | 生命周期、碰撞与爆炸的公开状态 |
| `Part.vClass,blitData,liv,mliv,otklad,isAlph,isPreAlph` | 视觉族、粒子寿命及延迟出现 |

**不可外读**：`Bullet.vse` 是 protected（`:13`）；`expl_t` 是 internal（`:131`）；`PhisBullet.prilip/dr/isSensor` 等也是 internal。用 `in_chain/liv/babah/isExpl` 推断状态，避免动态访问产生 #1069。不改变 `isExpl`；它是原生防重复爆炸开关，改它会影响伤害。

`Bullet.step`（`:170`）会按 `World.maxdelta` 把高速位移拆成多次 `run`。`popadalo`（`:325`）通常令 `liv<=4`、`babah=true`，命中后保留数帧；只能在状态首次转变时发一次冲击光，不能每帧重放。`liv<=0` 不一定是命中，`popadalo(0)` 也可能来自边界或水中熄灭，应避免把所有消失都变成爆炸。

`SmartBullet` 继承此链，并在基类 step 前导航、加速；`PhisBullet` 自己处理弹跳/引信，仍复用 `Bullet` 的构造加入和爆炸视觉。对弯曲/弹跳弹每帧保存当前位置，不能一直从发射点画一条长直线。

## 已确认：粒子捕获可补齐爆炸，不需要给隐藏冲击弹照明

`Bullet.explBlast/explBullet`（`:797,841`）按单位生成没有 `vis` 的短命辅助 Bullet，生命周期 3 步，用于投递爆压伤害。它们不是实际曳光，必须排除。ADDED 自然不会捕获它们；若增加链扫描补偿，仍需 `vis != null` 等守卫。

反方向也存在：`Unit.explosion`（`Unit.as:3328`）、`Interact`（`Interact.as:1421`）、`UnitDamager`（`UnitDamager.as:345`）可以创建 `new Bullet(...,null,false)` 并直接引爆，父弹既无视觉又不入链。只监控可见 Bullet 会漏掉这些爆炸，须读取实际 `Part` 视觉。

`Emitter.cast` 会先配置完整 `Part`，再 `loc.addObj(part)`（`Emitter.as:170,306,354`）。即使 blit（位图逐帧动画），`Part.initBlit`（`Part.as:80`）也创建一个 `MovieClip vis` 包住 Bitmap；因此同一个 ADDED 捕获口可识别 blit 爆炸，不需要专门逐像素扫描画面。

`Part` 没有公开 emitter ID。识别方式为：普通视觉比 `vClass` 与白名单 `Emitter.arr[id].visClass`；blit 比 `part.blitData` 与 `Grafon.spriteLists[Emitter.arr[id].blit]` 对象身份。`Grafon.spriteLists` 是 public static 缓存（`Grafon.as:25,911`），不要仅按 `MovieClip` 类名识别 blit，也不要读取 internal `blitX/blitFrame`。

资源只能区分视觉族，不能完美还原发射器。`AllData.as:6916–6967` 中：

- `expl/fireexpl/ttexpl` 共用 `sprExpl`；可同属暖色爆炸族，以父弹信息或视觉尺寸辅助细分。
- `plaexpl/ttplaexpl` 共用 `visualPlaExpl`；同属等离子族。
- `iskr/iskr_bul/iskr_wall/burn` 共用 `sprIskr`；每颗火星不应生成独立强光，可聚合成短弱闪或直接交给父弹冲击光。
- `plasma/plasma1` 共用 `flPlasma`；`laser/blump` 共用 `flLaser`；`laser3/plasma2` 共用 `flPlasma2`。
- 普通激光碰撞 Part 寿命 3 步、`moln` 电弧寿命 8 步。`Emitter.cast` 在 `addObj` 前已设置有端点素材的 `vis.len/vis.fl`，可读实际相对终点，但没有射手身份。

每次爆炸可能同时出现父弹 `isExpl`、`expl`、`flare` 和多颗火星。须按空间位置、光效族及同一模拟步合并或选择一个主事件，不能累加为几十倍亮度。后续连爆的 `expl_t` 不可读，每次新的白名单 Part 可作为后续脉冲证据。

`Emitter.cast` 的画面粒子预算（`:171`）会省略 `imp==0` 粒子；大爆炸主体通常 `imp=1`。小型碰撞光不能绝对依赖非重要火星出现；父弹 `babah` 转变可作为补偿。只根据视觉 Part 的环境火花/电弧可以照明，但不能宣称它们必然来自射击。

## 观察到：既有知识需要带着纠正使用

已阅读 `shared-knowledge/rendering/facts/part-lifecycle.md` 的 2026-10-09 纠正：原生 `Part.setNull → Location.remObj → Pt.remVisual` 会摘掉显示对象，不采用“原生粒子死亡必留孤儿”的旧归因。

`shared-knowledge/weapons-projectiles/facts/bullet-explosion-flow.md` 的旧类族表把 `Trasser` 记为弹壳，但本轮 `Trasser.trass` 源码明确用于预测轨迹画线，`Weapon.setTrass` 调用它；它不是实际飞行 Bullet，不能照明。真实弹壳是 `gilza` Part（`AllData.as:6943`），应默认无照明。本轮仅在模组文档记下证据，未修改公共文件。

## 推测与实现建议：遮挡和上限必须先于强光

当前 `LadLightField.traceRay` 从光源所在格跨到下一格后才检查不透明度，不检查源格。`Bullet.run` 则先推进 X/Y 再判断是否进入墙体。因此把最终命中点直接作为光心，可能从墙内部漏光到另一侧。

建议沿上一帧自由点到新位置做段遮挡检测，尾迹只布点到首次遮挡前 1–3 像素；命中光也放在该自由侧。若只剩出生点和终点，用 `begx/begy` 做同样裁剪。真正爆炸会先 `explDestroy` 再 `explVis`，可根据爆炸后的当前地形重新判断；若源点仍在不透明格中，保守跳过或回退光心，不因单个源格漏判照亮墙后。部分玻璃/薄障碍沿用光场 `opac`，不要把所有 `phis` 当不透明墙。

建议将短时灯追加到既有 `lights()` 数组，共享画面和 `field.sample`；独立透明叠加的光晕只能美化弹丸，不能照亮环境或可靠参与视觉感知。长射线用少量沿线节点，短弹只保留头部和最近一段尾迹；不要每步累积永久节点。

可作为首轮调参起点的上限：最多记录 96 个活动候选、每步最多 24–32 个短时光节点、单束最多 4–6 节点、只处理视口加最大光半径范围。密集霰弹按光源格聚合；普通子弹优先保留近屏光，重要爆炸优先于远处小火星。最终数值由实际混合场景耗时决定，本文没有替实现声称性能达标。

身份字典应弱引用或在对象结束且尾迹消失后释放；场景切换、关模组、载档清空临时状态，绝不把子弹引用/光龄存进槽文件。可一次或低频有上限地扫链补偿启用时已经存在的弹丸，但热路径以 ADDED 捕获为主。

## 尚未验证：候选需要的针对性断言

1. 构造器 ADDED 捕获到默认字段后，由真实 Weapon 写入不同 `tipDamage`，最后分类正确；玩家和敌人各一例。
2. 同帧出生、前进并 `remObj` 的高速弹仍形成短暂路径光，且重复重挂不二次生成枪口光。
3. 手雷/火箭真实爆炸、无 vis 且不入链的直接爆炸均亮；隐藏 blast bullets 不增加光数。
4. 一个爆炸同时产生父弹、expl、flare、多火星时总光强有上限；连续霰弹/火焰和多次连爆不积累失控。
5. 固体墙命中点在墙内时墙后不亮；开门/炸墙后重新照亮；水中熄灭不产生无根据的大爆炸。
6. 缓慢弹、导航弹、物理弹跳、长激光分别取真实最新位置，不在发射点与弹丸之间留下永久直线。
7. 主动暂停、对话暂停、catPause 不按实际等待时间老化；恢复后继续衰减，换场景和关模组立即清空。
8. 在当前 ContinuousScene 大场景开发线验证视口裁剪、初次预绘制和 HUD 缓存保持；记录新增渲染时间及最大节点数。
9. 同一照度场中灯具/随身灯/暗区与弹光共存；验证感知采样边界，避免把原生探索黑幕误作照明失败。
10. 不改变原弹生命周期、伤害、穿透、爆炸次数、物品/存档；最终测试必须加载待部署的正式候选字节。

本调查没有实测当前宿主补丁对相关方法的改写，也没有操作用户游戏、存档或其他模组。最终运行证据、视觉观感及发布结论由主实现阶段补齐。
