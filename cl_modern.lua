-- Safety net: if cl_auth.lua failed to load for any reason,
-- define a deny-all stub so this file never crashes on ClientAuth.
if not ClientAuth then
	ClientAuth = { _allowed = false }
	function ClientAuth.IsAllowed() return false end
	function ClientAuth.ShowDenied() end
	function ClientAuth.Gate() return false end
	print("[VehDebug] ADVARSEL: ClientAuth mangler — cl_auth.lua lastet ikke korrekt.")
end

--[[
	cl_modern.lua  (Modern UI)
	New professional tuning dashboard, opened via /vehiclehandling command.
	Shares all handling logic with Legacy via shared_handling.lua.
	Does NOT conflict with Legacy UI - they can both exist simultaneously.
]]

ModernUI = {
	isOpen = false,
	hasFocus = false,
	vehicle = nil,
	-- Preset storage: table of { name = string, values = { [key] = value, ... } }
	presets = {},
	-- Original values snapshot taken when UI opens, for "Reset to Original"
	originalValues = {},
}

-- Send a message to the Modern UI NUI page
function ModernUI:Invoke(_type, data)
	SendNUIMessage({
		modernCallback = {
			type = _type,
			data = data,
		},
	})
end

-- Build the serialised field list to send to NUI on open
function ModernUI:BuildFieldData(vehicle)
	local fields = {}
	for key, field in pairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType then
			local ok, value = pcall(fieldType.getter, vehicle, "CHandlingData", field.name)
			if ok then
				local displayValue
				if type(value) == "vector3" then
					displayValue = { x = value.x, y = value.y, z = value.z }
				elseif field.type == "float" then
					displayValue = SharedHandling.TruncateNumber(value)
				else
					displayValue = value
				end

				fields[#fields + 1] = {
					key      = key,
					name     = field.name,
					type     = field.type,
					value    = displayValue,
					min      = field.min,
					max      = field.max,
					step     = field.step,
					category = field.category or "Other",
					description = field.description or "No description available.",
				}
			else
				print("[VehicleDebug/Modern] WARNING: Could not read field " .. field.name)
			end
		end
	end
	return fields
end

-- Capture original values for reset functionality
function ModernUI:CaptureOriginals(vehicle)
	self.originalValues = {}
	for key, field in pairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType then
			local ok, value = pcall(fieldType.getter, vehicle, "CHandlingData", field.name)
			if ok then
				if type(value) == "vector3" then
					self.originalValues[key] = ("%s,%s,%s"):format(value.x, value.y, value.z)
				elseif field.type == "float" then
					self.originalValues[key] = tostring(SharedHandling.TruncateNumber(value))
				else
					self.originalValues[key] = tostring(value)
				end
			end
		end
	end
end

function ModernUI:Open()
	-- UX gate: deny access if player is not on the allowlist.
	-- The server enforces this independently in sv_security.lua.
	if not ClientAuth.Gate() then return end

	local ped = PlayerPedId()
	if not IsPedInAnyVehicle(ped, false) then
		TriggerEvent('chat:addMessage', {
			color     = { 255, 100, 100 },
			multiline = false,
			args      = { "Vehicle Handling", "Du må være i et kjøretøy for å bruke dette." },
		})
		return
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if not DoesEntityExist(vehicle) then return end

	self.vehicle = vehicle
	self.isOpen = true

	-- Capture originals for reset
	self:CaptureOriginals(vehicle)

	-- Get model name for display
	-- Use GetEntityArchetypeName to get the actual spawn/model name
	-- (matches <handlingName> in meta files, e.g. "khangarage_wheelchair")
	local modelName = GetEntityArchetypeName(vehicle) or ""
	modelName = modelName:match("^%s*(.-)%s*$")
	if modelName == "" then
		local modelHash = GetEntityModel(vehicle)
		modelName = GetDisplayNameFromVehicleModel(modelHash) or "Unknown"
	end

	-- Build and send field data + presets
	self:Invoke("open", {
		fields    = self:BuildFieldData(vehicle),
		modelName = modelName,
		presets   = self.presets,
	})

	-- Give NUI focus while keeping game input (player can still drive)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	self.hasFocus = true
end

function ModernUI:Close()
	self.isOpen = false
	self.hasFocus = false
	self.vehicle = nil

	SetNuiFocus(false, false)
	self:Invoke("close", {})
end

function ModernUI:ResetToOriginals()
	if not DoesEntityExist(self.vehicle or 0) then return end

	for key, value in pairs(self.originalValues) do
		SharedHandling.SetFieldValue(self.vehicle, key, value)
	end

	-- Refresh the UI values
	self:Invoke("refreshValues", {
		fields = self:BuildFieldData(self.vehicle),
	})
end

function ModernUI:SavePreset(name)
	if not DoesEntityExist(self.vehicle or 0) then return end

	local values = {}
	for key, field in pairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType then
			local ok, value = pcall(fieldType.getter, self.vehicle, "CHandlingData", field.name)
			if ok then
				if type(value) == "vector3" then
					values[key] = ("%s,%s,%s"):format(value.x, value.y, value.z)
				elseif field.type == "float" then
					values[key] = tostring(SharedHandling.TruncateNumber(value))
				else
					values[key] = tostring(value)
				end
			end
		end
	end

	-- Replace existing preset with same name or add new
	local found = false
	for i, preset in ipairs(self.presets) do
		if preset.name == name then
			self.presets[i] = { name = name, values = values }
			found = true
			break
		end
	end
	if not found then
		table.insert(self.presets, { name = name, values = values })
	end

	self:Invoke("presetsUpdated", { presets = self.presets })
	print("[VehicleDebug/Modern] Preset saved: " .. name)
end

function ModernUI:LoadPreset(name)
	if not DoesEntityExist(self.vehicle or 0) then return end

	for _, preset in ipairs(self.presets) do
		if preset.name == name then
			for key, value in pairs(preset.values) do
				SharedHandling.SetFieldValue(self.vehicle, tonumber(key), value)
			end
			-- Refresh UI
			self:Invoke("refreshValues", {
				fields = self:BuildFieldData(self.vehicle),
			})
			print("[VehicleDebug/Modern] Preset loaded: " .. name)
			return
		end
	end
end

function ModernUI:DeletePreset(name)
	for i, preset in ipairs(self.presets) do
		if preset.name == name then
			table.remove(self.presets, i)
			self:Invoke("presetsUpdated", { presets = self.presets })
			return
		end
	end
end

--[[ NUI Callbacks from Modern UI ]]--

-- Field value changed (debounced on JS side)
RegisterNUICallback("modernUpdateHandling", function(data, cb)
	cb(true)
	if ModernUI.vehicle and DoesEntityExist(ModernUI.vehicle) then
		SharedHandling.SetFieldValue(ModernUI.vehicle, tonumber(data.key), tostring(data.value))
	end
end)

-- Close button clicked
RegisterNUICallback("modernClose", function(data, cb)
	cb(true)
	ModernUI:Close()
end)

-- Reset to original handling
RegisterNUICallback("modernResetOriginal", function(data, cb)
	cb(true)
	ModernUI:ResetToOriginals()
end)

-- Copy handling to clipboard (same XML format as legacy)
RegisterNUICallback("modernCopyHandling", function(data, cb)
	cb(true)
	if ModernUI.vehicle then
		local xml = SharedHandling.ExportXML(ModernUI.vehicle)
		if xml then
			-- Reuse legacy clipboard mechanism (both UIs share the same HTML page root)
			SendNUIMessage({
				callback = {
					type = "copyText",
					data = xml,
				}
			})
		end
	end
end)

-- Save preset
RegisterNUICallback("modernSavePreset", function(data, cb)
	cb(true)
	if data.name and data.name ~= "" then
		ModernUI:SavePreset(data.name)
	end
end)

-- Load preset
RegisterNUICallback("modernLoadPreset", function(data, cb)
	cb(true)
	ModernUI:LoadPreset(data.name)
end)

-- Delete preset
RegisterNUICallback("modernDeletePreset", function(data, cb)
	cb(true)
	ModernUI:DeletePreset(data.name)
end)

--[[ Command ]]--
-- /vehiclehandling: toggle the Modern UI dashboard.
-- Also bound to the same Alt key as the legacy UI via +vehicleHandling.
RegisterCommand("+vehicleHandling", function()
	if ModernUI.isOpen then
		ModernUI:Close()
	else
		ModernUI:Open()
	end
end, false)

-- Same keybind as legacy UI (Config.Keybind = "rmenu" = Right Alt)
RegisterKeyMapping("+vehicleHandling", "Vehicle Handling (Modern UI)", "keyboard", Config.Keybind)

-- /vehiclehandling chat command — fully closes if open
RegisterCommand("vehiclehandling", function()
	if ModernUI.isOpen then
		ModernUI:Close()
	else
		ModernUI:Open()
	end
end, false)

-- Also allow ESC / close while modern UI is open
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if ModernUI.isOpen then
			-- Disable camera controls while focused
			if ModernUI.hasFocus then
				DisableControlAction(0, 1)
				DisableControlAction(0, 2)
			end
		end
	end
end)
