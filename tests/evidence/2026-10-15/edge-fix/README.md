被测技能：diagnosing-bugs 2026-10-08.1（C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md）、Remains运行时/构建/自动测试
技能归属：用户级及Remains工作区级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness

# 随身灯明暗边缘实证

2026-10-15用户报告明暗边缘明显锯齿，要求参考RealisticVision。实际采用诊断技能的最小复现、可证伪假设与同输入前后图像检查；KB-000056用于避免把截图成本或合成渲染计时说成游戏FPS。

正式D866的源基线e21e914在Bitmap.bitmapData替换后丢失smoothing，真实AIR读到false。修复恢复true；主开发源已有该修复但旧正式版没有。root本轮只补解释注释，不重新设计遮挡或加大模糊。baseline为独立命名测试类，不进入发布SWF。

13项实际检查通过：首次创建、缩放分配后平滑标志、光照栅格逐像素相等、四朝向、墙后暗区、重建尺寸与clear后再建。相邻显示像素最大亮度跳变111→10（亮度范围0–255）。before.png和after.png已经目视核对；wall-after.png中墙后24px仍是原暗底。射线/功率/范围/感知栅格均不变。

独立进程remains-lad-edge-20261015222253731，edge-test.log包含SUITE_PASS，脚本退出0。正式编译参数debug=false/optimize=true。同进程无截图交替测180次render的总时长为44/37/38/39ms，仅是算法微基准；没有测真实战斗FPS、GPU显示成本或所有屏幕缩放。

冻结产物复验：性能窗口结束后运行remains-lad-edge-game-20261015224902427，通过游戏loader载入0.3.0候选3BA6A9C9…23BB9C，并取得其实际LadLightField类。HIGH画质下13项PASS、SUITE_PASS、退出0；像素跳变111→10及全部遮挡/转向/重建检查再现。探针不包含生产LadLightField，测试地图为合成场景。原日志frozen-edge-test.log，图片frozen-after.png和frozen-wall-after.png已目视核对；三文件SHA256见frozen-hashes.json。两轮共26项通过。

上线核对：2026-10-16已随0.3.0统一安装；本任务只读核对正式release为26,298字节，SHA256 3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C，与冻结边缘复验完全一致。部署会话从正式路径回读的remains-lad-projectile-20261016022047545报告为131项通过、0失败，宿主11BCECA8…AD1BD4F及最新视野BAA48289…DB4275；本任务已读回原报告及输入指纹。核对凭证见installed-receipt-2026-10-16.json。

验证边界：26项边缘检查在旧宿主9987C696…270F938上运行，正式新组合由曳光部署会话验收；131项安装运行检查不计入边缘检查。未重新编译或启动重复测试，未认证所有缩放和长期真人游玩。完整修复与安装记录见state/edge-fix-2026-10-15.md。

技能反馈：在已有开发代码包含修复、正式产物仍旧的情形，必须先比对实际发布基线。单看当前源码会误判“smoothing已经打开，因此无此问题”。对照支持根因，无需增加几何采样、引入模糊或扩展玩法。已于2026-10-15向全局测试报告台账去重追加本报告索引；后续冻结产物与安装结果继续在此更新，不重复登记。
