local state = require("state")
local logger = require("logger")

local function registerInputHandlers(Engine)
    Observe("PlayerPuppet", "OnAction", function(self, action, stateContext)

        if not state.vehicle.isMounted then return end
        if Engine and Engine.GetState().inMenu then return end

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
                state.inputs.accelerate = true
                state.inputs.accelerateVal = 1.0
            elseif isReleased then
                state.inputs.accelerate = false
                state.inputs.accelerateVal = 0.0
            else
                state.inputs.accelerate = (actionVal > 0.05)
                state.inputs.accelerateVal = actionVal
            end
        elseif actionName == "vehicleDecelrate" or actionName == "vehicleDecelerate" or actionName == "vehicleDecelerate2" or actionName == "Deceleration_Axis" then
            if isPressed then
                state.inputs.decelerate = true
                state.inputs.decelerateVal = 1.0
            elseif isReleased then
                state.inputs.decelerate = false
                state.inputs.decelerateVal = 0.0
            else
                state.inputs.decelerate = (actionVal > 0.05)
                state.inputs.decelerateVal = actionVal
            end
        end
    end)
end

return {
    registerInputHandlers = registerInputHandlers
}
