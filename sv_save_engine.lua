--[[
	sv_save_engine.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Universal handling.meta save engine for vehicleDebug v2.0
	Used by BOTH Legacy UI and Modern UI — single source of truth.

	Flow:
	  1. Client sends vehdebug:saveHandling(modelName, handlingTable)
	  2. SaveEngine.FindHandlingFile() scans all resources for the model
	  3. SaveEngine.UpdateHandlingBlock() rewrites only the matching <Item>
	  4. Backup is written before any changes
	  5. Result (success/fail + message) is sent back to client
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

SaveEngine = {}

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     CONFIGURATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]

-- Candidate sub-paths to check inside every resource folder
local HANDLING_PATHS = {
	"handling.meta",
	"data/handling.meta",
	"data/handling/handling.meta",
	"stream/data/handling.meta",
}

-- How many resources to scan per tick during startup cache build
-- (prevents blocking the server thread on large resource counts)
local CACHE_BATCH_SIZE = 50

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     CACHE
     model (lowercase) -> { resourceName, filePath, absolutePath }
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]

SaveEngine.cache = {}       -- populated at startup + on demand
SaveEngine.cacheBuilt = false

--- Extract all <handlingName> values from a file's content.
--- Returns a table (array) of lowercase model name strings.
local function extractHandlingNames(content)
	local names = {}
	for name in content:gmatch("<handlingName>%s*([%w_]+)%s*</handlingName>") do
		names[#names + 1] = name:lower()
	end
	return names
end

--- Check whether a resource path actually exists on disk.
--- FiveM's LoadResourceFile returns nil when the file does not exist.
local function resourceFileExists(resourceName, relativePath)
	return LoadResourceFile(resourceName, relativePath) ~= nil
end

--- Scan one resource for handling.meta files and populate cache entries.
local function scanResource(resourceName)
	for _, subPath in ipairs(HANDLING_PATHS) do
		local content = LoadResourceFile(resourceName, subPath)
		if content and content ~= "" then
			-- Check this file contains any handling data at all
			if content:find("<handlingName>") then
				local names = extractHandlingNames(content)
				for _, modelName in ipairs(names) do
					if not SaveEngine.cache[modelName] then
						-- Use GetResourcePath to get the absolute OS path
						local resourcePath = GetResourcePath(resourceName)
						if resourcePath and resourcePath ~= "" then
							local absolutePath = resourcePath .. "/" .. subPath
							SaveEngine.cache[modelName] = {
								resourceName = resourceName,
								relativePath = subPath,
								absolutePath = absolutePath,
							}
							print(("[VehDebug/SaveEngine] Cached: %s → %s/%s"):format(
								modelName, resourceName, subPath
							))
						end
					end
				end
			end
		end
	end
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     PUBLIC: BuildCache
     Called once at resource start.
     Iterates all running resources in
     batches to avoid tick stalls.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveEngine.BuildCache()
	local total = GetNumResources()
	print(("[VehDebug/SaveEngine] Starting cache build. %d resources to scan."):format(total))

	local scanned = 0
	Citizen.CreateThread(function()
		for i = 0, total - 1 do
			local resName = GetResourceByFindIndex(i)
			if resName and resName ~= "" and GetResourceState(resName) == "started" then
				local ok, err = pcall(scanResource, resName)
				if not ok then
					print(("[VehDebug/SaveEngine] ERROR scanning resource '%s': %s"):format(resName, tostring(err)))
				end
			end
			scanned = scanned + 1
			-- Yield every batch to avoid blocking
			if scanned % CACHE_BATCH_SIZE == 0 then
				Citizen.Wait(0)
			end
		end
		SaveEngine.cacheBuilt = true
		local count = 0
		for _ in pairs(SaveEngine.cache) do count = count + 1 end
		print(("[VehDebug/SaveEngine] Cache build complete. %d models indexed."):format(count))
	end)
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     PUBLIC: FindHandlingFile
     Returns the cache entry for a model,
     or nil if not found.
     Falls back to a fresh scan if the
     model is not in cache (hot-added
     resources, etc.)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveEngine.FindHandlingFile(modelName)
	-- Trim whitespace and normalise to lowercase for cache lookup
	local key = modelName:match("^%s*(.-)%s*$"):lower()

	-- Fast path: already in cache
	if SaveEngine.cache[key] then
		return SaveEngine.cache[key]
	end

	-- Slow path: live scan (handles resources added after startup)
	print(("[VehDebug/SaveEngine] Cache miss for '%s' — live scan starting."):format(key))
	local total = GetNumResources()
	for i = 0, total - 1 do
		local resName = GetResourceByFindIndex(i)
		if resName and resName ~= "" and GetResourceState(resName) == "started" then
			pcall(scanResource, resName)
			if SaveEngine.cache[key] then
				print(("[VehDebug/SaveEngine] Found '%s' in '%s' via live scan."):format(key, resName))
				return SaveEngine.cache[key]
			end
		end
	end

	return nil
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: WriteBackup
     Writes <absolutePath>.bak before
     any changes are made.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function writeBackup(entry, originalContent)
	-- SaveResourceFile only works within a resource's directory.
	-- We append ".bak" to the relative path.
	local bakPath = entry.relativePath .. ".bak"
	local ok = SaveResourceFile(entry.resourceName, bakPath, originalContent, -1)
	if ok then
		print(("[VehDebug/SaveEngine] Backup written: %s/%s"):format(entry.resourceName, bakPath))
	else
		print(("[VehDebug/SaveEngine] WARNING: Backup FAILED for %s/%s"):format(entry.resourceName, bakPath))
	end
	return ok
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: FormatValue
     Converts a Lua value to the string
     representation expected in XML.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function formatValue(fieldType, value)
	if fieldType == "vector" then
		-- value is expected as "x,y,z" string or {x,y,z}
		if type(value) == "table" then
			return value.x, value.y, value.z
		end
		-- parse "x,y,z"
		local parts = {}
		for part in tostring(value):gmatch("([^,]+)") do
			parts[#parts+1] = tonumber(part) or 0
		end
		return parts[1] or 0, parts[2] or 0, parts[3] or 0
	elseif fieldType == "integer" then
		return tostring(math.floor(tonumber(value) or 0))
	else
		-- float
		local n = tonumber(value)
		if n == nil then return nil end
		-- Format to 6 decimal places max, trimming trailing zeros
		local s = ("%.6f"):format(n)
		s = s:gsub("%.?0+$", "")
		-- Ensure at least one decimal for floats so GTA is happy
		if not s:find("%.") then s = s .. ".0" end
		return s
	end
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: UpdateSingleField
     Rewrites one XML field inside a
     CHandlingData block string.
     Supports:
       <fField value="X.X" />
       <vecField x="X" y="Y" z="Z" />
       <nField value="N" />
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function updateSingleField(block, fieldName, fieldType, value)
	if fieldType == "vector" then
		local x, y, z = formatValue("vector", value)
		-- Match: <vecCentreOfMassOffset x="..." y="..." z="..." />
		-- Preserve surrounding whitespace and attribute order
		local pattern = '(<' .. fieldName .. '%s+x=")([^"]*)(")(%s+y=")([^"]*)(")(%s+z=")([^"]*)(")'
		local replacement = '%1' .. tostring(x) .. '%3%4' .. tostring(y) .. '%6%7' .. tostring(z) .. '%9'
		local new, n = block:gsub(pattern, replacement)
		if n > 0 then return new, true end
		-- Fallback: self-closing with different spacing
		pattern = '(<' .. fieldName .. '[^/]*)x="[^"]*"([^/]*)y="[^"]*"([^/]*)z="[^"]*"'
		replacement = '%1x="' .. tostring(x) .. '"%2y="' .. tostring(y) .. '"%3z="' .. tostring(z) .. '"'
		new, n = block:gsub(pattern, replacement)
		return new, n > 0
	else
		local fmtVal = formatValue(fieldType, value)
		if fmtVal == nil then return block, false end
		-- Match: <fieldName value="X" />  (self-closing)
		local pattern = '(<' .. fieldName .. '%s+value=")([^"]*)(")'
		local new, n = block:gsub(pattern, '%1' .. fmtVal .. '%3')
		return new, n > 0
	end
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     INTERNAL: FindAndUpdateBlock
     Locates the <Item type="CHandlingData">
     block whose <handlingName> matches
     modelName, then applies all fields.

     Strategy: extract just that block,
     update it, splice it back — so every
     other block and all surrounding XML
     is untouched.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
local function findAndUpdateBlock(fileContent, modelName, handlingTable)
	-- Normalise to lowercase for case-insensitive comparison.
	-- handling.meta files can have the name in any case
	-- (e.g. "khangarage_wheelchair", "NALAMO", "Adder").
	local targetLower = modelName:lower()

	local result = fileContent
	local updated = false
	local updatedFields = 0

	local searchPos = 1
	while true do
		-- Find next <Item type="CHandlingData"> opening tag.
		-- %s* handles any whitespace variation around = and quotes.
		local blockStart, blockEnd_tag = result:find('<Item%s+type%s*=%s*"CHandlingData"%s*>', searchPos)
		if not blockStart then break end

		-- Find the matching </Item> that closes this CHandlingData block.
		-- NULL sub-items are self-closing (<Item type="NULL" />) so they
		-- do not produce a </Item>, making the next </Item> ours.
		local closingStart, closingEnd = result:find('</Item>', blockEnd_tag + 1, true)
		if not closingStart then break end

		local block = result:sub(blockStart, closingEnd)

		-- Case-insensitive handlingName match:
		-- extract the name from the block and compare lowercased.
		local blockName = block:match('<handlingName>%s*([%w_]+)%s*</handlingName>')
		if blockName and blockName:lower() == targetLower then
			-- Correct block found — apply all field updates.
			local updatedBlock = block

			for _, field in ipairs(handlingTable) do
				local fieldType  = field.type
				local fieldName  = field.name
				local fieldValue = field.value

				if fieldName and fieldType and fieldValue ~= nil then
					local newBlock, ok = updateSingleField(updatedBlock, fieldName, fieldType, fieldValue)
					if ok then
						updatedBlock = newBlock
						updatedFields = updatedFields + 1
					else
						print(("[VehDebug/SaveEngine] WARNING: Could not update field '%s' for model '%s'"):format(
							fieldName, modelName
						))
					end
				end
			end

			-- Splice the updated block back; leave everything else untouched.
			result = result:sub(1, blockStart - 1) .. updatedBlock .. result:sub(closingEnd + 1)
			updated = true
			break
		end

		searchPos = closingEnd + 1
	end

	return result, updated, updatedFields
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     PUBLIC: SaveHandling
     Main entry point.
     modelName     : string  (e.g. "adder")
     handlingTable : array of { name, type, value }
     Returns: success (bool), message (string)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveEngine.SaveHandling(modelName, handlingTable)
	if not modelName or modelName == "" then
		return false, "No model name provided."
	end
	if not handlingTable or #handlingTable == 0 then
		return false, "No handling data provided."
	end

	-- 1. Find the handling file
	local entry = SaveEngine.FindHandlingFile(modelName)
	if not entry then
		local msg = ("Model '%s' not found in any resource handling.meta."):format(modelName)
		print("[VehDebug/SaveEngine] " .. msg)
		return false, msg
	end

	print(("[VehDebug/SaveEngine] Saving '%s' → %s/%s"):format(
		modelName, entry.resourceName, entry.relativePath
	))

	-- 2. Read current file content
	local content = LoadResourceFile(entry.resourceName, entry.relativePath)
	if not content or content == "" then
		local msg = ("Failed to read file: %s/%s"):format(entry.resourceName, entry.relativePath)
		print("[VehDebug/SaveEngine] ERROR: " .. msg)
		return false, msg
	end

	-- 3. Write backup
	writeBackup(entry, content)

	-- 4. Find & update the correct <Item> block
	local newContent, updated, updatedFields = findAndUpdateBlock(content, modelName, handlingTable)

	if not updated then
		local msg = ("Model '%s' found in cache but <Item> block not matched in file. File may be malformed."):format(modelName)
		print("[VehDebug/SaveEngine] ERROR: " .. msg)
		return false, msg
	end

	-- 5. Write the updated file back
	local writeOk = SaveResourceFile(entry.resourceName, entry.relativePath, newContent, -1)
	if not writeOk then
		local msg = ("Failed to write file: %s/%s — check server file permissions."):format(
			entry.resourceName, entry.relativePath
		)
		print("[VehDebug/SaveEngine] ERROR: " .. msg)
		return false, msg
	end

	local msg = ("Saved %d fields for '%s' in %s/%s"):format(
		updatedFields, modelName, entry.resourceName, entry.relativePath
	)
	print("[VehDebug/SaveEngine] SUCCESS: " .. msg)
	return true, msg
end

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     CACHE INVALIDATION
     Call when a resource is restarted
     so we re-scan it.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveEngine.InvalidateResource(resourceName)
	-- Remove all cache entries belonging to this resource
	local removed = 0
	for key, entry in pairs(SaveEngine.cache) do
		if entry.resourceName == resourceName then
			SaveEngine.cache[key] = nil
			removed = removed + 1
		end
	end
	if removed > 0 then
		print(("[VehDebug/SaveEngine] Invalidated %d cache entries for resource '%s'"):format(removed, resourceName))
	end
	-- Re-scan immediately
	pcall(scanResource, resourceName)
end

-- Hook into resource start/stop events to keep cache fresh
AddEventHandler("onResourceStart", function(resName)
	if resName ~= GetCurrentResourceName() then
		Citizen.SetTimeout(2000, function()  -- small delay so files are fully loaded
			SaveEngine.InvalidateResource(resName)
		end)
	end
end)

AddEventHandler("onResourceStop", function(resName)
	SaveEngine.InvalidateResource(resName)
end)

-- Build cache at startup
AddEventHandler("onResourceStart", function(resName)
	if resName == GetCurrentResourceName() then
		SaveEngine.BuildCache()
	end
end)

--[[ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     PUBLIC: ReadHandling
     Reads the handling.meta for modelName
     and returns a flat table of
     { name, type, value } entries
     parsed directly from the XML file.
     This is the true "original" state —
     unaffected by any live in-game edits.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━]]
function SaveEngine.ReadHandling(modelName)
	local entry = SaveEngine.FindHandlingFile(modelName)
	if not entry then
		return nil, ("No handling file found for '%s'."):format(modelName)
	end

	local content = LoadResourceFile(entry.resourceName, entry.relativePath)
	if not content or content == "" then
		return nil, ("Could not read file '%s/%s'."):format(entry.resourceName, entry.relativePath)
	end

	local targetLower = modelName:lower()

	-- Locate the correct <Item type="CHandlingData"> block
	local searchPos = 1
	while true do
		local blockStart, blockEnd_tag = content:find('<Item%s+type%s*=%s*"CHandlingData"%s*>', searchPos)
		if not blockStart then break end

		local closingStart, closingEnd = content:find('</Item>', blockEnd_tag + 1, true)
		if not closingStart then break end

		local block = content:sub(blockStart, closingEnd)

		local blockName = block:match('<handlingName>%s*([%w_]+)%s*</handlingName>')
		if blockName and blockName:lower() == targetLower then
			-- Parse all fields from the block
			local fields = {}

			-- float / integer: <fieldName value="X" />
			for fname, fval in block:gmatch('<([%w_]+)%s+value%s*=%s*"([^"]*)"') do
				if fname ~= "handlingName" then
					-- Determine type: integer fields start with 'n' or 'i' by GTA convention,
					-- but we rely on Config field list via a lookup on the client side.
					-- Send raw string value; client knows the type from Config.Fields.
					fields[#fields + 1] = { name = fname, value = fval }
				end
			end

			-- vector: <fieldName x="X" y="Y" z="Z" />
			for fname, fx, fy, fz in block:gmatch('<([%w_]+)%s+x%s*=%s*"([^"]*)"[^/]*y%s*=%s*"([^"]*)"[^/]*z%s*=%s*"([^"]*)"') do
				fields[#fields + 1] = { name = fname, value = fx .. "," .. fy .. "," .. fz }
			end

			return fields, nil
		end

		searchPos = closingEnd + 1
	end

	return nil, ("Model '%s' not found in handling file."):format(modelName)
end
