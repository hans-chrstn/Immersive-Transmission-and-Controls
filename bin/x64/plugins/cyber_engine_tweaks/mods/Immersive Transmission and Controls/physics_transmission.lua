local state = require("state")
local settings = require("settings")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")
local hudInterface = require("hud_interface")

local function setGearBlock(block)
    state.blockChangeGearState = block
    GameOptions.SetBool("Vehicle", "BlockChangeGear", block)
end

local function toggleDifferential()
    if not state.activeVehicle then return end
    local newState = not GameOptions.GetBool("Vehicle", "UseDifferential")
    GameOptions.SetBool("Vehicle", "UseDifferential", newState)
    settings.useDifferential = newState
    settings.save()
    GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
    logger.logDebug("Differential " .. (newState and "OPEN (Grip)" or "LOCKED (Drift)"))
end

local function triggerShift(direction)
    if not state.activeVehicle or state.isShifting then return end
    state.isShifting = true
    state.shiftTimeoutTimer = 0.3
    setGearBlock(false)
    if settings.transmissionMode == "Manual" or state.isManualOverride then
        state.clutchTransitionTimer = 0.2
    end
    GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
end

local function handleGearUp()
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
    if not state.activeVehicle or not state.activeVehicleBB then return end
    if settings.transmissionMode == "Manual" then
        if not state.isClutchPressed then
            logger.logDebug("Shift UP Blocked: Clutch is disengaged/not pressed!")
            GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
            return
        end
    end
    if settings.transmissionMode == "Automatic" then
        if state.currentGearState == "R" then
            state.currentGearState = "N"
            logger.logDebug("Shifted to Neutral (N)")
        elseif state.currentGearState == "N" then
            state.currentGearState = "D"
            state.targetGear = 1
            state.isManualOverride = false
            setGearBlock(false)
            logger.logDebug("Shifted to Drive (D)")
        elseif state.currentGearState == "D" then
            state.isManualOverride = true
            state.overrideTimer = 4.0
            local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
            state.targetGear = currentGear + 1
            triggerShift("UP")
            logger.logDebug("Manual Override: Gear Up to " .. state.targetGear)
        end
    else
        if state.currentGearState == "R" then
            state.currentGearState = "N"
            logger.logDebug("Shifted to Neutral (N)")
        elseif state.currentGearState == "N" then
            state.currentGearState = "1"
            state.targetGear = 1
            triggerShift("UP")
            logger.logDebug("Shifted to 1st Gear")
        else
            local maxGears = #state.vehicleGears
            if maxGears == 0 then maxGears = 5 end
            local currentSelected = tonumber(state.currentGearState) or 1
            if currentSelected < maxGears then
                state.targetGear = currentSelected + 1
                state.currentGearState = tostring(state.targetGear)
                triggerShift("UP")
                logger.logDebug("Gear Up to " .. state.targetGear)
            end
        end
    end
end

local function handleGearDown()
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
    if not state.activeVehicle or not state.activeVehicleBB then return end
    if settings.transmissionMode == "Manual" then
        if not state.isClutchPressed then
            logger.logDebug("Shift DOWN Blocked: Clutch is disengaged/not pressed!")
            GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
            return
        end
    end
    if settings.transmissionMode == "Automatic" then
        if state.currentGearState == "D" then
            if state.isManualOverride then
                local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear > 1 then
                    state.targetGear = currentGear - 1
                    triggerShift("DOWN")
                    logger.logDebug("Manual Override: Gear Down to " .. state.targetGear)
                else
                    state.isManualOverride = false
                    state.currentGearState = "N"
                    logger.logDebug("Shifted to Neutral (N)")
                end
            else
                state.currentGearState = "N"
                logger.logDebug("Shifted to Neutral (N)")
            end
        elseif state.currentGearState == "N" then
            state.currentGearState = "R"
            state.targetGear = 0
            triggerShift("DOWN")
            logger.logDebug("Shifted to Reverse (R)")
        end
    else
        if state.currentGearState == "R" then
            return
        elseif state.currentGearState == "N" then
            state.currentGearState = "R"
            state.targetGear = 0
            triggerShift("DOWN")
            logger.logDebug("Shifted to Reverse (R)")
        elseif state.currentGearState == "1" then
            state.currentGearState = "N"
            logger.logDebug("Shifted to Neutral (N)")
        else
            local currentSelected = tonumber(state.currentGearState) or 1
            if currentSelected > 1 then
                state.targetGear = currentSelected - 1
                state.currentGearState = tostring(state.targetGear)
                triggerShift("DOWN")
                logger.logDebug("Gear Down to " .. state.targetGear)
            end
        end
    end
end

local function updateTransmission(dt)
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
    if not state.activeVehicle or not state.activeVehicleBB or not state.isMounted then
        hudInterface.updateHUDState()
        return
    end
    if #state.vehicleGears == 0 then
        vehicleManager.cacheVehicleGearData()
    end
    local currentGear = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    local velocity = state.activeVehicle:GetLinearVelocity()
    local currentSpeed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
    local currentRPM = state.activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue)
    local maxDecelForce = 6.0 * 9.81 * state.vehicleMass

    local isThrottlePressed = false
    if state.currentGearState == "R" then
        isThrottlePressed = state.isDeceleratePressed
    elseif state.currentGearState == "N" then
        isThrottlePressed = state.isAcceleratePressed or state.isDeceleratePressed
    else
        isThrottlePressed = state.isAcceleratePressed
    end

    local activeGearIdx = nil
    if settings.transmissionMode == "Manual" then
        if state.currentGearState == "R" then
            activeGearIdx = 0
        elseif state.currentGearState == "N" then
            activeGearIdx = nil
        elseif state.currentGearState ~= "N" then
            activeGearIdx = tonumber(state.currentGearState)
            if activeGearIdx and activeGearIdx < 1 then activeGearIdx = 1 end
        end
    elseif state.isManualOverride then
        activeGearIdx = state.targetGear
        if activeGearIdx and activeGearIdx < 1 then activeGearIdx = 1 end
    else
        if state.currentGearState == "R" or currentGear == 0 then
            activeGearIdx = 0
        elseif state.currentGearState == "D" then
            activeGearIdx = currentGear
            if not activeGearIdx or activeGearIdx <= 0 then activeGearIdx = 1 end
        end
    end
    state.speedLogTimer = (state.speedLogTimer or 0.0) + dt
    if state.speedLogTimer >= 1.0 then
        state.speedLogTimer = 0.0
        local limitStr = "None"
        if activeGearIdx and state.vehicleGears[activeGearIdx] then
            local lim = state.vehicleGears[activeGearIdx].maxSpeed
            if settings.cruiseControlEnabled then
                lim = state.vehicleGears[activeGearIdx].normalMaxSpeed
            end
            limitStr = string.format("%.1f km/h", lim * 3.6)
        end
        logger.logDebug(string.format("Speed Monitor: Speed=%.1f km/h, GearState=%s, NativeGear=%d, ActiveGearIdx=%s, Limit=%s, Override=%s, Cruise=%s",
            currentSpeed * 3.6, state.currentGearState, currentGear, tostring(activeGearIdx), limitStr, tostring(state.isManualOverride), tostring(settings.cruiseControlEnabled)))
    end
    if activeGearIdx then
        local selectedGear = state.vehicleGears[activeGearIdx]
        if not selectedGear and activeGearIdx == 0 then
            local scale = settings.gearSpeedScale or 1.0
            selectedGear = {
                maxSpeed = (40.0 / 3.6) * scale,
                minSpeed = 0.0,
                normalMaxSpeed = (20.0 / 3.6) * scale,
                torqueMultiplier = 2.0,
                maxRPM = 6500.0,
                minRPM = 900.0
            }
        elseif not selectedGear and #state.vehicleGears > 0 then
            selectedGear = state.vehicleGears[#state.vehicleGears]
        end
        if selectedGear then
            local isCruise = settings.cruiseControlEnabled
            local maxSpeed = selectedGear.maxSpeed
            if isCruise then
                maxSpeed = selectedGear.normalMaxSpeed
            end
            if currentSpeed > maxSpeed then
                local forwardVec = state.activeVehicle:GetWorldForward()
                local forwardSpeed = velocity.x * forwardVec.x + velocity.y * forwardVec.y + velocity.z * forwardVec.z
                local diffMS = currentSpeed - maxSpeed
                local dragMag = 0.0
                if isCruise then
                    dragMag = -4.0 * state.vehicleMass * diffMS
                else
                    dragMag = -12.0 * state.vehicleMass * diffMS
                end
                if activeGearIdx == 0 and forwardSpeed < -0.1 then
                    dragMag = -dragMag
                end
                if dragMag < -maxDecelForce then dragMag = -maxDecelForce end
                if dragMag > maxDecelForce then dragMag = maxDecelForce end
                local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                state.activeVehicle:AddCollisionForce(dragVec)
                logger.logDebug(string.format("Speed Limiter active: Speed=%.2f m/s (%.1f km/h), Max=%.2f m/s (%.1f km/h), Force=%.1f N, BrakesApplied=false, Cruise=%s", 
                    currentSpeed, currentSpeed * 3.6, maxSpeed, maxSpeed * 3.6, dragMag, tostring(isCruise)))
            end
        end
    end

    if activeGearIdx and activeGearIdx > 1 and not state.isClutchPressed and isThrottlePressed then
        local selectedGear = state.vehicleGears[activeGearIdx]
        if selectedGear and currentSpeed < selectedGear.minSpeed then
            local lugRatio = (selectedGear.minSpeed - currentSpeed) / selectedGear.minSpeed
            local vibration = math.sin(os.clock() * 45.0) * lugRatio * 0.3 * state.vehicleMass
            local lugDrag = -0.6 * lugRatio * state.vehicleMass
            local forwardVec = state.activeVehicle:GetWorldForward()
            local forceMag = vibration + lugDrag
            local forceVec = Vector4.new(forwardVec.x * forceMag, forwardVec.y * forceMag, forwardVec.z * forceMag, 0.0)
            state.activeVehicle:AddCollisionForce(forceVec)
            if math.random() < 0.05 then
                logger.logDebug(string.format("Engine lugging/chugging: speed=%.2f m/s (%.1f km/h), min=%.2f m/s (%.1f km/h), ratio=%.2f", 
                    currentSpeed, currentSpeed * 3.6, selectedGear.minSpeed, selectedGear.minSpeed * 3.6, lugRatio))
            end
        end
    end

    local forwardVec = state.activeVehicle:GetWorldForward()
    local forwardSpeed = velocity.x * forwardVec.x + velocity.y * forwardVec.y + velocity.z * forwardVec.z

    if state.currentGearState == "N" then
        setGearBlock(true)
        if isThrottlePressed then
            if currentSpeed < 2.0 then
                local dragMag = -35.0 * state.vehicleMass * forwardSpeed
                local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                state.activeVehicle:AddCollisionForce(dragVec)
            else
                local dragMag = -6.0 * state.vehicleMass * forwardSpeed
                local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                state.activeVehicle:AddCollisionForce(dragVec)
            end
        elseif currentSpeed < 1.0 then
            state.activeVehicle:ForceBrakesFor(dt)
        end
        hudInterface.updateHUDState()
        return
    elseif state.currentGearState == "R" then
        if forwardSpeed > 0.1 then
            local dragMag = -6.0 * state.vehicleMass * forwardSpeed
            local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
            state.activeVehicle:AddCollisionForce(dragVec)
            state.activeVehicle:ForceBrakesFor(dt)
        end
    else
        if forwardSpeed < -0.1 then
            local dragMag = -6.0 * state.vehicleMass * forwardSpeed
            local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
            state.activeVehicle:AddCollisionForce(dragVec)
            state.activeVehicle:ForceBrakesFor(dt)
        end
    end

    if state.isEngineStalled and settings.transmissionMode == "Manual" and not state.isClutchPressed and state.currentGearState ~= "N" then
        if currentSpeed > 1.5 then
            state.isEngineStalled = false
            state.activeVehicle:TurnEngineOn(true)
            logger.logDebug(string.format("Engine bump-started: Speed=%.2f m/s (%.1f km/h), Gear=%s", currentSpeed, currentSpeed * 3.6, state.currentGearState))
        end
    end
    if state.isEngineStalled and (state.isClutchPressed or state.currentGearState == "N") and state.isAcceleratePressed then
        state.isEngineStalled = false
        state.activeVehicle:TurnEngineOn(true)
        logger.logDebug("Engine automatically restarted (Clutch/Neutral + Throttle).")
    end
    local isEVSOff = settings.evsIntegration and not vehicleManager.isEngineOn()
    if isEVSOff or state.isEngineStalled then
        if state.isEngineStalled and vehicleManager.isEngineOn() then
            state.activeVehicle:TurnEngineOn(false)
        end
        if state.isShifting then
            state.shiftTimeoutTimer = state.shiftTimeoutTimer - dt
            if state.shiftTimeoutTimer <= 0.0 or currentGear == state.targetGear then
                state.isShifting = false
                logger.logDebug(string.format("Shift window finished (Stalled). Target=%d, Actual=%d", state.targetGear, currentGear))
                setGearBlock(true)
            end
        end
        if not state.isShifting then
            if state.currentGearState == "R" then
                if currentGear == 0 then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            elseif state.currentGearState == "N" then
                setGearBlock(true)
            else
                local expectedGear = tonumber(state.currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end
        if not state.isClutchPressed and state.currentGearState ~= "N" then
            state.activeVehicle:ForceBrakesFor(0.1)
        end
        hudInterface.updateHUDState()
        return
    end
    if state.isShifting then
        state.shiftTimeoutTimer = state.shiftTimeoutTimer - dt
        if state.shiftTimeoutTimer <= 0.0 or currentGear == state.targetGear then
            state.isShifting = false
            logger.logDebug(string.format("Shift window finished. Target=%d, Actual=%d", state.targetGear, currentGear))
            if settings.transmissionMode == "Manual" or state.isManualOverride then
                setGearBlock(true)
            else
                if state.currentGearState == "N" then
                    setGearBlock(true)
                elseif state.currentGearState == "R" and currentGear == 0 then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end
    end
    if settings.transmissionMode == "Manual" or state.isManualOverride then
        if state.clutchTransitionTimer > 0.0 then
            state.clutchTransitionTimer = state.clutchTransitionTimer - dt
        end
        local gearIdx = nil
        if state.currentGearState == "R" then
            gearIdx = 0
        elseif state.currentGearState == "N" then
            gearIdx = nil
        else
            gearIdx = tonumber(state.currentGearState)
        end
        if settings.transmissionMode == "Manual" and state.isClutchPressed then
            if not state.isShifting then
                local expectedGear = tonumber(state.currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
            if isThrottlePressed then
                if currentSpeed < 2.0 then
                    local dragMag = -35.0 * state.vehicleMass * forwardSpeed
                    local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                    state.activeVehicle:AddCollisionForce(dragVec)
                else
                    local dragMag = -6.0 * state.vehicleMass * forwardSpeed
                    local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                    state.activeVehicle:AddCollisionForce(dragVec)
                end
            elseif currentSpeed < 1.0 then
                state.activeVehicle:ForceBrakesFor(0.1)
                logger.logDebug(string.format("Clutch creep prevention: speed=%.2f m/s (%.1f km/h), applying brakes", currentSpeed, currentSpeed * 3.6))
            end
            hudInterface.updateHUDState()
            return
        end
        if state.currentGearState == "N" then
            setGearBlock(true)
            if isThrottlePressed then
                if currentSpeed < 2.0 then
                    local dragMag = -35.0 * state.vehicleMass * forwardSpeed
                    local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                    state.activeVehicle:AddCollisionForce(dragVec)
                else
                    local dragMag = -6.0 * state.vehicleMass * forwardSpeed
                    local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                    state.activeVehicle:AddCollisionForce(dragVec)
                end
            elseif currentSpeed < 1.0 then
                state.activeVehicle:ForceBrakesFor(0.1)
                logger.logDebug(string.format("Neutral creep prevention: speed=%.2f m/s (%.1f km/h), applying brakes", currentSpeed, currentSpeed * 3.6))
            end
            hudInterface.updateHUDState()
            return
        end
        if settings.transmissionMode == "Manual" and not state.isClutchPressed and state.currentGearState ~= "N" then
            local selectedGear = state.vehicleGears[gearIdx]
            if selectedGear then
                local gearMaxRPM = selectedGear.maxRPM or 6500.0
                if gearMaxRPM <= 0 then gearMaxRPM = 6500.0 end
                local stallSpeed = selectedGear.maxSpeed * (550.0 / gearMaxRPM)
                if stallSpeed < 1.5 then stallSpeed = 1.5 end
                if currentSpeed < stallSpeed then
                    local isBraking = false
                    if state.activeVehicleBB then
                        local isHandbraking = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
                        local isFootBraking = false
                        if gearIdx == 0 then
                            isFootBraking = state.isAcceleratePressed
                        else
                            isFootBraking = state.isDeceleratePressed
                        end
                        isBraking = isHandbraking or isFootBraking
                    end
                    if (gearIdx == 1 or gearIdx == 0) and not isBraking and currentSpeed < 1.5 then
                        local forceMag = 0.8 * state.vehicleMass
                        if isThrottlePressed then
                            forceMag = 1.8 * state.vehicleMass
                        end
                        if gearIdx == 0 then forceMag = -forceMag end
                        local forwardVec = state.activeVehicle:GetWorldForward()
                        local forceVec = Vector4.new(forwardVec.x * forceMag, forwardVec.y * forceMag, forwardVec.z * forceMag, 0.0)
                        state.activeVehicle:AddCollisionForce(forceVec)
                        logger.logDebug(string.format("Clutch creep/bite: Speed=%.2f m/s (%.1f km/h), Gear=%d, Force=%.1f N", currentSpeed, currentSpeed * 3.6, gearIdx, forceMag))
                    else
                        state.isEngineStalled = true
                        state.activeVehicle:TurnEngineOn(false)
                        setGearBlock(true)
                        GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
                        logger.logDebug(string.format("Stall triggered: Released clutch below stall speed (Speed=%.2f m/s (%.1f km/h), StallSpeed=%.2f m/s (%.1f km/h)) in gear %s", currentSpeed, currentSpeed * 3.6, stallSpeed, stallSpeed * 3.6, state.currentGearState))
                        hudInterface.updateHUDState()
                        return
                    end
                end
            end
        end
        if not state.isShifting then
            if state.currentGearState == "R" then
                if currentGear == 0 then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            else
                local expectedGear = tonumber(state.currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end
        if gearIdx then
            local selectedGear = state.vehicleGears[gearIdx]
            if selectedGear then
                if state.clutchTransitionTimer > 0.0 then
                    local forwardVec = state.activeVehicle:GetWorldForward()
                    local slipMag = -2.0 * state.vehicleMass
                    local slipVec = Vector4.new(forwardVec.x * slipMag, forwardVec.y * slipMag, forwardVec.z * slipMag, 0.0)
                    state.activeVehicle:AddCollisionForce(slipVec)
                elseif isThrottlePressed then
                    local Tg = selectedGear.torqueMultiplier
                    local nativeGearIdx = currentGear
                    if nativeGearIdx == 0 then nativeGearIdx = 1 end
                    local Tn = state.vehicleGears[nativeGearIdx] and state.vehicleGears[nativeGearIdx].torqueMultiplier or 1.0
                    local ratio = Tg / Tn
                    local forceMag = 0.0
                    local forwardVec = state.activeVehicle:GetWorldForward()
                    if ratio > 1.0 then
                        if nativeGearIdx <= gearIdx then
                            forceMag = (ratio - 1.0) * 1.5 * state.vehicleMass
                            logger.logDebug(string.format("Torque boost applied: Target=%d, Native=%d, Ratio=%.2f, Force=%.1f N", gearIdx, nativeGearIdx, ratio, forceMag))
                        else
                            logger.logDebug(string.format("Torque boost blocked (Downshifting): Target=%d, Native=%d, Ratio=%.2f (Speed Limiter will engine brake)", gearIdx, nativeGearIdx, ratio))
                        end
                    elseif ratio < 1.0 then
                        if currentSpeed > 0.1 then
                            forceMag = (ratio - 1.0) * 1.2 * state.vehicleMass
                        end
                    end
                    local pitchZ = forwardVec.z
                    if pitchZ > 0.02 and (gearIdx == 1 or gearIdx == 2) then
                        local uphillBoost = pitchZ * 8.0 * state.vehicleMass
                        forceMag = forceMag + uphillBoost
                    end
                    if math.abs(forceMag) > 1.0 then
                        if gearIdx == 0 then
                            forceMag = -forceMag
                        end
                        local forceVec = Vector4.new(forwardVec.x * forceMag, forwardVec.y * forceMag, forwardVec.z * forceMag, 0.0)
                        state.activeVehicle:AddCollisionForce(forceVec)
                    end
                end
            end
        end
    else
        if state.currentGearState == "N" then
            setGearBlock(true)
            if isThrottlePressed then
                state.activeVehicle:ForceBrakesFor(0.1)
            end
            hudInterface.updateHUDState()
            return
        elseif state.currentGearState == "R" then
            if currentGear == 0 then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        elseif state.currentGearState == "D" and not state.isManualOverride then
            if settings.reverseGateRealism and currentSpeed < 0.1 and not state.isShifting then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        end
    end
    if state.isManualOverride then
        state.overrideTimer = state.overrideTimer - dt
        local maxRPM = state.activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
        if not maxRPM or maxRPM <= 0 then maxRPM = 8000.0 end
        local selectedGear = state.vehicleGears[state.targetGear]
        local isOverRevving = false
        if selectedGear then
            local maxSpeed = selectedGear.maxSpeed
            if settings.cruiseControlEnabled then
                maxSpeed = selectedGear.normalMaxSpeed
            end
            if currentSpeed <= maxSpeed then
                isOverRevving = currentRPM > (state.overrideThresholdRPM * maxRPM) and state.isAcceleratePressed
            end
        else
            isOverRevving = currentRPM > (state.overrideThresholdRPM * maxRPM) and state.isAcceleratePressed
        end
        if state.overrideTimer <= 0.0 or isOverRevving then
            state.isManualOverride = false
            if settings.transmissionMode == "Automatic" then
                state.currentGearState = "D"
                setGearBlock(false)
                logger.logDebug("Manual Override expired. Returned to Automatic.")
            end
        end
    end
    if settings.cruisingEnabled and not state.isFullThrottlePressed and state.currentGearState ~= "N" then
        local activeGearIdx = nil
        if settings.transmissionMode == "Manual" then
            if state.currentGearState == "R" then
                activeGearIdx = 0
            else
                activeGearIdx = tonumber(state.currentGearState)
            end
        elseif state.isManualOverride then
            activeGearIdx = state.targetGear
        else
            if state.currentGearState == "R" or currentGear == 0 then
                activeGearIdx = 0
            elseif state.currentGearState == "D" then
                activeGearIdx = currentGear
                if activeGearIdx == 0 then activeGearIdx = 1 end
            end
        end
        local selectedGear = activeGearIdx and state.vehicleGears[activeGearIdx]
        if not selectedGear and activeGearIdx and #state.vehicleGears > 0 then
            selectedGear = state.vehicleGears[#state.vehicleGears]
        end
        if selectedGear then
            local maxCruiseSpeed = selectedGear.maxSpeed * settings.cruiseThrottle
            local isCruisingThrottlePressed = false
            if activeGearIdx == 0 then
                isCruisingThrottlePressed = state.isDeceleratePressed
            else
                isCruisingThrottlePressed = state.isAcceleratePressed
            end
            if isCruisingThrottlePressed then
                local cruiseDragMag = 0.0
                if currentSpeed > maxCruiseSpeed then
                    local diff = currentSpeed - maxCruiseSpeed
                    cruiseDragMag = -8.0 * state.vehicleMass * diff
                else
                    cruiseDragMag = -1.2 * state.vehicleMass * (1.0 - settings.cruiseThrottle)
                end
                if activeGearIdx == 0 then
                    cruiseDragMag = -cruiseDragMag
                end
                if cruiseDragMag < -maxDecelForce then cruiseDragMag = -maxDecelForce end
                if cruiseDragMag > maxDecelForce then cruiseDragMag = maxDecelForce end
                local forwardVec = state.activeVehicle:GetWorldForward()
                local cruiseDragVec = Vector4.new(forwardVec.x * cruiseDragMag, forwardVec.y * cruiseDragMag, forwardVec.z * cruiseDragMag, 0.0)
                state.activeVehicle:AddCollisionForce(cruiseDragVec)
            end
        end
    end
    local velocity = state.activeVehicle:GetLinearVelocity()
    local forwardVec = state.activeVehicle:GetWorldForward()
    local rightVec = Vector4.new(-forwardVec.y, forwardVec.x, 0.0, 0.0)
    local lateralSpeed = velocity.x * rightVec.x + velocity.y * rightVec.y + velocity.z * rightVec.z
    if settings.steeringDampingEnabled then
        if math.abs(lateralSpeed) > 0.05 then
            local steeringScale = settings.steeringScale or 0.85
            local dampMag = - (1.0 - steeringScale) * 3.0 * state.vehicleMass * lateralSpeed
            local dampVec = Vector4.new(rightVec.x * dampMag, rightVec.y * dampMag, rightVec.z * dampMag, 0.0)
            state.activeVehicle:AddCollisionForce(dampVec)
        end
    end
    local isHandbraking = false
    if state.activeVehicleBB then
        isHandbraking = state.activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end
    local maxRPM = state.activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
    if not maxRPM or maxRPM <= 0 then maxRPM = 8000.0 end
    local rpmPct = currentRPM / maxRPM
    local isSlideActive = false
    local slideFactor = 0.0
    local slideReason = ""
    if isHandbraking then
        isSlideActive = true
        slideFactor = 0.50
        slideReason = "Handbrake"
    elseif settings.transmissionMode == "Manual" or state.isManualOverride then
        if isThrottlePressed and (state.currentGearState == "1" or state.currentGearState == "2") and rpmPct > 0.55 then
            isSlideActive = true
            slideFactor = 0.35
            slideReason = "Power Oversteer"
        end
    end
    if not isSlideActive and math.abs(lateralSpeed) > 0.5 then
        if state.isDeceleratePressed and currentSpeed > 2.0 then
            isSlideActive = true
            slideFactor = 0.25
            slideReason = "Weight Transfer (Braking)"
        elseif isThrottlePressed and currentSpeed > 2.0 then
            local stabilizingMag = -0.15 * state.vehicleMass * lateralSpeed
            local stabilizingVec = Vector4.new(rightVec.x * stabilizingMag, rightVec.y * stabilizingMag, rightVec.z * stabilizingMag, 0.0)
            state.activeVehicle:AddCollisionForce(stabilizingVec)
            if math.abs(lateralSpeed) > 1.0 then
                logger.logDebug(string.format("Weight Transfer (Acceleration) stabilizing: LatSpeed=%.2f, Force=%.1f N", lateralSpeed, stabilizingMag))
            end
        end
    end
    if isSlideActive and math.abs(lateralSpeed) > 0.1 then
        local slideMag = slideFactor * 2.5 * state.vehicleMass * lateralSpeed
        local maxSlideForce = 1.5 * 9.81 * state.vehicleMass
        if slideMag > maxSlideForce then slideMag = maxSlideForce end
        if slideMag < -maxSlideForce then slideMag = -maxSlideForce end
        local slideVec = Vector4.new(rightVec.x * slideMag, rightVec.y * slideMag, rightVec.z * slideMag, 0.0)
        state.activeVehicle:AddCollisionForce(slideVec)
        logger.logDebug(string.format("Slide Assist active (%s): LatSpeed=%.2f m/s, Factor=%.2f, Force=%.1f N", slideReason, lateralSpeed, slideFactor, slideMag))
    end
    hudInterface.updateHUDState()
end

return {
    setGearBlock = setGearBlock,
    toggleDifferential = toggleDifferential,
    triggerShift = triggerShift,
    handleGearUp = handleGearUp,
    handleGearDown = handleGearDown,
    updateTransmission = updateTransmission
}
