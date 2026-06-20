local settings = require("settings")

local modName = "Immersive Transmission and Controls"
local version = "0.0.1"

local Engine = nil
local nativeSettings = nil
local activeVehicle = nil
local activeVehicleBB = nil
local isOverlayOpen = false
local isMounted = false


local vehicleGears = {}
local vehicleMass = 1500.0
local clutchTransitionTimer = 0.0



local currentGearState = "N" 
local targetGear = 1
local blockChangeGearState = true


local isShifting = false
local shiftTimeoutTimer = 0.0
local isManualOverride = false
local overrideTimer = 0.0
local overrideThresholdRPM = 0.90


local isClutchPressed = false
local isEngineStalled = false


local lastSentHUD = {
    visible = -1,
    mode = -1,
    gear = -1,
    diff = -1,
    handbrake = -1,
    clutch = -1,
    brake = -1,
    posX = -1,
    posY = -1
}


local GEAR_REVERSE = 0
local GEAR_NEUTRAL = 1
local GEAR_FIRST = 1


local isAcceleratePressed = false
local isDeceleratePressed = false
local isFullThrottlePressed = false





local function logDebug(msg)
    if settings.debugMode then
        print("[ITC][DEBUG] " .. tostring(msg))
        local file = io.open("Immersive Transmission and Controls.log", "a")
        if file then
            file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
            file:close()
        end
    end
end





local function getActiveVehicle()
    if not GetPlayer() then return nil end
    local success, mountedVehicle = pcall(function() return GetPlayer():GetMountedVehicle() end)
    if not success or not mountedVehicle then return nil end
    

    if mountedVehicle:IsA('vehicleAVBaseObject') or mountedVehicle:IsA('vehicleTankBaseObject') then
        return nil
    end
    
    return mountedVehicle
end

local function updateActiveVehicle()
    if activeVehicle and isMounted then
        return
    end
    
    local vehicle = getActiveVehicle()
    if vehicle and vehicle:IsPlayerDriver() then
        isMounted = true
        if not activeVehicle or activeVehicle:GetEntityID().hash ~= vehicle:GetEntityID().hash then
            activeVehicle = vehicle
            activeVehicleBB = activeVehicle:GetBlackboard()

            GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
            isEngineStalled = false
        end
    end
end


local function isEngineOn()
    if not activeVehicle then return false end
    if isEngineStalled then return false end
    

    if settings.evsIntegration then
        local success, result = pcall(function()
            local comp = activeVehicle:GetVehicleComponent()
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
    

    local success, result = pcall(function() return activeVehicle:IsEngineTurnedOn() end)
    if success then
        return result
    end
    

    local controllerPS = activeVehicle:GetVehicleComponent():GetVehicleControllerPS()
    if not controllerPS then return false end
    
    local engineState = controllerPS:GetState()
    return engineState ~= vehicleEState.Default
end

local function cacheVehicleGearData()
    vehicleGears = {}
    vehicleMass = 1500.0
    if not activeVehicle then return end
    
    local success, err = pcall(function()
        local record = activeVehicle:GetRecord()
        if not record then return end
        

        local m = record:Mass()
        if m and m > 0 then
            vehicleMass = m
        else
            local recordID = record:GetID()
            local eid = recordID and recordID.value or ""
            if eid ~= "" then
                local tdbVal = TweakDB:GetFlat(eid .. ".mass")
                if tdbVal then vehicleMass = tdbVal end
            end
        end
        

        local engineData = record:VehEngineData()
        if not engineData then return end
        
        local gearsCount = engineData:GetGearsCount()
        local scale = settings.gearSpeedScale or 0.70
        for i = 0, gearsCount - 1 do
            local gearRecord = engineData:GetGearsItem(i)
            if gearRecord then
                local idx = i + 1
                vehicleGears[idx] = {
                    maxSpeed = gearRecord:MaxSpeed() * scale,
                    minSpeed = gearRecord:MinSpeed() * scale,
                    torqueMultiplier = gearRecord:TorqueMultiplier(),
                    maxRPM = gearRecord:MaxEngineRPM(),
                    minRPM = gearRecord:MinEngineRPM()
                }
            end
        end
    end)
    

    if #vehicleGears == 0 then
        local scale = settings.gearSpeedScale or 0.70
        vehicleGears[1] = { maxSpeed = 12.5 * scale, minSpeed = 0.0, torqueMultiplier = 2.5 }
        vehicleGears[2] = { maxSpeed = 22.2 * scale, minSpeed = 8.3 * scale, torqueMultiplier = 1.8 }
        vehicleGears[3] = { maxSpeed = 34.7 * scale, minSpeed = 16.7 * scale, torqueMultiplier = 1.3 }
        vehicleGears[4] = { maxSpeed = 50.0 * scale, minSpeed = 25.0 * scale, torqueMultiplier = 1.0 }
        vehicleGears[5] = { maxSpeed = 69.4 * scale, minSpeed = 36.1 * scale, torqueMultiplier = 0.8 }
    end
    

    if vehicleGears[1] then
        local originalMax = vehicleGears[1].maxSpeed
        vehicleGears[1].maxSpeed = math.min(vehicleGears[1].maxSpeed, 12.5)
        logDebug(string.format("First gear maxSpeed set to %.2f m/s (%.1f km/h) (Original: %.2f m/s (%.1f km/h))", vehicleGears[1].maxSpeed, vehicleGears[1].maxSpeed * 3.6, originalMax, originalMax * 3.6))
    end
    

    if vehicleGears[1] then
        vehicleGears[0] = {
            maxSpeed = math.min(11.1, vehicleGears[1].maxSpeed * 0.7),
            minSpeed = 0.0,
            torqueMultiplier = vehicleGears[1].torqueMultiplier * 0.9,
            maxRPM = vehicleGears[1].maxRPM,
            minRPM = vehicleGears[1].minRPM
        }
    else
        vehicleGears[0] = { maxSpeed = 9.7, minSpeed = 0.0, torqueMultiplier = 2.0 }
    end
    
    logDebug(string.format("Cached data for vehicle. Mass=%.1f kg, GearsCount=%d, SpeedScale=%.2f", vehicleMass, #vehicleGears, settings.gearSpeedScale))
end


local function setGearBlock(block)
    blockChangeGearState = block
    GameOptions.SetBool("Vehicle", "BlockChangeGear", block)
end

local function toggleDifferential()
    if not activeVehicle then return end
    local newState = not GameOptions.GetBool("Vehicle", "UseDifferential")
    GameOptions.SetBool("Vehicle", "UseDifferential", newState)
    settings.useDifferential = newState
    settings.save()
    GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
    logDebug("Differential " .. (newState and "OPEN (Grip)" or "LOCKED (Drift)"))
end


local function triggerShift(direction)
    if not activeVehicle or isShifting then return end
    
    isShifting = true
    shiftTimeoutTimer = 0.3
    setGearBlock(false)
    

    if settings.transmissionMode == "Manual" or isManualOverride then
        clutchTransitionTimer = 0.2
    end
    

    GameObject.PlaySoundEvent(GetPlayer(), 'sq023_sc_10_press_button')
end





local function handleGearUp()
    updateActiveVehicle()
    if not activeVehicle or not activeVehicleBB then return end
    

    if settings.transmissionMode == "Manual" then
        if not isClutchPressed then
            logDebug("Shift UP Blocked: Clutch is disengaged/not pressed!")
            GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
            return
        end
    end
    

    if settings.transmissionMode == "Automatic" then
        if currentGearState == "R" then
            currentGearState = "N"
            logDebug("Shifted to Neutral (N)")
        elseif currentGearState == "N" then
            currentGearState = "D"
            targetGear = 1
            isManualOverride = false
            setGearBlock(false)
            logDebug("Shifted to Drive (D)")
        elseif currentGearState == "D" then

            isManualOverride = true
            overrideTimer = 4.0
            
            local currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
            targetGear = currentGear + 1
            triggerShift("UP")
            logDebug("Manual Override: Gear Up to " .. targetGear)
        end
    else

        if currentGearState == "R" then
            currentGearState = "N"
            logDebug("Shifted to Neutral (N)")
        elseif currentGearState == "N" then
            currentGearState = "1"
            targetGear = 1
            triggerShift("UP")
            logDebug("Shifted to 1st Gear")
        else
            local maxGears = #vehicleGears
            if maxGears == 0 then maxGears = 5 end
            
            local currentSelected = tonumber(currentGearState) or 1
            if currentSelected < maxGears then
                targetGear = currentSelected + 1
                currentGearState = tostring(targetGear)
                triggerShift("UP")
                logDebug("Gear Up to " .. targetGear)
            end
        end
    end
end

local function handleGearDown()
    updateActiveVehicle()
    if not activeVehicle or not activeVehicleBB then return end
    

    if settings.transmissionMode == "Manual" then
        if not isClutchPressed then
            logDebug("Shift DOWN Blocked: Clutch is disengaged/not pressed!")
            GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
            return
        end
    end
    
    if settings.transmissionMode == "Automatic" then
        if currentGearState == "D" then
            if isManualOverride then
                local currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear > 1 then
                    targetGear = currentGear - 1
                    triggerShift("DOWN")
                    logDebug("Manual Override: Gear Down to " .. targetGear)
                else
                    isManualOverride = false
                    currentGearState = "N"
                    logDebug("Shifted to Neutral (N)")
                end
            else
                currentGearState = "N"
                logDebug("Shifted to Neutral (N)")
            end
        elseif currentGearState == "N" then
            currentGearState = "R"
            targetGear = GEAR_REVERSE
            triggerShift("DOWN")
            logDebug("Shifted to Reverse (R)")
        end
    else

        if currentGearState == "R" then

            return
        elseif currentGearState == "N" then
            currentGearState = "R"
            targetGear = GEAR_REVERSE
            triggerShift("DOWN")
            logDebug("Shifted to Reverse (R)")
        elseif currentGearState == "1" then
            currentGearState = "N"
            logDebug("Shifted to Neutral (N)")
        else
            local currentSelected = tonumber(currentGearState) or 1
            if currentSelected > 1 then
                targetGear = currentSelected - 1
                currentGearState = tostring(targetGear)
                triggerShift("DOWN")
                logDebug("Gear Down to " .. targetGear)
            end
        end
    end
end





local function setHUDFact(name, value)
    pcall(function()
        local qs = Game.GetQuestsSystem()
        if qs then
            qs:SetFact(CName.new(name), math.floor(value))
        end
    end)
end

local function updateHUDState()
    local showHUD = settings.showHUD and isMounted and not isOverlayOpen
    local showHUDVal = showHUD and 1 or 0
    

    local modeVal = 0
    if settings.transmissionMode == "Manual" then
        modeVal = 1
    elseif isManualOverride then
        modeVal = 2
    end
    

    local gearVal = 1
    local currentGear = 1
    if activeVehicleBB then
        currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    end
    
    if settings.transmissionMode == "Manual" then
        if currentGearState == "R" then
            gearVal = 0
        elseif currentGearState == "N" then
            gearVal = 1
        else
            local gearNum = tonumber(currentGearState) or 1
            gearVal = gearNum + 1
        end
    else
        if currentGearState == "N" then
            gearVal = 1
        elseif currentGearState == "R" or currentGear == GEAR_REVERSE then
            gearVal = 0
        elseif currentGearState == "D" then
            if isManualOverride then
                gearVal = 200 + currentGear
            else
                gearVal = 100 + currentGear
            end
        end
    end
    
    local diffLocked = not GameOptions.GetBool("Vehicle", "UseDifferential")
    local diffLockedVal = diffLocked and 1 or 0
    local isHandbraking = false
    if activeVehicleBB then
        isHandbraking = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end
    local handbrakeVal = isHandbraking and 1 or 0
    
    local clutchVal = isClutchPressed and 1 or 0
    local footBrakeVal = isDeceleratePressed and 1 or 0
    
    local posXVal = math.floor((settings.hudX or 0.85) * 100)
    local posYVal = math.floor((settings.hudY or 0.82) * 100)
    

    if showHUDVal ~= lastSentHUD.visible or
       modeVal ~= lastSentHUD.mode or
       gearVal ~= lastSentHUD.gear or
       diffLockedVal ~= lastSentHUD.diff or
       handbrakeVal ~= lastSentHUD.handbrake or
       clutchVal ~= lastSentHUD.clutch or
       footBrakeVal ~= lastSentHUD.brake or
       posXVal ~= lastSentHUD.posX or
       posYVal ~= lastSentHUD.posY then
       
        lastSentHUD.visible = showHUDVal
        lastSentHUD.mode = modeVal
        lastSentHUD.gear = gearVal
        lastSentHUD.diff = diffLockedVal
        lastSentHUD.handbrake = handbrakeVal
        lastSentHUD.clutch = clutchVal
        lastSentHUD.brake = footBrakeVal
        lastSentHUD.posX = posXVal
        lastSentHUD.posY = posYVal
        
        setHUDFact("itc_hud_visible", showHUDVal)
        setHUDFact("itc_hud_mode", modeVal)
        setHUDFact("itc_hud_gear", gearVal)
        setHUDFact("itc_hud_diff", diffLockedVal)
        setHUDFact("itc_hud_handbrake", handbrakeVal)
        setHUDFact("itc_hud_clutch", clutchVal)
        setHUDFact("itc_hud_brake", footBrakeVal)
        setHUDFact("itc_hud_pos_x", posXVal)
        setHUDFact("itc_hud_pos_y", posYVal)
        
        logDebug(string.format("HUD Fact Update: Vis=%d, Mode=%d, Gear=%d, Diff=%d, PB=%d, Clutch=%d, Brake=%d, X=%d, Y=%d", 
            showHUDVal, modeVal, gearVal, diffLockedVal, handbrakeVal, clutchVal, footBrakeVal, posXVal, posYVal))
    end
end

local function updateTransmission(dt)
    updateActiveVehicle()
    if not activeVehicle or not activeVehicleBB then return end
    
    if #vehicleGears == 0 then
        cacheVehicleGearData()
    end


    local currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
    local currentSpeed = activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.SpeedValue)
    local currentRPM = activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue)
    

    local isThrottlePressed = false
    if currentGearState == "R" then
        isThrottlePressed = isDeceleratePressed
    elseif currentGearState == "N" then
        isThrottlePressed = isAcceleratePressed or isDeceleratePressed
    else
        isThrottlePressed = isAcceleratePressed
    end


    if isEngineStalled and isThrottlePressed then
        local canRestart = false
        if settings.transmissionMode == "Manual" then
            if currentGearState == "N" or isClutchPressed then
                canRestart = true
            end
        else
            if currentGearState == "N" then
                canRestart = true
            end
        end

        if canRestart then
            isEngineStalled = false
            activeVehicle:TurnEngineOn(true)
            logDebug("Engine started automatically via Throttle input.")
        end
    end
    

    local isEVSOff = settings.evsIntegration and not isEngineOn()
    

    if isEngineStalled and settings.transmissionMode == "Manual" and not isClutchPressed and currentGearState ~= "N" then
        if currentSpeed > 1.5 then
            isEngineStalled = false
            activeVehicle:TurnEngineOn(true)
            logDebug(string.format("Engine bump-started: Speed=%.2f m/s (%.1f km/h), Gear=%s", currentSpeed, currentSpeed * 3.6, currentGearState))
        end
    end

    if isEVSOff or isEngineStalled then

        if isShifting then
            shiftTimeoutTimer = shiftTimeoutTimer - dt
            if shiftTimeoutTimer <= 0.0 or currentGear == targetGear then
                isShifting = false
                logDebug(string.format("Shift window finished (Stalled). Target=%d, Actual=%d", targetGear, currentGear))
                setGearBlock(true)
            end
        end


        if not isShifting then
            if currentGearState == "R" then
                if currentGear == GEAR_REVERSE or currentGear == 0 then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            elseif currentGearState == "N" then
                setGearBlock(true)
            else
                local expectedGear = tonumber(currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end


        if not isClutchPressed and currentGearState ~= "N" then
            activeVehicle:ForceBrakesFor(0.1)
        end

        updateHUDState()
        return
    end
    

    if isShifting then
        shiftTimeoutTimer = shiftTimeoutTimer - dt
        if shiftTimeoutTimer <= 0.0 or currentGear == targetGear then
            isShifting = false
            logDebug(string.format("Shift window finished. Target=%d, Actual=%d", targetGear, currentGear))
            


            if settings.transmissionMode == "Manual" or isManualOverride then
                setGearBlock(true)
            else

                if currentGearState == "N" then
                    setGearBlock(true)
                elseif currentGearState == "R" and currentGear == GEAR_REVERSE then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end
    end
    

    local maxDecelForce = 6.0 * 9.81 * vehicleMass
    

    if settings.transmissionMode == "Manual" or isManualOverride then

        if clutchTransitionTimer > 0.0 then
            clutchTransitionTimer = clutchTransitionTimer - dt
        end

        local gearIdx = nil
        if currentGearState == "R" then
            gearIdx = 0
        elseif currentGearState == "N" then
            gearIdx = nil
        else
            gearIdx = tonumber(currentGearState)
        end
        

        if settings.transmissionMode == "Manual" and isClutchPressed then
            if not isShifting then
                local expectedGear = tonumber(currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end

            if isThrottlePressed then
                activeVehicle:ForceBrakesFor(0.1)
            elseif currentSpeed < 1.0 then

                activeVehicle:ForceBrakesFor(0.1)
                logDebug(string.format("Clutch creep prevention: speed=%.2f m/s (%.1f km/h), applying brakes", currentSpeed, currentSpeed * 3.6))
            end
            updateHUDState()
            return
        end
        

        if currentGearState == "N" then
            setGearBlock(true)

            if isThrottlePressed then
                activeVehicle:ForceBrakesFor(0.1)
            elseif currentSpeed < 1.0 then

                activeVehicle:ForceBrakesFor(0.1)
                logDebug(string.format("Neutral creep prevention: speed=%.2f m/s (%.1f km/h), applying brakes", currentSpeed, currentSpeed * 3.6))
            end
            updateHUDState()
            return
        end
        

        if settings.transmissionMode == "Manual" and not isClutchPressed and currentGearState ~= "N" then
            local selectedGear = vehicleGears[gearIdx]
            if selectedGear then
                local gearMaxRPM = selectedGear.maxRPM or 6500.0
                if gearMaxRPM <= 0 then gearMaxRPM = 6500.0 end
                local stallSpeed = selectedGear.maxSpeed * (550.0 / gearMaxRPM)
                

                if stallSpeed < 1.5 then stallSpeed = 1.5 end

                if currentSpeed < stallSpeed then
                    if (gearIdx == 1 or gearIdx == 0) and isThrottlePressed and currentSpeed < 1.5 then

                        local launchMag = 1.8 * vehicleMass
                        if gearIdx == 0 then launchMag = -launchMag end
                        local forwardVec = activeVehicle:GetWorldForward()
                        local launchVec = Vector4.new(forwardVec.x * launchMag, forwardVec.y * launchMag, forwardVec.z * launchMag, 0.0)
                        activeVehicle:AddCollisionForce(launchVec)
                        logDebug(string.format("Clutch biting: launching vehicle. Speed=%.2f m/s (%.1f km/h), target launch gear=%d", currentSpeed, currentSpeed * 3.6, gearIdx))
                    else

                        isEngineStalled = true
                        activeVehicle:TurnEngineOn(false)
                        setGearBlock(true)
                        GameObject.PlaySoundEvent(GetPlayer(), 'ui_menu_error')
                        logDebug(string.format("Stall triggered: Released clutch below stall speed (Speed=%.2f m/s (%.1f km/h), StallSpeed=%.2f m/s (%.1f km/h)) in gear %s", currentSpeed, currentSpeed * 3.6, stallSpeed, stallSpeed * 3.6, currentGearState))
                        updateHUDState()
                        return
                    end
                end
            end
        end
        

        if not isShifting then
            if currentGearState == "R" then
                if currentGear == GEAR_REVERSE or currentGear == 0 then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            else

                local expectedGear = tonumber(currentGearState)
                if expectedGear and currentGear == expectedGear then
                    setGearBlock(true)
                else
                    setGearBlock(false)
                end
            end
        end
        
        if gearIdx then
            local selectedGear = vehicleGears[gearIdx]
            if selectedGear then

                local maxSpeed = selectedGear.maxSpeed
                if currentSpeed > maxSpeed then
                    local forwardVec = activeVehicle:GetWorldForward()

                    local diffMS = currentSpeed - maxSpeed
                    local dragMag = -8.0 * vehicleMass * diffMS
                    

                    if gearIdx == 0 then
                        dragMag = 8.0 * vehicleMass * diffMS
                    end
                    

                    if dragMag < -maxDecelForce then dragMag = -maxDecelForce end
                    if dragMag > maxDecelForce then dragMag = maxDecelForce end
                    
                    local dragVec = Vector4.new(forwardVec.x * dragMag, forwardVec.y * dragMag, forwardVec.z * dragMag, 0.0)
                    activeVehicle:AddCollisionForce(dragVec)
                    

                    local brakesApplied = false
                    if diffMS > 1.5 then
                        activeVehicle:ForceBrakesFor(dt)
                        brakesApplied = true
                    end
                    
                    logDebug(string.format("Speed Limiter active: Speed=%.2f m/s (%.1f km/h), Max=%.2f m/s (%.1f km/h), Force=%.1f N, BrakesApplied=%s", 
                        currentSpeed, currentSpeed * 3.6, maxSpeed, maxSpeed * 3.6, dragMag, tostring(brakesApplied)))
                end
                

                if clutchTransitionTimer > 0.0 then

                    local forwardVec = activeVehicle:GetWorldForward()
                    local slipMag = -2.0 * vehicleMass
                    local slipVec = Vector4.new(forwardVec.x * slipMag, forwardVec.y * slipMag, forwardVec.z * slipMag, 0.0)
                    activeVehicle:AddCollisionForce(slipVec)
                elseif isThrottlePressed then
                    local Tg = selectedGear.torqueMultiplier
                    local nativeGearIdx = currentGear
                    if nativeGearIdx == 0 then nativeGearIdx = 1 end
                    local Tn = vehicleGears[nativeGearIdx] and vehicleGears[nativeGearIdx].torqueMultiplier or 1.0
                    
                    local ratio = Tg / Tn
                    local forceMag = 0.0
                    local forwardVec = activeVehicle:GetWorldForward()
                    
                    if ratio > 1.0 then


                        if nativeGearIdx <= gearIdx then
                            forceMag = (ratio - 1.0) * 1.5 * vehicleMass
                            logDebug(string.format("Torque boost applied: Target=%d, Native=%d, Ratio=%.2f, Force=%.1f N", gearIdx, nativeGearIdx, ratio, forceMag))
                        else
                            logDebug(string.format("Torque boost blocked (Downshifting): Target=%d, Native=%d, Ratio=%.2f (Speed Limiter will engine brake)", gearIdx, nativeGearIdx, ratio))
                        end
                    elseif ratio < 1.0 then

                        if currentSpeed > 0.1 then
                            forceMag = (ratio - 1.0) * 1.2 * vehicleMass
                        end
                    end
                    

                    local pitchZ = forwardVec.z
                    if pitchZ > 0.02 and (gearIdx == 1 or gearIdx == 2) then

                        local uphillBoost = pitchZ * 8.0 * vehicleMass
                        forceMag = forceMag + uphillBoost
                    end
                    

                    if math.abs(forceMag) > 1.0 then

                        if gearIdx == 0 then
                            forceMag = -forceMag
                        end
                        local forceVec = Vector4.new(forwardVec.x * forceMag, forwardVec.y * forceMag, forwardVec.z * forceMag, 0.0)
                        activeVehicle:AddCollisionForce(forceVec)
                    end
                end
            end
        end
    else

        if currentGearState == "N" then
            setGearBlock(true)
            if isThrottlePressed then
                activeVehicle:ForceBrakesFor(0.1)
            end
            updateHUDState()
            return
        elseif currentGearState == "R" then
            if currentGear == GEAR_REVERSE or currentGear == 0 then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        elseif currentGearState == "D" and not isManualOverride then
            if settings.reverseGateRealism and currentSpeed < 0.1 and not isShifting then
                setGearBlock(true)
            else
                setGearBlock(false)
            end
        end
    end
    

    if isManualOverride then
        overrideTimer = overrideTimer - dt
        

        local maxRPM = activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
        if not maxRPM or maxRPM <= 0 then maxRPM = 8000.0 end
        local isOverRevving = currentRPM > (overrideThresholdRPM * maxRPM)
        
        if overrideTimer <= 0.0 or isOverRevving then
            isManualOverride = false
            if settings.transmissionMode == "Automatic" then
                currentGearState = "D"
                setGearBlock(false)
                logDebug("Manual Override expired. Returned to Automatic.")
            end
        end
    end


    if settings.cruisingEnabled and not isFullThrottlePressed and currentGearState ~= "N" then

        local activeGearIdx = nil
        if settings.transmissionMode == "Manual" or isManualOverride then
            if currentGearState == "R" then
                activeGearIdx = 0
            else
                activeGearIdx = tonumber(currentGearState)
            end
        else

            if currentGearState == "R" or currentGear == GEAR_REVERSE then
                activeGearIdx = 0
            elseif currentGearState == "D" then
                activeGearIdx = currentGear
                if activeGearIdx == 0 then activeGearIdx = 1 end
            end
        end
        
        local selectedGear = activeGearIdx and vehicleGears[activeGearIdx]
        if selectedGear then
            local maxCruiseSpeed = selectedGear.maxSpeed * settings.cruiseThrottle
            local isCruisingThrottlePressed = false
            if activeGearIdx == 0 then
                isCruisingThrottlePressed = isDeceleratePressed
            else
                isCruisingThrottlePressed = isAcceleratePressed
            end
            
            if isCruisingThrottlePressed then
                local cruiseDragMag = 0.0
                if currentSpeed > maxCruiseSpeed then

                    local diff = currentSpeed - maxCruiseSpeed
                    cruiseDragMag = -8.0 * vehicleMass * diff
                else

                    cruiseDragMag = -1.2 * vehicleMass * (1.0 - settings.cruiseThrottle)
                end
                

                if activeGearIdx == 0 then
                    cruiseDragMag = -cruiseDragMag
                end
                

                if cruiseDragMag < -maxDecelForce then cruiseDragMag = -maxDecelForce end
                if cruiseDragMag > maxDecelForce then cruiseDragMag = maxDecelForce end
                
                local forwardVec = activeVehicle:GetWorldForward()
                local cruiseDragVec = Vector4.new(forwardVec.x * cruiseDragMag, forwardVec.y * cruiseDragMag, forwardVec.z * cruiseDragMag, 0.0)
                activeVehicle:AddCollisionForce(cruiseDragVec)
            end
        end
    end
    

    local velocity = activeVehicle:GetLinearVelocity()
    local forwardVec = activeVehicle:GetWorldForward()
    local rightVec = Vector4.new(-forwardVec.y, forwardVec.x, 0.0, 0.0)
    local lateralSpeed = velocity.x * rightVec.x + velocity.y * rightVec.y + velocity.z * rightVec.z

    if settings.steeringDampingEnabled then
        if math.abs(lateralSpeed) > 0.05 then
            local steeringScale = settings.steeringScale or 0.85
            local dampMag = - (1.0 - steeringScale) * 3.0 * vehicleMass * lateralSpeed
            local dampVec = Vector4.new(rightVec.x * dampMag, rightVec.y * dampMag, rightVec.z * dampMag, 0.0)
            activeVehicle:AddCollisionForce(dampVec)
        end
    end


    local isHandbraking = false
    if activeVehicleBB then
        isHandbraking = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.IsHandbraking) == 1
    end

    local maxRPM = activeVehicleBB:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax)
    if not maxRPM or maxRPM <= 0 then maxRPM = 8000.0 end
    local rpmPct = currentRPM / maxRPM
    
    local isSlideActive = false
    local slideFactor = 0.0
    local slideReason = ""
    
    if isHandbraking then
        isSlideActive = true
        slideFactor = 0.50
        slideReason = "Handbrake"
    elseif settings.transmissionMode == "Manual" or isManualOverride then

        if isThrottlePressed and (currentGearState == "1" or currentGearState == "2") and rpmPct > 0.55 then
            isSlideActive = true
            slideFactor = 0.35
            slideReason = "Power Oversteer"
        end
    end
    



    if not isSlideActive and math.abs(lateralSpeed) > 0.5 then
        if isDeceleratePressed and currentSpeed > 2.0 then
            isSlideActive = true
            slideFactor = 0.25
            slideReason = "Weight Transfer (Braking)"
        elseif isThrottlePressed and currentSpeed > 2.0 then

            local stabilizingMag = -0.15 * vehicleMass * lateralSpeed
            local stabilizingVec = Vector4.new(rightVec.x * stabilizingMag, rightVec.y * stabilizingMag, rightVec.z * stabilizingMag, 0.0)
            activeVehicle:AddCollisionForce(stabilizingVec)
            if math.abs(lateralSpeed) > 1.0 then
                logDebug(string.format("Weight Transfer (Acceleration) stabilizing: LatSpeed=%.2f, Force=%.1f N", lateralSpeed, stabilizingMag))
            end
        end
    end
    

    if isSlideActive and math.abs(lateralSpeed) > 0.1 then

        local slideMag = slideFactor * 2.5 * vehicleMass * lateralSpeed
        

        local maxSlideForce = 1.5 * 9.81 * vehicleMass
        if slideMag > maxSlideForce then slideMag = maxSlideForce end
        if slideMag < -maxSlideForce then slideMag = -maxSlideForce end
        
        local slideVec = Vector4.new(rightVec.x * slideMag, rightVec.y * slideMag, rightVec.z * slideMag, 0.0)
        activeVehicle:AddCollisionForce(slideVec)
        
        logDebug(string.format("Slide Assist active (%s): LatSpeed=%.2f m/s, Factor=%.2f, Force=%.1f N", slideReason, lateralSpeed, slideFactor, slideMag))
    end

    updateHUDState()
end





registerForEvent("onInit", function()
    Engine = GetMod("0-Engine")
    nativeSettings = GetMod("nativeSettings")
    

    if Engine then
        Engine.Subscribe("VehicleMount", function(vehicle)
            if vehicle and vehicle:IsPlayerDriver() then
                isMounted = true
                activeVehicle = vehicle
                activeVehicleBB = activeVehicle:GetBlackboard()
                isEngineStalled = false
                

                currentGearState = "N"
                setGearBlock(true)
                isManualOverride = false
                

                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                

                cacheVehicleGearData()
                
                logDebug("[0-Engine] Vehicle mounted. Set to Neutral (N).")
            end
        end)
        
        Engine.Subscribe("VehicleUnmount", function()
            isMounted = false
            activeVehicle = nil
            activeVehicleBB = nil
            isManualOverride = false
            vehicleGears = {}
            setGearBlock(false)
            

            setHUDFact("itc_hud_visible", 0)
            setHUDFact("itc_hud_gear", 1)
            setHUDFact("itc_hud_mode", 0)
            
            logDebug("[0-Engine] Vehicle unmounted.")
        end)
    else

        Observe('VehicleComponent', 'OnMountingEvent', function(self, evt)
            local vehicle = self:GetVehicle()
            if vehicle and vehicle:IsPlayerDriver() then
                isMounted = true
                activeVehicle = vehicle
                activeVehicleBB = activeVehicle:GetBlackboard()
                isEngineStalled = false
                

                currentGearState = "N"
                setGearBlock(true)
                isManualOverride = false
                

                GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                

                cacheVehicleGearData()
                
                logDebug("[Fallback] Vehicle mounted. Set to Neutral (N).")
            end
        end)
        
        Observe('VehicleComponent', 'OnUnmountingEvent', function(self, evt)
            isMounted = false
            activeVehicle = nil
            activeVehicleBB = nil
            isManualOverride = false
            vehicleGears = {}
            setGearBlock(false)
            

            setHUDFact("itc_hud_visible", 0)
            setHUDFact("itc_hud_gear", 1)
            setHUDFact("itc_hud_mode", 0)
            updateActiveVehicle()
            
            logDebug("[Fallback] Vehicle unmounted.")
        end)
    end


    Observe("PlayerPuppet", "OnAction", function(self, action, state)
        local actionName = ""
        local actionType = nil
        local actionVal = 0

        pcall(function() actionName = Game.NameToString(action:GetName(action)) end)
        if not actionName or actionName == "" then
            pcall(function() actionName = tostring(ListenerAction.GetName(action)) end)
        end
        pcall(function() actionType = action:GetType(action) end)
        if not actionType then
            pcall(function() actionType = ListenerAction.GetType(action) end)
        end
        pcall(function() actionVal = action:GetValue(action) end)
        if not actionVal then
            pcall(function() actionVal = ListenerAction.GetValue(action) end)
        end

        local isPressed = false
        local isReleased = false
        
        if actionType then
            local typeStr = ""
            if type(actionType) == "table" or type(actionType) == "userdata" then
                pcall(function() typeStr = tostring(actionType.value or "") end)
            else
                typeStr = tostring(actionType)
            end
            
            if typeStr == "BUTTON_PRESSED" or typeStr == "BUTTON_HOLD" or typeStr == "AXIS_CHANGE" or
               actionType == gameinputActionType.BUTTON_PRESSED or actionType == gameinputActionType.BUTTON_HOLD then
                isPressed = true
            elseif typeStr == "BUTTON_RELEASED" or actionType == gameinputActionType.BUTTON_RELEASED then
                isReleased = true
            end
        end

        if actionName == "vehicleAccelerate" or actionName == "vehicleAccelerate2" or actionName == "Acceleration_Axis" then
            if isPressed then
                isAcceleratePressed = true
            elseif isReleased then
                isAcceleratePressed = false
            else
                isAcceleratePressed = (actionVal > 0.05)
            end
            logDebug(string.format("Input vehicleAccelerate: val=%.2f, type=%s, pressed=%s, name=%s", actionVal, tostring(actionType), tostring(isAcceleratePressed), actionName))
        elseif actionName == "vehicleDecelrate" or actionName == "vehicleDecelerate" or actionName == "vehicleDecelerate2" or actionName == "Deceleration_Axis" then
            if isPressed then
                isDeceleratePressed = true
            elseif isReleased then
                isDeceleratePressed = false
            else
                isDeceleratePressed = (actionVal > 0.05)
            end
            logDebug(string.format("Input vehicleDecelerate: val=%.2f, type=%s, pressed=%s, name=%s", actionVal, tostring(actionType), tostring(isDeceleratePressed), actionName))
        end
    end)


    if nativeSettings then
        nativeSettings.addTab("/ITC", "Immersive Transmission")
        
        nativeSettings.addSelectorString("/ITC", "Transmission Mode", "Choose drivetrain shifting mode.", {"Automatic", "Manual"}, 
            (settings.transmissionMode == "Automatic" and 0 or 1), 0, function(idx)
                settings.transmissionMode = (idx == 0 and "Automatic" or "Manual")
                if settings.transmissionMode == "Manual" then
                    if activeVehicleBB then
                        local currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                        if currentGear == GEAR_REVERSE or currentGear == 0 then
                            currentGearState = "R"
                        else
                            currentGearState = tostring(math.max(1, currentGear))
                        end
                    else
                        currentGearState = "1"
                    end
                else
                    currentGearState = "D"
                    isManualOverride = false
                    setGearBlock(false)
                end
                settings.save()
            end)
            
        nativeSettings.addSwitch("/ITC", "Realistic Reverse Gate", "Prevents automatic reversing when stopped in forward gear. Requires manual shift to Reverse (R).", 
            settings.reverseGateRealism, true, function(state)
                settings.reverseGateRealism = state
                settings.save()
            end)
            
        nativeSettings.addSwitch("/ITC", "Automatic Manual Override", "Allows manual shifting while in Auto mode, creating a temporary gear override.", 
            settings.manualOverrideOnAuto, true, function(state)
                settings.manualOverrideOnAuto = state
                settings.save()
            end)
            
        nativeSettings.addSwitch("/ITC", "Locked Differential (Drift Mode)", "Forces drive wheels to spin at the same speed, making drifting easier. Can toggle while driving via keybind.", 
            not settings.useDifferential, false, function(state)
                settings.useDifferential = not state
                settings.save()
                if activeVehicle then
                    GameOptions.SetBool("Vehicle", "UseDifferential", settings.useDifferential)
                end
            end)
            
        nativeSettings.addSwitch("/ITC", "Show Gear HUD", "Displays the current gear overlay on the screen.", 
            settings.showHUD, true, function(state)
                settings.showHUD = state
                settings.save()
            end)

        nativeSettings.addSwitch("/ITC", "Enable Cruising Throttle", "Limits default acceleration on keyboard. Holding Full Throttle modifier disables limits.", 
            settings.cruisingEnabled, true, function(state)
                settings.cruisingEnabled = state
                settings.save()
            end)
            
        nativeSettings.addRangeFloat("/ITC", "Cruising Throttle Scale", "Default cruising throttle level (recommended: 0.3).", 0.1, 1.0, 0.05, "%.2f", 
            settings.cruiseThrottle, function(val)
                settings.cruiseThrottle = val
                settings.save()
            end)
            
        nativeSettings.addSwitch("/ITC", "Enable Steering Damping", "Applies stabilizing lateral forces to smooth out keyboard steering.", 
            settings.steeringDampingEnabled, true, function(state)
                settings.steeringDampingEnabled = state
                settings.save()
            end)
            
        nativeSettings.addRangeFloat("/ITC", "Steering Damping Factor", "Strength of steering damping (higher = more grip, less slide).", 0.5, 1.0, 0.05, "%.2f", 
            settings.steeringScale, function(val)
                settings.steeringScale = val
                settings.save()
            end)

        nativeSettings.addRangeFloat("/ITC", "Gear Speed Limit Scale", "Scales vehicle gear max speeds (default: 0.70). Lower values make gear limits more realistic.", 0.5, 1.2, 0.05, "%.2f", 
            settings.gearSpeedScale, function(val)
                settings.gearSpeedScale = val
                settings.save()
                cacheVehicleGearData()
            end)

        nativeSettings.addSwitch("/ITC", "Verbose Debug Logging", "Enables writing debug logs to Immersive Transmission and Controls.log.", 
            settings.debugMode, true, function(state)
                settings.debugMode = state
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

            updateTransmission(0.083)
        end)
    end
end)


local updateTimer = 0.0
registerForEvent("onUpdate", function(dt)
    if not Engine then
        updateTimer = updateTimer + dt
        if updateTimer >= 0.083 then
            updateTransmission(updateTimer)
            updateTimer = 0.0
        end
    end
end)


registerForEvent("onOverlayOpen", function() isOverlayOpen = true end)
registerForEvent("onOverlayClose", function() isOverlayOpen = false end)


registerInput("ITC_GearUp", "Gear Up / Shift Drive", function(isDown)
    if isDown then handleGearUp() end
end)

registerInput("ITC_GearDown", "Gear Down / Shift Reverse", function(isDown)
    if isDown then handleGearDown() end
end)

registerInput("ITC_Clutch", "Manual Clutch (Hold)", function(isDown)
    isClutchPressed = isDown
    logDebug("Clutch key: " .. (isClutchPressed and "HELD" or "RELEASED"))
end)

registerInput("ITC_ToggleTransmission", "Toggle Transmission Mode", function(isDown)
    if isDown then
        if settings.transmissionMode == "Automatic" then
            settings.transmissionMode = "Manual"

            if activeVehicleBB then
                local currentGear = activeVehicleBB:GetInt(GetAllBlackboardDefs().Vehicle.GearValue)
                if currentGear == GEAR_REVERSE or currentGear == 0 then
                    currentGearState = "R"
                else
                    currentGearState = tostring(math.max(1, currentGear))
                end
            else
                currentGearState = "1"
            end
            logDebug("Switched to Manual Gearbox")
        else
            settings.transmissionMode = "Automatic"
            currentGearState = "D"
            isManualOverride = false
            setGearBlock(false)
            logDebug("Switched to Automatic Gearbox")
        end
        settings.save()
    end
end)

registerInput("ITC_ToggleEngine", "Stall / Restart Engine", function(isDown)
    if isDown and activeVehicle then
        if isEngineOn() then
            isEngineStalled = true
            activeVehicle:TurnEngineOn(false)
            logDebug("Engine turned OFF manually.")
        else
            isEngineStalled = false
            activeVehicle:TurnEngineOn(true)
            logDebug("Engine started/restored manually.")
        end
    end
end)

registerInput("ITC_ToggleDifferential", "Toggle Differential Lock (Drift/Grip)", function(isDown)
    if isDown then toggleDifferential() end
end)

registerInput("ITC_Boost", "Full Throttle / Boost Modifier", function(isDown)
    isFullThrottlePressed = isDown
end)

logDebug("Immersive Transmission & Controls Mod successfully loaded!")
