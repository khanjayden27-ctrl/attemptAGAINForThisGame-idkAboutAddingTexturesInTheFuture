os.execute("stty raw -echo min 0 time 0")
io.write("\27[2J\27[?25l")

local colors = {
    red    = "\27[31m",
    green  = "\27[32m",
    yellow = "\27[33m",
    blue   = "\27[34m",
    white  = "\27[37m"
}

local function draw(x, y, symbol, color_name)
    local color = colors[color_name] or ""
    io.write(string.format("\27[%d;%dH%s%s\27[0m", y, x, color, symbol))
end

local x, y = 15, 10
local target_frame_time = 1 / 60

while true do
    local frame_start = os.clock()
    local key = io.read(1)


    -- Clear previous position
    draw(x, y, " ")

    if key == "q" then break end
    if key == "e" then menu.draw_menu() end
    if key == "w" then y = y - 1 end
    if key == "s" then y = y + 1 end
    if key == "a" then x = x - 1 end
    if key == "d" then x = x + 1 end

    -- Draw player at new position
    draw(x, y, "@", "blue")
    io.flush()

    while (os.clock() - frame_start) < target_frame_time do end
end

os.execute("stty sane")
io.write("\27[?25h\27[2J\27[H\27[0;37m")
io.flush()
