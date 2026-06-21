local state = require("state")
local logger = require("logger")

local function registerInputHandlers()
    Observe("PlayerPuppet", "OnAction", function(self, action, stateContext)
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
                state.isAcceleratePressed = true
            elseif isReleased then
                state.isAcceleratePressed = false
            else
                state.isAcceleratePressed = (actionVal > 0.05)
            end
            logger.logDebug(string.format("Input vehicleAccelerate: val=%.2f, type=%s, pressed=%s, name=%s", actionVal, tostring(actionType), tostring(state.isAcceleratePressed), actionName))
        elseif actionName == "vehicleDecelrate" or actionName == "vehicleDecelerate" or actionName == "vehicleDecelerate2" or actionName == "Deceleration_Axis" then
            if isPressed then
                state.isDeceleratePressed = true
            elseif isReleased then
                state.isDeceleratePressed = false
            else
                state.isDeceleratePressed = (actionVal > 0.05)
            end
            logger.logDebug(string.format("Input vehicleDecelerate: val=%.2f, type=%s, pressed=%s, name=%s", actionVal, tostring(actionType), tostring(state.isDeceleratePressed), actionName))
        end
    end)
end

return {
    registerInputHandlers = registerInputHandlers
}
