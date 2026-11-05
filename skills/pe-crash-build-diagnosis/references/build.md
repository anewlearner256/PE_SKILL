# Build and load failures

The example baseline is x64, v141, MultiByte, shared MFC, Qt5 msvc2017_64. Confirm against the host SDK property sheets. Check which VS supplies MSBuild, installed Windows SDK, Qt paths and configuration.

From a VS Developer PowerShell with C++/MFC/v141 installed:

    msbuild ExampleQt.sln /m /t:Build /p:Configuration=Release /p:Platform=x64 /bl:build.binlog /fl "/flp:logfile=build.log;verbosity=normal"

Fix the earliest source error first. Binlogs may contain local paths and environment values; inspect before sharing.

| Symptom | Check first |
|---|---|
| MSB8020 | Missing PlatformToolset components |
| MSB8036 | WindowsTargetPlatformVersion versus installed SDK |
| C1083 | Include/props paths and base directory, Qt/MFC, generated headers |
| Missing QtMsBuild | Qt VS Tools qt.props/qt.targets location |
| vtable/staticMetaObject | Q_OBJECT moc generation and compiled output |
| LNK1104 | Library paths, configuration, file locks |
| LNK2019/2001 | Signatures, macros, missing cpp, SDK libraries, exports |
| LNK2038 | /MD versus /MDd, Qt/SDK configuration, iterator debug level |
| LNK1112 | x64/Win32 mismatch |
| LNK1168 | Host locking PLU: save project and close host normally |

Example release libraries: FxLibCore/FxLibPlugin/FxLibCoreMfc/FxLibPluginMfc. Debug usually adds d; inspect actual SDK props and libraries. For damaged Chinese text check GBK/BOM before editing or converting source.

When linking succeeds but loading fails:

    dumpbin /headers ExampleQt.plu
    dumpbin /dependents ExampleQt.plu
    dumpbin /exports ExampleQt.plu
    Get-FileHash ExampleQt.plu -Algorithm SHA256

Check stale copies at the actual load path, FxPluginDLL_Init export, dependency architecture/version and Qt debug/release suffixes. dumpbin does not recursively cover every dependency or runtime dynamic load.

For Qt platform loading, temporarily set QT_DEBUG_PLUGINS=1 in the terminal launching the host and restore its previous value afterward. Do not overwrite a host's Qt DLLs with windeployqt without verifying compatibility. Record build, load, menu and behavior/RUN validation as separate stages.
