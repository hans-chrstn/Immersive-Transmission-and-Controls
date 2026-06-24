local state = require("state")
local logger = require("logger")

local MPH_CONV = 2.23694
local METER_TO_INCH = 0.0254
local RPM_CONSTANT = 336.0
local FALLBACK_DIAMETER = 26.0
local FALLBACK_AXLE = 3.5
local IDLE_RPM = 900.0
local CALIBRATE_MIN_RPM = 300
local CALIBRATE_MIN_SPEED = 2.0
local AXLE_RATIO_MIN = 0.5
local AXLE_RATIO_MAX = 20.0
local TRANSITION_SPEED = 5.0
local DT_DEFAULT = 0.083
local DT_MAX = 0.2

local axleRatio = nil
local tireDiameterInches = nil
local calibrated = false
local simulatedRPM = 0.0

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
        return (radiusM * 2.0) / METER_TO_INCH
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
    if not nativeRPM or nativeRPM < CALIBRATE_MIN_RPM or not speedMS or speedMS < CALIBRATE_MIN_SPEED then return false end

    local gearIdx = tonumber(state.gearbox.current)
    if not gearIdx or gearIdx < 1 then return false end
    local gearRec = state.vehicle.gears[gearIdx]
    if not gearRec then return false end

    local diameter = getTireDiameter()
    if not diameter then return false end

    local speedMPH = speedMS * MPH_CONV
    local gearRatio = gearRec.torqueMultiplier or 1.0
    local ratio = (nativeRPM * diameter) / (speedMPH * gearRatio * RPM_CONSTANT)

    if ratio > AXLE_RATIO_MIN and ratio < AXLE_RATIO_MAX then
        axleRatio = ratio
        simulatedRPM = nativeRPM
        calibrated = true
        logger.logDebug(string.format("[RPM] Calibrated axle=%.2f dia=%.1f RPM=%.0f", axleRatio, diameter, nativeRPM))
        return true
    end
    return false
end

local function computeWheelRPM()
    local speedMS = state.vehicle.active:GetCurrentSpeed() or 0
    local gearIdx = tonumber(state.gearbox.current)
    if state.gearbox.current == "R" then gearIdx = 0 end
    if not gearIdx then gearIdx = 1 end
    local gearRec = state.vehicle.gears[gearIdx]
    if not gearRec then return 0 end
    local diameter = tireDiameterInches or FALLBACK_DIAMETER
    local ratio = axleRatio or FALLBACK_AXLE
    local speedMPH = speedMS * MPH_CONV
    local gearRatio = gearRec.torqueMultiplier or 1.0
    return (speedMPH * gearRatio * ratio * RPM_CONSTANT) / diameter
end

local function getCoupling()
    if state.gearbox.current == "N" then return 0.0 end
    if state.clutch.isPressed then return 0.0 end
    return state.clutch.engagement
end

local function getMax()
    local bb = state.vehicle.bb
    return bb and bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax) or 8000
end

local function getThrottleTarget()
    local throttle = state.inputs.accelerateVal or 0.0
    if state.gearbox.current == "R" then
        throttle = state.inputs.decelerateVal or 0.0
    end
    local maxRPM = getMax()
    return IDLE_RPM + throttle * (maxRPM - IDLE_RPM)
end

local function get(dt)
    if not state.vehicle.active then return 0 end

    if state.engine.isStalled then
        simulatedRPM = 0.0
        return 0
    end

    calibrate()
    if not calibrated then
        local bb = state.vehicle.bb
        return bb and bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue) or 0
    end

    local coupling = getCoupling()
    local wheelRPM = computeWheelRPM()
    local throttleTarget = getThrottleTarget()

    local targetRPM
    if coupling >= 1.0 then
        targetRPM = wheelRPM
    else
        targetRPM = coupling * math.max(wheelRPM, throttleTarget) + (1.0 - coupling) * throttleTarget
    end

    local dtClamped = math.min(dt or DT_DEFAULT, DT_MAX)
    simulatedRPM = simulatedRPM + (targetRPM - simulatedRPM) * math.min(TRANSITION_SPEED * dtClamped, 1.0)
    if simulatedRPM ~= simulatedRPM then simulatedRPM = 0 end

    return math.max(0, simulatedRPM)
end

local function reset()
    axleRatio = nil
    tireDiameterInches = nil
    calibrated = false
    simulatedRPM = 0.0
end

return {
    get = get,
    getMax = getMax,
    reset = reset
}
