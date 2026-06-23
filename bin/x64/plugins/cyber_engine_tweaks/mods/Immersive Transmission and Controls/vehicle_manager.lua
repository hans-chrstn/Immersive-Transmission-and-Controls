local state = require("state")
local settings = require("settings.init")
local logger = require("logger")
local gearCache = require("gear_cache")

local function getActiveVehicle()
    if not GetPlayer() then return nil end
    local success, mountedVehicle = pcall(function() return GetPlayer():GetMountedVehicle() end)
    if not success or not mountedVehicle then return nil end
    if mountedVehicle:IsA('vehicleAVBaseObject') or mountedVehicle:IsA('vehicleTankBaseObject') then
        return nil
    end

    if mountedVehicle:IsA('vehicleBikeBaseObject') then
        state.vehicle.isBike = true
    else
        state.vehicle.isBike = false
    end
    return mountedVehicle
end

local function isEngineOn()
    if not state.vehicle.active then return false end
    if settings.evsIntegration then
        local success, result = pcall(function()
            local comp = state.vehicle.active:GetVehicleComponent()
            if comp then
                local ps = comp:GetPS()
                if ps then
                    return ps.m_hgyi56_EVS_engineState
                end
            end
            return nil
        end)
        if success and result ~= nil then
            return result
        end
    end
    local success, result = pcall(function() return state.vehicle.active:IsEngineTurnedOn() end)
    if success then
        return result
    end
    local controllerPS = state.vehicle.active:GetVehicleComponent():GetVehicleControllerPS()
    if not controllerPS then return false end
    local engineState = controllerPS:GetState()
    return engineState ~= vehicleEState.Default
end

local function cacheVehicleGearData()
    if not state.vehicle.active then return end
    state.vehicle.gears, state.vehicle.mass = gearCache.getGears(state.vehicle.active, settings.gearSpeedScale)
    state.vehicle.isBike = state.vehicle.active:IsA('vehicleBikeBaseObject')
    logger.logDebug(string.format("Cached data for vehicle. Mass=%.1f kg, GearsCount=%d, SpeedScale=%.2f", state.vehicle.mass, #state.vehicle.gears, settings.gearSpeedScale))
end

return {
    getActiveVehicle = getActiveVehicle,
    isEngineOn = isEngineOn,
    cacheVehicleGearData = cacheVehicleGearData
}
