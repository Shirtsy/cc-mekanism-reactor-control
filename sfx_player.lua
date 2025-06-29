local speaker = peripheral.find("speaker")
local dfpwm = require("cc.audio.dfpwm")
local volume = 0.5

local function play()
    local decoder = dfpwm.make_decoder()
    for chunk in io.lines("sound.dfpwm", 16 * 1024) do
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer, volume) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

while true do
    for _, side in ipairs(redstone.getSides()) do
        if redstone.getInput(side) then
            play()
            break
        end
    end
    os.pullEvent("redstone")
end
