--[[
	cl_config.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Shared configuration for vehicleDebug.

	ACCESS CONTROL
	──────────────
	Config.AllowedLicenses is the SINGLE source of truth for access.
	Add license identifiers here to grant access to a player.

	Format : "license:<40-character hex string>"
	Example: "license:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"

	To find a player's license:
	  • Server console → type "status" and read the identifiers column
	  • Or use: print(GetPlayerIdentifierByType(source, "license"))

	Client uses this list for UX gating (deny before UI opens).
	Server uses the SAME list as the hard security gate.
	No ACE. No steam. No discord. License only.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

Config = {}

-- ── ACCESS CONTROL ────────────────────────────────────────────────
Config.AllowedLicenses = {
	-- "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
	-- "license:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
}

-- Message shown client-side to players not on the allowlist.
Config.AccessDeniedMessage = "Du har ikke tilgang til Vehicle Debugger."

-- ── DEBUG ─────────────────────────────────────────────────────────
-- Set to true to enable verbose logging in F8 and server console.
-- Set to false in production to suppress routine messages.
Config.Debug = false

-- ── UI / GENERAL SETTINGS ─────────────────────────────────────────
-- Keybind for Legacy UI open/close.
-- Full reference: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
Config.Keybind = "rmenu"        -- rmenu = Right Alt | lmenu = Left Alt

-- Whether the legacy UI starts in the enabled state.
Config.EnabledByDefault = true

-- Decimal rounding precision used when displaying float values.
Config.Precision = 100.0

-- ── HANDLING FIELDS ───────────────────────────────────────────────
-- min/max/step are consumed only by the Modern UI slider renderer.
-- Legacy UI ignores them and renders plain <input> fields.
Config.Fields = {
	{ name = "fMass", type = "float", min = 100.0, max = 10000.0, step = 10.0, category = "Mass & Damage", description = [[
		The weight of the vehicle in kilograms.
		<ul><li>Used in collision calculations against other vehicles and non-static objects.</li></ul>
	]] },
	{ name = "fInitialDragCoeff", type = "float", min = 0.0, max = 150.0, step = 0.5, category = "Engine & Acceleration", description = [[
		Aerodynamic drag coefficient. Value: 10–120.
	]] },
	{ name = "fDownforceModifier", type = "float", min = 0.0, max = 100.0, step = 0.5, category = "Engine & Acceleration" },
	{ name = "fPercentSubmerged", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Mass & Damage", description = [[
		Float height percentage before sinking. Default ~0.85 for land vehicles.
	]] },
	{ name = "vecCentreOfMassOffset", type = "vector", category = "Mass & Damage", description = [[
		Centre of gravity offset in metres. X = left/right, Y = front/rear, Z = up/down.
	]] },
	{ name = "vecInertiaMultiplier", type = "vector", category = "Mass & Damage", description = [[
		Inertia multiplier. X = Pitch, Y = Roll, Z = Yaw. Default ~1.0.
	]] },
	{ name = "fDriveBiasFront", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Engine & Acceleration", description = [[
		Drive layout: 0.0 = RWD, 1.0 = FWD, 0.01–0.99 = AWD, 0.5 = equal AWD.
	]] },
	{ name = "nInitialDriveGears", type = "integer", min = 1, max = 10, step = 1, category = "Engine & Acceleration", description = [[
		Number of forward gears.
	]] },
	{ name = "fInitialDriveForce", type = "float", min = 0.01, max = 4.0, step = 0.01, category = "Engine & Acceleration", description = [[
		Drive force multiplier. 1.0 = unmodified. &gt;1.0 = more power.
	]] },
	{ name = "fDriveInertia", type = "float", min = 0.01, max = 4.0, step = 0.01, category = "Engine & Acceleration", description = [[
		Engine rev speed. Bigger = quicker redline.
	]] },
	{ name = "fClutchChangeRateScaleUpShift", type = "float", min = 0.1, max = 10.0, step = 0.1, category = "Engine & Acceleration", description = [[
		Clutch speed on up-shifts. Bigger = faster.
	]] },
	{ name = "fClutchChangeRateScaleDownShift", type = "float", min = 0.1, max = 10.0, step = 0.1, category = "Engine & Acceleration", description = [[
		Clutch speed on down-shifts. Bigger = faster.
	]] },
	{ name = "fInitialDriveMaxFlatVel", type = "float", min = 0.0, max = 500.0, step = 1.0, category = "Engine & Acceleration", description = [[
		Speed at redline in top gear. Multiply by 0.82 for mph, 1.32 for kph.
	]] },
	{ name = "fBrakeForce", type = "float", min = 0.01, max = 4.0, step = 0.01, category = "Braking", description = [[
		Brake deceleration multiplier. Bigger = harder braking.
	]] },
	{ name = "fBrakeBiasFront", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Braking", description = [[
		Brake bias: 0.0 = rear, 1.0 = front, 0.5 = equal.
	]] },
	{ name = "fHandBrakeForce", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Braking", description = [[
		Handbrake force. Bigger = harder.
	]] },
	{ name = "fSteeringLock", type = "float", min = 0.1, max = 2.0, step = 0.01, category = "Traction & Grip", description = [[
		Steering angle multiplier. High values cause easy spin-outs.
	]] },
	{ name = "fTractionCurveMax", type = "float", min = 0.0, max = 5.0, step = 0.01, category = "Traction & Grip", description = [[
		Cornering grip (off-pedal).
	]] },
	{ name = "fTractionCurveMin", type = "float", min = 0.0, max = 5.0, step = 0.01, category = "Traction & Grip", description = [[
		Accelerating/braking grip (on-pedal).
	]] },
	{ name = "fTractionCurveLateral", type = "float", min = 0.0, max = 45.0, step = 0.1, category = "Traction & Grip", description = [[
		Slip angle / lateral traction curve shape.
	]] },
	{ name = "fTractionSpringDeltaMax", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Traction & Grip", description = [[
		Distance above ground at which traction is lost.
	]] },
	{ name = "fLowSpeedTractionLossMult", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Traction & Grip", description = [[
		Wheelspin at launch. 0.0 = minimal, higher = more burnout.
	]] },
	{ name = "fCamberStiffnesss", type = "float", min = -2.0, max = 2.0, step = 0.01, category = "Traction & Grip", description = [[
		Drift grip modifier. &gt;0 = hold slide angle, &lt;0 = oversteer.
	]] },
	{ name = "fTractionBiasFront", type = "float", min = 0.01, max = 0.99, step = 0.01, category = "Traction & Grip", description = [[
		Traction distribution: 0.01 = rear, 0.99 = front, 0.5 = equal.
	]] },
	{ name = "fTractionLossMult", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Traction & Grip", description = [[
		Traction loss multiplier on non-asphalt surfaces.
	]] },
	{ name = "fSuspensionForce", type = "float", min = 0.0, max = 10.0, step = 0.05, category = "Suspension", description = [[
		Suspension strength. 1 / (Force * Wheels) = lower force limit at full extension.
	]] },
	{ name = "fSuspensionCompDamp", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Suspension", description = [[
		Compression damping. Bigger = stiffer.
	]] },
	{ name = "fSuspensionReboundDamp", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Suspension", description = [[
		Rebound damping.
	]] },
	{ name = "fSuspensionUpperLimit", type = "float", min = -1.0, max = 1.0, step = 0.01, category = "Suspension", description = [[
		Upper wheel travel limit from rest.
	]] },
	{ name = "fSuspensionLowerLimit", type = "float", min = -1.0, max = 0.0, step = 0.01, category = "Suspension", description = [[
		Lower wheel travel limit from rest.
	]] },
	{ name = "fSuspensionRaise", type = "float", min = -1.0, max = 1.0, step = 0.01, category = "Suspension", description = [[
		Suspension ride height offset.
	]] },
	{ name = "fSuspensionBiasFront", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Suspension", description = [[
		Stiffness bias: &gt;0.5 = stiffer front, &lt;0.5 = stiffer rear.
	]] },
	{ name = "fAntiRollBarForce", type = "float", min = 0.0, max = 5.0, step = 0.05, category = "Suspension", description = [[
		Anti-roll bar strength. Larger = less body roll.
	]] },
	{ name = "fAntiRollBarBiasFront", type = "float", min = 0.0, max = 1.0, step = 0.01, category = "Suspension", description = [[
		Anti-roll bar bias: 0 = front, 1 = rear.
	]] },
	{ name = "fRollCentreHeightFront", type = "float", min = -0.5, max = 0.5, step = 0.01, category = "Suspension", description = [[
		Front roll centre height. Larger = less rollover. Recommended ±0.15.
	]] },
	{ name = "fRollCentreHeightRear", type = "float", min = -0.5, max = 0.5, step = 0.01, category = "Suspension", description = [[
		Rear roll centre height. High positive = wheelie potential. Recommended ±0.15.
	]] },
	{ name = "fCollisionDamageMult", type = "float", min = 0.0, max = 10.0, step = 0.1, category = "Mass & Damage", description = [[
		Collision damage multiplier.
	]] },
	{ name = "fWeaponDamageMult", type = "float", min = 0.0, max = 10.0, step = 0.1, category = "Mass & Damage", description = [[
		Weapon damage multiplier.
	]] },
	{ name = "fDeformationDamageMult", type = "float", min = 0.0, max = 10.0, step = 0.1, category = "Mass & Damage", description = [[
		Deformation damage multiplier.
	]] },
	{ name = "fEngineDamageMult", type = "float", min = 0.0, max = 10.0, step = 0.1, category = "Mass & Damage", description = [[
		Engine damage multiplier.
	]] },
	{ name = "fPetrolTankVolume", type = "float", min = 0.0, max = 100.0, step = 0.5, category = "Mass & Damage", description = [[
		Petrol volume lost after tank damage.
	]] },
	{ name = "fOilVolume", type = "float", min = 0.0, max = 10.0, step = 0.1, category = "Mass & Damage", description = [[
		Oil volume.
	]] },
	{ name = "fSeatOffsetDistX", type = "float", min = -2.0, max = 2.0, step = 0.01, category = "Mass & Damage", description = [[
		Driver seat X offset (driver → passenger direction).
	]] },
	{ name = "fSeatOffsetDistY", type = "float", min = -2.0, max = 2.0, step = 0.01, category = "Mass & Damage", description = [[
		Driver seat Y offset (trunk → hood direction).
	]] },
	{ name = "fSeatOffsetDistZ", type = "float", min = -2.0, max = 2.0, step = 0.01, category = "Mass & Damage", description = [[
		Driver seat Z offset (undercarriage → roof direction).
	]] },
	{ name = "nMonetaryValue", type = "integer", min = 0, max = 2000000, step = 1000, category = "Mass & Damage" },
}

-- ── NATIVE TYPE HANDLERS ──────────────────────────────────────────
-- These are client-only; the server uses sv_config.lua for type info.
Config.Types = {
	["float"] = {
		getter = GetVehicleHandlingFloat,
		setter = function(vehicle, _type, fieldName, value)
			local v = tonumber(value)
			if v == nil then error("value not a number") end
			SetVehicleHandlingFloat(vehicle, _type, fieldName, v + 0.0)
		end,
	},
	["integer"] = {
		getter = GetVehicleHandlingInt,
		setter = function(vehicle, _type, fieldName, value)
			local v = tonumber(value)
			if v == nil then error("value not a number") end
			SetVehicleHandlingInt(vehicle, _type, fieldName, math.floor(v))
		end,
	},
	["vector"] = {
		getter = GetVehicleHandlingVector,
		setter = function(vehicle, _type, fieldName, value)
			local axes, vec = 1, {}
			for axis in value:gmatch("([^,]+)") do
				vec[axes] = tonumber(axis)
				axes = axes + 1
			end
			for i = 1, 3 do
				if vec[i] == nil then error("invalid vector axis " .. i) end
			end
			SetVehicleHandlingVector(vehicle, _type, fieldName, vector3(vec[1], vec[2], vec[3]))
		end,
	},
}
