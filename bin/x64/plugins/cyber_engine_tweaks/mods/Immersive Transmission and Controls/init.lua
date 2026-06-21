local settings = require("settings")
local state = require("state")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")
local hudInterface = require("hud_interface")
local physicsTransmission = require("physics_transmission")
local inputHandler = require("input_handler")

local Engine = nil
local nativeSettings = nil

registerForEvent("onInit", function()
    Engine = GetMod("0-Engine")
    nativeSettings = GetMod("nativeSettings")
    
    if Engine then
        Engine.Subscribe("VehicleMount", function(vehicle)
            if vehicle and vehicle:IsPlayerDriver() then
                state.isMounted = true
                state.activeVehicle = vehicle
                state.activeVehicleBB = state.activeVehicle:GetBlackboard()
                state.isEngineStalled = false
                state.isManualOverride = false
                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                vehicleManager.cacheVehicleGearData()
                local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                local velocity = state.activeVehicle:GetLinearVelocity()
                local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
                if speed > 1.0 then
                    if settings.transmissionMode == "Automatic" then
                        if currentGear == 0 then
                            state.currentGearState = "R"
                        elseif currentGear == -1 then
                            state.currentGearState = "N"
                        else
                            state.currentGearState = "D"
                        end
                    else
                        if currentGear == 0 then
                            state.currentGearState = "R"
                        elseif currentGear == -1 or currentGear == nil then
                            state.currentGearState = "N"
                        else
                            state.currentGearState = tostring(math.max(1, currentGear))
                        end
                    end
                else
                    state.currentGearState = "N"
                end
                physicsTransmission.setGearBlock(true)
                logger.logDebug("[0-Engine] Vehicle mounted. Synced gear state.")
            end
        end)
        
        Engine.Subscribe("VehicleUnmount", function()
            state.isMounted = false
            state.activeVehicle = nil
            state.activeVehicleBB = nil
            state.isManualOverride = false
            state.vehicleGears = {}
            physicsTransmission.setGearBlock(false)
            hudInterface.setHUDFact("itc_hud_visible", 0)
            hudInterface.setHUDFact("itc_hud_gear", 1)
            hudInterface.setHUDFact("itc_hud_mode", 0)
            logger.logDebug("[0-Engine] Vehicle unmounted.")
        end)
    else
        Observe('VehicleComponent', 'OnMountingEvent', function(self, evt)
            local vehicle = self:GetVehicle()
            if vehicle and vehicle:IsPlayerDriver() then
                state.isMounted = true
                state.activeVehicle = vehicle
                state.activeVehicleBB = state.activeVehicle:GetBlackboard()
                state.isEngineStalled = false
                state.isManualOverride = false
                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                vehicleManager.cacheVehicleGearData()
                local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                local velocity = state.activeVehicle:GetLinearVelocity()
                local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
                if speed > 1.0 then
                    if settings.transmissionMode == "Automatic" then
                        if currentGear == 0 then
                            state.currentGearState = "R"
                        elseif currentGear == -1 then
                            state.currentGearState = "N"
                        else
                            state.currentGearState = "D"
                        end
                    else
                        if currentGear == 0 then
                            state.currentGearState = "R"
                        elseif currentGear == -1 or currentGear == nil then
                            state.currentGearState = "N"
                        else
                            state.currentGearState = tostring(math.max(1, currentGear))
                        end
                    end
                else
                    state.currentGearState = "N"
                end
                physicsTransmission.setGearBlock(true)
                logger.logDebug("[Fallback] Vehicle mounted. Synced gear state.")
            end
        end)
        
        Observe('VehicleComponent', 'OnUnmountingEvent', function(self, evt)
            state.isMounted = false
            state.activeVehicle = nil
            state.activeVehicleBB = nil
            state.isManualOverride = false
            state.vehicleGears = {}
            physicsTransmission.setGearBlock(false)
            hudInterface.setHUDFact("itc_hud_visible", 0)
            hudInterface.setHUDFact("itc_hud_gear", 1)
            hudInterface.setHUDFact("itc_hud_mode", 0)
            local vehicle = vehicleManager.getActiveVehicle()
            if vehicle and vehicle:IsPlayerDriver() then
                state.isMounted = true
                if not state.activeVehicle or state.activeVehicle:GetEntityID().hash ~= vehicle:GetEntityID().hash then
                    state.activeVehicle = vehicle
                    state.activeVehicleBB = state.activeVehicle:GetBlackboard()
                    GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                    state.isEngineStalled = false
                    vehicleManager.cacheVehicleGearData()
                end
            else
                if state.isMounted or state.activeVehicle then
                    logger.logDebug("Active vehicle cleared (Player not driving).")
                end
                state.isMounted = false
                state.activeVehicle = nil
                state.activeVehicleBB = nil
                hudInterface.updateHUDState()
            end
            logger.logDebug("[Fallback] Vehicle unmounted.")
        end)
    end

    inputHandler.registerInputHandlers()

    if nativeSettings then
        nativeSettings.addTab("/ITC", "Immersive Transmission")
        
        nativeSettings.addSelectorString("/ITC", "Transmission Mode", "Choose drivetrain shifting mode.", {"Automatic", "Manual"}, 
            (settings.transmissionMode == "Automatic" and 0 or 1), 0, function(idx)
                settings.transmissionMode = (idx == 0 and "Automatic" or "Manual")
                if settings.transmissionMode == "Manual" then
                    if state.activeVehicleBB then
                        local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                        if currentGear == 0 then
                            state.currentGearState = "R"
                        else
                            state.currentGearState = tostring(math.max(1, currentGear))
                        end
                    else
                        state.currentGearState = "1"
                    end
                else
                    state.currentGearState = "D"
                    state.isManualOverride = false
                    physicsTransmission.setGearBlock(false)
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
                if state.activeVehicle then
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
            physicsTransmission.updateTransmission(0.083)
        end)
    end
end)

local updateTimer = 0.0
registerForEvent("onUpdate", function(dt)
    if not Engine then
        updateTimer = updateTimer + dt
        if updateTimer >= 0.083 then
            physicsTransmission.updateTransmission(updateTimer)
            updateTimer = 0.0
        end
    end
end)

registerForEvent("onOverlayOpen", function() state.isOverlayOpen = true end)
registerForEvent("onOverlayClose", function() state.isOverlayOpen = false end)

registerInput("ITC_ToggleCruiseControl", "Toggle Cruise Control Mode", function(isDown)
    if isDown then
        settings.cruiseControlEnabled = not settings.cruiseControlEnabled
        settings.save()
        GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
        logger.logDebug("Cruise Control " .. (settings.cruiseControlEnabled and "ENABLED" or "DISABLED"))
    end
end)

registerInput("ITC_GearUp", "Gear Up / Shift Drive", function(isDown)
    if isDown then physicsTransmission.handleGearUp() end
end)

registerInput("ITC_GearDown", "Gear Down / Shift Reverse", function(isDown)
    if isDown then physicsTransmission.handleGearDown() end
end)

registerInput("ITC_Clutch", "Manual Clutch (Hold)", function(isDown)
    state.isClutchPressed = isDown
    logger.logDebug("Clutch key: " .. (state.isClutchPressed and "HELD" or "RELEASED"))
end)

registerInput("ITC_ToggleTransmission", "Toggle Transmission Mode", function(isDown)
    if isDown then
        if settings.transmissionMode == "Automatic" then
            settings.transmissionMode = "Manual"
            if state.activeVehicleBB then
                local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear == 0 then
                    state.currentGearState = "R"
                else
                    state.currentGearState = tostring(math.max(1, currentGear))
                end
            else
                state.currentGearState = "1"
            end
            logger.logDebug("Switched to Manual Gearbox")
        else
            settings.transmissionMode = "Automatic"
            state.currentGearState = "D"
            state.isManualOverride = false
            physicsTransmission.setGearBlock(false)
            logger.logDebug("Switched to Automatic Gearbox")
        end
        settings.save()
    end
end)

registerInput("ITC_ToggleEngine", "Stall / Restart Engine", function(isDown)
    if isDown and state.activeVehicle then
        if vehicleManager.isEngineOn() then
            state.isEngineStalled = true
            state.activeVehicle:TurnEngineOn(false)
            logger.logDebug("Engine turned OFF manually.")
        else
            state.isEngineStalled = false
            state.activeVehicle:TurnEngineOn(true)
            logger.logDebug("Engine started/restored manually.")
        end
    end
end)

registerInput("ITC_ToggleDifferential", "Toggle Differential Lock (Drift/Grip)", function(isDown)
    if isDown then physicsTransmission.toggleDifferential() end
end)

registerInput("ITC_Boost", "Full Throttle / Boost Modifier", function(isDown)
    state.isFullThrottlePressed = isDown
end)

logger.logDebug("Immersive Transmission & Controls Mod successfully loaded!")
