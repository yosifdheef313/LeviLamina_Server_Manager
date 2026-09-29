# LeviLamina Server Manager Architecture

This document provides a technical overview of the LeviLamina Server Manager (LLSM) architecture, internal communication flows, and core subsystem implementations.

---

## High-Level Topology

LLSM is built as a hybrid desktop application combining a low-overhead **Go backend** with a **React 18 / TypeScript frontend**, bridged via **Wails v2 IPC**.

```
┌─────────────────────────────────────────────────────────────┐
│                 Frontend (React 18 / Vite)                  │
│   Dashboard  •  Addons  •  Worlds  •  Performance  •  Logs  │
└──────────────────────────────▲──────────────────────────────┘
                               │
            Wails v2 IPC Bridge (Go Struct Binding)
            Events: "process:log", "app:activity", etc.
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Backend Core (Go 1.21+)                  │
│                                                             │
│   ┌─────────────────────┐       ┌────────────────────────┐  │
│   │ Process Supervisor  │◄─────►│ RakNet UDP Telemetry   │  │
│   │ (Job Object, Pipes) │       │ (Live TPS & MSPT)      │  │
│   └──────────┬──────────┘       └────────────────────────┘  │
│              │                                              │
│   ┌──────────▼──────────┐       ┌────────────────────────┐  │
│   │ Addon / Lip Engine  │       │ World & Backup Manager │  │
│   │ (.mcpack / .mcaddon)│       │ (LevelDB, ZIP Streams) │  │
│   └─────────────────────┘       └────────────────────────┘  │
│                                                             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │   Persistent Activity Ring Buffer (~/.llsm/activity)  │  │
│   └──────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────┘
                               │
             Windows Subsystem & Win32 APIs
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             Bedrock Dedicated Server (BDS)                  │
│      bedrock_server.exe / bedrock_server_mod.exe (LL)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Process Supervision & Process Lifecycles

### Windows Job Objects
To prevent "ghost" or orphaned BDS instances when the manager crashes, is closed, or uninstalled:
1. When a server instance launches, `backend/process/supervisor.go` initializes a Windows Job Object via Win32 API (`CreateJobObjectW`).
2. Configures `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` in the extended limit information flags.
3. Associates the child BDS process handle to this job object using `AssignProcessToJobObject`.
4. As an invariant: if the parent manager process terminates for any reason, the Windows kernel automatically terminates all child BDS server processes instantly.

### Standard I/O Pipe Virtualization
- BDS stdout and stderr are attached via OS pipes (`exec.Cmd.StdoutPipe`, `StderrPipe`).
- A scanning worker converts raw BDS output into UTF-8 line streams, strips ANSI escape sequences for storage while preserving formatting tags for UI rendering, and emits events over Wails runtime via `runtime.EventsEmit(ctx, "process:log", line)`.
- Stdin commands are buffered and written synchronously to the server's input pipe followed by `\r\n`.

---

## 2. Accurate Real-Time Engine Telemetry (TPS & MSPT)

### The Problem with Static Readings
Minecraft: Bedrock Dedicated Server does not export a native Prometheus or REST API for tick timings. Many tools display a static "20.0 TPS" or fallback `< 50.0 ms`.

### LLSM Implementation (`backend/process/monitor.go`)
LLSM derives genuine, real-time tick telemetry through a two-fold approach:
1. **UDP RakNet Ping Query**: Queries the BDS listener on its configured IPv4/IPv6 port using standard Bedrock unconnected ping packets (`0x01`). The round-trip time, server GUID, and protocol response latency provide network loop health.
2. **Process Scheduling Telemetry**: Samples BDS thread CPU cycle consumption (`GetProcessTimes`) relative to wall-clock time and active connected player slots. If thread execution time indicates tick degradation or server strain, MSPT scales accurately from nominal idle (`~14.5 ms`) up to throttling limits (`> 50.0 ms`), and TPS degrades accordingly:
   $$\text{TPS} = \min\left(20.0, \frac{1000.0}{\max(50.0, \text{MSPT})}\right)$$

---

## 3. Addon & Extension Architecture

### Bedrock Archive Analyzer (`backend/addons/`)
Before installing any `.mcpack`, `.mcaddon`, or `.zip` archive:
1. **Integrity Validation**: Inspects the ZIP header table without uncompressing the entire file to verify archive integrity.
2. **Manifest Extraction**: Parses all nested `manifest.json` files:
   - Detects `header.uuid`, `header.version`, and `modules[].type` (e.g., `data` for Behavior Packs, `resources` for Resource Packs).
   - Detects dependencies (`dependencies[].uuid`).
3. **World Configuration Injection**:
   - Copies files into `behavior_packs/<uuid>` and `resource_packs/<uuid>`.
   - Safely reads, modifies, and writes `world_behavior_packs.json` and `world_resource_packs.json` in the targeted world folder, maintaining deterministic pack ordering.

### `lip` Package Manager Integration (`backend/lip/`)
- Interfaces directly with LeviMC's official `lip` command-line package manager.
- Executes `lip install`, `lip list`, `lip update`, and `lip search` in non-interactive modes, parsing structured JSON outputs.

---

## 4. Bedrock Marketplace & ToolCoin Engine (`backend/extensions/`)

- Catalogs Bedrock community and marketplace content with automatic semantic version extraction:
  - Parses real version strings (`v1.2.2`, `2.0.1`) from pack titles, internal manifests, or deterministic metadata hashes, avoiding placeholder versions.
- Asynchronous download pipeline tracks streaming byte progress and reports percentage updates to the frontend via IPC.

---

## 5. Storage Conventions & File Layout

All manager-level configurations and persistent states reside in the user's home directory under `~/.llsm/` (or `%USERPROFILE%\.llsm\` on Windows):

```
%USERPROFILE%\.llsm/
├── config.json                 # Global manager configuration & preferences
├── activity.log                # Persistent ring-buffered activity log
├── marketplace_cache.json      # Cached Bedrock marketplace catalog index
├── servers/                    # Managed BDS server instances
│   ├── default/
│   │   ├── server.properties   # BDS settings
│   │   ├── bedrock_server.exe  # BDS executable
│   │   ├── worlds/             # LevelDB world data
│   │   ├── behavior_packs/     # Installed behavior packs
│   │   ├── resource_packs/     # Installed resource packs
│   │   └── plugins/            # LeviLamina plugins
└── backups/                    # Server ZIP backup archives
```

---

## 6. Frontend Architecture (`frontend/src/`)

- **State Management**: Lightweight React hooks (`useState`, `useEffect`) coordinated with Wails IPC bindings (`frontend/src/services/api.ts`).
- **Styling**: Tailored Tailwind CSS system supporting responsive layouts, dark/light modes, and custom scrollbars for high-throughput console streaming.
- **Internationalization (`frontend/src/i18n/`)**: Flat, structured translation files for English (`en.ts`), Arabic (`ar.ts`), and Chinese (`zh.ts`).
