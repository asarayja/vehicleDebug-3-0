# vehicleDebug v2.1.0

A dual-UI FiveM vehicle handling editor with **permanent file save**.  
Edit handling values live with the classic compact editor or a professional tuning dashboard — both can write changes directly back to `handling.meta` on the server.

---

## What's in v2.1

- **Permanent save** — both UIs can write changes directly to the vehicle's `handling.meta` file on the server
- **Auto-discovery** — the server scans all resources at startup to map every model to its handling file
- **Backup before save** — a `.bak` file is written automatically before any changes are made
- **Precision XML rewriting** — only the correct `<Item type="CHandlingData">` block is touched; all other vehicles and formatting are preserved
- **ACE permission security** — save is gated behind `vehicleDebug.save` permission (configurable)
- **Single save engine** — both Legacy and Modern UI use the same code path; zero duplication

---

## Installation

1. Drop the `vehicleDebug` folder into `resources/`.
2. Add `ensure vehicleDebug` to `server.cfg`.
3. Grant save permission:

```
add_ace group.admin vehicleDebug.save allow
add_ace identifier.license:abc123 vehicleDebug.save allow
```

Or open `sv_events.lua` and set `REQUIRE_ACE_PERMISSION = false` for open access.

---

## Commands

| Command | Description |
|---|---|
| **Right Alt** | Open/close Legacy UI (in vehicle) |
| `/vehdebug` | Toggle Legacy UI on/off |
| `/vehiclehandling` | Open/close Modern UI (in vehicle) |
| `/vehdebug_cachestatus` | (ACE only) Print handling file cache to F8 |

---

## Save Flow

When 💾 Save to File is clicked in either UI:

1. All live handling values are read from the vehicle
2. Sent to server via `vehdebug:saveHandling`
3. Server locates the correct `handling.meta` for that model
4. Backup written: `handling.meta.bak`
5. Only the matching `<Item type="CHandlingData">` block is updated
6. File written back to disk
7. Success/failure shown in UI

---

## Supported File Structures

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
├── fxmanifest.lua         — Resource manifest
├── cl_config.lua          — Shared config: fields, types, slider ranges
├── shared_handling.lua    — Client utility: get/set/export
├── cl_save_bridge.lua     — Client save layer: collects values, fires event, shows result
├── cl_debugger.lua        — Legacy UI controller
├── cl_modern.lua          — Modern UI controller
├── sv_save_engine.lua     — Server: cache, file discovery, XML rewrite, backup
├── sv_events.lua          — Server: auth, validation, dispatch
└── html/index.html        — Single NUI page (both UIs)
```

### Data flow

```
[UI click] → [cl_save_bridge] → vehdebug:saveHandling → [sv_events auth]
  → [sv_save_engine: find file → backup → rewrite XML → write]
  → vehdebug:saveResult → [UI toast]
```

---

## Security

All inputs are sanitised server-side before any file I/O:
- Model name: alphanumeric + underscore, max 64 chars
- Field names: alphanumeric + underscore only
- Field types: whitelist (`float`, `integer`, `vector`)
- Values: parsed through tonumber / vector parser before write

Settings in `sv_events.lua`:

| Setting | Default | Effect |
|---|---|---|
| `REQUIRE_ACE_PERMISSION` | `true` | Require `vehicleDebug.save` ACE |
| `USE_LICENSE_WHITELIST` | `false` | Use license list instead |
| `ALLOWED_LICENSES` | `{}` | Licenses to whitelist |

---

## Credits

- Original resource by **Kerminal**
- Handling field descriptions: V4D3R on 5Mods — https://forums.gta5-mods.com/topic/3842/tutorial-handling-meta
