local input = {}

-- Reads a single raw character from the terminal.
-- Returns nil if nothing is available (thanks to `stty ... min 0 time 0`).
local function getChar()
    return io.read(1)
end

-- Single entry point for all keyboard input. Call this ONCE per frame.
-- Fully consumes whatever is waiting on stdin (a plain key, or a full
-- escape sequence for arrow keys) before returning, so nothing is ever
-- left half-read for another caller to pick up.
--
-- Returns a normalized action string, or nil if no input was waiting:
--   "w", "a", "s", "d", "q", "space"  -- plain keys
--   "arrow_up", "arrow_down", "arrow_left", "arrow_right"
--   "escape"                          -- lone Esc key
--   any other raw character, returned as-is
function input.getAction()
    local char = getChar()
    if not char then return nil end

    -- Escape sequences: arrow keys arrive as \27 '[' 'A'/'B'/'C'/'D'
    if char == "\27" then
        local next1 = getChar()

        if next1 == "[" then
            local next2 = getChar()
            if next2 == "A" then return "arrow_up" end
            if next2 == "B" then return "arrow_down" end
            if next2 == "C" then return "arrow_right" end
            if next2 == "D" then return "arrow_left" end
            -- Unrecognized escape sequence -- swallow it and report nothing
            -- useful rather than leaking a stray "[" or arrow-tail byte.
            return nil
        end

        -- Lone Esc key (no "[" followed it)
        if next1 == nil then
            return "escape"
        end

        -- Something followed \27 that wasn't "[" -- not a sequence we
        -- recognize. Swallow it rather than returning it as a "key".
        return nil
    end

    if char == " " then return "space" end

    -- Plain characters: w, a, s, d, q, i, e, etc. returned as-is
    return char
end

return input