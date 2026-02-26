vehicleDebug v3.0

A dual-UI FiveM vehicle handling editor with permanent server-side file save and unified architecture.

Edit vehicle handling live using either the classic compact editor or a modern professional tuning dashboard — both write changes directly to the correct handling.meta on the server.

🚀 What's New in v3.0

Unified save engine — Legacy and Modern UI now use the same permanent save pipeline

License-based security — Access controlled via Config.AllowedLicenses (no ACE required)

Automatic handling file discovery — Server scans and maps all models at startup

Safe XML rewriting — Only the correct <Item type="CHandlingData"> block is modified

Automatic backup — .bak file written before every overwrite

Stable build compatible — No beta natives required

Modular architecture — Clear separation between UI, handling logic, save engine, and security

✨ Features

Live handling editing (real-time apply)

Dual UI system:

🧓 Classic Legacy UI

🆕 Modern tuning dashboard with sliders + numeric sync

Permanent save to correct handling file

Supports GTA vehicles (override capable)

Supports custom vehicles

Multiple vehicles per file supported

Cache system for performance

🔐 Security (v3.0)

Access is now controlled exclusively via license whitelist.

In cl_config.lua:

Config.AllowedLicenses = {
  "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

Only these players can:

Open Legacy UI

Open Modern UI

Save handling to file

Trigger reload events

All save events are validated server-side.

No ACE permissions required.

📦 Installation

Place vehicleDebug inside resources/

Add to server.cfg:

ensure vehicleDebug

Add your license identifiers to Config.AllowedLicenses

Restart server.

⌨ Commands
Command	Description
Right Alt	Toggle Legacy UI (in vehicle)
/vehdebug	Toggle Legacy UI
/vehiclehandling	Open Modern UI
/vehdebug_cachestatus	Print handling cache status (whitelisted only)
💾 Save Flow (Both UIs)

When 💾 Save is pressed:

All live handling values are read from the vehicle

Sent to server via vehdebug:saveHandling

License validated

Correct handling.meta located via cache

Backup created (handling.meta.bak)

Only matching <Item type="CHandlingData"> updated

File written to disk

UI receives success/fail response

📁 Supported File Structures

vehicleDebug supports automatic detection of:

resource/handling.meta
resource/data/handling.meta
resource/data/handling/handling.meta
resource/stream/data/handling.meta

Multiple vehicles per file are fully supported.

🏗 Architecture (v3.0)
vehicleDebug/
├── fxmanifest.lua
├── cl_config.lua
├── shared_handling.lua
├── cl_save_bridge.lua
├── cl_debugger.lua        (Legacy UI controller)
├── cl_modern.lua          (Modern UI controller)
├── sv_save_engine.lua     (File discovery, cache, XML rewrite, backup)
├── sv_events.lua          (Security + validation + dispatch)
└── html/index.html        (Dual UI system)
Data Flow
[UI click]
   ↓
[cl_save_bridge]
   ↓
vehdebug:saveHandling
   ↓
[sv_events → license validation]
   ↓
[sv_save_engine → locate → backup → rewrite → save]
   ↓
vehdebug:saveResult
   ↓
[UI toast notification]
🛡 Input Validation

All inputs are sanitised server-side before file write:

Model name: alphanumeric + underscore (max 64 chars)

Field names: whitelist-validated

Field types: float, integer, vector

Values parsed via tonumber() / safe vector parsing

🎯 Compatibility

Works on standard FiveM stable build

No experimental natives

Compatible with large servers

Handles multiple resources and mixed file layouts

👑 Credits

Original resource by Kerminal

Handling field documentation by V4D3R
https://forums.gta5-mods.com/topic/3842/tutorial-handling-meta
