--[[
	cl_save_bridge.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Client-side save bridge shared by Legacy and Modern UIs.

	Neither UI contains its own save logic.
	Both call SaveBridge.Save(vehicle) — this module handles:
	  • Resolving the model name from the vehicle entity
	  • Reading all live handling values from the vehicle
	  • Sending them to the server via vehdebug:saveHandling
	  • Receiving the result and routing it back to the correct UI
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

SaveBridge = {}

-- Which UI is currently expecting the save result so we can
-- route the notification correctly.  Values: "legacy" | "modern" | nil
SaveBridge._pendingSource = nil

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: GetModelName
     Returns lowercase display model name
     from a vehicle entity handle.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function getModelName(vehicle)
	-- GetEntityArchetypeName returns the actual model/spawn name
	-- e.g. "khangarage_wheelchair" — this is what <handlingName> in
	-- handling.meta files contains. Always use this as primary source.
	local name = GetEntityArchetypeName(vehicle) or ""
	name = name:match("^%s*(.-)%s*$")  -- trim whitespace

	-- Fallback: GetDisplayNameFromVehicleModel if archetype returns empty
	-- (rare, but handles edge cases with some vanilla vehicles)
	if name == "" then
		local modelHash = GetEntityModel(vehicle)
		name = (GetDisplayNameFromVehicleModel(modelHash) or ""):match("^%s*(.-)%s*$")
	end

	return name
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: CollectHandlingData
     Reads all Config.Fields from the live
     vehicle and returns a flat array:
       { { name, type, value }, ... }
     Vectors are serialised as "x,y,z".
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function collectHandlingData(vehicle)
	local data = {}

	for _, field in ipairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType then
			local ok, value = pcall(fieldType.getter, vehicle, "CHandlingData", field.name)
			if ok and value ~= nil then
				local serialised
				if type(value) == "vector3" then
					serialised = ("%s,%s,%s"):format(
						tostring(value.x),
						tostring(value.y),
						tostring(value.z)
					)
				elseif field.type == "float" then
					serialised = tostring(SharedHandling.TruncateNumber(value))
				else
					serialised = tostring(value)
				end

				data[#data + 1] = {
					name  = field.name,
					type  = field.type,
					value = serialised,
				}
			else
				if Config.Debug then
					print(("[VehDebug/SaveBridge] Could not read field '%s': %s"):format(
						field.name, tostring(value)
					))
				end
			end
		end
	end

	return data
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     PUBLIC: Save
     Call from Legacy or Modern UI.
     uiSource: "legacy" | "modern"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveBridge.Save(vehicle, uiSource)
	if not vehicle or not DoesEntityExist(vehicle) then
		SaveBridge._deliverResult(uiSource, false, "No valid vehicle to save.")
		return
	end

	local modelName = getModelName(vehicle)
	if not modelName or modelName == "" then
		SaveBridge._deliverResult(uiSource, false, "Could not resolve vehicle model name.")
		return
	end

	local handlingData = collectHandlingData(vehicle)
	if #handlingData == 0 then
		SaveBridge._deliverResult(uiSource, false, "No handling data collected.")
		return
	end

	-- Record which UI is waiting so the result handler can notify it
	SaveBridge._pendingSource = uiSource

	if Config.Debug then
		print(("[VehDebug/SaveBridge] Sending save for '%s' (%d fields) from %s UI"):format(
			modelName, #handlingData, uiSource
		))
	end

	TriggerServerEvent("vehdebug:saveHandling", modelName, handlingData)
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: DeliverResult
     Routes the save result notification
     to whichever UI requested the save.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveBridge._deliverResult(uiSource, success, message)
	-- Toast notification via NUI (works for both UIs)
	SendNUIMessage({
		saveResult = {
			success = success,
			message = message,
			source  = uiSource,
		}
	})

	-- Also print to F8 for debugging
	if Config.Debug then
		local prefix = success and "[OK]" or "[FAIL]"
		print(("[VehDebug/SaveBridge] %s %s"):format(prefix, message))
	end
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     EVENT: Save result from server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
RegisterNetEvent("vehdebug:saveResult", function(success, message)
	local src = SaveBridge._pendingSource
	SaveBridge._pendingSource = nil
	SaveBridge._deliverResult(src, success, message)
end)

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     EVENT: Access denied by server
     Fired by Security.Deny() in sv_security.lua
     when any protected event is blocked.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
RegisterNetEvent("vehdebug:accessDenied", function(message)
	-- Show the denial message in chat
	TriggerEvent('chat:addMessage', {
		color     = { 255, 80, 80 },
		multiline = false,
		args      = { "Vehicle Debugger", message or Config.AccessDeniedMessage },
	})

	-- Also surface it in any open UI via saveResult-style notification
	SaveBridge._deliverResult(SaveBridge._pendingSource, false, message or Config.AccessDeniedMessage)
	SaveBridge._pendingSource = nil

	-- Force-close any open UI panels
	if ModernUI and ModernUI.isOpen then
		ModernUI:Close()
	end
	if Debugger and Debugger.hasFocus then
		Debugger:Focus(false)
		Debugger:ToggleOn(false)
	end
end)

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     EVENT: Cache status debug response
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
RegisterNetEvent("vehdebug:cacheStatus", function(text)
	-- Always print: this event is only fired when explicitly requested via /vehdebug_cachestatus
	print("[VehDebug/CacheStatus]\n" .. text)
end)

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     NUI CALLBACKS
     Both UIs trigger save via NUI post.
     ClientAuth.IsAllowed() is checked here
     as an additional client-side guard.
     The server will re-check independently.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]

-- Legacy UI save button
RegisterNUICallback("legacySaveHandling", function(data, cb)
	cb(true)
	-- Client-side guard (UX layer only — server re-checks via sv_security.lua)
	if not ClientAuth.IsAllowed() then
		SaveBridge._deliverResult("legacy", false, Config.AccessDeniedMessage)
		return
	end
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) then
		local vehicle = GetVehiclePedIsIn(ped, false)
		SaveBridge.Save(vehicle, "legacy")
	else
		SaveBridge._deliverResult("legacy", false, "Ikke i et kjøretøy.")
	end
end)

-- Modern UI save button
RegisterNUICallback("modernSaveHandling", function(data, cb)
	cb(true)
	-- Client-side guard (UX layer only — server re-checks via sv_security.lua)
	if not ClientAuth.IsAllowed() then
		SaveBridge._deliverResult("modern", false, Config.AccessDeniedMessage)
		return
	end
	local vehicle = ModernUI and ModernUI.vehicle
	if vehicle and DoesEntityExist(vehicle) then
		SaveBridge.Save(vehicle, "modern")
	else
		SaveBridge._deliverResult("modern", false, "Ingen kjøretøy sporet av Modern UI.")
	end
end)

-- Debug: dump cache status to F8 (server will re-check license)
RegisterCommand("vehdebug_cachestatus", function()
	if not ClientAuth.Gate() then return end
	TriggerServerEvent("vehdebug:requestCacheStatus")
end, false)
