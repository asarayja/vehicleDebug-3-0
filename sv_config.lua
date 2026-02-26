--[[
	sv_config.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Server-side configuration for vehicleDebug.

	IMPORTANT: This file mirrors Config.AllowedLicenses from
	cl_config.lua. Keep both files in sync.

	The server CANNOT read cl_config.lua at runtime because client
	scripts are not executed in the server context. This file
	provides the server with the same license list so it can
	perform the hard security check independently of the client.

	WHY A SEPARATE FILE?
	  FiveM loads client_scripts only in the client runtime and
	  server_scripts only in the server runtime. They cannot share
	  a file directly. This is the standard, correct pattern.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

SvConfig = {}

-- ── ACCESS CONTROL ────────────────────────────────────────────────
-- Must match Config.AllowedLicenses in cl_config.lua exactly.
-- Format: "license:<40-character hex string>"
SvConfig.AllowedLicenses = {
	 --"license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
	 --"license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}

-- Message sent to the client when a server-side check rejects a request.
SvConfig.AccessDeniedMessage = "Du har ikke tilgang til Vehicle Debugger."
