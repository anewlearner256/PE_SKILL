---
name: gbk-safe-edit
description: Use when reading, editing or creating C/C++ sources, headers or .rc files in Windows/MSVC projects that may be GBK (CP936) encoded, such as PE SDK plugins; also when Chinese comments or strings turn into mojibake (锟斤拷, U+FFFD, 乱码), when MSVC reports C2065/C2143/C4819 at lines that make no sense, or rc.exe fails with RC1004. Not needed for pure-UTF-8 projects.
---

# GBK 源文件安全编辑

**核心事实**：apply_patch / Edit / Write 这类编辑工具一律按 UTF-8 读写。用它们改 GBK 文件，哪怕只改一个 ASCII 字符，**整个文件的中文都会变成 U+FFFD（锟斤拷），无法恢复**，而且改完读出来看不出异常。所以每次动手前先判定编码，再选工具。

下文 `<S>` 指本 SKILL.md 同目录下的 `scripts/`，调用方式统一为：
`powershell -NoProfile -ExecutionPolicy Bypass -File <S>/<脚本> ...`

## 1. 先判定编码（每个文件、每次修改前）

`enc_detect.ps1 <文件...>`（或 `-Dir <目录>`）

| 结果 | 怎么改 |
|---|---|
| `gbk` | **只能**用本 skill 的脚本 |
| `ascii` | 只改 ASCII 可用常规工具；要加中文 → `gbk_replace.ps1`（写入 GBK） |
| `utf8-bom` | 常规编辑工具，保留 BOM |
| `utf8-nobom` | 隐患：MSVC 按 GBK 编译它。先 `enc_convert.ps1 -Path f -To gbk` 再按 gbk 处理 |
| `bad-bom` | 已损坏，`git checkout HEAD -- <文件>` 恢复 |
| `utf16` | VS 资源文件，不要用脚本改 |

不要按目录名或"读出来看着正常"判断——同一个插件里经常混编（UI 层 UTF-8 BOM、业务层 GBK）。

## 2. 脚本

**读**：`gbk_read.ps1 <文件> [-Offset 行号] [-Limit 行数]`，输出 UTF-8 带行号文本。不要用 cat / Get-Content / 读文件工具读 GBK，乱码复制回 Old 一定匹配失败。

**改**：`gbk_replace.ps1 <文件> -OldFile old.txt -NewFile new.txt [-All] [-DryRun]`
- 先用常规写文件工具把原文本、新文本写成 UTF-8 临时文件（放 `$env:TEMP`；沙箱不允许就放仓库内 `.gbk-tmp/`，用完删除）。原文本从 `gbk_read.ps1` 输出逐字复制，**不含行号前缀**，缩进一致。
- 含中文或多行一律走文件；`-Old/-New` 只用于短 ASCII。
- 删除用 `-Delete`（`-New ""` 会被 powershell 丢弃）。
- 换行自动适配文件的 CRLF/LF；默认要求唯一匹配，多处匹配会报行号；按字节替换，匹配区以外的字节保证不变。

**新建文件**：`gbk_write.ps1 -Path new.cpp -FromFile draft.txt`，草稿是 UTF-8，写出 GBK + CRLF + 末尾换行。已存在的文件要 `-Force`，改已有文件优先用 replace。

**转换**：`enc_convert.ps1 -Path f -To gbk|utf8bom`

## 3. 改完后

- 看 `git diff --stat -- <文件>` 和**完整** diff，确认只有预期的行变化。git 按 UTF-8 显示 GBK 中文会乱码，这是显示问题；改动处的中文用 `gbk_read.ps1 -Offset` 复查。
- 仓库装了 pre-commit 检查时，提交被拦截说明文件已损坏：`git checkout HEAD -- <文件>` 后用脚本重做，不要手工修补，也不要 `--no-verify` 绕过。

## 常见错误

| 做法 | 后果 |
|---|---|
| "只改一行 ASCII"就用 apply_patch / Edit | 全文件中文变 锟斤拷 |
| PowerShell `GetString`→`GetBytes` 整文件往返改写 | 文件里已有的坏字节再错位，位置离改动很远，盯着目标 hunk 发现不了 |
| here-string 直接当原文本 | 换行是 LF、文件是 CRLF，静默匹配 0 次 |
| 用 Write 新建含中文的 .h/.cpp | 无 BOM UTF-8，MSVC 按 GBK 编译，报 C2065/C2143 |
| 写出的文件末尾没有换行 | rc.exe 报 RC1004 |
| 新文本里有 emoji / 生僻符号 | GBK 无法表示，脚本会拒绝——改用 ASCII 或常用汉字 |
