local state = require("state")
local settings = require("settings")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")

local function setHUDFact(name, value)
    pcall(function()
        Game.SetFactValue(name, math.floor(value))
    end)
end

local HUD_THROTTLE_SECS = 0.25
local ZONE_LOG_INTERVAL = 1.0
local INITIAL_FORCE_DELAY = 1.0
local FALLBACK_MAX_RPM = 8000.0

local hudRefreshTimer = 0.0
local zoneLogTimer = 0.0


if state.lastSentHUD.visible == -1 then
    hudRefreshTimer = HUD_THROTTLE_SECS + INITIAL_FORCE_DELAY
end

local function updateHUDState(dt)

    dt = dt or 0.083
    hudRefreshTimer = hudRefreshTimer + dt

    if hudRefreshTimer < HUD_THROTTLE_SECS and state.vehicle.isMounted then
        return
    end
    hudRefreshTimer = 0.0

    local showHUD = settings.showHUD and state.vehicle.isMounted and not state.isOverlayOpen
    local showHUDVal = showHUD and 1 or 0
    local mountedVal = state.vehicle.isMounted and 1 or 0
    local ccVal = settings.cruiseControlEnabled and 1 or 0
    local isEngineOn = false
    if state.vehicle.isMounted and state.vehicle.active then
        isEngineOn = vehicleManager.isEngineOn() and not state.engine.isStalled
    end
    local engineVal = isEngineOn and 1 or 0
    local modeVal = 0
    if settings.transmissionMode == "Manual" then
        modeVal = 1
    elseif state.manualOverride.active then
        modeVal = 2
    end
    local gearVal = 1
    local currentGear = 1
    if state.vehicle.bb then
        currentGear = state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    end
    if settings.transmissionMode == "Manual" then
        if state.gearbox.current == "R" then
            gearVal = 0
        elseif state.gearbox.current == "N" then
            gearVal = 1
        else
            local gearNum = tonumber(state.gearbox.current) or 1
            gearVal = gearNum + 1
        end
    else
        if state.gearbox.current == "N" then
            gearVal = 1
        elseif state.gearbox.current == "R" or currentGear == 0 then
            gearVal = 0
        elseif state.gearbox.current == "D" then
            local displayGear = currentGear
            if not displayGear or displayGear <= 0 then displayGear = 1 end
            if state.manualOverride.active then
                gearVal = 200 + displayGear
            else
                gearVal = 100 + displayGear
            end
        end
    end
    local diffLocked = not GameOptions.GetBool("Vehicle", "UseDifferential")
    local diffLockedVal = diffLocked and 1 or 0
    local isHandbraking = state.inputs.handbrakeToggled or false
    if not isHandbraking and state.vehicle.bb then
        isHandbraking = state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end
    local handbrakeVal = isHandbraking and 1 or 0
    local clutchVal = state.clutch.isPressed and 1 or 0
    local footBrakeVal = state.inputs.footBrake and 1 or 0
    local posXVal = math.floor((settings.hudX or 0.80) * 100)
    local posYVal = math.floor((settings.hudY or 0.82) * 100)

    local speedVal = 0
    local rawRPM = 0
    local rpmPercent = 0
    local rpmZone = 1
    if state.vehicle.bb then
        rawRPM = math.floor(state.vehicle.bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue))
        local maxRPM = state.vehicle.bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
        if not maxRPM or maxRPM <= 0 then maxRPM = FALLBACK_MAX_RPM end
        rpmPercent = math.floor((rawRPM / maxRPM) * 100)
    end
    if state.vehicle.active then
        local success, vel = pcall(function() return state.vehicle.active:GetLinearVelocity() end)
        if success and vel then
            local mps = math.sqrt((vel.x or 0)^2 + (vel.y or 0)^2 + (vel.z or 0)^2)
            speedVal = math.floor(mps * 3.6 + 0.5)
        else
            local ok, spd = pcall(function() return state.vehicle.active:GetCurrentSpeed() end)
            speedVal = ok and math.floor((spd or 0) * 3.6) or 0
        end
        local gearIdx = nil
        if settings.transmissionMode == "Manual" then
            if state.gearbox.current == "R" then gearIdx = 0
            elseif state.gearbox.current ~= "N" then gearIdx = tonumber(state.gearbox.current) end
        elseif state.gearbox.current == "D" then
            local nativeGear = state.vehicle.bb and state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue) or 1
            gearIdx = math.max(1, nativeGear)
        end
        if gearIdx then
            local gearRec = state.vehicle.gears[gearIdx]
            if gearRec then
                local s = math.max(0.0, state.vehicle.active:GetCurrentSpeed())
                local redlineMin = gearRec.redlineMin or gearRec.maxSpeed or 999.0
                local normalMax = gearRec.normalMaxSpeed or 999.0
                local minSpd = gearRec.minSpeed or 0.0
                if s >= redlineMin then
                    rpmZone = 3
                elseif s >= normalMax then
                    rpmZone = 2
                elseif s >= minSpd then
                    rpmZone = 1
                else
                    rpmZone = 0
                end
                zoneLogTimer = zoneLogTimer + HUD_THROTTLE_SECS
                if zoneLogTimer >= ZONE_LOG_INTERVAL then
                    zoneLogTimer = 0.0
                    logger.logDebug(string.format("[HUD] zone=%d gear=%d speed=%.1f min=%.1f normal=%.1f redline=%.1f", rpmZone, gearIdx, s * 3.6, minSpd * 3.6, normalMax * 3.6, redlineMin * 3.6))
                end
            end
        end
    end

    if showHUDVal ~= state.lastSentHUD.visible or
       modeVal ~= state.lastSentHUD.mode or
       gearVal ~= state.lastSentHUD.gear or
       diffLockedVal ~= state.lastSentHUD.diff or
       handbrakeVal ~= state.lastSentHUD.handbrake or
       clutchVal ~= state.lastSentHUD.clutch or
       footBrakeVal ~= state.lastSentHUD.brake or
       posXVal ~= state.lastSentHUD.posX or
       posYVal ~= state.lastSentHUD.posY or
       ccVal ~= state.lastSentHUD.cc or
       engineVal ~= state.lastSentHUD.engine or
       mountedVal ~= state.lastSentHUD.mounted or
       speedVal ~= state.lastSentHUD.speed or
       rpmPercent ~= state.lastSentHUD.rpm or
       rawRPM ~= state.lastSentHUD.rpmRaw or
       rpmZone ~= state.lastSentHUD.rpmZone then

        state.lastSentHUD.visible = showHUDVal
        state.lastSentHUD.mode = modeVal
        state.lastSentHUD.gear = gearVal
        state.lastSentHUD.diff = diffLockedVal
        state.lastSentHUD.handbrake = handbrakeVal
        state.lastSentHUD.clutch = clutchVal
        state.lastSentHUD.brake = footBrakeVal
        state.lastSentHUD.posX = posXVal
        state.lastSentHUD.posY = posYVal
        state.lastSentHUD.cc = ccVal
        state.lastSentHUD.engine = engineVal
        state.lastSentHUD.mounted = mountedVal
        state.lastSentHUD.speed = speedVal
        state.lastSentHUD.rpm = rpmPercent
        state.lastSentHUD.rpmRaw = rawRPM
        state.lastSentHUD.rpmZone = rpmZone

        setHUDFact("itc_hud_visible", showHUDVal)
        setHUDFact("itc_hud_mounted", mountedVal)
        setHUDFact("itc_hud_mode", modeVal)
        setHUDFact("itc_hud_gear", gearVal)
        setHUDFact("itc_hud_diff", diffLockedVal)
        setHUDFact("itc_hud_handbrake", handbrakeVal)
        setHUDFact("itc_hud_clutch", clutchVal)
        setHUDFact("itc_hud_brake", footBrakeVal)
        setHUDFact("itc_hud_pos_x", posXVal)
        setHUDFact("itc_hud_pos_y", posYVal)
        setHUDFact("itc_hud_cc", ccVal)
        setHUDFact("itc_hud_engine", engineVal)
        setHUDFact("itc_hud_speed", speedVal)
        setHUDFact("itc_hud_rpm", rpmPercent)
        setHUDFact("itc_hud_rpm_raw", rawRPM)
        setHUDFact("itc_hud_rpm_zone", rpmZone)

        local uiSys = Game.GetUISystem()
        if uiSys then
            local itcHUD = uiSys.itcHUD
            if itcHUD then
                pcall(function()
                    itcHUD:Refresh()
                end)
            end
        end

    end
end

local function forceHideHUD()
    hudRefreshTimer = 0.0
    setHUDFact("itc_hud_visible", 0)
    setHUDFact("itc_hud_mounted", 0)
    setHUDFact("itc_hud_mode", 0)
    setHUDFact("itc_hud_gear", 1)
    setHUDFact("itc_hud_diff", 0)
    setHUDFact("itc_hud_handbrake", 0)
    setHUDFact("itc_hud_clutch", 0)
    setHUDFact("itc_hud_brake", 0)
    setHUDFact("itc_hud_cc", 0)
    setHUDFact("itc_hud_engine", 0)
    setHUDFact("itc_hud_speed", 0)
    setHUDFact("itc_hud_rpm", 0)
    setHUDFact("itc_hud_rpm_raw", 0)
    setHUDFact("itc_hud_rpm_zone", 1)
    setHUDFact("itc_hud_pos_x", 80)
    setHUDFact("itc_hud_pos_y", 82)

    local uiSys = Game.GetUISystem()
    if uiSys then
        local itcHUD = uiSys.itcHUD
        if itcHUD then
            pcall(function()
                itcHUD:Refresh()
            end)
        end
    end

    logger.logDebug("[HUD] Forced HUD hidden.")
end

return {
    setHUDFact = setHUDFact,
    updateHUDState = updateHUDState,
    forceHideHUD = forceHideHUD
}
