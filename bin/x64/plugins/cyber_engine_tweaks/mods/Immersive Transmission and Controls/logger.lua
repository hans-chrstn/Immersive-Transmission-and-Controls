local settings = require("settings")
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
return {
    logDebug = logDebug
}
