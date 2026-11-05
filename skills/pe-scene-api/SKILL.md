---
name: pe-scene-api
description: Use when writing or debugging PE (PostEngineer) plugin code that calls the Vs* scene API or CVsModule - fields, VS_KEY, meshes, lights, textures, shadows, shaders, .vob streams, model loading/deletion, ruts (CVsRut). Also for symptoms like objects flickering, scene not refreshing until the 3D view is clicked, "invalidkey" popups, textures/shadows lost after rebuild, crashes in 3dgs.dll or nvoglv64.dll, or nodes vanishing after RUN.
---

# PE 场景 API 踩坑集

SDK 头文件注释不全，以下规则都是实测/崩溃后得出的。先看下面的通用规则，再按症状查对应参考文件。

## 通用规则（每次都适用）

1. **无效 key 是 `INVALID_KEY`（-1），不是 0/NULL。** 用 `if (!key)` 判断会把失败当成功。
2. **`VS_KEY` 不是永久句柄。** 同一路径删除后重建（LOD 切换、重新生成）、点 RUN、重开工程，都会让缓存的 key 失效，但它不会变成 `INVALID_KEY`，而是变成野值。跨越这些时机的缓存一律保存**路径**，用时按路径重新解析。
3. **热路径（Tick、定时器）里不要调 `VsOpenField*`/`VsCloseField`。** "当前节点"是引擎全局状态，开关一次就会让不相关的对象（如物理场）闪烁。按路径查 key 用 `VsShowFieldKey`，它不改当前节点。
4. **从面板或定时器改场景后，`VsInvalidate()` 后面必须跟 `VsUpdateDisplay()`。** 否则要等用户点一下三维视图才会重绘。一批改动最后调一次即可。
5. **删除场景节点用 `VsDeleteByKey` / `VsDeleteField`，不要用 `CVsModule::UnloadModel`。** 多个节点共享同一个 `.vis` 时，`UnloadModel` 会提前释放共享 GPU 资源，下一帧在显卡驱动里崩溃。
6. **删除后重建节点会丢掉节点上的所有属性**：纹理、heuristics（阴影）、透明度、shader。重建前先捕获，重建后重新设置，参见 rebuild-loses-state。
7. **不要在仿真运行（RUN）期间增删场景几何。** 会导致三维视图黑屏。时机问题参见 `pe-plugin-lifecycle` skill。

## 按症状查

| 症状 / 任务 | 参考文件 |
|---|---|
| key 失效、野 key、往节点下插入网格或光源、无关对象闪烁 | [references/keys-and-fields.md](references/keys-and-fields.md) |
| LOD 切换或重建后贴图、阴影、透明度丢失 | [references/rebuild-loses-state.md](references/rebuild-loses-state.md) |
| 光源：创建、绑定用户手建光源、invalidkey 弹框、光源重复出现 | [references/lights.md](references/lights.md) |
| 不刷新、阴影、shader / PBR、heuristics 关键字、材质 | [references/rendering.md](references/rendering.md) |
| `.vob` 存读、RUN 后节点消失、模型加载与删除、崩溃在驱动里 | [references/persistence.md](references/persistence.md) |
| 车辙 `CVsRut`：地形变白、车辙变红、RUN 卡死 | [references/rut.md](references/rut.md) |

## 先验证再下结论

- 让用户实测前，确认对方**真的重新编译**了：日志里应能看到新加的日志行。旧二进制会让"修复无效"的判断完全失真。
- 一个现象可能有多个崩溃源同时存在，先取 dump 判断是哪个模块崩的，不要靠"改了 X 就不崩"这种小样本相关性下结论。
