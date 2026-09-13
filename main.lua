os.execute("stty raw -echo min 0 time 0")
io.write("\27[2J\27[?25l")
local input = require("input")
local termsizex, termsizey = 0, 0
local colors = {
    red    = "\27[31m",
    green  = "\27[32m",
    yellow = "\27[33m",
    blue   = "\27[34m",
    white  = "\27[37m"
}

local function getTerminalSize()
    local handle = io.popen("stty size 2>/dev/null")
    if not handle then return 80, 24 end
    local result = handle:read("*a")
    handle:close()
    local height, width = result:match("(%d+)%s+(%d+)")
    if height and width then return tonumber(width), tonumber(height) end
    return 80, 24
end

termsizex, termsizey = getTerminalSize()

local x, y = 10, 10
local cursorx, cursory = math.floor(termsizex / 2), math.floor(termsizey / 2)

-- Only real tiles now -- no hand-authored blank padding needed.
local map = {
    {x=0, y=0, symbol="#", color="green"}
}

local function draw(px, py, symbol, color_name)
    local color = colors[color_name] or ""
    io.write(string.format("\27[%d;%dH%s%s\27[0m", py, px, color, symbol))
end

-- Tracks what was drawn at each screen cell last frame, keyed by "x,y".
-- Used to erase cells that are no longer occupied this frame, regardless
-- of whether that's because the camera moved, a tile was added, or the
-- cursor moved.
local lastFrame = {}

local function renderFrame()
    local thisFrame = {}

    -- Only cells actually on-screen get recorded. Anything filtered out
    -- here simply never gets drawn or tracked -- so the erase pass below
    -- (which only ever erases positions that WERE on-screen last frame)
    -- never tries to write outside the terminal, which is what caused
    -- the wraparound clogging.
    local function onScreen(sx, sy)
        return sx >= 1 and sx <= termsizex and sy >= 1 and sy <= termsizey
    end

    -- Build this frame's contents first (don't draw yet).
    for _, tile in pairs(map) do
        local sx, sy = tile.x + x, tile.y + y
        if onScreen(sx, sy) then
            thisFrame[sx .. "," .. sy] = {x = sx, y = sy, symbol = tile.symbol, color = tile.color}
        end
    end
    
    thisFrame[cursorx .. "," .. cursory] = {x = cursorx, y = cursory, symbol = "+", color = "red"}
 
    -- Erase any cell that was occupied last frame but isn't this frame.
    for key, cell in pairs(lastFrame) do
        if not thisFrame[key] then
            draw(cell.x, cell.y, " ")
        end
    end

    -- Draw everything in this frame (redrawing unchanged cells is cheap
    -- and simpler than diffing values too -- fine at this scale).
    for _, cell in pairs(thisFrame) do
        draw(cell.x, cell.y, cell.symbol, cell.color)
    end

    lastFrame = thisFrame
end

local function findTiles(criteria)
    local matches = {}
    for i, tile in ipairs(map) do
        local isMatch = true
        for field, expected in pairs(criteria) do
            if tile[field] ~= expected then
                isMatch = false
                break
            end
        end
        if isMatch then
            table.insert(matches, {index = i, tile = tile})
        end
    end
    return matches
end

local function removeTile(coords)
    local matches = findTiles({x = coords.x, y = coords.y})
    for i = #matches, 1, -1 do
        table.remove(map, matches[i].index)
    end
    return #matches
end


while true do
    local action = input.getAction()

    if action == "q" then break end
    if action == "w" then y = y + 1 end
    if action == "s" then y = y - 1 end
    if action == "a" then x = x + 1 end
    if action == "d" then x = x - 1 end
    if action == "x" then table.insert(map, {
        x = cursorx - x, y = cursory - y, symbol = "#", color = "white",
        passable = false, description = "a basic wall"
    }) end
    if action == "z" then
        local tiletoremove = removeTile({x = cursorx - x, y = cursory - y})
    end

    if action == "arrow_up"    then cursory          = math.max(1, math.min(cursory - 1, termsizey))        end
    if action == "arrow_down"  then cursory          = math.max(1, math.min(cursory + 1, termsizey))        end
    if action == "arrow_left"  then cursorx          = math.max(1, math.min(cursorx - 1, termsizex))        end
    if action == "arrow_right" then cursorx          = math.max(1, math.min(cursorx + 1, termsizex))        end
    if action == "/"           then cursorx, cursory = math.floor(termsizex / 2), math.floor(termsizey / 2) end


    renderFrame()
    io.flush()
end

os.execute("stty sane")
io.write("\27[?25h\27[2J\27[H\27[0;37m")
io.flush()