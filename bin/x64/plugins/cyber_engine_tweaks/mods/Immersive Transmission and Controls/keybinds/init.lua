local state = require("state")
local settings = require("settings.init")
local gearbox = require("gearbox")
local clutch = require("clutch")
local hudInterface = require("hud_interface")
local logger = require("logger")

local function register(Engine)
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

    registerInput("ITC_Boost", "Full Throttle / Boost Modifier", function(isDown)
        if not state.vehicle.isMounted then return end
        if Engine and Engine.GetState().inMenu then return end
        state.inputs.fullThrottle = isDown
    end)
end

return { register = register }
