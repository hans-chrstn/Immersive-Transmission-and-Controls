local state = require("state")

local function applyDrivetrainForces(dt)
    local vehicle = state.vehicle.active
    if not vehicle then return end
    if state.gearbox.current == "N" then return end
    if state.vehicle.isBike then return end
    local releaseBlock = false

    if state.gearbox.current == "1" and not state.inputs.accelerate and not state.clutch.isPressed then
        releaseBlock = true
    end

    if state.clutch.isPressed and not state.inputs.accelerate then
        releaseBlock = true
    end

    if releaseBlock and state.gearbox.blockChange then
        GameOptions.SetBool("Vehicle", "BlockChangeGear", false)
        state.gearbox.blockChange = false
    end
end

return {
    applyDrivetrainForces = applyDrivetrainForces
}
