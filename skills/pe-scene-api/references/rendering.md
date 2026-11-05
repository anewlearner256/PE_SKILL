# 渲染：刷新、阴影、shader

## 改了场景但画面不动

`VsInvalidate()` 只是设置"需要刷新"的标志，`VsUpdateDisplay()` 才会在标志存在时真正重绘。编辑态下，PE 只有在三维视图自己收到鼠标或键盘事件时才会重绘。所以焦点在 Qt/MFC 面板上时，定时器里的改动不会显示，直到用户点一下三维视图。

```cpp
static void RefreshView() { VsInvalidate(); VsUpdateDisplay(); }
```

一批改动最后调用一次即可。每调一次就是一帧完整渲染，不要在每个 setter 后都调用。引擎自己的每帧逻辑也是成对调用这两个函数。

## 阴影：两层都要开

1. **全局**：`VsEnableShadow()` + `VsSetShadowMapVisibility(TRUE)`。PE 界面"杂项"中的阴影选项对应 `project.ini` 里的 `shadow=`，相关参数有 `shadowccount`、`shadowfirstrange`、`shadowcameralength`、`shadowblur`。
2. **节点**：`VsSetHeuristicsByKey(key, "shadowvolume=on")`。heuristics 沿场景树向下继承，设在模型根节点上就能覆盖整个子树。

回读时用裸关键字：`VsShowHeuristicsByKey(key, "shadowvolume", buf)`，buf 得到 `"on"` 或 `"off"`。

节点重建后 heuristics 会被清除，需要重新设置（参见 rebuild-loses-state.md）。

### heuristics 关键字

SDK 头文件和文档都没有列出合法关键字。从 3dgs.dll 的字符串表中提取到的关键字如下：

`facenormal` `alphatest` `clip` `lod` `normalize` `fog` `occlusion` `heavy` `grasp` `depthtest` `cameracollision` `shadowvolume` `shadow` `sort` `collision` `quickmodelcollision` `render=(hide|point|wire|texture|texturewire|color|line)` `glow` `gpu` `reflect` `mirror` `intomirror` `earth` `shape` `normalstrength` `mapblendmode`

`shadow=` 和 `shadowvolume=` 是两个不同的关键字。

## shader / PBR

- 挂 shader：`VsAttachShaderByKey(key, "Pbr")`，按路径的版本是 `VsAttachShader(path, name)`，回读用 `VsShowShaderByKey`。对应 PE 脚本里的 `setFieldShader`。
- shader 名实测是 **`"Pbr"`**，不是 `"PBR"`，尽管 `Shaders/` 下的目录名是 `PBR`。拿不准时看函数的返回值。
- shader 要挂在**实际有几何的渲染子节点**上，和透明度设在同一个节点。
- 不要走"材质球"那条路：`VsSetFieldMaterial*` 和 PBR 无关；`VsShowFieldMaterial(char*)` 虽然在头文件里声明了，但 3dgs.dll **没有导出**，调用会报 LNK2019。

## 透明网格的混合

一个不透明、却设置了 `VS_PRI_FOLIAGE` 优先级的网格，会把同一趟渲染的地形带偏，整片变白。半透明叠加层要同时设置：

```cpp
VsSetTransparencyByKey(meshKey, 0.99f);   // 必须严格小于 1.0
VsSetPriorityByKey(meshKey, VS_PRI_FOLIAGE);
```

几何每次重建或刷新后都要重设（参见 rut.md）。

## 大场景远处条纹闪烁

PE 默认 near=0.01、far=1e6，20km 处深度分辨率约 2400m，大地形远处会出现 z-fighting 条纹。这是深度精度问题，不是网格或贴图的问题。
