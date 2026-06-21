local settings = {
    transmissionMode = "Automatic",
    reverseGateRealism = true,
    manualOverrideOnAuto = true,
    showHUD = true,
    evsIntegration = true,
    useDifferential = true,
    cruisingEnabled = true,
    cruiseThrottle = 0.3,
    steeringDampingEnabled = true,
    steeringScale = 0.85,
    hudX = 0.85,
    hudY = 0.82,
    gearSpeedScale = 1.0,
    cruiseControlEnabled = false,
    debugMode = true
}

function settings.load()
    local file = io.open("settings.json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        local data = json.decode(content)
        if data then
            for k, v in pairs(data) do
                settings[k] = v
            end
        end
    end
    return settings
end

function settings.save()
    local file = io.open("settings.json", "w")
    if file then

        local data = {}
        for k, v in pairs(settings) do
            if type(v) ~= "function" then
                data[k] = v
            end
        end
        file:write(json.encode(data))
        file:close()
    end
end

return settings
