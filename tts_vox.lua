local vox = require("vox")

local function input_loop()
    while true do
        write("> ")
        local input = read()
        vox.announce(input)
    end
end

parallel.waitForAny(vox.vox_loop, input_loop)
