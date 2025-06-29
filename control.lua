local cc_strings = require("cc.strings")
local dfpwm = require("cc.audio.dfpwm")

local reactor = peripheral.find("fissionReactorLogicAdapter")
local boiler = peripheral.find("boilerValve")
local turbine = peripheral.find("turbineValve")
local matrix = peripheral.find("inductionPort")
local monitor = peripheral.find("monitor")

monitor.setTextScale(0.5)

local function monitor_print(text)
    local x, y = monitor.getSize()
    local time_string = os.day() .. " " .. textutils.formatTime(os.time())
    local lines = cc_strings.wrap("\n" .. time_string .. "\n" .. text, x)
    monitor.scroll(#lines)
    for i, line in ipairs(lines) do
        monitor.setCursorPos(1, y - (#lines - (i - 1)))
        monitor.write(line)
    end
end

local vox_queue = {}

local function vox_announce(text)
    for word in text:gmatch("%S+") do
        table.insert(vox_queue, word)
    end
end

local function vox_loop()
    while true do
        local speakers = {peripheral.find("speaker")}
        if #speakers > 0 and #vox_queue > 0 then
            local decoder = dfpwm.make_decoder()

            local word = table.remove(vox_queue, 1)
            for chunk in io.lines("vox/" .. word .. ".dfpwm", 16 * 1024) do
                local buffer = decoder(chunk)
                for _, speaker in pairs (speakers) do
                    speaker.playAudio(buffer)
                end
            end
            os.pullEvent("speaker_audio_empty")
        else
            sleep(0.1)
        end
    end
end

local scram_bounds = {
    reactor_burn_rate = {
        min = 0,
        max = 60,
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
            vox_announce("reactor emergency shut down")
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

local function get_status_string()
    local status = ""
    for k, v in pairs(scram_bounds) do
        status = status .. k .. ": " .. v.get() .. "\n"
    end
    return status
end

local function main_reactor_loop()
    local last_status_time = 0
    while true do
        if reactor.getStatus() == true then
            scram_if_out_of_bounds()
            update_burn_rate()
        else
            reactor.setBurnRate(0)
        end
        local current_time = os.clock()
        if current_time - last_status_time >= 10 then
            monitor_print(get_status_string())
            last_status_time = current_time
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
            vox_announce("reactor activated")
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
            vox_announce("reactor shut down")
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
            vox_announce("reactor shut down")
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



local success, error_msg = pcall(parallel.waitForAny, main_reactor_loop, command_handler, vox_loop)
if not success then
    monitor_print("UNRECOVERABLE PROGRAM ERROR: " .. error_msg)
    print("PROGRAM ERROR: " .. error_msg)
    while reactor.getStatus() == true do
        monitor_print("!!! INITIATING EMERGENCY SHUTDOWN !!!")
        reactor.scram()
        reactor.setBurnRate(0)
        vox_announce("reactor emergency shut down")
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
