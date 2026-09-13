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

local BOX = {
    h = "─", v = "│",
    tl = "┌", tr = "┐", bl = "└", br = "┘",
    lj = "├", rj = "┤", tj = "┬", bj = "┴", cross = "┼"
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

-- All drawing goes here instead of straight to io.write. Everything
-- queued this frame is sent in ONE write at the very end (flushFrame).
-- This is what actually fixes the menu-flicker: previously every
-- draw()/drawText() call was its own separate write, and with no
-- frame-rate cap the loop runs thousands of times a second -- fast
-- enough that a terminal can render mid-frame and show a half-drawn
-- box. Batching removes the possibility of that entirely, regardless
-- of how fast the loop spins.
local outputBuffer = {}
local function flushFrame()
    io.write(table.concat(outputBuffer))
    io.flush()
    outputBuffer = {}
end

local function draw(px, py, symbol, color_name)
    local color = colors[color_name] or ""
    table.insert(outputBuffer, string.format("\27[%d;%dH%s%s\27[0m", py, px, color, symbol))
end

local function drawText(px, py, text, color_name)
    local color = colors[color_name] or ""
    table.insert(outputBuffer, string.format("\27[%d;%dH%s%s\27[0m", py, px, color, text))
end

local x, y = 10, 10
local cursorx, cursory = math.floor(termsizex / 2), math.floor(termsizey / 2)

-- Bottom row: hint bar. Right side: a permanent sidebar (list + details),
-- always visible -- not something you open and close.
local uiHeight = 1
local sidebarWidth = 24
local worldHeight = termsizey - uiHeight
local worldWidth = termsizex - sidebarWidth
local sidebarStartX = math.max(1, termsizex - sidebarWidth + 1)

local buildOptions = {
    {name = "Wall",  symbol = "#", color = "white"},
    {name = "Floor", symbol = ".", color = "green"},
    {name = "Door",  symbol = "+", color = "yellow"},
}
local selectedBuildIndex = 1

-- Set by "space" in the world -- what the sidebar's DETAILS section
-- currently shows.
local lastInspected = nil

-- currentPanel: nil = world has full control (sidebar just displays,
-- doesn't need to be "opened"). "mainmenu"/"quitconfirm" ARE blocking --
-- they freeze world input while shown.
local currentPanel = nil
local previousPanel = nil

local mainMenuOptions = {
    {name = "New Game",  action = "new_game"},
    {name = "Save Game", action = "save_game"},
    {name = "Load Game", action = "load_game"},
    {name = "Settings",  action = "settings"},
}

local mainMenuPanel = {
    items = mainMenuOptions,
    scrollOffset = 0,
    isSelected = function(idx) return false end,
    onSelect = function(idx)
        local item = mainMenuOptions[idx]
        -- TODO: stubs -- wire real save/load/new-game/settings logic here.
        if item.action == "new_game" then
        elseif item.action == "save_game" then
        elseif item.action == "load_game" then
        elseif item.action == "settings" then
        end
        currentPanel = previousPanel
    end,
}

local function panelIsBlocking()
    return currentPanel == "mainmenu" or currentPanel == "quitconfirm"
end

local visibleSlotCount = 7

-- Shared input handling for any scrollable list panel: 1/9 scroll,
-- 2-8 select, 0 requests "go back". Only used by the main menu now --
-- the build sidebar isn't a panel you navigate this way anymore.
local function handlePanelInput(action, panel)
    local maxOffset = math.max(0, #panel.items - visibleSlotCount)
    if action == "0" then
        return true
    elseif action == "1" then
        panel.scrollOffset = math.max(0, panel.scrollOffset - 1)
    elseif action == "9" then
        panel.scrollOffset = math.min(maxOffset, panel.scrollOffset + 1)
    else
        local slot = tonumber(action)
        if slot and slot >= 2 and slot <= 8 then
            local idx = panel.scrollOffset + (slot - 1)
            if panel.items[idx] then
                panel.onSelect(idx)
            end
        end
    end
    return false
end

local map = {
    {x=0, y=0, symbol="#", color="green"}
}

local lastFrame = {}

local function renderFrame()
    local thisFrame = {}

    local function onScreen(sx, sy)
        return sx >= 1 and sx <= worldWidth and sy >= 1 and sy <= worldHeight
    end

    for _, tile in pairs(map) do
        local sx, sy = tile.x + x, tile.y + y
        if onScreen(sx, sy) then
            thisFrame[sx .. "," .. sy] = {x = sx, y = sy, symbol = tile.symbol, color = tile.color}
        end
    end

    thisFrame[cursorx .. "," .. cursory] = {x = cursorx, y = cursory, symbol = "+", color = "red"}

    for key, cell in pairs(lastFrame) do
        if not thisFrame[key] then
            draw(cell.x, cell.y, " ")
        end
    end

    for _, cell in pairs(thisFrame) do
        draw(cell.x, cell.y, cell.symbol, cell.color)
    end

    lastFrame = thisFrame
end

local function padLeft(text, width)
    local pad = width - #text
    if pad < 0 then pad = 0 end
    return text .. string.rep(" ", pad)
end

local function padCenter(text, width)
    local pad = width - #text
    if pad < 0 then pad = 0 end
    local left = math.floor(pad / 2)
    return string.rep(" ", left) .. text .. string.rep(" ", pad - left)
end

-- Permanent right-side panel: a BUILD list on top, a DETAILS section
-- (driven by lastInspected) below, one continuous bordered box.
local function renderSidebar()
    local innerWidth = sidebarWidth - 2

    local function borderRow(left, right)
        return left .. string.rep(BOX.h, innerWidth) .. right
    end

    local rows = {}
    table.insert(rows, borderRow(BOX.tl, BOX.tr))
    table.insert(rows, BOX.v .. padCenter("BUILD", innerWidth) .. BOX.v)
    table.insert(rows, borderRow(BOX.lj, BOX.rj))

    for i, opt in ipairs(buildOptions) do
        local label = string.format(" %d:%s", i, opt.name)
        if i == selectedBuildIndex then label = label .. " <" end
        table.insert(rows, BOX.v .. padLeft(label, innerWidth) .. BOX.v)
    end

    table.insert(rows, borderRow(BOX.lj, BOX.rj))
    table.insert(rows, BOX.v .. padCenter("DETAILS", innerWidth) .. BOX.v)
    table.insert(rows, borderRow(BOX.lj, BOX.rj))

    local detailLines = {}
    if lastInspected then
        table.insert(detailLines, " " .. (lastInspected.description or lastInspected.symbol))
        table.insert(detailLines, " Symbol: " .. lastInspected.symbol)
        table.insert(detailLines, " Passable: " .. tostring(lastInspected.passable ~= false))
    else
        table.insert(detailLines, " Nothing selected")
        table.insert(detailLines, " (space to inspect)")
    end
    for _, line in ipairs(detailLines) do
        table.insert(rows, BOX.v .. padLeft(line, innerWidth) .. BOX.v)
    end

    -- Fill remaining interior rows with blank space so the box reaches
    -- exactly to the bottom of the world area.
    local usedRows = #rows + 1 -- +1 for the bottom border still to come
    while usedRows < worldHeight do
        table.insert(rows, BOX.v .. string.rep(" ", innerWidth) .. BOX.v)
        usedRows = usedRows + 1
    end

    table.insert(rows, borderRow(BOX.bl, BOX.br))

    for i, line in ipairs(rows) do
        drawText(sidebarStartX, i, line, "white")
    end
end

local function computeBoxLines(panel, title, extraFooter)
    local maxOffset = math.max(0, #panel.items - visibleSlotCount)
    local hasMoreAbove = panel.scrollOffset > 0
    local hasMoreBelow = panel.scrollOffset < maxOffset

    local innerWidth = #title
    local lines = {}
    for slot = 2, 8 do
        local idx = panel.scrollOffset + (slot - 1)
        local item = panel.items[idx]
        if item then
            local label = string.format("%d:%s", slot, item.name)
            if panel.isSelected and panel.isSelected(idx) then
                label = "[" .. label .. "]"
            end
            table.insert(lines, label)
            if #label > innerWidth then innerWidth = #label end
        end
    end

    local footerParts = {}
    if extraFooter then table.insert(footerParts, extraFooter) end
    table.insert(footerParts, "0:Back")
    if hasMoreAbove then table.insert(footerParts, "1:^") end
    if hasMoreBelow then table.insert(footerParts, "9:v") end
    local footer = table.concat(footerParts, "  ")
    if #footer > innerWidth then innerWidth = #footer end
    innerWidth = innerWidth + 2

    return lines, footer, innerWidth
end

local function boxWidthFor(innerWidth) return innerWidth + 2 end
local function boxHeightFor(lines) return #lines + 5 end

local function drawBox(startX, startY, innerWidth, title, lines, footer)
    local function centered(text)
        local pad = innerWidth - #text
        local left = math.floor(pad / 2)
        return string.rep(" ", left) .. text .. string.rep(" ", pad - left)
    end

    local top = BOX.tl .. string.rep(BOX.h, innerWidth) .. BOX.tr
    local divider = BOX.lj .. string.rep(BOX.h, innerWidth) .. BOX.rj
    local bottom = BOX.bl .. string.rep(BOX.h, innerWidth) .. BOX.br

    local row = startY
    drawText(startX, row, top, "white"); row = row + 1
    drawText(startX, row, BOX.v .. centered(title) .. BOX.v, "white"); row = row + 1
    drawText(startX, row, divider, "white"); row = row + 1
    for _, label in ipairs(lines) do
        drawText(startX, row, BOX.v .. centered(label) .. BOX.v, "white")
        row = row + 1
    end
    drawText(startX, row, divider, "white"); row = row + 1
    drawText(startX, row, BOX.v .. centered(footer) .. BOX.v, "white"); row = row + 1
    drawText(startX, row, bottom, "white")
end

local function renderCenteredMenu(panel, title, extraFooter)
    local lines, footer, innerWidth = computeBoxLines(panel, title, extraFooter)
    local boxWidth = boxWidthFor(innerWidth)
    local boxHeight = boxHeightFor(lines)
    local startX = math.max(1, math.floor((worldWidth - boxWidth) / 2) + 1)
    local startY = math.max(1, math.floor((worldHeight - boxHeight) / 2) + 1)
    drawBox(startX, startY, innerWidth, title, lines, footer)
end

local function renderQuitConfirm()
    local lines = {"Quit the game?"}
    local footer = "[y]es   [n]o"
    local innerWidth = math.max(#lines[1], #footer) + 2
    local boxWidth = boxWidthFor(innerWidth)
    local boxHeight = boxHeightFor(lines)
    local startX = math.max(1, math.floor((worldWidth - boxWidth) / 2) + 1)
    local startY = math.max(1, math.floor((worldHeight - boxHeight) / 2) + 1)
    drawBox(startX, startY, innerWidth, "QUIT", lines, footer)
end

local function renderUI()
    renderSidebar()
    if currentPanel == "mainmenu" then
        renderCenteredMenu(mainMenuPanel, "MAIN MENU", "1:Quit")
    elseif currentPanel == "quitconfirm" then
        renderQuitConfirm()
    else
        drawText(1, termsizey, "ESC:Menu", "white")
    end
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
    if action == "escape" then
        if currentPanel == "mainmenu" then
            currentPanel = previousPanel
        else
            previousPanel = currentPanel
            currentPanel = "mainmenu"
        end
    else
        if not panelIsBlocking() then
            if action == "w" then y = y + 1 end
            if action == "s" then y = y - 1 end
            if action == "a" then x = x + 1 end
            if action == "d" then x = x - 1 end
            if action == "x" then
                local wx, wy = cursorx - x, cursory - y
                if #findTiles({x = wx, y = wy}) == 0 then
                    local opt = buildOptions[selectedBuildIndex]
                    table.insert(map, {
                        x = wx, y = wy, symbol = opt.symbol,
                        color = opt.color, passable = false, description = opt.name
                    })
                end
            end
            if action == "z" then
                removeTile({x = cursorx - x, y = cursory - y})
            end
            if action == "space" then
                local hits = findTiles({x = cursorx - x, y = cursory - y})
                lastInspected = hits[1] and hits[1].tile or nil
            end
            if action == "arrow_up"    then cursory = math.max(1, math.min(cursory - 1, worldHeight)) end
            if action == "arrow_down"  then cursory = math.max(1, math.min(cursory + 1, worldHeight)) end
            if action == "arrow_left"  then cursorx = math.max(1, math.min(cursorx - 1, worldWidth)) end
            if action == "arrow_right" then cursorx = math.max(1, math.min(cursorx + 1, worldWidth)) end
            if action == "/" then cursorx, cursory = math.floor(worldWidth / 2), math.floor(worldHeight / 2) end

            -- Sidebar selection: digits pick a build option directly,
            -- no "opening" the sidebar required -- it's always visible.
            local slot = tonumber(action)
            if slot and buildOptions[slot] then
                selectedBuildIndex = slot
            end
        end

        if currentPanel == "mainmenu" then
            if action == "1" then
                currentPanel = "quitconfirm"
            else
                local back = handlePanelInput(action, mainMenuPanel)
                if back then currentPanel = previousPanel end
            end

        elseif currentPanel == "quitconfirm" then
            if action == "y" then
                os.execute("stty sane")
                io.write("\27[?25h\27[2J\27[H\27[0;37m")
                io.flush()
                os.exit(0)
            elseif action == "n" or action == "0" then
                currentPanel = "mainmenu"
            end
        end
    end

    renderFrame()
    renderUI()
    flushFrame()
end

os.execute("stty sane")
io.write("\27[?25h\27[2J\27[H\27[0;37m")
io.flush()