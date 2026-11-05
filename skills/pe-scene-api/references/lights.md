# 光源

新版 SDK（`VsInterfaceLight.h`）中，光源是**项目树里的节点对象**，不再是全局光源。

## 类型枚举

`VsInsertLight(int type, const char* name)`：`0` = 点光源或平行光，`1` = 网格光源，`2` = 聚光灯。

点光源和平行光都用 type 0 创建，靠 `VsSetLightPositionByKey` 的参数区分。老代码里"点光源 = 1"的写法在新版会创建出网格光源。

## 推荐：绑定用户在项目树里手建的光源

插件自己创建、自己缓存 key 的光源，在 RUN 或场景重建后很容易变成野 key，表现为 `VsSetLight*:InvalidKey` 弹框，或在 3dgs.dll 内崩溃。更稳的做法是让用户在 PE 项目管理里建好光源，插件按名字绑定。

**1. 查找对象**

```cpp
CVsModule* m = (CVsModule*)FxPluginMgr_GetData(NULL, "Ptr_MainVsModule");
CMvoObject* obj = m->FindOtherObject(name, MVO_OBJ_TYPE_LIGHT);
```

手建对象挂在模块的"其他对象"表里，`FindObject(type, name)` 查的是另一条链，**查不到**。找不到时，用 `FindOtherObjectsByType(MVO_OBJ_TYPE_LIGHT, list)` 把所有候选的真实 `Name()` 打进日志对比。MVO 显示名不一定等于 Vs3D 里的光源名。

**2. 驱动光源：走光源 key，不走 `CVsLight` 的 setter**

`CVsLight::SetDirection/SetColor/SetIntensity/Enable` 使用对象自己缓存的 key，引擎可能不认，会弹出模态 invalidkey 框，界面卡住等用户点击。正确做法：

```cpp
VsOpenFieldByKey(ownerFieldKey);          // 只在绑定或换绑时做，不要放在 Tick 里
int n = 0; VsShowLightCount(n);
for (int i = 0; i < n; ++i) {
    VS_KEY lk; if (!VsShowLightKey(i, lk)) break;
    // 优先用 CVsLight::LightKey() 匹配，其次按名字
}
VsCloseField();
// 之后用 lk 调用：VsSetLightPositionByKey / VsSetLightStrengthByKey /
//              VsSetPointLightDataByKey / VsEnableLightByKey
```

- **只能用枚举出来的光源 key**。把节点 key（field key）传给 `Vs*LightByKey` 会在 3dgs.dll 内访问违例。
- 匹配成功后缓存光源 key，热路径直接使用，不要每次重新打开节点校验（参见 keys-and-fields.md 中的"当前节点"一节）。只在换绑时清空缓存。

## `VsShowLightCount` 会数到子孙节点的光源

SDK 注释写的是"当前节点"，实测在祖先节点上也会数到所有子孙节点的光源。逐级遍历场景树收集光源时，同一盏灯会在 `/scene`、`/scene/modules`、… 每一级各出现一次。

- 按光源 key **去重**。
- 光源属于哪个节点，用 `VsShowLightField(lightKey, baseKey)` 查询，不要拿"当前打开的节点"代替。

## 遍历场景树

根节点用 `VsGetSceneKey()` + `VsShowDatabaseByKey`，备用路径是 `VsShowDatabase("/scene/modules/main/model/")`。
