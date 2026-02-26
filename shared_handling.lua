--[[
	shared_handling.lua
	Core handling engine shared by both Legacy and Modern UI systems.
	All SetVehicleHandling* calls go through here.
]]

SharedHandling = {}

-- Truncate a float to Config.Precision decimal places
function SharedHandling.TruncateNumber(value)
	value = value * Config.Precision
	return (value % 1.0 > 0.5 and math.ceil(value) or math.floor(value)) / Config.Precision
end

-- Read a single field value from vehicle handling
-- Returns the raw value (vector3, number, etc.)
function SharedHandling.GetFieldValue(vehicle, field)
	if not DoesEntityExist(vehicle) then return nil end

	local fieldType = Config.Types[field.type]
	if not fieldType then
		print("[VehicleDebug] ERROR: Unknown field type: " .. tostring(field.type))
		return nil
	end

	local ok, value = pcall(fieldType.getter, vehicle, "CHandlingData", field.name)
	if not ok then
		print("[VehicleDebug] ERROR reading field " .. field.name .. ": " .. tostring(value))
		return nil
	end

	return value
end

-- Apply a value to a vehicle handling field
-- key   = index into Config.Fields (1-based integer)
-- value = string representation of the value
function SharedHandling.SetFieldValue(vehicle, key, value)
	if not DoesEntityExist(vehicle) then return false end

	local field = Config.Fields[key]
	if not field then
		print("[VehicleDebug] ERROR: No field at key " .. tostring(key))
		return false
	end

	local fieldType = Config.Types[field.type]
	if not fieldType then
		print("[VehicleDebug] ERROR: Unknown field type: " .. tostring(field.type))
		return false
	end

	local ok, err = pcall(fieldType.setter, vehicle, "CHandlingData", field.name, value)
	if not ok then
		print("[VehicleDebug] ERROR setting field " .. field.name .. ": " .. tostring(err))
		return false
	end

	-- Required for some top-speed values to take effect
	-- Uses stable native: ModifyVehicleTopSpeed
	ModifyVehicleTopSpeed(vehicle, 1.0)
	return true
end

-- Build a snapshot of all handling fields for a vehicle
-- Returns a table: { fieldName = displayValue, ... }
function SharedHandling.GetAllValues(vehicle)
	if not DoesEntityExist(vehicle) then return {} end

	local snapshot = {}
	for key, field in pairs(Config.Fields) do
		local value = SharedHandling.GetFieldValue(vehicle, field)
		if value ~= nil then
			if type(value) == "vector3" then
				snapshot[key] = {
					display = ("%s,%s,%s"):format(value.x, value.y, value.z),
					x = value.x, y = value.y, z = value.z,
					type = field.type,
					name = field.name,
				}
			elseif field.type == "float" then
				snapshot[key] = {
					display = SharedHandling.TruncateNumber(value),
					type = field.type,
					name = field.name,
				}
			else
				snapshot[key] = {
					display = value,
					type = field.type,
					name = field.name,
				}
			end
		end
	end
	return snapshot
end

-- Export handling as XML string (same format as legacy CopyHandling)
function SharedHandling.ExportXML(vehicle)
	if not DoesEntityExist(vehicle) then return nil end

	local lines = {}
	for key, field in pairs(Config.Fields) do
		local fieldType = Config.Types[field.type]
		if fieldType then
			local ok, value = pcall(fieldType.getter, vehicle, "CHandlingData", field.name, true)
			if ok then
				local nValue = tonumber(value)
				if nValue ~= nil then
					table.insert(lines, ("<%s value=\"%s\" />"):format(
						field.name,
						field.type == "float" and SharedHandling.TruncateNumber(nValue) or nValue
					))
				elseif field.type == "vector" then
					table.insert(lines, ("<%s x=\"%s\" y=\"%s\" z=\"%s\" />"):format(
						field.name, value.x, value.y, value.z
					))
				end
			end
		end
	end
	return table.concat(lines, "\n\t\t\t")
end
