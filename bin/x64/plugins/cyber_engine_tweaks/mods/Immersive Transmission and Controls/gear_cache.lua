local baseLimits = {
    [0] = { normalMin = 0.0, normalMax = 20.0, redlineMin = 20.0, redlineMax = 40.0 }, -- reverse
    [1] = { normalMin = 0.0, normalMax = 25.0, redlineMin = 50.0, redlineMax = 65.0 }, -- first gear
    [2] = { normalMin = 25.0, normalMax = 50.0, redlineMin = 90.0, redlineMax = 110.0 }, -- second gear
    [3] = { normalMin = 50.0, normalMax = 80.0, redlineMin = 140.0, redlineMax = 160.0 }, -- third gear
    [4] = { normalMin = 80.0, normalMax = 110.0, redlineMin = 190.0, redlineMax = 210.0 }, -- fourth gear
    [5] = { normalMin = 110.0, normalMax = 140.0, redlineMin = 240.0, redlineMax = 260.0 }, -- fifth gear
    [6] = { normalMin = 140.0, normalMax = 180.0, redlineMin = 260.0, redlineMax = 320.0 }, -- sixth gear
}

local function getGears(activeVehicle, gearSpeedScale)
    local vehicleGears = {}
    local vehicleMass = 1500.0
    if not activeVehicle then return vehicleGears, vehicleMass end

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
        local scale = gearSpeedScale or 1.0

        local revLimit = baseLimits[0]
        local firstGearRecord = engineData:GetGearsItem(0)
        local firstMaxRPM = firstGearRecord and firstGearRecord:MaxEngineRPM() or 6500.0
        local firstMinRPM = firstGearRecord and firstGearRecord:MinEngineRPM() or 900.0
        vehicleGears[0] = {
            maxSpeed = (revLimit.redlineMax / 3.6) * scale,
            minSpeed = (revLimit.normalMin / 3.6) * scale,
            normalMaxSpeed = (revLimit.normalMax / 3.6) * scale,
            redlineMin = (revLimit.redlineMin / 3.6) * scale,
            torqueMultiplier = firstGearRecord and firstGearRecord:TorqueMultiplier() * 0.9 or 2.0,
            maxRPM = firstMaxRPM,
            minRPM = firstMinRPM
        }

        for i = 0, gearsCount - 1 do
            local gearRecord = engineData:GetGearsItem(i)
            if gearRecord then
                local idx = i + 1
                local base = baseLimits[idx] or { normalMin = 140.0 + (idx - 5) * 30.0, normalMax = 140.0 + (idx - 5) * 30.0, redlineMin = 280.0 + (idx - 5) * 40.0, redlineMax = 300.0 + (idx - 5) * 40.0 }
                vehicleGears[idx] = {
                    minSpeed = (base.normalMin / 3.6) * scale,
                    maxSpeed = (base.redlineMax / 3.6) * scale,
                    normalMaxSpeed = (base.normalMax / 3.6) * scale,
                    redlineMin = (base.redlineMin / 3.6) * scale,
                    torqueMultiplier = gearRecord:TorqueMultiplier(),
                    maxRPM = gearRecord:MaxEngineRPM(),
                    minRPM = gearRecord:MinEngineRPM()
                }
            end
        end
    end)

    if #vehicleGears == 0 then
        local scale = gearSpeedScale or 1.0
        for idx = 1, 6 do
            local base = baseLimits[idx]
            vehicleGears[idx] = {
                maxSpeed = (base.redlineMax / 3.6) * scale,
                minSpeed = (base.normalMin / 3.6) * scale,
                normalMaxSpeed = (base.normalMax / 3.6) * scale,
                redlineMin = (base.redlineMin / 3.6) * scale,
                torqueMultiplier = 3.0 - (idx * 0.4),
                maxRPM = 6500.0,
                minRPM = 900.0
            }
        end
    end

    return vehicleGears, vehicleMass
end

return {
    getGears = getGears
}
