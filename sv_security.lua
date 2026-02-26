--[[
	sv_security.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Server-side security layer for vehicleDebug.

	This is the REAL security gate. The client-side check in
	cl_auth.lua is UX-only and provides no security guarantee.

	ALL sensitive server events MUST call Security.Check(source)
	before performing any action. This includes:
	  • vehdebug:saveHandling
	  • vehdebug:requestCacheStatus
	  • Any future admin/reload events

	Additionally, this module:
	  • Pushes auth result to each client on join / resource start
	    so cl_auth.lua can gate the UI without extra round-trips.
	  • Responds to vehdebug:requestAuth (explicit client request).

	No ACE. No steam. No discord. License only.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

Security = {}

-- ── ALLOWLIST HASH SET ────────────────────────────────────────────
-- Built from SvConfig.AllowedLicenses at startup.
-- Hash set gives O(1) lookup instead of O(n) scan on every event.
local _allowedSet = {}

local function buildAllowedSet()
	_allowedSet = {}
	local count = 0
	for _, license in ipairs(SvConfig.AllowedLicenses) do
		_allowedSet[license:lower()] = true
		count = count + 1
	end
	print(("[VehDebug/Security] Allowlist geladen: %d lisensnummer(e) registrert."):format(count))
end

-- Build immediately when script loads.
buildAllowedSet()

--- Reload the allowlist without restarting the resource.
--- Call after editing sv_config.lua and running `refresh`.
function Security.ReloadAllowlist()
	buildAllowedSet()
end

-- ── CORE FUNCTIONS ────────────────────────────────────────────────

--[[
	Security.IsAllowed(source)
	──────────────────────────
	The single shared predicate used by ALL protected events.

	@param  source   number   Player server ID
	@return allowed  bool     true if license is on the allowlist
	@return license  string   Resolved license identifier (or nil)
]]
function Security.IsAllowed(source)
	-- GetPlayerIdentifierByType is a stable server-side native.
	-- Returns nil if the player has no license identifier.
	local license = GetPlayerIdentifierByType(tostring(source), "license")

	if not license or license == "" then
		print(("[VehDebug/Security] ADVARSEL: Spiller %s har ingen license-identifikator."):format(tostring(source)))
		return false, nil
	end

	if _allowedSet[license:lower()] then
		return true, license
	end

	return false, license
end

--[[
	Security.Deny(source, license, eventName)
	──────────────────────────────────────────
	Call when a security check fails.
	Logs the attempt and notifies the client.
]]
function Security.Deny(source, license, eventName)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	print(("[VehDebug/Security] AVVIST | tid=%s | source=%s | license=%s | event=%s"):format(
		timestamp,
		tostring(source),
		tostring(license) or "ukjent",
		tostring(eventName)
	))
	TriggerClientEvent("vehdebug:accessDenied", source, SvConfig.AccessDeniedMessage)
end

--[[
	Security.Check(source, eventName)
	───────────────────────────────────
	Convenience wrapper: IsAllowed + Deny in one call.
	Returns true if allowed, false if denied (auto-logs + notifies).

	Usage in event handlers:
	  if not Security.Check(source, "vehdebug:saveHandling") then return end
]]
function Security.Check(source, eventName)
	local allowed, license = Security.IsAllowed(source)
	if allowed then return true end
	Security.Deny(source, license, eventName)
	return false
end

-- ── AUTH PUSH ─────────────────────────────────────────────────────
-- Push the authorisation result to a specific client.
-- Called on join and on explicit client request.
local function pushAuthToClient(source)
	local allowed, _ = Security.IsAllowed(source)
	TriggerClientEvent("vehdebug:authResult", source, allowed)
end

--[[
	vehdebug:requestAuth
	─────────────────────
	Client fires this on resource start (cl_auth.lua).
	Server responds with the player's authorisation result.
	No security check needed here — we're only sending a bool.
]]
RegisterNetEvent("vehdebug:requestAuth", function()
	local source = source
	pushAuthToClient(source)
end)

--[[
	playerJoining / onResourceStart
	─────────────────────────────────
	Push auth result automatically when:
	  • A player joins the server mid-session
	  • The vehicleDebug resource is (re)started
]]
AddEventHandler("playerJoining", function()
	local source = source
	-- Small delay: player may not have all identifiers immediately on join
	Citizen.SetTimeout(1000, function()
		pushAuthToClient(source)
	end)
end)

AddEventHandler("onResourceStart", function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	-- Push to all already-connected players (covers resource restarts)
	for _, playerId in ipairs(GetPlayers()) do
		pushAuthToClient(tonumber(playerId))
	end
end)
