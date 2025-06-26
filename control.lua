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

local function scram_if_out_of_bounds()
    for key, bounds in pairs(scram_bounds) do
        local value = bounds.get()
        if not (bounds.min <= value and value <= bounds.max) then
            print("REACTOR ERROR: " .. key .. "out of safe range.")
            print("Min: " .. bounds.min)
            print("Max: " .. bounds.max)
            print("Actual Value: " .. value)
            print("!!! INITIATING EMERGENCY SHUTDOWN !!!")
            reactor.scram()
            if reactor.getStatus() == false then
                print("REACTOR SHUTDOWN SUCCESSFUL.")
            else
                print("!!! REACTOR SHUTDOWN NOT SUCCESSFUL !!! ")
            end
            return true
        end
    end
    return false
end

local function map_range(input, input_min, input_max, output_min, output_max)
    local normalized = (input - input_min) / (input_max - input_min)
    return output_min + normalized * (output_max - output_min)
end

local function update_burn_rate()
    local new_burn_rate = map_range(
        scram_bounds.matrix_power_percent.get(),
        scram_bounds.matrix_power_percent.min,
        scram_bounds.matrix_power_percent.max,
        scram_bounds.reactor_max_burn_rate.max,
        scram_bounds.reactor_max_burn_rate.min
    )
    reactor.setBurnRate(new_burn_rate)
end

local function main_reactor_loop()
    while true do
        if reactor.getStatus() == true then
            scram_if_out_of_bounds()
            update_burn_rate()
        else
            reactor.setBurnRate(0)
        end
        sleep(0.05)
    end
end

local commands = {
    help = function()
        print("help  - Displays this message.")
        print("start - Boots up reactor.")
        print("stop  - Stops reactor.")
        print("exit  - Stops reactor and shuts down program.")
    end,
    start = function()
        if reactor.getStatus() == false then
            reactor.activate()
            print("Reactor started.")
        else
            print("Reactor already running.")
        end
    end,
    stop = function()
        if reactor.getStatus() == true then
            reactor.scram()
            reactor.setBurnRate(0)
            print("Reactor stopped.")
        else
            print("Reactor already stopped.")
        end
    end,
    exit = function()
        commands.stop()
        print("Exiting program.")
        shell.exit()
    end,
}

local function command_handler()
    while true do
        local input = read("Enter Command: ")
        if commands[input] == nil then
            print("Unknown command. Enter 'help' command to get list of valid commands.")
        else
            commands[input]()
        end
    end
end

local success, error_msg = pcall(parallel.waitForAny, main_reactor_loop, command_handler)
if not success then
    print("UNRECOVERABLE PROGRAM ERROR: " .. error_msg)
    while reactor.getStatus() == true do
        print("!!! INITIATING EMERGENCY SHUTDOWN !!!")
        reactor.scram()
        reactor.setBurnRate(0)
        if reactor.getStatus() == false then
            print("REACTOR SHUTDOWN SUCCESSFUL.")
            print("Exiting program.")
            shell.exit()
        else
            print("!!! REACTOR SHUTDOWN FAILED !!!")
            sleep(0.05)
        end
    end
end