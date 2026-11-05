---
name: pe-qt-plugin-scaffold
description: Create PE PostEngineer Qt5 MFC qtwinmigrate plugin scaffolds and wrap UI actions as registered PE commands or behavior-graph calls.
---

# Qt plugin scaffold and PE commands

Baseline: PE-SDK-MSVC2017-x64, Qt5, shared MFC. Check the installed SDK examples and property sheets before changing ABI settings.

Run scripts/new_plugin.py with Python 3.10+:

    python scripts/new_plugin.py --name ExampleQt --output D:/work/ExampleQt
    cmake -S D:/work/ExampleQt -B D:/work/ExampleQt/build -G "Visual Studio 17 2022" -A x64 -T v141 -DPE_SDK_ROOT=D:/sdk -DQTWINMIGRATE_DIR=D:/sdk/Plugins/ModelSizeQt/qtwinmigrate -DCMAKE_PREFIX_PATH=D:/Qt/5.14.2/msvc2017_64
    cmake --build D:/work/ExampleQt/build --config Release

Requires CMake 3.15+, VS C++/MFC/v141 components, compatible Qt5 and the local SDK. The generator refuses an existing output directory. C++ files use UTF-8 BOM. SDK and qtwinmigrate sources are referenced locally, not redistributed. Outputs stay in build; deployment is explicit.

Only the plugin creating qApp installs the QMfcApp message hook. Plugins reusing qApp must not install another hook. Execute Qt UI and PE commands on the host UI thread; use queued connections for worker results. Stop owned timers, ticks and callbacks before unloading; destroy owned widgets without deleting shared qApp. Verify hook lifetime against the installed qtwinmigrate version.

Initialization must not modify geometry or start ticks. RUN can reload DLL state and invalidate cached VS_KEY values: retain paths and resolve again. Provide explicit load commands instead of depending solely on project-open messages.

Read [command contracts](references/commands.md) before exposing operations. Use this toolkit's gbk-safe-edit tools for existing GBK sources.

Validate Debug/Release x64 builds, menu open/close/reopen, hidden commands without popups, two Qt plugins together, RUN/stop/RUN and unload. Report which stages were actually tested; generator tests do not prove host compatibility.
