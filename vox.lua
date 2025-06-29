local dfpwm = require("cc.audio.dfpwm")

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