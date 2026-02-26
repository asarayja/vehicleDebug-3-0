# vehicleDebug `v3.0`

> A dual-UI FiveM vehicle handling editor with live editing, permanent server-side saves, and license-based access control.

Edit vehicle handling in real time using either the classic compact editor or a modern professional tuning dashboard — both write changes directly to the correct `handling.meta` on the server, with automatic backup.

---

## What's New in v3.0

- **Unified save engine** — Legacy and Modern UI share the same permanent save pipeline
- **License-based security** — Access controlled via `Config.AllowedLicenses`, no ACE required
- **Automatic file discovery** — Server scans and maps all `handling.meta` files at startup
- **Safe XML rewriting** — Only the matching `<Item>` block is modified, nothing else is touched
- **Automatic backup** — A `.bak` file is written before every overwrite
- **Stable build only** — No experimental or beta natives required
- **Modular architecture** — Clear separation between UI, handling logic, save engine, and security

---

## Features

- Live handling editing with real-time apply
- **Dual UI system:**
  - Classic Legacy UI — compact, keyboard-driven editor
  - Modern tuning dashboard — category tabs, sliders with numeric sync, preset system
- Permanent save to the correct handling file
- Supports GTA base vehicles (override capable) and custom addon vehicles
- Multiple vehicles per file fully supported
- Startup cache for fast file lookups

---

## Security

Access is controlled exclusively via a license whitelist — no ACE permissions needed.

Add license identifiers to **both** `cl_config.lua` and `sv_config.lua`:

```lua
-- cl_config.lua
Config.AllowedLicenses = {
    "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}
```

```lua
-- sv_config.lua
SvConfig.AllowedLicenses = {
    "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}
```

> **Keep both files in sync.** The client list gates the UI (UX layer). The server list is the real security boundary — every protected event is independently re-validated server-side.

To find a player's license identifier, run `status` in the server console and read the identifiers column.

Only whitelisted players can open either UI, save handling to file, or trigger cache events.

---

## Installation

1. Place `vehicleDebug` inside your `resources/` folder
2. Add to `server.cfg`:
   ```
   ensure vehicleDebug
   ```
3. Add your license identifiers to `Config.AllowedLicenses` in `cl_config.lua` **and** `SvConfig.AllowedLicenses` in `sv_config.lua`
4. Restart the server

---

## Commands

| Command | Description |
|---|---|
| `Right Alt` | Toggle Legacy UI (must be in a vehicle) |
| `/vehdebug` | Toggle Legacy UI on/off |
| `/vehiclehandling` | Open/close Modern UI |
| `/vehdebug_cachestatus` | Print handling file cache to F8 console (whitelisted only) |

---

## Save Flow

When **💾 Save to File** is pressed in either UI:

1. All live handling values are read from the vehicle entity
2. Values are sent to the server via `vehdebug:saveHandling`
3. License is validated server-side
4. Correct `handling.meta` is located via the startup cache
5. Backup is written (`handling.meta.bak`)
6. Only the matching `<Item>` block is updated
7. File is written to disk
8. UI receives a success or failure toast notification

---

## Supported File Structures

vehicleDebug automatically detects `handling.meta` in any of these layouts:

```
resource/handling.meta
resource/data/handling.meta
resource/data/handling/handling.meta
resource/stream/data/handling.meta
```

Multiple vehicles per file are fully supported.

---

## Architecture

```
vehicleDebug/
├── fxmanifest.lua
├── cl_config.lua              — Config, AllowedLicenses, field definitions
├── cl_auth.lua                — Client-side UX gate (caches server auth result)
├── shared_handling.lua        — Shared handling read/write/export utilities
├── cl_save_bridge.lua         — Collects values, sends to server, routes result
├── cl_debugger.lua            — Legacy UI controller
├── cl_modern.lua              — Modern UI controller (presets, reset, tabs)
├── sv_config.lua              — Server-side mirror of AllowedLicenses
├── sv_security.lua            — Hard security gate, O(1) license hash set
├── sv_save_engine.lua         — File discovery, cache, XML rewrite, backup
├── sv_events.lua              — Net event handlers, validation, dispatch
└── html/index.html            — Dual UI (Legacy + Modern in one NUI page)
```

**Data flow:**

```
[UI button click]
       ↓
[cl_save_bridge]  →  collect live values + model name
       ↓
vehdebug:saveHandling  (server event)
       ↓
[sv_events]  →  Security.Check() + input sanitisation
       ↓
[sv_save_engine]  →  locate file → backup → rewrite XML → save
       ↓
vehdebug:saveResult  (client event)
       ↓
[UI toast notification]
```

---

## Input Validation

All inputs are sanitised server-side before any file write:

| Input | Validation |
|---|---|
| Model name | Alphanumeric + underscore only, max 64 chars |
| Field names | Pattern-matched against `^[%w_]+$` |
| Field types | Whitelist: `float`, `integer`, `vector` only |
| Values | Parsed via `tonumber()` or safe vector splitting |

---

## Compatibility

- Standard FiveM stable build — no experimental natives
- Compatible with large servers and high player counts
- Handles multiple resources with mixed file layouts
- No framework dependency (ESX, QBCore etc. not required)

---

## Credits

- Original resource by **Kerminal**
- Handling field documentation by [**V4D3R**](https://forums.gta5-mods.com/topic/3842/tutorial-handling-meta)
