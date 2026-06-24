local state = require("state")
local utilities = require("utilities")
local logger = require("logger")

local LIMITER_THRESHOLD = 0.98

local function calculateLimiterForce(dt)
    local vehicle = state.vehicle.active
    if not vehicle then return end
    if state.gearbox.current == "N" then return end
    if state.vehicle.isBike then return end
    if state.clutch.isPressed then return end

    local gearIdx = utilities.getGearIdx()
    if not gearIdx then return end

    local selectedGear = state.vehicle.gears[gearIdx]
    if not selectedGear then return end

    local maxSpeed = selectedGear.maxSpeed
    local currentSpeed = vehicle:GetCurrentSpeed()

    local comp = vehicle:GetVehicleComponent()
    local ps = comp and comp:GetVehicleControllerPS()

    if currentSpeed >= maxSpeed * LIMITER_THRESHOLD then
        if ps and not state.engine.isStalled then
            ps:SetState(vehicleEState.Disabled)
            logger.logDebug(string.format(
                "[LIMITER] gear=%d speed=%.1f max=%.1f FUEL CUT",
                gearIdx, currentSpeed * 3.6, maxSpeed * 3.6
            ))
        end
    else
        if ps and ps:GetState() == vehicleEState.Disabled and not state.engine.isStalled then
            ps:SetState(vehicleEState.On)
        end
    end
end

return {
    calculateLimiterForce = calculateLimiterForce
}
