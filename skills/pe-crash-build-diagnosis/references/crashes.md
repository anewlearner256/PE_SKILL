# Native crashes and dumps

Record PID, trigger, RUN history, Qt plugin combination, and loaded PLU/DLL paths, versions and SHA256. Preserve PDBs from the failing build; rebuilding usually produces incompatible symbols. Use existing dumps first.

If ProcDump is already installed, wait for an unhandled exception in the specific process:

    procdump64.exe -accepteula -ma -e <PID> D:/dumps

Full dumps can contain project data; analyze locally first. Alternatively attach Visual Studio's native debugger and break on the relevant exception. Do not default to global registry changes.

In WinDbg, add matching private symbols, optionally fetching Microsoft system symbols:

    .symfix C:\symbols
    .sympath+ D:\matching-build\symbols
    .reload
    !analyze -v
    .ecxr
    kv
    lm
    lmv m PluginName

Check exception code, read/write/execute address, faulting thread, loaded module path and symbol match before citing source lines. Optimization, stack corruption and missing minidump pages limit conclusions. A fault in Qt, CRT or ntdll does not establish that module as the root cause.

- Low-address 0xC0000005: check null, bare behavior integers decoded as strings, argument count and signature mismatches.
- Stale VS_KEY after RUN: compare node creation/destruction logs; resolve by path.
- Reentrant Qt event stacks: check multiple statically linked qtwinmigrate copies installing WH_GETMESSAGE hooks.
- Exit/unload crash: inspect ticks, timers, callbacks, QObject threads and destruction order, cross-DLL allocation/free.
- Heap corruption can surface well after an overwrite. Use process-scoped Application Verifier/PageHeap only when warranted, recording and reverting diagnostic settings.

For hangs inspect all threads with ~* kb and identify wait relationships. Debugger suspension itself stops heartbeats and does not demonstrate deadlock. Report critical stacks, symbol quality, trigger, hypothesis and verification; repeat the trigger with the fixed binary.
