# 车辙 CVsRut

## 1. `Refresh()` 只重算几何，不恢复渲染状态

`Refresh()` 内部只做向量和矩阵运算，不处理贴图、透明度和优先级，也不调用 `VsInvalidate`。每次几何重建后，混合状态都会退回默认的不透明，结果是**地形整片变白**（参见 rendering.md 中"透明网格的混合"一节）。

**每次 `Refresh()` 之后**都要重设渲染子节点的透明度（小于 1.0）、优先级（`VS_PRI_FOLIAGE`）和 shader（`"Pbr"`）。渲染子节点和父节点同名，路径是 `<parent>/<name>/<name>`。缓存路径，每次按路径重新解析 key。

## 2. setter 的调用顺序

`SetGroundKey` / `SetGroundUpward` / `SetImageFile` / `SetWidth` 都要在 `VsInvalidate()` + `FxUpdateAllKey()` **之前**调用。

`SetImageFile` 内部按自己保存的节点 key 和名字打开节点，不需要等场景树刷新。把它挪到 `FxUpdateAllKey()` 之后，贴图就绑不上，车辙会显示为引擎默认的红色。

只有"解析渲染子节点 key 并设置混合"这一步需要放在刷新之后，因为新子节点在刷新前按路径解析不到。

## 3. `Clear()` 会删除渲染节点

`Clear()` 会对渲染网格调用 `VsDeleteByKey`，纹理绑定也随之丢失，而 `Refresh()` 不会重设贴图。清点后车辙会变回默认色。车辙内部的网格 key 没有 getter，也不会序列化，不要缓存它。

## 4. 野 key 会让 RUN 卡死

车辙序列化时，会把地面节点 key 和自身节点 key 转换成路径字符串写入 RUN 交接流。转换前**不检查 key 是否有效**，转换用的缓冲区也没有清零。如果地面节点被重建过（例如地形 LOD 切换），车辙缓存的地面 key 就是野的，写进流里的是一段栈上的垃圾数据。读取端不校验长度，RUN 进程会卡死在后续的序列读取里（`CRgSequence::ReadFromBuffer` 死循环）。

处理方法：
- 低频（例如 1Hz）按路径用 `VsShowFieldKey` 重新解析地面 key 和车辙节点 key，再调用 `SetGroundKey` 更新。
- 销毁车辙时检查 `DeleteObject` 的返回值（被引用时不会删除）；全部销毁后再扫描一遍剩余数量，仍有残留就在界面上提示用户不要点 RUN。
