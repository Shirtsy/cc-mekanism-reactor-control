local cc_strings = require("cc.strings")

local reactor = peripheral.find("fissionReactorLogicAdapter")
local boiler = peripheral.find("boilerValve")
local turbine = peripheral.find("turbineValve")
local matrix = peripheral.find("inductionPort")
local monitor = peripheral.find("monitor")

monitor.setTextScale(0.5)

local function monitor_print(text)
    local x, y = monitor.getSize()
    local time_string = textutils.formatTime(os.time())
    local lines = cc_strings.wrap(time_string .. " " .. text, x)
    for _, line in ipairs(lines) do
        monitor.scroll(1)
        monitor.setCursorPos(1, y)
        monitor.write(line)
    end
    
end

local scram_bounds = {
    reactor_burn_rate = {
        min = 0,
        max = 30,
        get = function()
            return reactor.getBurnRate()
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
        max = 100000000,
        get = function()
            return reactor.getHeatingRate()
        end
    },
    reactor_waste_percent = {
        min = 0,
        max = 0.90,
        get = function()
            return reactor.getWasteFilledPercentage()
        end
    },
    reactor_cold_coolant_percent = {
        min = 0.10,
        max = 1.00,
        get = function()
            return reactor.getCoolantFilledPercentage()
        end
    },
    reactor_hot_coolant_percent = {
        min = 0,
        max = 0.10,
        get = function()
            return reactor.getHeatedCoolantFilledPercentage()
        end
    },
    boiler_cold_coolant_percent = {
        min = 0,
        max = 0.10,
        get = function()
            return boiler.getCooledCoolantFilledPercentage()
        end
    },
    boiler_hot_coolant_percent = {
        min = 0,
        max = 0.90,
        get = function()
            return boiler.getHeatedCoolantFilledPercentage()
        end
    },
    boiler_water_percent = {
        min = 0.50,
        max = 1.00,
        get = function()
            return boiler.getWaterFilledPercentage()
        end
    },
    boiler_steam_percent = {
        min = 0,
        max = 0.10,
        get = function()
            return boiler.getSteamFilledPercentage()
        end
    },
    turbine_steam_percent = {
        min = 0,
        max = 0.60,
        get = function()
            return turbine.getSteamFilledPercentage()
        end
    },
    matrix_power_percent = {
        min = 0,
        max = 0.90,
        get = function()
            return matrix.getEnergyFilledPercentage()
        end
    },
}

local function scram_if_out_of_bounds()
    for key, bounds in pairs(scram_bounds) do
        local value = bounds.get()
        if not (bounds.min <= value and value <= bounds.max) then
            monitor_print("REACTOR ERROR: " .. key .. " out of safe range.")
            monitor_print(
                "Min: " .. bounds.min
                .. " | " ..
                "Max: " .. bounds.max
                .. " | " ..
                "Actual Value: " .. value
            )
            monitor_print("!!! INITIATING EMERGENCY SHUTDOWN !!!")
            reactor.scram()
            if reactor.getStatus() == false then
                monitor_print("REACTOR SHUTDOWN SUCCESSFUL.")
            else
                monitor_print("!!! REACTOR SHUTDOWN NOT SUCCESSFUL !!! ")
            end
            reactor.setBurnRate(0)
            monitor_print("Burn Rate: " .. scram_bounds.reactor_burn_rate.get())
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
        scram_bounds.reactor_burn_rate.max,
        scram_bounds.reactor_burn_rate.min
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
        return true
    end,
    start = function()
        if reactor.getStatus() == false then
            reactor.activate()
            print("Reactor started.")
            monitor_print("Reactor started.")
        else
            print("Reactor already running.")
        end
        return true
    end,
    stop = function()
        if reactor.getStatus() == true then
            reactor.scram()
            reactor.setBurnRate(0)
            print("Reactor stopped.")
            monitor_print("Reactor stopped.")
        else
            print("Reactor already stopped.")
        end
        return true
    end,
    exit = function()
        if reactor.getStatus() == true then
            reactor.scram()
            reactor.setBurnRate(0)
            print("Reactor stopped.")
            monitor_print("Reactor stopped.")
        end
        print("Exiting program.")
        return false
    end,
}

local function command_handler()
    while true do
        write("Enter Command: ")
        local input = read()
        if commands[input] == nil then
            print("Unknown command. Enter 'help' command to get list of valid commands.")
        else
            if not commands[input]() then
                return
            end
        end
    end
end

local success, error_msg = pcall(parallel.waitForAny, main_reactor_loop, command_handler)
if not success then
    monitor_print("UNRECOVERABLE PROGRAM ERROR: " .. error_msg)
    print("PROGRAM ERROR: " .. error_msg)
    while reactor.getStatus() == true do
        monitor_print("!!! INITIATING EMERGENCY SHUTDOWN !!!")
        reactor.scram()
        reactor.setBurnRate(0)
        if reactor.getStatus() == false then
            monitor_print("REACTOR SHUTDOWN SUCCESSFUL.")
            print("Exiting program.")
            return
        else
            monitor_print("!!! REACTOR SHUTDOWN FAILED !!!")
            sleep(0.05)
        end
    end
end
