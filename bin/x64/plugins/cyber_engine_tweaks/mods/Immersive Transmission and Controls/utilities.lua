local state = require("state")
local settings = require("settings")

local function isThrottlePressed()
    if state.gearbox.current == "R" then
        return state.inputs.decelerate
    elseif state.gearbox.current == "N" then
        return state.inputs.accelerate or state.inputs.decelerate
    else
        return state.inputs.accelerate
    end
end

local function getForwardSpeed(vehicle)
    if not vehicle then
        vehicle = state.vehicle.active
        if not vehicle then return 0.0 end
    end
    local velocity = vehicle:GetLinearVelocity()
    local forwardVec = vehicle:GetWorldForward()
    return velocity.x * forwardVec.x + velocity.y * forwardVec.y + velocity.z * forwardVec.z
end

local function getGearIdx()
    if settings.transmissionMode == "Manual" then
        if state.gearbox.current == "R" then return 0
        elseif state.gearbox.current ~= "N" then return tonumber(state.gearbox.current) end
    elseif state.manualOverride.active then
        return state.gearbox.target
    else
        local nativeGear = state.vehicle.bb and state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue) or -1
        if state.gearbox.current == "R" or nativeGear == 0 then return 0
        elseif state.gearbox.current == "D" then return math.max(1, nativeGear) end
    end
    return nil
end

return {
    isThrottlePressed = isThrottlePressed,
    getForwardSpeed = getForwardSpeed,
    getGearIdx = getGearIdx
}
