local state = require("state")

local function getCurrent()
    if not state.vehicle.bb then return 0 end
    return state.vehicle.bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMValue) or 0
end

local function getMax()
    if not state.vehicle.bb then return 8000 end
    return state.vehicle.bb:GetFloat(GetAllBlackboardDefs().Vehicle.RPMMax) or 8000
end

return {
    get = getCurrent,
    getMax = getMax
}
