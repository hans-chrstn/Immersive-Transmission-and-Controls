local state = require("state")

local function applyDrivetrainForces(dt)
    local vehicle = state.vehicle.active
    if not vehicle then return end
    if state.gearbox.current == "N" then return end
    if state.vehicle.isBike then return end
    if state.engine.isStalled then return end

    if state.gearbox.current == "1" and state.vehicle.bb then
        if state.inputs.accelerate then
            if not state.gearbox.blockChange then
                GameOptions.SetBool("Vehicle", "BlockChangeGear", true)
                state.gearbox.blockChange = true
            end
        else
            if state.gearbox.blockChange then
                GameOptions.SetBool("Vehicle", "BlockChangeGear", false)
                state.gearbox.blockChange = false
            end
        end
    end
end

return {
    applyDrivetrainForces = applyDrivetrainForces
}
