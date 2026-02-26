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
	cl_debugger.lua  (Legacy UI)
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Original vehicleDebug functionality — design and behaviour
	preserved exactly. Access is now gated through cl_auth.lua.

	ClientAuth.Gate() is called at every entry point:
	  • +vehicleDebug keybind command
	  • /vehdebug toggle command
	If the player is not on the allowlist, a message is shown
	and the action is silently blocked.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

Debugger = {
	speedBuffer = {},
	speed       = 0.0,
	accel       = 0.0,
	decel       = 0.0,
	toggle      = false,
	-- Only initialise as enabled if the player is allowed.
	-- Evaluated lazily on first command call.
	toggleOn    = false,
}

--[[ Functions ]]--

-- Local alias kept for compatibility with any call sites.
function TruncateNumber(value)
	return SharedHandling.TruncateNumber(value)
end

function Debugger:Set(vehicle)
	self.vehicle = vehicle
	self:ResetStats()

	local handlingText = ""

	for key, field in pairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType == nil then error("no field type") end

		local value = fieldType.getter(vehicle, "CHandlingData", field.name)
		if type(value) == "vector3" then
			value = ("%s,%s,%s"):format(value.x, value.y, value.z)
		elseif field.type == "float" then
			value = TruncateNumber(value)
		end

		local input = ([[
			<input
				oninput='updateHandling(this.id, this.value)'
				id='%s'
				value=%s
			>
			</input>
		]]):format(key, value)

		handlingText = handlingText .. ([[
			<div class='tooltip'><span class='tooltip-text'>%s</span><span>%s</span>%s</div>
		]]):format(field.description or "Unspecified.", field.name, input)
	end

	self:Invoke("updateText", {
		["handling-fields"] = handlingText,
	})
end

function Debugger:UpdateVehicle()
	local ped = PlayerPedId()
	local isInVehicle = IsPedInAnyVehicle(ped, false)
	local vehicle     = isInVehicle and GetVehiclePedIsIn(ped, false)

	if self.isInVehicle ~= isInVehicle or self.vehicle ~= vehicle then
		self.vehicle    = vehicle
		self.isInVehicle = isInVehicle

		if isInVehicle and DoesEntityExist(vehicle) then
			self:Set(vehicle)
		end
	end
end

function Debugger:UpdateInput()
	if self.hasFocus then
		DisableControlAction(0, 1)
		DisableControlAction(0, 2)
	end
end

function Debugger:UpdateAverages()
	if not DoesEntityExist(self.vehicle or 0) then return end

	local speed = GetEntitySpeed(self.vehicle)
	table.insert(self.speedBuffer, speed)
	if #self.speedBuffer > 100 then
		table.remove(self.speedBuffer, 1)
	end

	local accel, decel         = 0.0, 0.0
	local accelCount, decelCount = 0, 0

	for k, v in ipairs(self.speedBuffer) do
		if k > 1 then
			local change = v - self.speedBuffer[k - 1]
			if change > 0.0 then
				accel = accel + change
				accelCount = accelCount + 1
			else
				decel = accel + change
				decelCount = decelCount + 1
			end
		end
	end

	accel = accel / accelCount
	decel = decel / decelCount

	self.speed = math.max(self.speed, speed)
	self.accel = math.max(self.accel, accel)
	self.decel = math.min(self.decel, decel)

	self:Invoke("updateText", {
		["top-speed"] = self.speed * 2.236936,
		["top-accel"] = self.accel * 60.0 * 2.236936,
		["top-decel"] = math.abs(self.decel) * 60.0 * 2.236936,
	})
end

function Debugger:ResetStats()
	self.speed       = 0.0
	self.accel       = 0.0
	self.decel       = 0.0
	self.speedBuffer = {}
end

function Debugger:SetHandling(key, value)
	SharedHandling.SetFieldValue(self.vehicle, key, value)
end

function Debugger:CopyHandling()
	local text = SharedHandling.ExportXML(self.vehicle)
	if text then self:Invoke("copyText", text) end
end

function Debugger:Focus(toggle)
	if toggle and not DoesEntityExist(self.vehicle or 0) then return end

	SetNuiFocus(toggle, toggle)
	SetNuiFocusKeepInput(toggle)

	self.hasFocus = toggle
	self:Invoke("setFocus", toggle)
end

function Debugger:ToggleOn(toggleData)
	self.toggleOn = toggleData
	self:Invoke("toggle", toggleData)

	if not toggleData and self.hasFocus then
		self:Focus(false)
	end
end

function Debugger:Invoke(_type, data)
	SendNUIMessage({
		callback = {
			type = _type,
			data = data,
		},
	})
end

--[[ Threads ]]--

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)
		-- Only poll vehicle state if the player has access and the UI is active
		if Debugger.toggleOn then
			Debugger:UpdateVehicle()
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		if Debugger.isInVehicle and Debugger.toggleOn then
			Citizen.Wait(0)
			Debugger:UpdateInput()
			Debugger:UpdateAverages()
		else
			Citizen.Wait(500)
		end
	end
end)

--[[ NUI Events ]]--

RegisterNUICallback("updateHandling", function(data, cb)
	cb(true)
	-- NUI callbacks are client-side; player must have passed the gate
	-- to open the UI in the first place. Guard anyway for safety.
	if not ClientAuth.IsAllowed() then return end
	Debugger:SetHandling(tonumber(data.key), data.value)
end)

RegisterNUICallback("copyHandling", function(data, cb)
	cb(true)
	Debugger:CopyHandling()
end)

RegisterNUICallback("resetStats", function(data, cb)
	cb(true)
	Debugger:ResetStats()
end)

--[[ Commands ]]--

-- Keybind: open / close the legacy editor panel.
-- Access gate: ClientAuth.Gate()
RegisterCommand("+vehicleDebug", function()
	-- UX gate: deny if not on allowlist
	if not ClientAuth.Gate() then return end

	-- Initialise toggleOn state on first allowed use
	if Debugger.toggleOn == nil then
		Debugger.toggleOn = Config.EnabledByDefault
	end

	if Debugger.toggleOn == false then return end
	Debugger:Focus(not Debugger.hasFocus)
end, true)

RegisterKeyMapping("+vehicleDebug", "Vehicle Debugger", "keyboard", Config.Keybind)

-- /vehdebug: toggle legacy UI on/off.
RegisterCommand("vehdebug", function()
	if not ClientAuth.Gate() then return end

	Debugger.toggleOn = not Debugger.toggleOn
	Debugger:ToggleOn(Debugger.toggleOn)

	TriggerEvent('chat:addMessage', {
		color     = { 255, 255, 0 },
		multiline = true,
		args      = { "Vehicle Debugger", Debugger.toggleOn and "Aktivert" or "Deaktivert" },
	})
end, false)
