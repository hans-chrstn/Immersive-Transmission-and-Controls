local settings = require("settings.init")
local state = require("state")
local gearbox = require("gearbox")
local vehicleManager = require("vehicle_manager")

local function register(nativeSettings)
    if not nativeSettings then return end

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

return { register = register }
