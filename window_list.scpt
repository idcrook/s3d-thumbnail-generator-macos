
set names to {}
tell application "System Events"
    repeat with theProcess in processes
        if not background only of theProcess then
            tell theProcess
                set processName to name
                set theWindows to windows
                repeat with theWindow in theWindows
                    set end of names to (processName & ":\"" & (name of theWindow) & "\"")
                end repeat
            end tell
        end if
    end repeat
end tell

set AppleScript's text item delimiters to "
"
display dialog names as text
set AppleScript's text item delimiters to ""
