---
name: pe-crash-build-diagnosis
description: Diagnose PE PostEngineer native plugin crashes, dumps, DLL load failures and MSVC Qt MFC build errors using matching binaries, symbols and build logs.
---

# PE crash and build diagnosis

Identify the failing stage: compile, link, load, command execution, RUN or exit. Obtain the first error with context, build configuration, actual host/plugin paths and reproduction steps.

- For exceptions, dumps and heap corruption, read [crash diagnosis](references/crashes.md).
- For compile/link failures, missing DLLs and Qt platform loading, read [build and load diagnosis](references/build.md).
- For a black view with a responsive UI, inspect heartbeats and the UI thread before assuming deadlock. Check geometry edits during simulation, VsOpenField global state and duplicate Qt hooks.

Make the smallest evidence-based correction. Do not default to upgrading the toolchain or rebuilding every project. Preserve original dumps, logs and matching binaries. Verify that the rebuilt binary is actually loaded before repeating the original trigger. Distinguish observations, hypotheses and untested conclusions.
