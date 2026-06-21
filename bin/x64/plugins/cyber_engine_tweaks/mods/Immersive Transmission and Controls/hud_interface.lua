local state = require("state")
local settings = require("settings")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")

local function setHUDFact(name, value)
    pcall(function()
        Game.SetFactValue(name, math.floor(value))
    end)
end

local function updateHUDState()
    local showHUD = settings.showHUD and state.isMounted and not state.isOverlayOpen
    local showHUDVal = showHUD and 1 or 0
    local mountedVal = state.isMounted and 1 or 0
    local ccVal = settings.cruiseControlEnabled and 1 or 0
    local isEngineOn = false
    if state.isMounted and state.activeVehicle then
        isEngineOn = vehicleManager.isEngineOn() and not state.isEngineStalled
    end
    local engineVal = isEngineOn and 1 or 0
    local modeVal = 0
    if settings.transmissionMode == "Manual" then
        modeVal = 1
    elseif state.isManualOverride then
        modeVal = 2
    end
    local gearVal = 1
    local currentGear = 1
    if state.activeVehicleBB then
        currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    end
    if settings.transmissionMode == "Manual" then
        if state.currentGearState == "R" then
            gearVal = 0
        elseif state.currentGearState == "N" then
            gearVal = 1
        else
            local gearNum = tonumber(state.currentGearState) or 1
            gearVal = gearNum + 1
        end
    else
        if state.currentGearState == "N" then
            gearVal = 1
        elseif state.currentGearState == "R" or currentGear == 0 then
            gearVal = 0
        elseif state.currentGearState == "D" then
            local displayGear = currentGear
            if not displayGear or displayGear <= 0 then displayGear = 1 end
            if state.isManualOverride then
                gearVal = 200 + displayGear
            else
                gearVal = 100 + displayGear
            end
        end
    end
    local diffLocked = not GameOptions.GetBool("Vehicle", "UseDifferential")
    local diffLockedVal = diffLocked and 1 or 0
    local isHandbraking = state.isHandbrakeToggled or false
    if not isHandbraking and state.activeVehicleBB then
        isHandbraking = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end
    local handbrakeVal = isHandbraking and 1 or 0
    local clutchVal = state.isClutchPressed and 1 or 0
    local footBrakeVal = state.isDeceleratePressed and 1 or 0
    local posXVal = math.floor((settings.hudX or 0.85) * 100)
    local posYVal = math.floor((settings.hudY or 0.82) * 100)

    -- Calculate Speed & RPM
    local speedVal = 0
    if state.activeVehicle then
        local velocity = state.activeVehicle:GetLinearVelocity()
        speedVal = math.floor(math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2) * 3.6)
    end

    local rawRPM = 0
    local rpmPercent = 0
    if state.activeVehicleBB then
        rawRPM = math.floor(state.activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue))
        local maxRPM = state.activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
        if not maxRPM or maxRPM <= 0 then maxRPM = 8000.0 end
        rpmPercent = math.floor((rawRPM / maxRPM) * 100)
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
       rawRPM ~= state.lastSentHUD.rpmRaw then

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

        local uiSys = Game.GetUISystem()
        if uiSys then
            local itcHUD = uiSys.itcHUD
            if itcHUD then
                pcall(function()
                    itcHUD:Refresh()
                end)
            end
        end

        logger.logDebug(string.format("HUD Fact Update: Vis=%d, Mounted=%d, Mode=%d, Gear=%d, Diff=%d, PB=%d, Clutch=%d, Brake=%d, CC=%d, Engine=%d, Spd=%d, RPM=%d, X=%d, Y=%d", 
            showHUDVal, mountedVal, modeVal, gearVal, diffLockedVal, handbrakeVal, clutchVal, footBrakeVal, ccVal, engineVal, speedVal, rawRPM, posXVal, posYVal))
    end
end

return {
    setHUDFact = setHUDFact,
    updateHUDState = updateHUDState
}
