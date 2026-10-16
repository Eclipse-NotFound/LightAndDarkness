被测技能：diagnosing-bugs 2026-10-08.1（C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md）；Remains运行时调试、构建、自动测试
技能归属：用户级及Remains工作区级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness

# 进图黑块：正式0.3.0的原生边框重置缺陷

2026-10-16。状态：原因已在隔离实例确认；本次只诊断，未修改生产源码、release或用户游戏。19项PASS是复现及归因检查通过，不表示缺陷已修复。

## 现象与调用链

用户报告画面上方和右方被黑块覆盖，并确认进入地图就出现。实际pfe日志中0.3.0在普通房间执行灯具转换：rbl/loc0_0为9灯，随后random_mane/loc0_4为10灯，均为beforeRaster=false；没有以异常退出解释遮挡的证据。

`src/lad/LadRuntime.as:154`在普通房间调用`LadSceneBake.change`去掉烘焙灯光；禁用时`:176`同样调用该方法恢复灯具。`src/lad/LadSceneBake.as:62`执行`g.drawLoc(loc)`，之后只有可选sceneTick，没有重新适配相机。

原生1.02 `fe.graph.Grafon.drawLoc`将ramT/ramB.scaleY、ramL/ramR.scaleX全部重置为2。随后原本应由`fe.inter.Camera.setZoom`根据视口设置边框朝向和尺寸，尤其上/左边框应为负值、向房间外延伸。模组在相机已经设置后再次drawLoc，打断了这段顺序，导致不透明边框伸进正常画面。Camera.calc平时不会无条件补调setZoom，因此黑块可一直存在。

## 实际验证

应用身份：`remains-lad-border-20261016130935784`；逻辑舞台2544×921。外部探针只通过动态入口操作实际已安装SWF，没有内嵌lad/fe替代实现。读取正式字节，在唯一AIR身份中新建rbl/loc0_0；未读写真实存档，也未关闭用户实例。

正式LAD：`3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C`。
宿主：`08A96759720C7A2AA489FCEEDB209C6E704500FDE7B1A4A49146BD578E99A8BC`。
配套加载ModLoader BD71、ContinuousScene F6ED、RealisticVision BAA4、WallBlend 3B1B；完整值见[hashes.json](hashes.json)。

每个缩放档位先设置正常相机，再启用实际灯光运行时；转换9个灯具后四边缩放均重置2。冻结同一帧，分别仅隐藏四个原生边框、仅重新调用当前档位的`world.cam.setZoom()`，导出最终Stage图像比较。后者不改变缩放档位、scaleV或镜头x/y，即可恢复被遮住的像素。禁用照明会再重绘，边框缺陷再次出现。

| 缩放档位 | scaleV | 仅重新适配相机后恢复的原纯黑像素 |
|---|---:|---:|
| 0 | 1 | 208611 |
| 1 | 1 | 208611 |
| 2 | 0.921 | 292496 |

19项检查全部通过，结果见[border-report.json](border-report.json)和[border-test.log](border-test.log)。图像已目视核对：[重绘后黑块](mode2-broken.png)、[仅相机适配后](mode2-camera-restored.png)。只隐藏全部边框会同时暴露房间外背景，不应将其当作正式修复。

## 处理位置与边界

临时操作：触发原版镜头缩放，默认单引号键`'`，以玩家绑定为准。室内可循环档位回到原档；下一次灯具重绘仍可能复发。单独关闭照明会重绘，不能保证恢复。

永久修复应使本模组场景重绘完成后恢复当前相机对应的边框；应覆盖普通房间初次转换、禁用恢复、后续换图及连续场景，避免改变玩家缩放选择。当前未实施或部署这一修复。

本次没有复制用户random_mane存档；确认的是正式字节在同尺寸原生房间中的同类机制缺陷。不能凭单张截图判定右侧每一处黑色都异常，地图外留黑与正常遮挡仍应保留；DLC、全14模组组合、操作系统DPI及联机不在本次认证范围。此前灯光平滑验证只覆盖灯光位图，未覆盖场景重绘后的原生边框，是测试覆盖缺口。

已有公共发现`shared-knowledge/rendering/discoveries/camera-screen-pixel-scale.md`记录相同原生机制，但其历史案例是测试器漏调相机。本次确认的是LAD生产调用链漏调，不能把两次案例混为同一原因。采用KB-000061修订1的实际产物外部探针方法，指纹9929d039…d5856；没有由知识出处扩展其他模组访问权限。

diagnosing-bugs SKILL指纹755c267af6dcb82d4749429476ed8b56cafc5f2e92d58f168e57b340f18c5a1d。新增证据支持其“真实症状→单变量对照→限定结论”的可复现诊断场景；不能据此升级不可复现或低频问题的验证状态。归档曾遭护栏误判只读参考查询为写入；经精确调用短时授权审核后原命令成功，未关闭护栏或修改参考源码。

## 2026-10-16 修复续接

用户随后明确要求修复。0.3.1让每次LadSceneBake重绘后重新应用当前相机缩放，补齐转换和禁用恢复路径；已部署514A7671…89A7F6，正式文件读回17项通过，候选17项专项与89项普通/大场景回归通过。原19项仍是0.3.0的归因证据；新增结果是实际修复验收，详见[修复与回退记录](../../../border-fix-2026-10-16.md)。未改真实存档、宿主或其他模组。本报告沿同一任务续写，不另算一次独立技能场景。
