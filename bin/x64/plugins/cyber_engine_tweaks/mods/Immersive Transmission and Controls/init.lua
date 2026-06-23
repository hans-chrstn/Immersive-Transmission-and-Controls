local settings = require("settings.init")
local state = require("state")
local logger = require("logger")
local vehicleManager = require("vehicle_manager")
local hudInterface = require("hud_interface")
local gearbox = require("gearbox")
local clutch = require("clutch")
local drivetrain = require("drivetrain")
local inputHandler = require("input_handler")
local settingsUI = require("settings.ui")
local keybinds = require("keybinds.init")

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

    settingsUI.register(nativeSettings)

    keybinds.register(Engine)


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
