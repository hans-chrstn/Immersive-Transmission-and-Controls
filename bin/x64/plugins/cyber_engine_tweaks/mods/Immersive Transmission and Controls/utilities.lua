local state = require("state")
local settings = require("settings.init")

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

return {
    isThrottlePressed = isThrottlePressed,
    getForwardSpeed = getForwardSpeed
}
