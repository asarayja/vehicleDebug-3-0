--[[
	sv_events.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Server-side event handlers for vehicleDebug.

	Security is enforced exclusively through sv_security.lua.
	Every protected event calls Security.Check(source, eventName)
	as its FIRST action. No ACE. No steam. No discord.

	Protected events:
	  • vehdebug:saveHandling       — write handling.meta to disk
	  • vehdebug:requestCacheStatus — read internal scan cache
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- ── INPUT SANITISATION ────────────────────────────────────────────

--- Validate and sanitise the handling table sent by the client.
--- Whitelists field types and scrubs names to alphanumeric + underscore.
--- @return clean table | nil on failure
local function sanitiseHandlingTable(raw)
	if type(raw) ~= "table" then return nil end

	local clean = {}
	for _, entry in ipairs(raw) do
		if type(entry) == "table"
			and type(entry.name)  == "string"
			and type(entry.type)  == "string"
			and entry.value ~= nil
		then
			-- Whitelist: only these three types are valid
			if entry.type == "float" or entry.type == "integer" or entry.type == "vector" then
				-- Field name: only alphanumeric + underscore
				local safeName = entry.name:match("^[%w_]+$")
				if safeName then
					clean[#clean + 1] = {
						name  = safeName,
						type  = entry.type,
						value = tostring(entry.value),
					}
				end
			end
		end
	end

	return #clean > 0 and clean or nil
end

--- Sanitise model name: trim whitespace, alphanumeric + underscore only, max 64 chars.
local function sanitiseModelName(name)
	if type(name) ~= "string" then return nil end
	-- Trim leading and trailing whitespace before any other check
	name = name:match("^%s*(.-)%s*$")
	if name == "" then return nil end
	local safe = name:match("^[%w_]+$")
	if not safe or #safe > 64 then return nil end
	return safe
end

-- ── EVENTS ────────────────────────────────────────────────────────

--[[
	vehdebug:saveHandling
	──────────────────────
	Triggered by BOTH Legacy and Modern UIs via cl_save_bridge.lua.

	Payload:
	  modelName    (string)  — vehicle model name, e.g. "adder"
	  handlingTable (table)  — array of { name, type, value }
]]
RegisterNetEvent("vehdebug:saveHandling", function(modelName, handlingTable)
	local source = source  -- capture immediately; avoid race with yields

	-- 1. Hard security check — license whitelist only
	if not Security.Check(source, "vehdebug:saveHandling") then
		-- Security.Check already called Security.Deny which logs + notifies client
		return
	end

	-- 2. Sanitise model name
	local safeModel = sanitiseModelName(modelName)
	if not safeModel then
		TriggerClientEvent("vehdebug:saveResult", source, false, "Ugyldig modellnavn.")
		return
	end

	-- 3. Sanitise handling table
	local safeTable = sanitiseHandlingTable(handlingTable)
	if not safeTable then
		TriggerClientEvent("vehdebug:saveResult", source, false, "Ugyldig eller tom handling-data.")
		return
	end

	-- 4. Delegate to save engine (file I/O)
	local ok, msg = SaveEngine.SaveHandling(safeModel, safeTable)

	-- 5. Return result to the requesting client
	TriggerClientEvent("vehdebug:saveResult", source, ok, msg)
end)

--[[
	vehdebug:requestCacheStatus
	────────────────────────────
	Debug event: dumps the model→file cache to the requesting
	player's F8 console. Requires allowlist access.
]]
RegisterNetEvent("vehdebug:requestCacheStatus", function()
	local source = source

	-- Security check — same gate as save
	if not Security.Check(source, "vehdebug:requestCacheStatus") then
		return
	end

	local count = 0
	for _ in pairs(SaveEngine.cache) do count = count + 1 end

	local lines = { ("Cache-status — %d modeller indeksert:"):format(count) }
	for model, entry in pairs(SaveEngine.cache) do
		lines[#lines + 1] = ("  %s → %s/%s"):format(model, entry.resourceName, entry.relativePath)
	end

	TriggerClientEvent("vehdebug:cacheStatus", source, table.concat(lines, "\n"))
end)

--[[
	vehdebug:requestOriginalHandling
	─────────────────────────────────
	Client fires this when Modern UI opens.
	Server reads the handling.meta file and
	returns the true original values — not
	what is currently on the live entity.
]]
RegisterNetEvent("vehdebug:requestOriginalHandling", function(modelName)
	local source = source

	if not Security.Check(source, "vehdebug:requestOriginalHandling") then
		return
	end

	local safeModel = modelName and modelName:match("^%s*(.-)%s*$")
	if not safeModel or safeModel == "" or not safeModel:match("^[%w_]+$") or #safeModel > 64 then
		TriggerClientEvent("vehdebug:originalHandling", source, nil, "Ugyldig modellnavn.")
		return
	end

	local fields, err = SaveEngine.ReadHandling(safeModel)
	TriggerClientEvent("vehdebug:originalHandling", source, fields, err)
end)
