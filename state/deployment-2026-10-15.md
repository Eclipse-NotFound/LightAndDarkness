# LightAndDarkness 0.1.0 部署记录

- 授权：用户于2026-10-15明确要求“请部署”。
- 安装时间：2026-10-15 17:45:57 +08:00；源实现提交 `95e79f5`。
- 正式文件：`../release/LightAndDarknessMod.swf`，13,873字节。
- SHA256：`DA13AA45B870C3576DEBD9CFB6098599BDA5A1A99EF1868F1872D00DA437F00C`。直接安装已验证候选，无重新编译。
- 通用清单只追加 `LightAndDarkness|LightAndDarknessMod|1|0|0`；原12行与注释保持原文。
- 清单安装前：`972764B4513F9FDAC130AD7F76783ABCC3F0781DA9E6EF0500A5598220BB7FDF`；安装后：`35A1A1764B730C6DA1899EB9B2D622916E98FCBA27BD4FB0D973C3B67109E1F2`。
- 宿主安装前后均为 `9987C696BEBBEB0626D8F73DA775CF867B2CED4FF626137FD9F161264270F938`；实际入口application.xml→根pfe.swf。没有补丁宿主，没有修改其他模组。
- 保护钩子曾阻止发布写入；依据既有用户授权，按规则登记10分钟会话绑定的精确调用，审阅放行后成功部署；未关闭保护。

## 安装后验证

`tests/run.ps1 -SkipBuild -Mixed -Installed` 通过。测试身份 `remains-lad-test-20261015174623287`：**47条PASS、SUITE_PASS，无失败断言**；新日志出现 `v0.1.0 loaded`，持续心跳正常。包括灯光遮挡、原生子弹/爆炸命中、维修扣料、两槽读档、开关恢复、192×75格/88灯/240块大场景。未知保存版本的SAVE_REJECT为刻意测试，断言验证原数据保留；无渲染/挂接失败。

从正式文件和正式清单中的本模组行复制到隔离环境并检查指纹，独立AIR身份，不使用用户pfe存储。混装范围为ContinuousScene、RealisticVision、WallBlend、ModLoader，未宣称全部生产模组组合通过。未重启或关闭用户实例。证据在 [deployment](../tests/evidence/2026-10-15/deployment/)。同字节候选上一轮另有4条进程重启后读档断言通过。

本次照明阶段：基地90次采样p50=1ms、p95=2ms、max=4ms；大场景末次1ms，非整帧耗时。大场景原版预载仍有秒级停顿。发布门禁完成：复用成功构建与候选验证、核对版本/授权/通用加载链、清单备份、安装、重启隔离冒烟、回退记录、记忆更新及模组仓库提交。

## 回退

备份目录：`../build/backups/install-20261015-174557-536/`。保存了清单原始字节 `loader-manifest.before.txt`、原子替换产生的 `loader-manifest.atomic-before.txt` 和部署指纹 `receipt.json`。安装前本模组release中不存在SWF，故无旧版模组文件；宿主没有被改动，不需恢复宿主。

回退时先将本次 `release/LightAndDarknessMod.swf`（必须匹配上述指纹）移出release，存进本次备份目录。若正式清单仍匹配安装后指纹，可还原 `loader-manifest.before.txt`；若已被其他任务修改，则只移除本模组行，保留其他变化。重启游戏后生效。不要把旧整份清单覆盖到有后续变动的清单上。

## 扫描器边界

只读核对ModScanner.cs确认：它从supported-mods.txt和release文件重建名单，**不保留现有名单中的版本开关**，新发现模组设为1/1/1。本次按通用加载器契约定向追加1/0/0，没有运行扫描器、修改其他模组的目录表或启动链。以后重新扫描可能把本模组行变为1/1/1，需重新核对；本版运行时另有 `World.boxDamage == 0.2` 守卫，非1.02不会进入照明/灯具处理。此守卫不是DLC兼容认证。
