os.execute("stty raw -echo min 0 time 0")
io.write("\27[2J\27[?25l")
local arrowmod = require("something")
local termsizex, termsizey = 0, 0
local colors = {
    red    = "\27[31m",
    green  = "\27[32m",
    yellow = "\27[33m",
    blue   = "\27[34m",
    white  = "\27[37m"
}

local function getTerminalSize()
    -- io.popen executes a shell command and lets Lua read its output like a file
    local handle = io.popen("stty size 2>/dev/null")
    if not handle then 
        return 80, 24 -- Return standard fallback if it fails
    end

    local result = handle:read("*a")
    handle:close()

    -- stty size returns "ROWS COLUMNS" (e.g. "24 80")
    -- We use Lua pattern matching to extract the two numbers
    local height, width = result:match("(%d+)%s+(%d+)")
    
    if height and width then
        return tonumber(width), tonumber(height)
    else
        return 80, 24 -- Fallback
    end
end

local function clearScreen()
    io.write("\27[2J") -- Clears screen
    io.flush()
end

local x, y = 10, 10
local cursorx, cursory, = 0,0
local map = {
    {x=0,y=0,symbol="#",color="green"}
}

local function draw(x, y, symbol, color_name)
    local color = colors[color_name] or ""
    io.write(string.format("\27[%d;%dH%s%s\27[0m", y, x, color, symbol))
end

local function render(rmap)
    for i, tile in pairs(rmap) do
        draw(tile["x"] + x, tile["y"] + y, tile["symbol"], tile["color"])
    end
end


local target_frame_time = 1 / 60

-- Clears the entire screen and moves the cursor to the top-left corner (1,1)
local function clearScreen()
    io.write("\27[2J\27[H")
    io.flush() -- Force Lua to send the characters to the terminal immediately
end
local frame = 0
while true do
    local frame_start = os.clock()
    local key = io.read(1)

    render(map)
    -- Clear previous position
    draw(x, y, " ")

    if key == "q" then break end
    if key == "w" then y = y + 1 end
    if key == "s" then y = y - 1 end
    if key == "a" then x = x + 1 end
    if key == "d" then x = x - 1 end
    if key == " " then table.insert(map, {
        x=x,
        y=y,
        symbol="#",
        color="white",
        passable=false,
        description="a basic wall"
        }) end
    local action = arrowmod.getAction()
    if arrow = "arrow_up"    then  end
    if arrow = "arrow_down"  then  end
    if arrow = "arrow_left"  then  end
    if arrow = "arrow_right" then  end
    math.max(0, math.min(cursory + 1, termsizey))
    math.max(0, math.min(cursory - 1, termsizey))
    math.max(0, math.min(cursorx - 1, termsizex))
    math.max(0, math.min(cursorx + 1, termsizex))
    draw(cursorx, cursory, "+", "red")
    io.flush()
    frame = frame + 1
    if frame / 60 = 0 then -- once per second
        termsizex, termsizey = getTerminalSize()
    end
    while (os.clock() - frame_start) < target_frame_time do end
    
end

os.execute("stty sane")
io.write("\27[?25h\27[2J\27[H\27[0;37m")
io.flush()
