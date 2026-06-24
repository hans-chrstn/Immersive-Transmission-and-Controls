local state = require("state")
local gearbox = require("gearbox")

local function applyDrivetrainForces(dt)
    local vehicle = state.vehicle.active
    if not vehicle then return end
    if state.vehicle.isBike then return end
    if state.gearbox.current == "N" then return end

    local forwardVec = vehicle:GetWorldForward()
    if not forwardVec then return end

    local velocity = vehicle:GetLinearVelocity()
    if not velocity then return end

    local forwardSpeed = velocity.x * forwardVec.x + velocity.y * forwardVec.y + velocity.z * forwardVec.z

    if state.gearbox.current == "R" then
        return
    end

    if forwardSpeed < -0.1 then
        return
    end

    local releaseBlock = false

    if state.gearbox.current == "1" and not state.inputs.accelerate and not state.clutch.isPressed then
        releaseBlock = true
    end

    if state.clutch.isPressed and not state.inputs.accelerate then
        releaseBlock = true
    end

    if releaseBlock then
        gearbox.setGearBlock(false)
    end
end

return {
    applyDrivetrainForces = applyDrivetrainForces
}
