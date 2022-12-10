local term = require("term")
local component = require("component")
local colors = require("colors")
local gpu = component.gpu

local drawing = {}

function drawing.drawPlayField(PlayGrid)
    gpu.setForeground(0xFFFFFF)
    local title = "MINESWEEPER"
    term.setCursor(PlayGrid.offset.x + #PlayGrid.values[0]/2 - #title/2, 2)
    term.write(title)
    term.setCursor(PlayGrid.offset.x, PlayGrid.offset.y)
    for y=0,#PlayGrid.values do
        for x=0,#PlayGrid.values[0] do
            term.setCursor(PlayGrid.offset.x + x, PlayGrid.offset.y + y)
            if(PlayGrid.revealedGrid[y][x] == "r") then
                gpu.setForeground(0xFFFFFF)
                term.write(PlayGrid.values[y][x])
            elseif PlayGrid.revealedGrid[y][x] == "f" then
                gpu.setForeground(0x006D00)
                term.write("F")
            else
                gpu.setForeground(0xFFFF80)
                term.write("H")
            end
        end
    end

    gpu.setForeground(0xFFFFFF)
    -- local instructions = "LMB = reveal, Alt + LMB = Flag"
    -- local  instructions2 = "To win the game you have to flag all the mines"
    -- term.setCursor(PlayGrid.offset.x + #PlayGrid.values[0]/2 - #instructions/2, PlayGrid.offset.y + PlayGrid.playFieldSize.y + 5)
    -- term.write(instructions)
    -- term.setCursor(PlayGrid.offset.x + #PlayGrid.values[0]/2 - #instructions2/2, PlayGrid.offset.y + PlayGrid.playFieldSize.y + 6)
    -- term.write(instructions2)

    if PlayGrid.cheater then
        for y=1,#PlayGrid.values+1 do
            for x=1,#PlayGrid.values[0]+1 do
                term.setCursor(x + PlayGrid.offset.x - PlayGrid.playFieldSize.x - 5, y)
                term.write(PlayGrid.values[y-1][x-1])
            end
        end

        for y=1,#PlayGrid.revealedGrid+1 do
            for x=1,#PlayGrid.revealedGrid[0]+1 do
                term.setCursor(x + PlayGrid.offset.x + PlayGrid.playFieldSize.x + 3, y)
                term.write(PlayGrid.revealedGrid[y-1][x-1])
            end
        end
    end
end

return drawing