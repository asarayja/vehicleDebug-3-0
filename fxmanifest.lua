author 'Kerminal. Forked by asarayja'
description 'Vehicle Handling Debugger — Legacy + Modern UI | License-based access control | Permanent file save'
version '2.2.0'

fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
	'html/index.html',
}

--[[ CLIENT SCRIPTS — load order
	1. cl_config      Config table + AllowedLicenses (single source of truth for access)
	2. cl_auth        ClientAuth — UX-only license gate (NOT security)
	3. shared_handling SharedHandling — get/set/export utilities
	4. cl_save_bridge  SaveBridge — collects values, fires server event, shows result
	5. cl_debugger     Legacy UI controller
	6. cl_modern       Modern UI controller
]]
client_scripts {
	'cl_config.lua',
	'cl_auth.lua',
	'shared_handling.lua',
	'cl_save_bridge.lua',
	'cl_debugger.lua',
	'cl_modern.lua',
}

--[[ SERVER SCRIPTS — load order
	1. sv_config     SvConfig — server-side mirror of AllowedLicenses
	2. sv_security   Security — IsAllowed / Check / Deny (hard security gate)
	3. sv_save_engine SaveEngine — file I/O: cache, XML rewrite, backup, write
	4. sv_events     Net event handlers — auth delegated to Security.Check()
]]
server_scripts {
	'sv_config.lua',
	'sv_security.lua',
	'sv_save_engine.lua',
	'sv_events.lua',
}
