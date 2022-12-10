local term = require("term")
local drawing = require("drawing")
local component = require("component")
local event = require("event")
local keyboard = require("keyboard")
local shell = require("shell")
local gpu = component.gpu

function clamp(num, min, max)
    if (num > max) then
        return max
    elseif (num < min) then
        return min
    else
        return num
    end
end

--Complementary function
function hasItem(table, item)
    for i = 0, #table-1 do
        for j = 0, #table[0]-1 do
            if table[i][j] == item then
                return true
            end
        end
    end
end


function revealCell(x, y, PlayGrid)
    local combinations = {
        [0] = {y = y - 1, x = x, condition = (y - 1 > -1)},
        [1] = {y = y - 1, x = x +  1, condition = (y - 1  > -1) and (x + 1 < PlayGrid.playFieldSize.x)},
        [2] = {y = y, x = x + 1, condition = (x + 1 < PlayGrid.playFieldSize.x)},
        [3] = {y = y + 1, x = x + 1, condition = (y + 1 < PlayGrid.playFieldSize.y) and (x + 1 < PlayGrid.playFieldSize.x)},
        [4] = {y = y + 1, x = x, condition = (y + 1 < PlayGrid.playFieldSize.y)},
        [5] = {y = y + 1, x = x - 1, condition = (y + 1 < PlayGrid.playFieldSize.y) and (x - 1 > -1)},
        [6] = {y = y, x = x - 1, condition = (x - 1 > -1)},
        [7] = {y = y - 1, x = x - 1, condition = (y - 1 > -1) and (x - 1 > -1)},
    }
    if PlayGrid.revealedGrid[y][x] == "r" then
        return
    end
    if PlayGrid.values[y][x] == "M" then
        PlayGrid.revealedGrid[y][x] = "r"
        PlayGrid.gameOver = true
        return
    elseif PlayGrid.values[y][x] == "0" then
        PlayGrid.revealedGrid[y][x] = "r"
        PlayGrid.unrevealedAmount = PlayGrid.unrevealedAmount - 1
        for i=0,#combinations do
            if combinations[i].condition then
                if PlayGrid.values[combinations[i].y][combinations[i].x]  ~= "M" and PlayGrid.revealedGrid[combinations[i].y][combinations[i].x] ~= "r" then
                    PlayGrid.revealedGrid[combinations[i].y][combinations[i].x] = "t"
                    drawing.drawPlayField(PlayGrid)
                end
            end
        end
    else
        PlayGrid.revealedGrid[y][x] = "r"
        PlayGrid.unrevealedAmount = PlayGrid.unrevealedAmount - 1
    end
end

--Event handlers
function nullEvent()
    --Do nothing
end

local eventHandler = setmetatable({}, {__index = function() return nullEvent end})

function eventHandler.touch(PlayGrid, screenAddress, x, y, button, playerName)
    local clickWithOffset = {x = x - PlayGrid.offset.x, y = y - PlayGrid.offset.y}
    local isClickInPlayFieldBounds = (clickWithOffset.x >= 0 and clickWithOffset.x < PlayGrid.playFieldSize.x) and (clickWithOffset.y >= 0 and clickWithOffset.y < PlayGrid.playFieldSize.y)
    if isClickInPlayFieldBounds then
        if keyboard.isAltDown() then
            if PlayGrid.revealedGrid[clickWithOffset.y][clickWithOffset.x] == "r" then
                return
            end
            if PlayGrid.revealedGrid[clickWithOffset.y][clickWithOffset.x] == "f" then
                PlayGrid.revealedGrid[clickWithOffset.y][clickWithOffset.x] = "u"
                PlayGrid.flagedAmount = PlayGrid.flagedAmount - 1
            else
                PlayGrid.revealedGrid[clickWithOffset.y][clickWithOffset.x] = "f"
                PlayGrid.flagedAmount =  PlayGrid.flagedAmount + 1
            end
            return
        end
        revealCell(clickWithOffset.x, clickWithOffset.y, PlayGrid)
        local nextReveal = {x = clickWithOffset.x, y = clickWithOffset.y}
        while hasItem(PlayGrid.revealedGrid, "t") do
            for i = 0, PlayGrid.playFieldSize.y do
                for j = 0, PlayGrid.playFieldSize.x do
                    if PlayGrid.revealedGrid[i][j] == "t" then
                        nextReveal.x, nextReveal.y = j, i
                        revealCell(j, i, PlayGrid)
                    end
                end
            end
        end 
    end
end

function handleEvent(PlayGrid, eventID, ...)
    if (eventID) then
        eventHandler[eventID](PlayGrid, ...)
    end
end

gpu.setForeground(0xFFFFFF)

--Init
local PlayGrid = {values = {}, revealedGrid = {}, playFieldSize = {x = 0, y = 0}, offset = {x = 0, y = 0},  mineAmount = 0,  unrevealedAmount = 0, 
                  flagedAmount = 0, gameOver = false, gameWon = false, cheater = false }

local arguments_as_a_table = {...}
if arguments_as_a_table[1] == "cheater" then
    PlayGrid.cheater = true
end

--Player input on difficulty
term.clear()
term.setCursor(1, 1)
print("MINESWEEPER")
print("Enter difficulty [1][2][3]: ")
local input = tostring(term.read())
term.clear()


if input == "1\n" then
    PlayGrid.playFieldSize.x, PlayGrid.playFieldSize.y = 9, 9
    PlayGrid.mineAmount = 10
elseif input == "2\n" then
    PlayGrid.playFieldSize.x, PlayGrid.playFieldSize.y = 16, 16
    PlayGrid.mineAmount = 40
elseif input == "3\n" then
    PlayGrid.playFieldSize.x, PlayGrid.playFieldSize.y = 30, 16
    PlayGrid.mineAmount = 99
else
    term.clear()
    term.write("Wrong difficulty!")
    return
end

PlayGrid.unrevealedAmount = PlayGrid.playFieldSize.x * PlayGrid.playFieldSize.y

--Global variables
local termSize = {}
termSize.width, termSize.height = component.gpu.getViewport()
PlayGrid.offset.x, PlayGrid.offset.y = math.ceil(termSize.width / 2 - PlayGrid.playFieldSize.x / 2), math.ceil(termSize.height / 2 - PlayGrid.playFieldSize.y / 2)

--Initializing play playGrid
for y = 0, PlayGrid.playFieldSize.y - 1 do
    PlayGrid.values[y] = {}
    for x = 0, PlayGrid.playFieldSize.x - 1 do
        PlayGrid.values[y][x] = "0"
    end
end

--Population the grid with mines
math.randomseed(os.time())
local tempMineAmount = PlayGrid.mineAmount
while tempMineAmount > 0 do
    local xMine = math.floor(math.random() * PlayGrid.playFieldSize.x)
    local yMine = math.floor(math.random() * PlayGrid.playFieldSize.y)
    if PlayGrid.values[yMine][xMine] ~= "M" then
        PlayGrid.values[yMine][xMine] = "M"
        tempMineAmount = tempMineAmount - 1
    end
end


--Populating the playgrid with mine counts

for y = 0, PlayGrid.playFieldSize.y - 1 do
    for x = 0, PlayGrid.playFieldSize.x - 1 do
        if PlayGrid.values[y][x] ~= "M" then
            local combinations = {
                [0] = {y = y - 1, x = x, condition = (y - 1 > -1)},
                [1] = {y = y - 1, x = x +  1, condition = (y - 1  > -1) and (x + 1 < PlayGrid.playFieldSize.x)},
                [2] = {y = y, x = x + 1, condition = (x + 1 < PlayGrid.playFieldSize.x)},
                [3] = {y = y + 1, x = x + 1, condition = (y + 1 < PlayGrid.playFieldSize.y) and (x + 1 < PlayGrid.playFieldSize.x)},
                [4] = {y = y + 1, x = x, condition = (y + 1 < PlayGrid.playFieldSize.y)},
                [5] = {y = y + 1, x = x - 1, condition = (y + 1 < PlayGrid.playFieldSize.y) and (x - 1 > -1)},
                [6] = {y = y, x = x - 1, condition = (x - 1 > -1)},
                [7] = {y = y - 1, x = x - 1, condition = (y - 1 > -1) and (x - 1 > -1)},
            }
            local tempMineAmount = 0
            for i=0,#combinations do
                if combinations[i].condition then
                    if PlayGrid.values[combinations[i].y][combinations[i].x] == "M" then
                        tempMineAmount = tempMineAmount + 1
                    end
                end
            end
            PlayGrid.values[y][x] = tostring(tempMineAmount)
        end
    end
end

--Creating the reavealed-unrevealed playgrid
for y = 0, PlayGrid.playFieldSize.y - 1 do
    PlayGrid.revealedGrid[y] = {}
    for x = 0, PlayGrid.playFieldSize.x - 1 do
        PlayGrid.revealedGrid[y][x] = "u"
    end
end

while not PlayGrid.gameOver do
    drawing.drawPlayField(PlayGrid)
    handleEvent(PlayGrid, event.pull())
    term.setCursor(1, 1)
    -- term.write(PlayGrid.unrevealedAmount .. "\n") Debug
    -- term.write(PlayGrid.flagedAmount .. "\n")
    if PlayGrid.unrevealedAmount == PlayGrid.mineAmount and PlayGrid.flagedAmount == PlayGrid.mineAmount then
        PlayGrid.gameWon = true
        break
    end
end

gpu.setForeground(0xFFFFFF)

term.clear()
term.setCursor(1, 1)
if PlayGrid.gameWon then
    term.write("Game Won!\n")
elseif PlayGrid.gameOver then
    term.write("Game Over!\n")
end
term.write("Restart? [y/n]\n")

input = term.read()
if input == "y\n" then
    shell.execute("/home/MineSweeper/MineSweeper.lua")
elseif input == "cheater\n" then
    shell.execute("/home/MineSweeper/MineSweeper.lua cheater")
else
    term.clear()
end