local state = require("state")

local function updateClutch(dt)
    if state.engine.isStalled then
        state.clutch.engagement = 0.0
        state.clutch.transitionTimer = 0.0
        return
    end
    if state.clutch.isPressed then
        state.clutch.engagement = 0.0
        state.clutch.transitionTimer = 0.0
    else
        if state.clutch.transitionTimer > 0.0 then
            state.clutch.transitionTimer = state.clutch.transitionTimer - dt
            if state.clutch.transitionTimer <= 0.0 then
                state.clutch.transitionTimer = 0.0
                state.clutch.engagement = 1.0
            else
                local elapsed = (0.2 - state.clutch.transitionTimer) / 0.2
                state.clutch.engagement = math.min(elapsed, 1.0)
            end
        else
            state.clutch.engagement = 1.0
        end
    end
end

local function setClutch(pressed)
    if pressed == state.clutch.isPressed then
        return
    end
    state.clutch.isPressed = pressed
    if pressed then
        state.clutch.transitionTimer = 0.0
        state.clutch.engagement = 0.0
    else
        state.clutch.transitionTimer = 0.2
        state.clutch.engagement = 0.0
    end
end

return {
    updateClutch = updateClutch,
    setClutch = setClutch
}
