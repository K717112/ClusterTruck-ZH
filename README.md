# ClusterTruck 简体中文补丁

给 Landfall Games 的 **ClusterTruck（货不单行）** 做的高质量简体中文化补丁。

- 游戏版本：Steam 版 1.1（Unity 5.3.4f1）
- 覆盖范围：主菜单、能力商店、排行榜、设置、暂停、结算、成就提示、内置关卡编辑器（含完整帮助文档）
- 字体：内置微软雅黑子集，中文不会出现方块或空白
- 不改 exe、不注入进程、不需要额外运行库

---

## 一、安装

### 方式 A：一键脚本（推荐）

```powershell
# 1. 把本仓库下载到本地任意目录
git clone https://github.com/K717112/ClusterTruck-ZH.git
cd ClusterTruck-ZH

# 2. 右键「使用 PowerShell 运行」install.ps1，或在 PowerShell 里执行：
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会：

1. 通过注册表 + `libraryfolders.vdf` 自动定位 Steam 库里的 `ClusterTruck`；
2. 第一次安装时把原版文件备份到 `ClusterTruck\_ZH_backup\`；
3. 从 GitHub Release 下载补丁包（或使用同目录下已存在的 `patch\`），覆盖对应文件；
4. 完成后提示你从 Steam 启动游戏。

找不到游戏时可以手动指定：

```powershell
.\install.ps1 -GamePath "E:\Steam\steamapps\common\ClusterTruck"
```

### 方式 B：手动覆盖

下载 Release 里的 `ClusterTruck-ZH-patch.zip`，解压后按下面路径覆盖（先自己备份原文件）：

| 补丁文件 | 目标位置（相对游戏根目录） |
|---|---|
| `level0` | `Clustertruck_Data\level0` |
| `level1` | `Clustertruck_Data\level1` |
| `resources.assets` | `Clustertruck_Data\resources.assets` |
| `sharedassets0.assets` | `Clustertruck_Data\sharedassets0.assets` |
| `unity default resources` | `Clustertruck_Data\Resources\unity default resources` |
| `Assembly-CSharp.dll` | `Clustertruck_Data\Managed\Assembly-CSharp.dll` |

---

## 二、还原

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

或手动：把 `ClusterTruck\_ZH_backup\` 里的文件按原路径拷回去。

> 也可以在 Steam 里「属性 → 已安装文件 → 验证游戏文件完整性」，Steam 会把被修改的文件换回原版（但会顺带删掉备份目录，建议先手动还原）。

---

## 三、汉化范围

| 模块 | 内容 |
|---|---|
| 主菜单 | 开始游戏 / 特殊能力 / 排行榜 / 选项 / 编辑器 / 退出 |
| 能力系统 | 20 个能力的名称、说明、价格（二段跳、史诗模式、抓钩、空中冲刺、卡车炮…） |
| 游戏内 HUD | 暂停、重试、分数、时间奖励、技能点数、关卡完成/失败、幽灵竞速 |
| 排行榜 | 表头、TOP、自定义地图、无特殊能力 |
| 设置 | 音频/画面/操作、灵敏度和反转、按键说明、垂直同步、阴影、泛光等 |
| 结算评语 | 太棒了 / 精彩绝伦 / 惊艳 / 难以置信 / 花式 / 速度奖励（原为 DLL 内硬编码） |
| Twitch 整合 | 设置页说明、OAuth 引导 |
| 关卡编辑器 | 全部工具栏、属性面板、教程步骤、两条完整帮助文档（约 6000 字） |
| 制作名单 | 章节标题汉化，人名保留原文 |

合计 **774 处 UI 文本 + 20 个能力卡 + 24 处 DLL 字符串**。

---

## 四、原理（给好奇的人）

游戏是 Unity 5.3.4f1 + Mono，所有 UI 都是 uGUI `Text` 组件，文本以「长度前缀 + UTF-8」形式存在 `SerializedFile`（`level0` / `level1` / `resources.assets` / `sharedassets0.assets`）里。

1. **文本定位**：`Text` 组件的序列化布局固定 —— 前面 56 字节是 `FontData`（字体 PPtr、字号、对齐、行距…），紧随其后就是 `m_Text`，且它是该组件的最后一个字段。据此可以在不依赖 TypeTree 的情况下精确反推每条文本的偏移。
2. **文本重写**：`m_Text` 是末字段，改长度不会影响其它字段，直接「前缀 + 新长度 + 新 UTF-8 + 4 字节对齐」重组对象数据，再让 UnityPy 重算整个 SerializedFile 的对象偏移表。
3. **能力卡**：能力名称/描述是 `level0` 里的 ScriptableObject 字段（`name` + `description`，用 `*` 分段、`**` 分段+空行），按同样方式原地重写。
4. **DLL 字符串**：`UNLOCK`、`POINTS`、`ABILITIES`、结算评语等由 `Assembly-CSharp.dll` 的 `#US` 字符串堆提供。中文用 UTF-16 等长替换 + 空格补齐，**不改变堆内偏移**，因此不需要修复任何 token。
5. **字体**：游戏用 6 个内嵌 TTF（Gravity / Hydrogen / Future n0t Found / Chinese Rocks）+ 内置 Arial（动态字体）。把每个字体的 `m_FontData` 换成「微软雅黑子集（ASCII + 译文用字 + GB2312 一级常用字，共 3880 字形）」，同时改写 `m_FontNames` 作为回退，中文即可正常渲染。

生成脚本放在 `tools/` 里，可复现整个流程（需要 `UnityPy`、`fonttools`）。

---

## 五、已知限制

- **启动器配置窗口**（Unity 的 `Clustertruck Configuration`：分辨率 / 画质 / Play!）由 UnityPlayer 原生绘制，不在资源文件里，未汉化。
- 少数运行时拼接的字符串（如关卡编号 `LEVEL 1:1`、时间戳）仍显示英文/数字。
- 自定义地图的作者名、地图名由玩家输入，保持原样（字体已包含常用汉字，可正常显示）。
- 只适用于 Steam 1.1 版；其它版本（GOG / 早期测试版）文件布局不同，请勿直接覆盖。
- 补丁只替换资源文件，**不修改存档**，联机/创意工坊不受影响。

---

## 六、免责声明

本项目为个人学习交流用的**非官方汉化**，游戏版权归 Landfall Games 所有。
字体子集取自系统微软雅黑，仅供本地显示使用，不再分发原始字体文件。
请支持正版：<https://store.steampowered.com/app/397950/>

---

## 七、致谢

- [UnityPy](https://github.com/K0lb3/UnityPy) —— 解析与重写 Unity 资源
- [fontTools](https://github.com/fonttools/fonttools) —— 字体子集化
- Landfall Games —— 做出了这么好玩的小游戏
