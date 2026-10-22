-- Bring the first window whose title contains the given text to the front (macOS).
-- Prints "raised" or "not found". Needs Accessibility permission for the terminal app.
on run argv
    set wanted to item 1 of argv
    tell application "System Events"
        -- Fails here (outside the try below) if Accessibility permission is missing
        get name of every window of (first process whose frontmost is true)
        repeat with p in (every process whose background only is false)
            try
                repeat with w in (every window of p)
                    if name of w contains wanted then
                        set frontmost of p to true
                        perform action "AXRaise" of w
                        return "raised"
                    end if
                end repeat
            end try
        end repeat
    end tell
    return "not found"
end run
