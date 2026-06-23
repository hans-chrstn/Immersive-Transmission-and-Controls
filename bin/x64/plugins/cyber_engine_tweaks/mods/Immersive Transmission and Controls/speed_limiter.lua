local state = require("state")
local settings = require("settings")
local logger = require("logger")

local function getGearIdx()
    if settings.transmissionMode == "Manual" then
        if state.gearbox.current == "R" then
            return 0
        elseif state.gearbox.current ~= "N" then
            return tonumber(state.gearbox.current)
        end
    elseif state.manualOverride.active then
        return state.gearbox.target
    else
        local nativeGear = state.vehicle.bb and state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue) or -1
        if state.gearbox.current == "R" or nativeGear == 0 then
            return 0
        elseif state.gearbox.current == "D" then
            return math.max(1, nativeGear)
        end
    end
    return nil
end

local function calculateLimiterForce(dt)
    local vehicle = state.vehicle.active
    if not vehicle then return end
    if state.gearbox.current == "N" then return end
    if state.vehicle.isBike then return end
    if state.clutch.isPressed then return end

    local gearIdx = getGearIdx()
    if not gearIdx then return end

    local selectedGear = state.vehicle.gears[gearIdx]
    if not selectedGear then return end

    local maxSpeed = selectedGear.maxSpeed
    local currentSpeed = vehicle:GetCurrentSpeed()

    if currentSpeed >= maxSpeed * 0.98 then
        vehicle:ForceBrakesFor(dt)
        logger.logDebug(string.format(
            "[LIMITER] gear=%d speed=%.1f max=%.1f BRAKING",
            gearIdx, currentSpeed * 3.6, maxSpeed * 3.6
        ))
    end
end

return {
    calculateLimiterForce = calculateLimiterForce
}
