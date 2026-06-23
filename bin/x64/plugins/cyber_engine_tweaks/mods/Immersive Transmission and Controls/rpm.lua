local state = require("state")
local logger = require("logger")

local axleRatio = nil
local tireDiameterInches = nil
local calibrated = false

local function getTireDiameter()
    if tireDiameterInches then return tireDiameterInches end
    local vehicle = state.vehicle.active
    if not vehicle then return nil end
    local ok, result = pcall(function()
        local record = vehicle:GetRecord()
        if not record then return nil end
        local dimSetup = record:VehWheelDimensionsSetup()
        if not dimSetup then return nil end
        local frontPreset = dimSetup:FrontPreset()
        if not frontPreset then return nil end
        local radiusM = frontPreset:TireRadius()
        if not radiusM or radiusM <= 0 then return nil end
        return (radiusM * 2.0) / 0.0254
    end)
    if ok and result then
        tireDiameterInches = result
        logger.logDebug(string.format("[RPM] Tire diameter=%.1f inches", result))
    end
    return result
end

local function calibrate()
    if calibrated then return true end
    local vehicle = state.vehicle.active
    local bb = state.vehicle.bb
    if not vehicle or not bb then return false end

    local nativeRPM = bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue)
    local speedMS = vehicle:GetCurrentSpeed()
    if not nativeRPM or nativeRPM < 300 or not speedMS or speedMS < 2.0 then return false end

    local gearIdx = tonumber(state.gearbox.current)
    if not gearIdx or gearIdx < 1 then return false end
    local gearRec = state.vehicle.gears[gearIdx]
    if not gearRec then return false end

    local diameter = getTireDiameter()
    if not diameter then return false end

    local speedMPH = speedMS * 2.23694
    local gearRatio = gearRec.torqueMultiplier
    local ratio = (nativeRPM * diameter) / (speedMPH * gearRatio * 336.0)

    if ratio > 0.5 and ratio < 20.0 then
        axleRatio = ratio
        calibrated = true
        logger.logDebug(string.format("[RPM] Calibrated axle=%.2f dia=%.1f gear=%d RPM=%.0f speed=%.1fmph", axleRatio, diameter, gearIdx, nativeRPM, speedMPH))
        return true
    end
    return false
end

local function get()
    if not state.vehicle.active then return 0 end
    if not calibrate() then
        local bb = state.vehicle.bb
        return bb and bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue) or 0
    end

    local speedMS = state.vehicle.active:GetCurrentSpeed() or 0
    local gearIdx = tonumber(state.gearbox.current)
    if state.gearbox.current == "R" then gearIdx = 0 end
    if not gearIdx then gearIdx = 1 end
    local gearRec = state.vehicle.gears[gearIdx]
    if not gearRec then return 0 end

    local diameter = tireDiameterInches or 26.0
    local ratio = axleRatio or 3.5
    local speedMPH = speedMS * 2.23694
    local gearRatio = gearRec.torqueMultiplier
    local rpm = (speedMPH * gearRatio * ratio * 336.0) / diameter
    return math.max(0, rpm)
end

local function getMax()
    local bb = state.vehicle.bb
    return bb and bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax) or 8000
end

local function reset()
    axleRatio = nil
    tireDiameterInches = nil
    calibrated = false
end

return {
    get = get,
    getMax = getMax,
    reset = reset
}
