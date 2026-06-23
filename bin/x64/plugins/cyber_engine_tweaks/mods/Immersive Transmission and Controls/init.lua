local settings = require("settings")
local state = require("state")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")
local hudInterface = require("hud_interface")
local gearbox = require("gearbox")
local clutch = require("clutch")
local drivetrain = require("drivetrain")
local inputHandler = require("input_handler")

local Engine = nil
local nativeSettings = nil

local function resetVehicleState()
    state.vehicle.active = nil
    state.vehicle.bb = nil
    state.vehicle.isMounted = false
    state.vehicle.gears = {}
    state.vehicle.mass = 1500.0
    state.gearbox.current = "N"
    state.gearbox.target = 1
    state.gearbox.isShifting = false
    state.gearbox.shiftTimer = 0.0
    state.gearbox.blockChange = true
    state.clutch.isPressed = false
    state.clutch.transitionTimer = 0.0
    state.clutch.engagement = 1.0
    state.engine.isStalled = false
    state.manualOverride.active = false
    state.manualOverride.timer = 0.0
    state.inputs.handbrakeToggled = false
    state.isModDisabled = false
end

local function syncGearStateOnMount(vehicle, bb)
    local currentGear = bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    local speed = vehicle:GetCurrentSpeed()
    if speed > 1.0 then
        if settings.transmissionMode == "Automatic" then
            if currentGear == 0 then
                state.gearbox.current = "R"
            elseif currentGear == -1 then
                state.gearbox.current = "N"
            else
                state.gearbox.current = "D"
            end
        else
            if currentGear == 0 then
                state.gearbox.current = "R"
            elseif currentGear == -1 or currentGear == nil then
                state.gearbox.current = "N"
            else
                state.gearbox.current = tostring(math.max(1, currentGear))
            end
        end
    else
        state.gearbox.current = "N"
    end
    gearbox.setGearBlock(true)
end

registerInput("ITC_ToggleCruiseControl", "Toggle Cruise Control Mode", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then
        settings.cruiseControlEnabled = not settings.cruiseControlEnabled
        settings.save()
        GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
    end
end)

registerInput("ITC_GearUp", "Gear Up / Shift Drive", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then gearbox.handleGearUp() end
end)

registerInput("ITC_GearDown", "Gear Down / Shift Reverse", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then gearbox.handleGearDown() end
end)

registerInput("ITC_ToggleModActive", "Toggle ITC Mod Active (Enable/Disable)", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then
        state.isModDisabled = not state.isModDisabled
        if state.isModDisabled then
            gearbox.setGearBlock(false)
            GameOptions.SetBool("Vehicle", "UseDifferential", true)
            hudInterface.setHUDFact("itc_hud_visible", 0)
            hudInterface.updateHUDState(1.0)
            logger.logDebug("ITC Mod: DISABLED (Returned to Native Controls)")
            GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
        else
            if state.vehicle.active then
                gearbox.setGearBlock(true)
                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
            end
            hudInterface.updateHUDState(1.0)
            logger.logDebug("ITC Mod: ENABLED")
            GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
        end
    end
end)

registerInput("ITC_ToggleTransmission", "Toggle Transmission Mode", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then
        if settings.transmissionMode == "Automatic" then
            settings.transmissionMode = "Manual"
            if state.vehicle.bb then
                local currentGear = state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear == 0 then
                    state.gearbox.current = "R"
                else
                    state.gearbox.current = tostring(math.max(1, currentGear))
                end
            else
                state.gearbox.current = "1"
            end
            logger.logDebug("Switched to Manual Gearbox")
        else
            settings.transmissionMode = "Automatic"
            state.gearbox.current = "D"
            state.manualOverride.active = false
            gearbox.setGearBlock(false)
            logger.logDebug("Switched to Automatic Gearbox")
        end
        settings.save()
    end
end)

registerInput("ITC_ToggleDifferential", "Toggle Differential Lock (Drift/Grip)", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then
        local newState = not GameOptions.GetBool("Vehicle", "UseDifferential")
        GameOptions.SetBool("Vehicle", "UseDifferential", newState)
        settings.useDifferential = newState
        settings.save()
        GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
        logger.logDebug("Differential " .. (newState and "OPEN (Grip)" or "LOCKED (Drift)"))
    end
end)

registerInput("ITC_ToggleHandbrake", "Toggle Handbrake (Parking Brake)", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    if isDown then
        state.inputs.handbrakeToggled = not state.inputs.handbrakeToggled
        GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
    end
end)

registerInput("ITC_Clutch", "Manual Clutch (Hold)", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    clutch.setClutch(isDown)
end)

registerInput("ITC_FootBrake", "Foot Brake (Hold)", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    state.inputs.footBrake = isDown
    state.inputs.decelerate = isDown
    state.inputs.decelerateVal = isDown and 1.0 or 0.0
    hudInterface.updateHUDState(1.0)
end)

registerInput("ITC_Boost", "Full Throttle / Boost Modifier", function(isDown)
    if not state.vehicle.isMounted then return end
    if Engine and Engine.GetState().inMenu then return end
    state.inputs.fullThrottle = isDown
end)

registerForEvent("onInit", function()
    Engine = GetMod("0-Engine")
    nativeSettings = GetMod("nativeSettings")

    if Engine then
        Engine.Subscribe("VehicleMount", function(vehicle)
            if vehicle and vehicle:IsPlayerDriver() then
                state.vehicle.active = vehicle
                state.vehicle.bb = vehicle:GetBlackboard()
                state.vehicle.isMounted = true
                state.engine.isStalled = false
                state.manualOverride.active = false
                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                vehicleManager.cacheVehicleGearData()
                syncGearStateOnMount(state.vehicle.active, state.vehicle.bb)
                pcall(function()
                    hudInterface.setHUDFact("itc_hud_visible", 1)
                    local uiSys = Game.GetUISystem()
                    if uiSys and uiSys.itcHUD then
                        uiSys.itcHUD:Refresh()
                    end
                end)
            end
        end)

        Engine.Subscribe("VehicleUnmount", function()
            hudInterface.forceHideHUD()
            resetVehicleState()
            if gearbox then
                gearbox.setGearBlock(false)
            else
                logger.logDebug("[WARN] gearbox module is nil – skipping setGearBlock")
            end
        end)
    else
        Observe('VehicleComponent', 'OnMountingEvent', function(self, evt)
            local ok, err = pcall(function()
                local vehicle = self:GetVehicle()
                if vehicle and vehicle:IsPlayerDriver() then
                    state.vehicle.active = vehicle
                    state.vehicle.bb = vehicle:GetBlackboard()
                    state.vehicle.isMounted = true
                    state.engine.isStalled = false
                    state.manualOverride.active = false
                    GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                    vehicleManager.cacheVehicleGearData()
                    syncGearStateOnMount(state.vehicle.active, state.vehicle.bb)
                    pcall(function()
                        hudInterface.setHUDFact("itc_hud_visible", 1)
                        local uiSys = Game.GetUISystem()
                        if uiSys and uiSys.itcHUD then
                            uiSys.itcHUD:Refresh()
                        end
                    end)
                    hudInterface.forceHideHUD()
                end
            end)
            if not ok then
                logger.logDebug("[CRASH] OnMountingEvent error: " .. tostring(err))
            end
        end)

        Observe('VehicleComponent', 'OnUnmountingEvent', function(self, evt)
            local ok, err = pcall(function()
                hudInterface.forceHideHUD()
                resetVehicleState()
                gearbox.setGearBlock(false)
            end)
            if not ok then
                logger.logDebug("[CRASH] OnUnmountingEvent error: " .. tostring(err))
            end
        end)
    end

    inputHandler.registerInputHandlers(Engine)

    if nativeSettings then
        nativeSettings.addTab("/ITC", "Immersive Transmission")
        nativeSettings.addSelectorString("/ITC", "Transmission Mode", "Choose drivetrain shifting mode.", {"Automatic", "Manual"},
            (settings.transmissionMode == "Automatic" and 0 or 1), 0, function(idx)
                settings.transmissionMode = (idx == 0 and "Automatic" or "Manual")
                if settings.transmissionMode == "Manual" then
                    if state.vehicle.bb then
                        local currentGear = state.vehicle.bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                        if currentGear == 0 then
                            state.gearbox.current = "R"
                        else
                            state.gearbox.current = tostring(math.max(1, currentGear))
                        end
                    else
                        state.gearbox.current = "1"
                    end
                else
                    state.gearbox.current = "D"
                    state.manualOverride.active = false
                    gearbox.setGearBlock(false)
                end
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Realistic Reverse Gate", "Prevents automatic reversing when stopped in forward gear. Requires manual shift to Reverse (R).",
            settings.reverseGateRealism, true, function(stateVal)
                settings.reverseGateRealism = stateVal
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Automatic Manual Override", "Allows manual shifting while in Auto mode, creating a temporary gear override.",
            settings.manualOverrideOnAuto, true, function(stateVal)
                settings.manualOverrideOnAuto = stateVal
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Locked Differential (Drift Mode)", "Forces drive wheels to spin at the same speed, making drifting easier. Can toggle while driving via keybind.",
            not settings.useDifferential, false, function(stateVal)
                settings.useDifferential = not stateVal
                settings.save()
                if state.vehicle.active then
                    GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                end
            end)
        nativeSettings.addSwitch("/ITC", "Show Gear HUD", "Displays the current gear overlay on the screen.",
            settings.showHUD, true, function(stateVal)
                settings.showHUD = stateVal
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Enable Cruise Control", "Limits speed in each gear to the normal shift range maximum.",
            settings.cruiseControlEnabled, false, function(stateVal)
                settings.cruiseControlEnabled = stateVal
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Enable Cruising Throttle", "Limits default acceleration on keyboard. Holding Full Throttle modifier disables limits.",
            settings.cruisingEnabled, true, function(stateVal)
                settings.cruisingEnabled = stateVal
                settings.save()
            end)
        nativeSettings.addRangeFloat("/ITC", "Cruising Throttle Scale", "Default cruising throttle level (recommended: 0.3).", 0.1, 1.0, 0.05, "%.2f",
            settings.cruiseThrottle, function(val)
                settings.cruiseThrottle = val
                settings.save()
            end)
        nativeSettings.addSwitch("/ITC", "Enable Steering Damping", "Applies stabilizing lateral forces to smooth out keyboard steering.",
            settings.steeringDampingEnabled, true, function(stateVal)
                settings.steeringDampingEnabled = stateVal
                settings.save()
            end)
        nativeSettings.addRangeFloat("/ITC", "Steering Damping Factor", "Strength of steering damping (higher = more grip, less slide).", 0.5, 1.0, 0.05, "%.2f",
            settings.steeringScale, function(val)
                settings.steeringScale = val
                settings.save()
            end)
        nativeSettings.addRangeFloat("/ITC", "Gear Speed Limit Scale", "Scales vehicle gear max speeds (default: 1.0). Lower values make gear limits more realistic.", 0.5, 1.2, 0.05, "%.2f",
            settings.gearSpeedScale, function(val)
                settings.gearSpeedScale = val
                settings.save()
                vehicleManager.cacheVehicleGearData()
            end)
        nativeSettings.addSwitch("/ITC", "Verbose Debug Logging", "Enables writing debug logs to Immersive Transmission and Controls.log.",
            settings.debugMode, true, function(stateVal)
                settings.debugMode = stateVal
                settings.save()
            end)
        nativeSettings.addRangeFloat("/ITC", "HUD Position X", "Horizontal position of the gear HUD (percentage of screen width).", 0.0, 1.0, 0.01, "%.2f",
            settings.hudX, function(val)
                settings.hudX = val
                settings.save()
            end)
        nativeSettings.addRangeFloat("/ITC", "HUD Position Y", "Vertical position of the gear HUD (percentage of screen height).", 0.0, 1.0, 0.01, "%.2f",
            settings.hudY, function(val)
                settings.hudY = val
                settings.save()
            end)
    end

    if Engine then
        Engine.OnFrame(5, function(frame)
            local ok, err = pcall(function()
                if not state.vehicle.isMounted or (Engine and Engine.GetState().inMenu) then return end
                local dt = 0.083
                clutch.updateClutch(dt)
                if gearbox then
                    gearbox.updateGearbox(dt)
                else
                    logger.logDebug("[WARN] gearbox module is nil – skipping updateGearbox")
                end
                drivetrain.applyDrivetrainForces(dt)
                hudInterface.updateHUDState(dt)
            end)
            if not ok then
                local gearInfo = "unknown"
                if state.gearbox then gearInfo = tostring(state.gearbox.current) end
                logger.logDebug(string.format("[CRASH] Engine.OnFrame error: %s (gear=%s)", tostring(err), gearInfo))
            end
        end)
    end

    pcall(function()
        hudInterface.updateHUDState(0.0)
    end)
end)

local updateTimer = 0.0
registerForEvent("onUpdate", function(dt)
    if not Engine then
        if not state.vehicle.isMounted then return end
        updateTimer = updateTimer + dt
        if updateTimer >= 0.083 then
            local ok, err = pcall(function()
                local dt = updateTimer
                if clutch then
                    clutch.updateClutch(dt)
                else
                    logger.logDebug("[WARN] clutch module is nil – skipping update")
                end
                gearbox.updateGearbox(dt)
                drivetrain.applyDrivetrainForces(dt)
                hudInterface.updateHUDState(dt)
            end)
            if not ok then
                local gearInfo = "unknown"
                if state.gearbox then gearInfo = tostring(state.gearbox.current) end
                logger.logDebug(string.format("[CRASH] onUpdate error: %s (gear=%s)", tostring(err), gearInfo))
            end
            updateTimer = 0.0
        end
    end
end)

registerForEvent("onOverlayOpen", function() state.isOverlayOpen = true end)
registerForEvent("onOverlayClose", function() state.isOverlayOpen = false end)

logger.logDebug("Immersive Transmission & Controls Mod successfully loaded!")
