# 重建节点会丢失哪些状态

`VsDeleteField` + `VsCreateField` + 重新插入几何得到的是一个全新的节点。下面这些挂在旧节点上的东西全部丢失，引擎不会自动迁移：

| 丢失的状态 | 表现 | 重建后补设 |
|---|---|---|
| 纹理绑定（包括用户在 PE 场景树上手动加的贴图） | 缩放视角（LOD 切换）后贴图消失 | 见下方的捕获和重绑 |
| heuristics（如 `shadowvolume=on`） | 阴影消失 | `VsSetHeuristicsByKey(key, "shadowvolume=on")` |
| 透明度、渲染优先级 | 混合错误、地形变白 | `VsSetTransparencyByKey` / `VsSetPriorityByKey` |
| shader | 退回默认材质 | `VsAttachShaderByKey(key, "Pbr")` |
| 所有缓存的 key | 野 key | 按路径重新解析 |

重开工程（从 `.vob` 挂回）也算一次重建，同样需要补设。建议把补设逻辑写成一个函数，比如 `ApplyNodeRenderState(key)`，在**每一个**创建或重建的入口都调用一次：首次生成、LOD 切换、从 stream 加载、RUN 后重新挂回。

## 纹理：重建前捕获，重建后重绑

不需要知道图片路径，所以对用户在 PE 界面上手动加的贴图同样有效：

```cpp
// 1. 删除前：捕获当前节点绑定的纹理
VS_KEY texKey = INVALID_KEY;
BOOL env = FALSE; float texMat[16]; int coord = 0;
BOOL hasTex = VsShowFieldTextureKey(nodePath, texKey, VS_MAP_COLOR, 0);
if (hasTex) hasTex = VsShowFieldTextureParam(nodePath, env, texMat, coord, VS_MAP_COLOR, 0);

// 2. 删除、重建、插入网格 ...

// 3. 重建后：重新绑定
if (hasTex && texKey != INVALID_KEY) {
    VsSetTextureByKeyByKey(newKey, texKey, env, texMat, VS_MAP_COLOR, 0, coord);
    VsBindAllTextures();
}
```

纹理按名字唯一登记，见 `VsShowTextureKeyByName`。纹理 key 在节点重建后仍然有效，失效的只是节点 key。

## 已知局限

`.vob` 快照只包含写入那一刻节点上的东西。如果生成节点后立刻写了 `.vob`，用户之后才加的贴图不会进入快照，重开工程后贴图就没了。需要的话，在用户修改后重新写入，或者把贴图信息单独存一份配置。
