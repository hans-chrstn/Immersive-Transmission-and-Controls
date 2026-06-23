local state = require("state")
local settings = require("settings")
local engine = require("engine")
local rpm = require("rpm")
local logger = require("logger")

local stallTimer = 0.0

local function getReleaseDuration()
    local throttle = state.inputs.accelerateVal or 0.0
    if throttle > 0.8 then
        return 0.12
    elseif throttle > 0.3 then
        return 0.20
    else
        return 0.40
    end
end

local function updateClutch(dt)
    if state.engine.isStalled then
        state.clutch.engagement = 0.0
        state.clutch.transitionTimer = 0.0
        stallTimer = 0.0
        return
    end

    if state.clutch.isPressed then
        state.clutch.engagement = 0.0
        state.clutch.transitionTimer = 0.0
        stallTimer = 0.0
    else
        if state.clutch.transitionTimer > 0.0 then
            state.clutch.transitionTimer = state.clutch.transitionTimer - dt
            local duration = getReleaseDuration()
            if state.clutch.transitionTimer <= 0.0 then
                state.clutch.transitionTimer = 0.0
                state.clutch.engagement = 1.0
            else
                local elapsed = (duration - state.clutch.transitionTimer) / duration
                state.clutch.engagement = math.min(elapsed, 1.0)
            end
        else
            state.clutch.engagement = 1.0
        end
    end

    local vehicle = state.vehicle.active
    if vehicle and not state.engine.isStalled then
        local eng = state.clutch.engagement
        local speed = vehicle:GetCurrentSpeed()

        if eng < 0.7 and speed < 2.0 then
            vehicle:ForceBrakesFor(dt)
        end

        if eng > 0.5 and settings.stallEnabled and settings.transmissionMode == "Manual" and state.gearbox.current ~= "N" then
            local gearIdx = tonumber(state.gearbox.current)
            if state.gearbox.current == "R" then gearIdx = 0 end
            local gearRec = gearIdx and state.vehicle.gears[gearIdx]
            local minSpeed = gearRec and gearRec.minSpeed or 0.0
            if speed < minSpeed and not state.inputs.accelerate then
                stallTimer = stallTimer + dt
                if stallTimer >= 0.25 then
                    engine.stall()
                    logger.logDebug(string.format("[CLUTCH] Engine stalled (gear=%d speed=%.1f < min=%.1f)", gearIdx or -1, speed * 3.6, minSpeed * 3.6))
                    stallTimer = 0.0
                end
            else
                stallTimer = 0.0
            end
        else
            stallTimer = 0.0
        end
    end
end

local function setClutch(pressed)
    if pressed == state.clutch.isPressed then
        return
    end
    state.clutch.isPressed = pressed
    stallTimer = 0.0
    if pressed then
        state.clutch.transitionTimer = 0.0
        state.clutch.engagement = 0.0
    else
        local duration = getReleaseDuration()
        state.clutch.transitionTimer = duration
        state.clutch.engagement = 0.0
        logger.logDebug(string.format("[CLUTCH] Released, ramp duration=%.2fs", duration))
    end
end

return {
    updateClutch = updateClutch,
    setClutch = setClutch
}
