local state = require("state")
local settings = require("settings")
local engine = require("engine")
local rpm = require("rpm")
local logger = require("logger")

local STALL_ENGAGEMENT = 0.5
local STALL_DURATION = 0.8
local SPEED_TOLERANCE = 0.2
local STOP_ENGAGEMENT = 0.9
local RELEASE_FAST_THROTTLE = 0.8
local RELEASE_MID_THROTTLE = 0.3
local RELEASE_FAST = 0.12
local RELEASE_MID = 0.20
local RELEASE_SLOW = 0.40
local FALLBACK_MIN_RPM = 400
local STALL_LOG_INTERVAL = 1.0

local stallTimer = 0.0
local stallLogTimer = 0.0

local function getReleaseDuration()
    local throttle = state.inputs.accelerateVal or 0.0
    if throttle > RELEASE_FAST_THROTTLE then
        return RELEASE_FAST
    elseif throttle > RELEASE_MID_THROTTLE then
        return RELEASE_MID
    else
        return RELEASE_SLOW
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

        if eng > STALL_ENGAGEMENT
            and settings.stallEnabled
            and settings.transmissionMode == "Manual"
            and state.gearbox.current ~= "N"
            and state.gearbox.current ~= "R"
        then
            local gearIdx = tonumber(state.gearbox.current)
            local gearRec = gearIdx and state.vehicle.gears[gearIdx]
            local minSpeed = gearRec and gearRec.minSpeed or 0.0
            local minRPM = FALLBACK_MIN_RPM
            local ok, rpmResult = pcall(rpm.get, dt)
            local currentRPM = ok and rpmResult or 0
            if not ok then logger.logDebug("[STALL] rpm.get crashed: " .. tostring(rpmResult)) end
            stallLogTimer = stallLogTimer + dt
            if stallLogTimer >= STALL_LOG_INTERVAL then
                stallLogTimer = 0.0
                local stalling = (speed <= (minSpeed + SPEED_TOLERANCE) and currentRPM < minRPM) or (speed <= SPEED_TOLERANCE and eng >= STOP_ENGAGEMENT)
                logger.logDebug(string.format("[STALL] eng=%.2f gear=%d spd=%.1f/lim=%.1f RPM=%.0f/min=%.0f accel=%s stalling=%s timer=%.2f",
                    eng, gearIdx or -1, speed * 3.6, (minSpeed + SPEED_TOLERANCE) * 3.6, currentRPM, minRPM,
                    tostring(state.inputs.accelerate), tostring(stalling), stallTimer))
            end
            local isStallingByRPM = speed <= (minSpeed + SPEED_TOLERANCE) and currentRPM < minRPM
            local isStallingByStop = speed <= SPEED_TOLERANCE and eng >= STOP_ENGAGEMENT

            if (isStallingByRPM or isStallingByStop) and not state.inputs.accelerate then
                stallTimer = stallTimer + dt
                if stallTimer >= STALL_DURATION then
                    engine.stall()
                    logger.logDebug(string.format("[CLUTCH] Engine stalled (gear=%d speed=%.1f RPM=%.0f by=%s)", gearIdx or -1, speed * 3.6, currentRPM, isStallingByStop and "stop" or "RPM"))
                    stallTimer = 0.0
                end
            else
                stallTimer = 0.0
            end
        else
            stallTimer = 0.0
            stallLogTimer = 0.0
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
