---
name: pe-plugin-lifecycle
description: Use when PE (PostEngineer) plugin code depends on timing - plugin load/init, project open, RUN (simulation/debug mode), per-frame tick listeners, timers, PEM_MAIN_MSG / MAINMSG_* messages, behavior-graph pluginCall arguments, or several Qt plugins loaded together. Also for symptoms like 3D view black or "waiting" after RUN, things lost or duplicated after RUN, ticks running before Start, plugin state reset, intermittent event delivery, or crashes reading pluginCall parameters.
---

# PE 插件生命周期与时序

**核心事实**：点 RUN 会**重新加载插件 DLL**（全局变量和 static 归零）并重置场景；同时 PE 主消息到达插件**不可靠**。很多"偶发""只有 RUN 时出问题"的 bug，都是把某个时机当成了可靠信号。

## 1. RUN 带来的变化

| 发生了什么 | 后果 | 怎么做 |
|---|---|---|
| 插件 DLL 被重新加载 | 全局变量和 static 回到初值；"上次的工程路径"之类的状态清空 | 跨 RUN 的状态存进工程目录下的文件（例如 JSON） |
| 场景重置 | 没有通过 `AddModelInfo` 登记的节点被清空 | 参见 `pe-scene-api` skill 的 persistence.md |
| 部分子树被重建 | 缓存的 `VS_KEY` 变成野值 | 缓存路径，用时重新解析 |
| 仿真正在运行 | 此时增删场景几何会让三维视图黑屏、转圈，但主线程并没有死锁 | 几何只在仿真启动前或编辑态时改动 |

## 2. 不要依赖的信号

- **`MAINMSG_ProjectOpen` / `MAINMSG_FileRun`**：曾经实测能收到，也曾经在近百次加载里一条都没收到，原因不明（可能插件加载晚于工程打开）。如果要用，先在 `messageProc` 里无条件打日志确认能收到，并且准备好兜底方案。
- **轮询 `FxGetProjectPath` 的变化来判断"工程刚打开"**：RUN 重新加载插件后，static 中的上次路径变成空，"空 → 有路径"会被误判为工程刚打开，结果在**仿真运行中**往场景里加载几何，导致三维黑屏。
- **"编辑态"标志只靠消息来设置**：消息收不到时，标志永远为 false，依赖它的功能（如相机 LOD）会静默失效。要用用户的界面操作（点击"生成"、勾选开关）作为兜底，并且在状态变化时打日志。

**可靠的做法**：由显式命令触发。提供 `funcLoadXxxFromProject` 之类的命令，RUN 时由行为图按依赖顺序调用（例如先加载地形，再放置车辆），纯查看时由菜单命令调用。命令本身要幂等。

## 3. Tick、定时器

- 每帧 Tick 监听**只在"开始仿真"时挂上，"停止"时摘下**。检查 `RegisterCommands`、`FxPluginDLL_Init`、`InitInstance` 这类加载即执行的函数里，有没有顺手调用了 `EnsureTickListener()`。否则插件一加载 Tick 就在跑，导致没点开始也在闪烁、刷新。
- Tick 里不要调用 `VsOpenField`/`VsCloseField`（会扰动全局的"当前节点"），也不要增删几何。
- 面板定时器驱动的场景改动，最后要调用 `VsInvalidate()` + `VsUpdateDisplay()`。

## 4. 多个 Qt 插件同时加载

所有 Qt 插件共享同一个 `qApp`，每个插件各自静态链接一份 qtwinmigrate。**只有创建 `qApp` 的插件才能安装消息钩子：**

```cpp
if (!qApp) {
    QMfcApp::instance(this);
    QMfcApp::installMessageHook();   // 必须放在 if 里面
}
```

如果把钩子装在 `if` 外面，后加载的插件会再装一个 `WH_GETMESSAGE` 钩子，每条消息都会被重入地 `sendPostedEvents` 两次。表现为事件偶发丢失（例如行为图的 `outputMessage` 时有时无），严重时 RUN 卡住。新建或重构插件时先检查这一处；网上或同事给的样例代码常常写错。

## 5. 行为图 pluginCall 的参数

`pluginCall("插件名", "funcXxx", 参数...)` 中，参数的传法取决于行为图里**是否加了引号**：

| 行为图里的写法 | 插件收到的 `dwData` | 插件侧的写法 |
|---|---|---|
| `"120"`、`"中文"`（加引号） | 真实的 `char*`，内容是 GBK 编码 | `atof((const char*)p)` / `QString::fromLocal8Bit` |
| `120`（裸数字） | 整数值本身 | `(int)(intptr_t)p` |

两种混用会直接崩溃：对一个裸数字做 `atof((const char*)p)`，等于解引用一个很小的地址。开发指南说"数字一律以字符串传入"，实际情况并非如此。

**查看行为图实际怎么调用**：`.rg` 是二进制格式，但 PE 会把编译后的脚本明文写到工程目录的 `.build/<模块名>`（GBK 编码），里面有每一句 `pluginCall`。新增多参数命令前先看一眼。

## 6. 排查顺序

1. 在 `messageProc`、命令入口、Tick 挂钩处打无条件日志，确认时机真的按你的假设发生。
2. 让用户实测前，确认对方运行的是重新编译后的二进制。
3. 三维黑屏或卡住时，先确认主线程是否还活着（看心跳日志、窗口能否拖动），再区分"死锁"和"渲染冲突"。
4. 崩溃时先取 minidump 判断是哪个模块崩的，再动代码。
