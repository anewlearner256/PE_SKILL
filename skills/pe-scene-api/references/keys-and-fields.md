# key 与节点（field）

## INVALID_KEY

`VsInterface.h`: `#define INVALID_KEY -1`。所有 `VsShowFieldKey` / `VsOpenField` / `VsInsertLight` 的失败值都是它。

```cpp
VS_KEY k = INVALID_KEY;
VsShowFieldKey(path, k);
if (k == INVALID_KEY) { /* 不存在 */ }
```

## key 什么时候会失效

| 时机 | 原因 |
|---|---|
| 同一路径 `VsDeleteField` + `VsCreateField` 重建（LOD 切换、重新生成地形等） | 路径没变，但新节点分配了新的 key |
| 点 RUN | 插件被重新加载，仿真侧会重建部分子树 |
| 重开工程、从 `.vob` 挂回节点 | 节点是新建的 |
| 别的插件重建了你所依赖的节点 | 例如车辆或物理插件定型时重建模型子树 |

失效的 key **不等于** `INVALID_KEY`，传给 `Vs*ByKey` 的后果包括：弹出 `xxx:InvalidKey` 模态框（界面卡住，看起来像一次调用耗时好几秒）、在 3dgs.dll 内访问违例、被别的对象序列化进 RUN 交接流导致 RUN 卡死（参见 rut.md）。

**做法**：缓存路径，使用前重新解析。

```cpp
// 低频重新解析（例如 1Hz 节流），不碰"当前节点"
VS_KEY k = INVALID_KEY;
VsShowFieldKey(g_groundPath.c_str(), k);
if (k == INVALID_KEY) return;
```

## "当前节点"全局状态

`VsOpenField` / `VsOpenFieldByKey` / `VsCloseField` 会修改引擎全局的"当前节点"。在 Tick 中反复开关（哪怕节流到每秒一次）也会让其他模块的对象跟着闪烁，最典型的是 `loadVolumeAllData` 加载的物理场对象。

- 存活性探测、按路径查 key：用 `VsShowFieldKey`。
- 真正需要打开节点（插入几何、插入光源、复制 include）时：只在确定的时机（用户操作、换绑、重建）打开一次。
- 排查"没点开始也在闪"：除了查热路径函数，还要查**热路径的注册入口**是否被多处调用。例如 Tick 监听本应只在"开始仿真"时挂上，却在插件加载、命令注册时也被调用了一次。

## 往节点下插入网格或光源

`VsInsertTriMesh`、`VsInsertLight` 等都插到**当前节点**，所以必须先让宿主成为当前节点：

```cpp
VS_KEY host = VsOpenField(hostPath);
if (host == INVALID_KEY) host = VsCreateField(hostPath);
if (host == INVALID_KEY) return false;
// ... VsInsertTriMesh(...) / VsInsertLight(0, "MyLight") ...
VsCloseField();
VsInvalidate();
VsUpdateDisplay();
```

`VsInsertLight(type, name)` 的第二个参数是**光源名字**，不是路径。把路径传进去，光源无处可挂，项目树里也不会出现。

## 新建子节点后立刻解析不到

刚 `Create()` 出来的子节点，在 `VsInvalidate()` + `FxUpdateAllKey()` 之前，可能还不能被 `VsShowFieldKey` 按路径解析到。如果需要拿到子节点的 key 做后续设置，把这一步放在刷新之后。但**不要**把所有设置都往后挪，有的 setter 必须在刷新之前调用（参见 rut.md）。
