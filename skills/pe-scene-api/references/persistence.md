# 持久化、加载与删除

## RUN 后节点消失

PE 进入 RUN 时会重置场景，**没有登记在模块模型信息表里的节点会被清空**。直接用 `VsInsertTriMesh` 建的网格、用 `VtkReadStreamFile` 挂回的节点，都不在表里。

能在 RUN 后保留的标准做法是 `.vis` 模型：

```cpp
m->LoadModelFromFile(name, visPath, ...);
m->AddModelInfo(name, visPath, matrix16);   // 登记进工程，RUN 后和重开工程都会恢复
VsSetTransformByKey(key, matrix16);
```

程序生成的几何没有 `.vis`，常见做法有：
- **实例记录重放**：把 `{name, vis, matrix[16]}` 存进插件自己的 JSON，RUN 后或重开工程时逐条执行 `LoadModelFromFile + AddModelInfo`。不依赖源数据，结果幂等。适合大量共享模型的实例，例如散布的岩石。
- **显式加载命令**：提供 `funcLoadXxxFromProject` 命令，由行为图在仿真开始前按顺序调用。

不要用后台轮询去"检测丢失并自动补回"，那样会在仿真运行中往场景里灌几何（参见 `pe-plugin-lifecycle`）。

## `.vob` 存读

```cpp
VS_KEY key = INVALID_KEY;
VsShowFieldKey(nodePath, key);           // 全路径，例如 /scene/modules/main/model/<leaf>
VsOpenFieldByKey(key);
VsCopyIncludeByKey(key);
VtkWriteStreamFile(vobPath, FALSE);      // ★ 压缩参数必须传 FALSE
VsCloseField();
```

- `bCompression = TRUE` 写出的文件读回时 `VtkReadStreamFile` 返回 `7`（看似成功），但顶点为空。
- 读取成功的判断要同时接受 `TKS_Normal(0)` 和 `TKS_Complete(7)`，`TKS_Error` 是 1。
- `VtkWriteStreamFileOfField` 更慢，而且写出的文件读回时返回 `TKS_Error`，不要用。

## 删除节点

- 用 `VsShowFieldKey(name, k)` + `VsDeleteByKey(k, TRUE)`，或者按名字调用 `VsDeleteField`。
- **不要用 `CVsModule::UnloadModel`**：多个节点共享同一个 `.vis` 时，它会提前释放共享的 GPU 资源。函数本身正常返回，几秒后下一帧重绘时在显卡驱动（`nvoglv64.dll`）里崩溃，dump 里也没有插件自己的帧。
- 删除后还要从工程登记表中移除：`m->RemoveModelInfo(name)`，同时清掉插件自己 JSON 里对应的记录，否则下次打开工程会把已删除的对象恢复回来。
- `CVsModule::DeleteObject` 在对象仍被引用时**直接返回 0、不删除**。必须检查返回值，否则会留下活着的对象和野 key。
