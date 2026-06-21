local state = require("state")
local settings = require("settings")
local logger = require("logger")

local function setHUDFact(name, value)
    pcall(function()
        Game.SetFactValue(name, math.floor(value))
    end)
end

local function updateHUDState()
    local showHUD = settings.showHUD and state.isMounted and not state.isOverlayOpen
    local showHUDVal = showHUD and 1 or 0
    local ccVal = settings.cruiseControlEnabled and 1 or 0
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
    local isHandbraking = false
    if state.activeVehicleBB then
        isHandbraking = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end
    local handbrakeVal = isHandbraking and 1 or 0
    local clutchVal = state.isClutchPressed and 1 or 0
    local footBrakeVal = state.isDeceleratePressed and 1 or 0
    local posXVal = math.floor((settings.hudX or 0.85) * 100)
    local posYVal = math.floor((settings.hudY or 0.82) * 100)
    if showHUDVal ~= state.lastSentHUD.visible or
       modeVal ~= state.lastSentHUD.mode or
       gearVal ~= state.lastSentHUD.gear or
       diffLockedVal ~= state.lastSentHUD.diff or
       handbrakeVal ~= state.lastSentHUD.handbrake or
       clutchVal ~= state.lastSentHUD.clutch or
       footBrakeVal ~= state.lastSentHUD.brake or
       posXVal ~= state.lastSentHUD.posX or
       posYVal ~= state.lastSentHUD.posY or
       ccVal ~= state.lastSentHUD.cc then
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
        setHUDFact("itc_hud_visible", showHUDVal)
        setHUDFact("itc_hud_mode", modeVal)
        setHUDFact("itc_hud_gear", gearVal)
        setHUDFact("itc_hud_diff", diffLockedVal)
        setHUDFact("itc_hud_handbrake", handbrakeVal)
        setHUDFact("itc_hud_clutch", clutchVal)
        setHUDFact("itc_hud_brake", footBrakeVal)
        setHUDFact("itc_hud_pos_x", posXVal)
        setHUDFact("itc_hud_pos_y", posYVal)
        setHUDFact("itc_hud_cc", ccVal)
        logger.logDebug(string.format("HUD Fact Update: Vis=%d, Mode=%d, Gear=%d, Diff=%d, PB=%d, Clutch=%d, Brake=%d, CC=%d, X=%d, Y=%d", 
            showHUDVal, modeVal, gearVal, diffLockedVal, handbrakeVal, clutchVal, footBrakeVal, ccVal, posXVal, posYVal))
    end
end

return {
    setHUDFact = setHUDFact,
    updateHUDState = updateHUDState
}
