local state = require("state")
local settings = require("settings")
local logger = require("logger")
local gearCache = require("gear_cache")

local function getActiveVehicle()
    if not GetPlayer() then return nil end
    local success, mountedVehicle = pcall(function() return GetPlayer():GetMountedVehicle() end)
    if not success or not mountedVehicle then return nil end
    if mountedVehicle:IsA('vehicleAVBaseObject') or mountedVehicle:IsA('vehicleTankBaseObject') then
        return nil
    end
    return mountedVehicle
end

local function isEngineOn()
    if not state.activeVehicle then return false end
    if settings.evsIntegration then
        local success, result = pcall(function()
            local comp = state.activeVehicle:GetVehicleComponent()
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
    local success, result = pcall(function() return state.activeVehicle:IsEngineTurnedOn() end)
    if success then
        return result
    end
    local controllerPS = state.activeVehicle:GetVehicleComponent():GetVehicleControllerPS()
    if not controllerPS then return false end
    local engineState = controllerPS:GetState()
    return engineState ~= vehicleEState.Default
end

local function cacheVehicleGearData()
    if not state.activeVehicle then return end
    state.vehicleGears, state.vehicleMass = gearCache.getGears(state.activeVehicle, settings.gearSpeedScale)
    logger.logDebug(string.format("Cached data for vehicle. Mass=%.1f kg, GearsCount=%d, SpeedScale=%.2f", state.vehicleMass, #state.vehicleGears, settings.gearSpeedScale))
end

return {
    getActiveVehicle = getActiveVehicle,
    isEngineOn = isEngineOn,
    cacheVehicleGearData = cacheVehicleGearData
}
