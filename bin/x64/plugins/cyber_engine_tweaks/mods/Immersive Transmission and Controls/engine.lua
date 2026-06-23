local state = require("state")
local logger = require("logger")

local function stall()
    if not state.vehicle.active then return end
    state.engine.isStalled = true
    pcall(function()
        local comp = state.vehicle.active:GetVehicleComponent()
        if comp then
            local ps = comp:GetVehicleControllerPS()
            if ps then
                ps:SetState(vehicleEState.Disabled)
            end
        end
    end)
    state.vehicle.active:TurnEngineOn(false)
    logger.logDebug("[ENGINE] Stalled")
end

local function restart()
    if not state.vehicle.active then return end
    state.engine.isStalled = false
    pcall(function()
        local comp = state.vehicle.active:GetVehicleComponent()
        if comp then
            local ps = comp:GetVehicleControllerPS()
            if ps then
                ps:SetState(vehicleEState.On)
            end
        end
    end)
    state.vehicle.active:TurnVehicleOn(true)
    state.vehicle.active:TurnEngineOn(true)
    logger.logDebug("[ENGINE] Restarted")
end

return {
    stall = stall,
    restart = restart
}
