local reactor = peripheral.find("fission_reactor")
local boiler = peripheral.find("thermoelectric_boiler")
local turbine = peripheral.find("industrial_turbine")
local matrix = peripheral.find("induction_matrix")

local scram_bounds = {
    reactor_max_burn_rate = {
        min = 10,
        max = 100,
        get = function()
            return reactor.getMaxBurnRate()
        end
    },
    reactor_temperature = {
        min = 0,
        max = 800,
        get = function()
            return reactor.getTemperature()
        end
    },
    reactor_heating_rate = {
        min = 0,
        max = 100,
        get = function()
            return reactor.getHeatingRate()
        end
    },
    reactor_waste_percent = {
        min = 0,
        max = 90,
        get = function()
            return reactor.getWasteFilledPercentage()
        end
    },
    reactor_cold_coolant_percent = {
        min = 10,
        max = 100,
        get = function()
            return reactor.getCoolantFilledPercentage()
        end
    },
    reactor_hot_coolant_percent = {
        min = 0,
        max = 10,
        get = function()
            return reactor.getHeatedCoolantFilledPercentage()
        end
    },
    boiler_cold_coolant_percent = {
        min = 0,
        max = 10,
        get = function()
            return boiler.getCoolantFilledPercentage()
        end
    },
    boiler_hot_coolant_percent = {
        min = 0,
        max = 10,
        get = function()
            return boiler.getHeatedCoolantFilledPercentage()
        end
    },
    boiler_water_percent = {
        min = 50,
        max = 100,
        get = function()
            return boiler.getWaterFilledPercentage()
        end
    },
    boiler_steam_percent = {
        min = 0,
        max = 10,
        get = function()
            return boiler.getSteamFilledPercentage()
        end
    },
    turbine_water_percent = {
        min = 0,
        max = 100,
        get = function()
            return turbine.getWaterFilledPercentage()
        end
    },
    turbine_steam_percent = {
        min = 0,
        max = 10,
        get = function()
            return turbine.getSteamFilledPercentage()
        end
    },
    matrix_power_percent = {
        min = 0,
        max = 90,
        get = function()
            return matrix.getEnergyFilledPercentage()
        end
    },
}

local function in_scram_bounds()
    for key in scram_bounds do
        local value = key.get()
        if not (key.min >= value and value <= key.max) then
            return false
        end
    end
    return true
end