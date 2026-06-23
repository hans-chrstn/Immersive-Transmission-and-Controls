local state = require("state")
local settings = require("settings")
local logger = require("logger")
local hudInterface = require("hud_interface")

local function sendSEF(player, tags)
    if not player then return end
    pcall(function()
        player:SendEventMessage("BaseStatusEffect.SimpleEventMessage", tags)
    end)
end

local function setGearBlock(block)
    if state.gearbox.blockChange ~= block then
        state.gearbox.blockChange = block
        GameOptions.SetBool("Vehicle", "BlockChangeGear", block)
    end
end

local function handleGearUp()
    local activeVehicle = state.vehicle.active
    local bb = state.vehicle.bb
    if not activeVehicle or not bb or not state.vehicle.isMounted then
        return
    end

    if settings.transmissionMode == "Manual" then
        if not state.clutch.isPressed then
            pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
            return
        end


        if activeVehicle:GetCurrentSpeed() < 0.1 and state.gearbox.current ~= "1" and state.gearbox.current ~= "R" and state.gearbox.current ~= "N" then
            logger.logDebug("Shift UP Blocked: Cannot upshift from stop")
            return
        end

        if state.gearbox.current == "R" then
            state.gearbox.current = "N"
            state.gearbox.target = -1
            logger.logDebug("Shifted to Neutral (N)")
        elseif state.gearbox.current == "N" then
            if activeVehicle:GetCurrentSpeed() < 0.1 then
                state.gearbox.current = "1"
                state.gearbox.target = 1
                logger.logDebug("Shifted to 1st Gear")
            else
                logger.logDebug("Shift to 1st blocked: speed too high")
                pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
            end
        else
            local currentSpeed = activeVehicle:GetCurrentSpeed()
            local currentGearVal = tonumber(state.gearbox.current) or 1
            local maxGears = #state.vehicle.gears
            if maxGears == 0 then maxGears = 5 end


            if currentSpeed < 0.1 and currentGearVal > 1 then
                logger.logDebug("Shift UP Blocked: Cannot upshift from stop (gear > 1)")
                pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
                return
            end

            if currentGearVal < maxGears then
                state.gearbox.target = currentGearVal + 1
                state.gearbox.current = tostring(state.gearbox.target)
                logger.logDebug("Gear Up to " .. state.gearbox.target)
            end
        end
    else

        if activeVehicle:GetCurrentSpeed() < 0.1 and state.gearbox.current ~= "1" and state.gearbox.current ~= "R" and state.gearbox.current ~= "N" then
            logger.logDebug("Shift UP Blocked: Cannot upshift from stop")
            return
        end
        if state.gearbox.current == "R" then
            state.gearbox.current = "N"
            state.gearbox.target = -1
            logger.logDebug("Shifted to Neutral (N)")
        elseif state.gearbox.current == "N" then
            state.gearbox.current = "D"
            state.gearbox.target = 1
            state.manualOverride.active = false
            setGearBlock(false)
            logger.logDebug("Shifted to Drive (D)")
        elseif state.gearbox.current == "D" then
            state.manualOverride.active = true
            state.manualOverride.timer = 4.0
            local currentGear = bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
            state.gearbox.target = currentGear + 1
            triggerShift("UP")
            logger.logDebug("Manual Override: Gear Up to " .. state.gearbox.target)
        end
    end
    local player = Game.GetPlayer()
    sendSEF(player, {"ITC_GearShift", state.gearbox.current})
    hudInterface.updateHUDState(1.0)
end

local function handleGearDown()
    local activeVehicle = state.vehicle.active
    local bb = state.vehicle.bb
    if not activeVehicle or not bb or not state.vehicle.isMounted then
        return
    end

    if settings.transmissionMode == "Manual" then
        if not state.clutch.isPressed then
            logger.logDebug("Shift DOWN Blocked: Clutch is disengaged/not pressed!")
            pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
            return
        end

        if state.gearbox.current == "R" then
            return
        elseif state.gearbox.current == "N" then
            local currentSpeed = activeVehicle:GetCurrentSpeed()
            if currentSpeed * 3.6 > 15.0 then
                logger.logDebug(string.format("Reverse Lockout: Blocked shift to R at %.1f km/h", currentSpeed * 3.6))
                pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
                return
            end
            state.gearbox.current = "R"
            state.gearbox.target = 0
            logger.logDebug("Shifted to Reverse (R)")
        elseif state.gearbox.current == "1" then
            state.gearbox.current = "N"
            state.gearbox.target = -1
            logger.logDebug("Shifted to Neutral (N)")
        else
            local currentSelected = tonumber(state.gearbox.current) or 1
            if currentSelected > 1 then
                state.gearbox.target = currentSelected - 1
                state.gearbox.current = tostring(state.gearbox.target)
                logger.logDebug("Gear Down to " .. state.gearbox.target)
            end
        end
    else
        if state.gearbox.current == "D" then
            if state.manualOverride.active then
                local currentGear = bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear > 1 then
                    state.gearbox.target = currentGear - 1
                    triggerShift("DOWN")
                    logger.logDebug("Manual Override: Gear Down to " .. state.gearbox.target)
                else
                    state.manualOverride.active = false
                    state.gearbox.current = "N"
                    logger.logDebug("Shifted to Neutral (N)")
                end
            else
                state.gearbox.current = "N"
                state.gearbox.target = -1
                logger.logDebug("Shifted to Neutral (N)")
            end
        elseif state.gearbox.current == "N" then
            local currentSpeed = activeVehicle:GetCurrentSpeed()
            if currentSpeed * 3.6 > 15.0 then
                logger.logDebug(string.format("Reverse Lockout: Blocked shift to R at %.1f km/h", currentSpeed * 3.6))
                pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error') end)
                return
            end
            state.gearbox.current = "R"
            state.gearbox.target = 0
            triggerShift("DOWN")
            logger.logDebug("Shifted to Reverse (R)")
        end
    end
    local player = Game.GetPlayer()
    sendSEF(player, {"ITC_GearShift", state.gearbox.current})
    hudInterface.updateHUDState(1.0)
end

local function triggerShift(direction)
    if not state.vehicle.active or state.gearbox.isShifting then
        return
    end
    state.gearbox.isShifting = true
    state.gearbox.shiftTimer = 0.3
    setGearBlock(false)
    if settings.transmissionMode == "Manual" or state.manualOverride.active then
        state.clutch.transitionTimer = 0.2
    end
    pcall(function() GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button') end)
end

local function updateGearbox(dt)
    if not state.vehicle.active or not state.vehicle.bb then
        return
    end
    local bb = state.vehicle.bb
    local currentGear = bb:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)


    if state.gearbox.isShifting then
        local targetGear = state.gearbox.target

        local isOverRevDelayed = false
        if currentGear ~= targetGear and targetGear and targetGear > 0 and currentGear > targetGear then
            local targetGearRec = state.vehicle.gears[targetGear]
            if targetGearRec and state.vehicle.active:GetCurrentSpeed() > targetGearRec.maxSpeed then
                isOverRevDelayed = true
            end
        end
        if isOverRevDelayed then
            state.gearbox.shiftTimer = 0.5
            setGearBlock(false)
        else
            state.gearbox.shiftTimer = state.gearbox.shiftTimer - dt
            if state.gearbox.shiftTimer <= 0.0 or currentGear == targetGear then
                state.gearbox.isShifting = false
                logger.logDebug(string.format("Shift window finished. Target=%d, Actual=%d", targetGear, currentGear))
                local player = Game.GetPlayer()
                sendSEF(player, {"ITC_GearShift", state.gearbox.current .. "_complete"})
                if settings.transmissionMode == "Manual" or state.manualOverride.active then
                    if currentGear == targetGear then
                        setGearBlock(true)
                    else

                        if currentGear == 0 then
                            state.gearbox.current = "R"
                        elseif currentGear == -1 or currentGear == nil then
                            state.gearbox.current = "N"
                        else
                            state.gearbox.current = tostring(currentGear)
                        end
                        setGearBlock(true)
                        logger.logDebug(string.format("Shift failed. Reverted expected gear to actual native gear: %s", state.gearbox.current))
                    end
                else
                    if state.gearbox.current == "N" then
                        setGearBlock(true)
                    elseif state.gearbox.current == "R" and currentGear == 0 then
                        setGearBlock(true)
                    else
                        setGearBlock(false)
                    end
                end
            end
        end
    end


    if state.manualOverride.active then
        state.manualOverride.timer = state.manualOverride.timer - dt
        local maxRPM = bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax) or 8000
        local currentRPM = bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue) or 0
        local overrideThresholdRPM = 0.90 * maxRPM
        local isOverRevving = currentRPM > overrideThresholdRPM and state.inputs.accelerate
        if state.manualOverride.timer <= 0.0 or isOverRevving then
            state.manualOverride.active = false
            if settings.transmissionMode == "Automatic" then
                state.gearbox.current = "D"
                setGearBlock(false)
                logger.logDebug("Manual Override expired. Returned to Automatic.")
            end
        end
    end


    if settings.transmissionMode == "Manual" and not state.gearbox.isShifting then
        if state.clutch.isPressed then
            setGearBlock(true)
        elseif state.gearbox.current == "N" then
            setGearBlock(true)
        elseif state.gearbox.current == "R" then
            if currentGear == 0 then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        else
            local expectedGear = tonumber(state.gearbox.current)
            if expectedGear then
                if currentGear == expectedGear then
                    setGearBlock(true)
                elseif currentGear < expectedGear then
                    setGearBlock(false)
                elseif currentGear > expectedGear then

                    local targetRec = state.vehicle.gears[expectedGear]
                    local threshold = targetRec and (targetRec.normalMaxSpeed * 1.25) or 999.0
                    if state.vehicle.active:GetCurrentSpeed() > threshold then
                        setGearBlock(true)
                        logger.logDebug(string.format("Downshift Blocked: expected=%d, native=%d, speed=%.1f", expectedGear, currentGear, state.vehicle.active:GetCurrentSpeed() * 3.6))
                    else
                        setGearBlock(false)
                    end
                end
            end
        end
    end


    if settings.transmissionMode == "Automatic" and not state.gearbox.isShifting and not state.manualOverride.active then
        if state.gearbox.current == "N" then
            setGearBlock(true)
        elseif state.gearbox.current == "R" then
            if currentGear == 0 then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        elseif state.gearbox.current == "D" then
            if settings.reverseGateRealism and state.vehicle.active:GetCurrentSpeed() < 0.1 then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        end
    end
end

return {
    setGearBlock = setGearBlock,
    handleGearUp = handleGearUp,
    handleGearDown = handleGearDown,
    triggerShift = triggerShift,
    updateGearbox = updateGearbox
}
