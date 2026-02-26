--[[
	cl_auth.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Client-side access gate for vehicleDebug.

	PURPOSE  : UX layer only. Blocks UI for unauthorised players.
	SECURITY : NOT a security boundary. Server always re-checks.

	HOW IT WORKS
	  The server pushes "vehdebug:authResult(bool)" on join and on
	  resource start. Gate() reads that cached result synchronously.
	  No client-side native calls are needed or used.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- Define ClientAuth unconditionally at the very top.
-- Nothing below this line can prevent it from existing.
ClientAuth = {
	_allowed = nil,   -- nil = pending, true = allowed, false = denied
}

function ClientAuth.IsAllowed()
	return ClientAuth._allowed == true
end

function ClientAuth.ShowDenied()
	local msg = (Config and Config.AccessDeniedMessage)
		or "Du har ikke tilgang til Vehicle Debugger."
	TriggerEvent("chat:addMessage", {
		color     = { 255, 80, 80 },
		multiline = false,
		args      = { "Vehicle Debugger", msg },
	})
end

function ClientAuth.Gate()
	if ClientAuth.IsAllowed() then return true end
	ClientAuth.ShowDenied()
	return false
end

-- ── SERVER-PUSHED AUTH RESULT ─────────────────────────────────────
-- sv_security.lua fires "vehdebug:authResult" with a boolean.
RegisterNetEvent("vehdebug:authResult", function(allowed)
	ClientAuth._allowed = (allowed == true)

	if ClientAuth._allowed then
		print("[VehDebug/ClientAuth] Tilgang innvilget.")
	else
		print("[VehDebug/ClientAuth] Tilgang nektet.")
	end
end)

-- ── REQUEST AUTH ON RESOURCE START ───────────────────────────────
AddEventHandler("onClientResourceStart", function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	TriggerServerEvent("vehdebug:requestAuth")
end)
