# 菜单改键统一部署（2026-10-15）

已安装并验证。用户在统筹会话01a13f40-6ca2-7872-9f9a-c1e453e80745明确选择“安装剩余六个（推荐）”。本记录只确认改键部署，不发布源码目录其他实验。

- 正式文件：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/release/LightAndDarknessMod.swf
- 安装SHA256：`D8666B4ACD9E98BC73785402F9A9A771DA5F54CC742C4D69664824ADAD1857A3`
- 原文件SHA256：`01767319A54AC88961B2BA40391F0FA79359486EE5591E6A22D90AD49F84537C`
- 精确备份：D:/Program Files/Steam/steamapps/common/Remains/mods/ModLoader/build/backups/before-keybind-clients-20261015-214440-393ca9a3/LightAndDarkness/LightAndDarknessMod.swf
- 源候选：D:/Program Files/Steam/steamapps/common/Remains/mods/LightAndDarkness/build/generated/keybind-worktree/build/out/LightAndDarknessMod.swf

安装时间：2026-10-15T21:44:41.4244524+08:00。正式ModLoader BD71、FA B330与七客户端共同读回验证：首进程175项、重启171项；本模组改键按钮、精确组合、显示宽高、跨进程保存和默认恢复通过。各客户端更深入的实际动作验证保留在keybind-integration-2026-10-15.md，不把联合计数当作全部战斗或DLC验收。

统一回执：../../ModLoader/build/out/keybind-client-installation/deployment.json；稳定证据及说明：../../ModLoader/state/keybind-integration-2026-10-15.md。回退在游戏退出后调用ModLoader/build/deploy-keybind-clients.ps1 -Action Rollback，先核对六个目标仍为此次指纹，禁止覆盖后续部署。若出现更晚安装，应按更新的部署回执协调回退，不直接复制旧备份。

源码中未发布的B、墙面/曳光或灯光优化保持各自WIP所有权；后续版本须保留本轮按键适配器和菜单。此部署未改用户真实存储与加载清单，没有强制重启玩家实例，重启游戏后生效。
