---
domain: rendering
type: discoveries
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: LightAndDarkness
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.graph::Grafon.drawLoc/setLight/warShadow; fe.loc::Location.lighting/lighting2/lightAll; fe.loc::Tile.updVisi; fe.graph::BackObj.onoff"
  - kind: shared-knowledge-review
    summary: "核对既有 setLight/drawAllObjs 冲突、背景墙合成与公共资源登记，结论以本轮直接读源码为准。"
date-updated: 2026-10-15
---

# 原版光照与黑幕渲染审计

本文服务于 LightAndDarkness 的方案判断；是源码调查，不是当前正式宿主运行验证。源码根记作 `S = game-reference/decompiled/1.02/src102/scripts/`，下列路径相对此根，行号对应本轮读取的文件。没有改写游戏、公共资料或其他模组。

## 边界与最关键结论

**已确认（1.02 参考源码）**：原版所谓“光照”并非一个统一的光源系统，而是三套机制并存：背景装饰的静态灯光贴图、玩家探索/视野黑幕、特殊对象提前揭示地图。另有发光粒子与单位局部光晕，仅改变视觉。没有查到专门的 `Light` 类。

**观察到（公共记录）**：当前正式宿主已有 ContinuousScene 对 Grafon 的扩展，包含 `sceneTrack/sceneSave/sceneSurfaces`，并有 RV/WB 显示兼容版本。公共 registry 的旧宿主指纹不能代表 2026-10-15 当前文件。主调查已核对当前宿主文件指纹，未逐方法重新反编译；本文件不得被解释成“当前正式 Grafon 与参考源码完全相同”。当前大地图的动态尺寸、分块和视野实现需要在正式宿主抽取结果上再次核对。

**推测/设计建议**：新模组宜独立维护“物理照度/当前被照亮程度”，读取原生遮挡和场景灯具，统一供画面与战斗逻辑使用；不要直接把 `Tile.visi` 重定义为灯光亮度。后者还承载探索记忆、地图、交互和技能限制。

**尚未验证**：视觉效果、性能、当前正式宿主函数差异、RV/ContinuousScene/WallBlend 的实际组合、完整资源帧内容。本文不报告运行通过。

## 1. 三条调用链

```text
房间 XML options + BackObj XML
  → Location.darkness / cTransform / lightOn / backobjs
  → Grafon.drawLoc
  → colorBmp 填环境黑色 alpha
  → BackObj.light（MovieClip）画入 colorBmp
  → backBmp.draw(colorBmp, hardlight)
  → frontBmp 的 DropShadowFilter 结果盖到背景

Land.ativateLoc / 玩家移动 / 开门 / 地形破坏
  → Location.lighting(光心x,y,全亮半径,截止半径)
  → 对每格按距离衰减，逐格采样扣除 Tile.opac / opacWater
  → Tile.t_visi → Tile.updVisi → Tile.visi
  → Grafon.lightBmp 中黑像素 alpha = floor((1-visi)*255)
  → visLight 将低分辨率位图放大覆盖世界

Land.ativateLoc → Location.lightAll
  → 遍历 loc.objs 中 light=true 的对象
  → 在对象中部 x-10/x/x+10 各调用一次 lighting
```

证据：`fe/graph/Grafon.as:371,423,427,547,605,620,643,685`；`fe/loc/Land.as:1234,1273`；`fe/loc/Location.as:3094,3108,3394`。

## 2. 背景灯光是烘焙图，不是场景照度场

`BackObj` 保存 `vis/erase/light` 三个 MovieClip；从 `Grafon.numbBack=1` 的资源域按 `back_<tid或id>_t/_e/_l` 加载（`fe/graph/BackObj.as:86–88`）。`getObj` 只是转发资源读取（`Grafon.as:305`）；纹理源清单是 `texture.swf / texture1.swf / sprite.swf / sprite1.swf`（`:27`）。光图的形状、颜色和多帧差异在资源里，AS3 中没有把它变成强度/半径数据。

开灯状态优先序：数据定义固定 `fr` → 房间 `lightOn` 对应 `lon/loff` → 随机取 `vis.totalFrames`；房间 XML 可再覆盖帧/缩放/alpha。`frameOn/frameOff` 来自数据 `lon/loff`。`onoff(±1)` 同步三种剪辑的当前帧，但不自动改任何像素、遮挡或 AI（`BackObj.as:89–174,177–201`）。房间实例 XML 的 `lon` 条件写成 `>1` 取 on、`<1` 取 off；不能想当然把所有地方的 `lon=1` 当成同一种开灯语义。

`Grafon.drawLoc`：

- `D=clamp(170+loc.darkness,0,255)`，整张 `colorBmp` 填黑色、alpha=D（`:427–437`）。这是房间背景亮暗输入，不是计算实体各点的照度。
- 按 BackObj 图层 -2 至 3 遍历。`sloy<=0` 的图形写 `backBmp`；更上面的静态背景写 `backBmp2`，其 RGB 倍率受 darkness 和是否存在 light 资源影响（`:550–598`）。即使是灯具资源，也只是存在 `bo.light` 的判断，当前帧真正有没有发光像素还要看资源。
- `bo.light` 使用相同位置/缩放矩阵和颜色变换写进 `colorBmp`，未读取 Tile.opac，也未射线判断墙体（`:605–607`）。因此这条链本身不会生成基于灯位置的墙后阴影。
- 环境色 `cTransform` 独立作用于前景、水、背景；最后 `backBmp.draw(colorBmp, hardlight)`。该灯光贴图合成没有直接覆盖单位、前景地形和水（`:615–644`）。
- `DropShadowFilter(7,90,0,0.75,16,16,1,3,false,false,true)` 把前景轮廓投到背景（`:159,620`）。它是固定方向的装饰性投影，不是每盏灯各自产生的阴影。
- 透明背景房间会在合成后恢复保存的 alpha；天空/洞口不能靠最终图的 alpha 或一张纯黑背景替换来判断（`:397–400,639–647`）。

因此，关闭某个 BackObj 的亮灯帧后，旧灯光已经烘焙在背景里，单改帧不会让屏幕变暗。全房 `drawLoc/redrawLoc` 可重新烘焙，但它还会重建对象显示层、覆盖房间位图、重新定位相机/刷新 GUI；不适合作为移动灯逐帧更新方案（`Grafon.as:681`；`World.as:1102–1108`）。

## 3. 原生黑幕实际上是探索/视野缓冲

普通房间为 48×25 格、每格 40px；参考 Grafon 的主位图是 1920×1000，黑幕却仅 49×28 像素。`visLight.x=-20,y=-60,scaleX=scaleY=40`，Bitmap 开 smoothing；格 `(x,y)` 写到黑幕 `(x,y+1)`，以透明黑色像素表达可见程度（`World.as:40–42`；`Tile.as:8–10`；`Grafon.as:135–145,203–206,224–226,695`）。这会得到平滑的粗网格过渡，不是逐像素精确光影。

`Location.lighting` 参数为 `(x=-10000,y=-10000,r1=-1,r2=-1)`。默认位置是玩家 `X+storona*12, Y1+stayY*0.247`，默认全亮半径 300、截止半径 1000，并在建房时乘 `visMult`（`Location.as:129–131,643–648,3127–3139`）。

对每个内侧格的计算：

1. 非 active 房间立即返回；默认 `retDark=false` 时已经 `visi>=1` 的格完全跳过。
2. 以 `(格x*40,格y*40)` 为采样点。半径 r1 内基础值 1，r1 到 r2 线性下降，r2 外不增加可见度。
3. 沿 x 或 y 主轴每步前进一格，向 `getAbsTile` 查询途经格。每遇一格，把该格 `opac` 从可见度里**相减**；水中使用 `max(opac,opacWater)`。降至零就停止。它不是按透光率相乘，也不是按法线/材质做反射。
4. 若新结果比当前 `visi` 大 0.01，设置 `t_visi`，再 `updVisi`。后者每次加 0.1，但不超过 `t_visi`。
5. `retDark=true` 才允许变暗：目标以 0.025/次下降，最低到本次光心结果；屏幕缓冲由 `updVisi` 立即向下夹到这个目标。

证据：`Location.as:3123–3254`；`Tile.as:271–278`；`Location.getAbsTile:2331–2337`。边界外返回 `otstoy`，新算法应明确处理有效场景范围，不把取样越界的默认对象当作经过验证的墙。

`Location.step` 在 black=true 且玩家任一轴实际位移速度绝对值>0.5，或 `isRelight/isRebuild` 时重算；否则仅在 `relight_t>0` 时推进最多十步渐亮，随后清掉 `isRelight`（`:3394–3405`）。原版默认移动就持续照亮，离开后留亮。这是探索记忆，不等于手持灯照到哪里哪里才亮。

`Grafon.setLight` 只把现有 `visi` 写回 `lightBmp`；它既不重新射线计算，也不调用 `drawAllObjs`（`:685–700`）。`drawAllObjs` 的直接调用在 `drawLoc` 末尾（`:681`）。这与既有冲突记录最终结论一致；不能沿用早期“光照重算会重建对象层”的说法。

## 4. 遮挡来源、事件与多光源缺口

`Tile` 的物理块在设置形状时令 `opac=1`；`setZForm(>0)` 会令 opac=0；地形 `die()` 清 opac（`Tile.as:198–200,281–296,350–357`）。所以渲染视野算法并不是精确使用斜坡形状轮廓。`Area` 的 `tileop` 可为无实体格写指定不透明度，房间/地区的 `wopac` 可让水逐格扣光（`Area.as:186–190`；`Location.as:386,418–420`）。

门初始化把 `door_opac` 写入占据格；开门令 opac=0、关门恢复。`Box.setDoor` 只有开门分支设置 `isRelight/isRebuild`（`Box.as:653–692`）。破坏实体格会 `isRebuild=true`，并通过 `Tile.die` 清遮挡（`Location.hitTile:2521–2551; dieTile:2572–2596`）。这里的 `Location.rebuild()` 只是重算水并清标记，不是 Grafon 全场景重画（`:2601–2604`）。

`lightAll` 遍历 **objs**，不是 backobjs，也不是 units；凡对象 light=true，就在中心横向三个点调用与玩家相同的默认半径 lighting（`:3094–3104`）。`Box.light` 来自房间实例 XML（`Box.as:377–379`）。`Unit.light` 也有同名布尔字段并读取 XML（`Unit.as:480,651–653`），但本轮没有在原版光照链找到针对 units 的对应消费，不能声称所有发光敌人都会持续照明。正常单位创建加入 `units`；交互对象加入 `objs`（`Location.as:1223,2004`）。

多光源不能直接逐灯调用现有 `lighting` 得到稳定结果：

- retDark=false：结果只增不减；灭灯后旧亮度留下。
- retDark=true：每次 lighting 都对不属于当前光源的格减亮，多灯顺序调用会相互压暗，并受当前 visi/渐变中间态影响。
- 原方法没有按光源保存贡献、没有加法/最大值合成表、没有独立光源颜色/功率/方向参数。

这些是由算法结构推出的限制，尚未运行测量具体画面和衰减速度。若只试图调小 `lDist1/lDist2`，能改变原生视野半径，但不会自然得到灯具供电、单灯破坏、阴影潜行或多灯混光。

## 5. 动态“发亮”与画面开关

`UnitZombie` 在 vis 内挂 `visZombieLight`，设 `blendMode="screen"` 与 cacheAsBitmap，并在苏醒/死亡等阶段变化 alpha/visible（`UnitZombie.as:112–116,251–276,407–409`）。粒子 `Emitter` 给生成的 vis 设 blend、GlowFilter 和颜色变换（`Emitter.as:20–21,327–340`）。武器还能改变子弹 vis 混合模式（`Weapon.as:1476`）。这些渲染手段本身不会改变 Tile.visi、邻近单位受光或 AI。

一个确认的特殊动态入口是 `UnitSpectre.command("show")`：显示自身并调用一次 `loc.lighting(X,Y)`（`:65–70`）。这仍是揭示黑幕，不是每帧移动光。

`visLight.visible=loc.black && World.w.black`（`Grafon.as:425`）。房间选项 `noblack` 的存在会关闭房间 black 并把所有 Tile.visi 设为 1；`retdark` 的存在开启回暗；`dark` 调环境黑度，`vis` 调视野距离倍率，`lon` 改灯具初帧；注意这些不是一个统一开关（`Location.as:442–480,530–538`）。开发控制台命令 `black` 切 `World.w.black` 与显示层可见性（`Consol.as:460–463`），作弊测试入口也会隐藏黑幕（`UnitPlayer.as:388–397`）。本轮未在 PipPageOpt 找到独立的灯光质量设置；`mat_filter` 是其他设置，不应误判成光照开关。

红外：`Grafon.warShadow` 根据 `pers.infravis`，将黑幕从 normal 改为 multiply，并用 `ColorTransform(1,1,1,1,100)` 增加红通道 offset；取消时复位（`Grafon.as:159–161,357–368`）。红外药剂启用/解除都会调用 warShadow（`Effect.as:187–189,368–370`）。若模组替换黑幕，需另外定义红外下的暗区视觉；原生代码并没有自动处理任意新增照度图。

全房 `allon/alloff` 有额外玩法副作用：改房间色调、环境 dark、所有单位/物体 cTransform、所有 BackObj 帧并 redrawLoc；allon 还激活对象交互并开 lockTip=4 的电子锁（`Location.as:2920–2972`）。不宜复用为一盏灯开关。

## 6. 图层、公开接入点与副作用

参考 Grafon 的世界内部显示顺序如下，**kolObjs=6，索引0..5**（旧知识曾泛称0..7，不能据此创建第6/7层）：

```text
visBack → visBack2 → visObjs[0] → [1] → [2]
→ visFront → visObjs[3] → visVoda → visLight
→ visObjs[4] → visSats → visObjs[5] → 四边遮罩
```

证据 `Grafon.as:49,175–235`。位于黑幕后面的层才被黑幕压暗，后面的标记/界面型效果可继续可见。新图层位置决定伤害数字、提示、发光体是否被遮挡，需明确规则，不能粗暴遮住整个 Stage。

可公开读取/调用：

| 接口 | 能做什么 | 使用限制 |
|---|---|---|
| `World.w.grafon.visual/visLight/visBack/visBack2/visFront/visObjs` | 插入独立光照显示层、获取现有显示节点 | 需要处理相机坐标、重绘重挂和其他模组层序 |
| `Grafon.lightBmp/frontBmp` | 读取/写入黑幕或前景位图 | 原生每帧/重绘会覆盖；不宜拿别人的缓冲作唯一真相 |
| `Location.space/getTile/getAbsTile` | 读格子遮挡、水和地形 | `Tile.opac` 是原生近似遮挡，不能擅自改成新语义 |
| `Location.backobjs` 和 BackObj 公共字段 | 识别场景灯、位置/缩放/当前帧、on/off帧 | BackObj 不带独立耐久/供电/维修状态；变帧不能清理烘焙图 |
| `Location.lighting/lightAll/isRelight/lDist1/lDist2/retDark` | 实验或调整原生黑幕 | 探索记忆、多源与游戏玩法耦合见上文 |
| `Grafon.drawLoc / World.redrawLoc` | 全房静态重画 | 较重、有重建对象层/刷新副作用，需确认涂写/破坏痕迹保持 |
| `Grafon.getObj / resIsLoad` | 等资源就绪、按名字读原生灯具图 | 每个资源的当前帧和缺失返回还需实测 |

`backBmp/backBmp2/colorBmp/shadBmp/lightBitmap` 都是 internal，不能靠外部模组动态字符串访问当成 public API（`Grafon.as:77–95`）。可经公开 visBack 中的 Bitmap 读取其 bitmapData，但必须识别原生 Bitmap、排除其他模组的覆盖层，且不能只靠位图对象引用判断是否重绘——原版 drawLoc 复用同一对象。

drawAllObjs 会销毁并新建六个 visObjs Sprite，再遍历 firstObj 重挂存活对象。模组直接塞进 visObjs 的非原生子节点会留在脱离舞台的旧 Sprite 中；独立挂在 visual 的兄弟层在参考实现中不被该方法移除，但仍须重新确认层序及当前宿主行为（`Grafon.as:703–725`）。

## 7. 为什么要保留探索状态

除黑幕，`Tile.visi` 的消费包括：

- `Location.drawMap`：用本格及邻格最高 visi 决定地图透明度（`:2759–2785`）。
- `Location.getDist`：光标所在格 visi<0.1 就清 `celObj`（`:3484–3496`）。
- `Unit.getTileVisi`：查询单位中心格是否超过阈值（`Unit.as:4527–4529`）。
- `UnitPlayer` 传送检查：目标格 visi<0.8 或 >=0.8 的分支（`:1671,1703`）。
- `UnitPet`：目标格 visi<0.5 的检查（`:421`）。

AI 主视觉判定 `Unit.look` 使用目标 visibility/stealthMult、房间 visMult、demask、观察者 vision 和遮挡（`:4587` 起），没有在这条公式中取 `BackObj.light` 的像素。战斗专项报告应进一步说明所有消费路径，本文仅强调：玩家看到黑、玩家已探索、敌人看见玩家是不同事实。

## 8. 性能与 LightAndDarkness 的可行方向

源码可推导的成本：一次原生 lighting 扫全部格，半径内再为每格沿光线采样多个 tile，复杂度约 O(格子数×平均射线步数)。默认普通房间扫描47×24=1128格，每个 light 对象还在入房调用三次。若按多灯逐帧照搬，光源数会线性叠加工作；大地图使成本更明显。尚无本轮毫秒/帧数据。

drawLoc 处理多张1920×1000透明位图，按材质/装饰重复合成并施加滤镜，而 setLight 只写约千个黑幕像素。二者不能混称“重算光照”。后台定时全房重画会带来与照明无关的大量工作。

供设计选择的建议（未实现）：

1. 新建照度服务：静态灯、随身灯、短暂闪光登记成同一种光源；独立保留开关/损坏/功率/半径/方向，输出采样照度和渲染图。
2. 先使用格级遮挡，但与 Tile.visi 分开。静态灯照度按房间/遮挡变化缓存；玩家灯按移动/朝向节流；爆闪和火焰用限量短命源。对多光源采用明确的 max、加法或柔和饱和规则，再统一写图。
3. 灭灯/修灯先改变自有状态再合成照度；灯具外观重画和背景烘焙单独处理。BackObj 没有默认保存灯具维修状态；Location.saveObjs 只保存 saves 中带 code 的 Obj，未见保存 BackObj 状态（`:3552–3560`）。需稳定灯具键和独立版本化存档数据。
4. 渲染层遮挡世界但保留必要提示；玩家、敌人共用同一照度采样依据，再分别结合眼睛/红外/适应/视线与警戒决定战斗效果。
5. 正式性能原型至少量：无灯/1灯/10灯、关门/破墙、静止/移动、普通48×25与当前连续大场景；要记录照度计算和图像更新各自耗时，而非只看平均帧率。

兼容边界来自公共登记：RV 已使用 grafon.visLight 后的同层雾层；WallBlend 在 visFront/visBack 内插入覆盖位图；ContinuousScene 扩大 Location 并分块绘图。新模组不能声明独占这些容器，不能固定假设1920×1000，也不能只检查 Tile.visi 就认定当前玩家画面。见 `shared-knowledge/knowledge-validation/coordination/registry.md:59,128,132–139`。没有读取这些模组的私有目录，具体接口/运行顺序仍待专门兼容调查。

## 9. 后续实证应回答的问题

- 当前正式 Grafon/Location 哪些方法与参考一致，哪些是连续场景补丁；光图尺寸和局部更新方式是什么。
- 灯具关灯/坏灯帧实际像素是什么；能否只更新局部背景而保留弹痕/血迹/墙体融合。
- 同一照度场驱动画面与 AI 后，关闭灯具能否可靠改变暴露时间；开灯是否也暴露玩家自身。
- 关门、破墙、修复灯具、跨房/读档能否恢复预期照度；探索地图是否保留。
- 红外、暂停、SATS、屏幕缩放、RV各模式、连续场景是否让新黑幕重复相乘或遮住信息。

过程限制：一条包含 XML 角括号正则的纯只读批量资源查询被本机 PreToolUse 以保护参考资料为由拦截，未执行该批次、未绕过保护。灯具资源完整枚举由同轮另一专项继续，本文件没有把未读到的资源认定为不存在。
