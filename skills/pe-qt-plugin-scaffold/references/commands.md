# PE command contracts

Separate business operations, panel adapters and plugin entry points. Business methods return checkable results and avoid dialogs. Panels expose ApiSet*/ApiDo*/read-only getters; MFC setters synchronize UpdateData(FALSE), Qt setters update widgets. Actions must not overwrite new parameters with stale control values.

A show command only shows the panel. Action commands should work without showing it. Do not expose file-browser buttons: accept paths instead. Register with PluginInfo::AddCmd, using stable ASCII aliases hidden from menus/toolbars for scripting. Check exported symbols, registered names and behavior-graph names separately.

## Distinguish caller ABIs

Native in-process C++ calls can pass a parameter structure through void(FX_PTR). Document layout, lifetime, null semantics and compatibility. Do not transfer Qt/STL ownership across DLL boundaries. Copy borrowed values before asynchronous work. Zero, negative values and empty strings may be legitimate: define omission per field.

Behavior-graph pluginCall arguments map to separate FX_PTR parameters, using the installed SDK's function types and AddCmd overloads. They are not automatically a native parameter structure.

- Quoted strings arrive as char pointers, typically GBK in existing PE projects. Use fromLocal8Bit only when the system code page is known; otherwise decode GBK explicitly.
- Bare integers arrive as values. Convert through intptr_t, never dereference as strings.
- For decimals, a quoted decimal string can be the contract. Validate complete consumption, range and finite values.
- Do not infer parameter types from pointer magnitude. Use separate native and behavior commands where necessary.

The scaffold SetText command accepts one quoted string; null is rejected, empty clears text, and the command does not show the panel. Inspect the compiled scripts under a project's .build directory with the correct encoding to verify actual callers; do not edit binary .rg files.

Make repeated operations predictable. Resolve scene objects by path after reload/rebuild. Pair tick registration with removal; avoid geometry creation in simulation ticks.

Test menu calls without parameters, valid/empty inputs, invalid values within the declared types, repeated execution, multiple Qt plugins and RUN reload. Do not use forged pointers as validation tests.
