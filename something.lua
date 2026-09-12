local input = {}

-- Reads a single raw character from the terminal
local function getChar()
    return io.read(1)
end

-- Processes the input stream and returns a normalized action name
function input.getAction()
    local char = getChar()
    if not char then return nil end

    -- Handle Escape Sequences (Arrows, Esc Key)
    if char == "\27" then
        -- Read ahead to see if it's an arrow key sequence
        local next1 = getChar()
        
        if next1 == "[" then
            local next2 = getChar()
            if next2 == "A" then return "arrow_up" end
            if next2 == "B" then return "arrow_down" end
            if next2 == "C" then return "arrow_right" end
            if next2 == "D" then return "arrow_left" end
        end
        
        -- If it wasn't an arrow sequence, treat it as the standalone ESC key
        return "escape"
    end

    -- Return normal characters as-is (w, a, s, d, i, e, etc.)
    return char
end

return input
