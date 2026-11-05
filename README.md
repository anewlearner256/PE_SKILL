# pe-dev-toolkit

PE（PostEngineer）插件开发用的 AI 编码助手工具包：一组 [Agent Skills](https://agentskills.io/)（Codex / Claude Code 通用）加若干 git hook，把插件开发中踩过的坑沉淀成助手可直接调用的流程和脚本。

## 内容

| 名称 | 类型 | 解决什么问题 |
|---|---|---|
| `gbk-safe-edit` | skill + 脚本 | AI 编辑工具按 UTF-8 读写，改 GBK 源文件会把全文件中文毁成"锟斤拷"；提供按字节安全读/改/建/转换 GBK 文件的脚本 |
| `pe-scene-api` | skill（参考型） | Vs* 场景 API 的坑：INVALID_KEY、野 key、"当前节点"全局态致闪烁、重建丢贴图/阴影、光源绑定、阴影与 shader、.vob 存读、删除节点、车辙 |
| `pe-plugin-lifecycle` | skill | RUN 重载插件与场景重置、不可靠的主消息、Tick 挂钩、多 Qt 插件共享 qApp 的消息钩子、行为图 pluginCall 参数规则 |
| `git-hooks/pre-commit` | git hook | 提交前检查暂存的 C/C++/rc 文件：中文被毁、GBK 字节错位、BOM 损坏、新出现无 BOM UTF-8（MSVC 会按 GBK 编译）一律拦截 |

| `pe-qt-plugin-scaffold` | skill + generator | Qt5/MFC/qtwinmigrate scaffold and PE command contracts |
| `pe-crash-build-diagnosis` | skill | Native dump, MSVC/Qt/MFC build and plugin load diagnosis |

Future work: PE runtime MCP.

Qt scaffolds additionally require Python 3.10+, CMake 3.15+, VS C++/MFC, Qt5 and the local PE SDK. See skills/pe-qt-plugin-scaffold/SKILL.md. SDK sources are not bundled.

## 环境要求

- Windows + Windows PowerShell 5.1（系统自带）
- Git for Windows
- Codex（桌面版 / CLI）或 Claude Code

## 安装

```powershell
git clone https://github.com/anewlearner256/PE_SKILL.git pe-dev-toolkit
cd pe-dev-toolkit
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Repo D:\path\to\pe-sdk
```

- skill 复制到 `%USERPROFILE%\.agents\skills\`（Codex 用户级 skill 目录）；加 `-ClaudeCode` 同时复制到 `%USERPROFILE%\.claude\skills\`。
- `-Repo` 指定的每个仓库安装 pre-commit hook（可传多个，逗号分隔）。仓库已有别的 pre-commit 时不会覆盖，会打印需要手动追加的一行。
- 安装后**重启 Codex**。
- 更新：`git pull` 后重新运行同一条命令。

## 建议在项目 AGENTS.md 中加入

```markdown
## 源文件编码
本仓库 C/C++/rc 源文件多为 GBK，部分为 UTF-8 BOM。修改任何 .h/.cpp/.rc 前必须使用 gbk-safe-edit skill 判定编码；
GBK 文件禁止用 apply_patch 或其他编辑工具直接修改。
```

## pre-commit 拦截后怎么办

```
encoding check BLOCKED: Foo.cpp : U+FFFD replacement characters 0 -> 435 ...
```

1. `git checkout HEAD -- Foo.cpp` 恢复（工作区未提交的改动会丢失，先确认）。
2. 让助手按 gbk-safe-edit 重做修改。
3. 确属有意为之（例如有意把文件转成 UTF-8 BOM）：`git commit --no-verify` 跳过一次，或设环境变量 `PE_SKIP_ENCODING_CHECK=1`。

## 脚本一览（`skills/gbk-safe-edit/scripts/`）

| 脚本 | 用途 |
|---|---|
| `enc_detect.ps1` | 判定文件编码并给出可用的修改方式；`-Dir` 扫整个目录 |
| `gbk_read.ps1` | 以 UTF-8 输出带行号的内容 |
| `gbk_replace.ps1` | 字节级精确替换，自动适配 CRLF，匹配区外字节不变 |
| `gbk_write.ps1` | 从 UTF-8 草稿新建 GBK 文件 |
| `enc_convert.ps1` | 无 BOM UTF-8 / GBK / UTF-8 BOM 互转 |
| `check_staged_encoding.ps1` | pre-commit 调用的检查逻辑 |

脚本也可以脱离 AI 助手手动使用，参数见各脚本头部注释。

## 许可证

[MIT](LICENSE)
