--------------------------------------------------
-- Utility: Simulate a key press with optional modifiers
--------------------------------------------------
local function keyCode(key, modifiers)
    modifiers = modifiers or {}
    return function()
        hs.eventtap.event.newKeyEvent(modifiers, string.lower(key), true):post()
        hs.timer.usleep(1000)
        hs.eventtap.event.newKeyEvent(modifiers, string.lower(key), false):post()
    end
end

--------------------------------------------------
-- Global hotkey table (enabled except in Terminal)
--------------------------------------------------
local globalHotkeys = {}

-- Register global hotkeys
local function remapKey(modifiers, key, action)
    table.insert(globalHotkeys, hs.hotkey.new(modifiers, key, action, nil, action))
end

local function enableGlobalHotkeys()
    for _, hk in ipairs(globalHotkeys) do hk:enable() end
end

local function disableGlobalHotkeys()
    for _, hk in ipairs(globalHotkeys) do hk:disable() end
end

--------------------------------------------------
-- Trigger buffer for Markdown-like shortcuts
--------------------------------------------------
local inputBuffer = ""
local activeWatcher = nil

-- Safely delete only the trigger (e.g., "## ")
local function deleteTypedTriggerSafe(triggerLength)
    for i = 1, triggerLength do
        hs.eventtap.event.newKeyEvent({}, "left", true):post()
        hs.eventtap.event.newKeyEvent({}, "left", false):post()
        hs.timer.usleep(500)
    end
    for i = 1, triggerLength do
        hs.eventtap.event.newKeyEvent({"shift"}, "right", true):post()
        hs.eventtap.event.newKeyEvent({"shift"}, "right", false):post()
        hs.timer.usleep(500)
    end
    hs.eventtap.event.newKeyEvent({}, "delete", true):post()
    hs.eventtap.event.newKeyEvent({}, "delete", false):post()
end

-- Simulate a custom key combo
local function simulateKeyCombo(mods, key)
    hs.eventtap.event.newKeyEvent(mods, key, true):post()
    hs.timer.usleep(1000)
    hs.eventtap.event.newKeyEvent(mods, key, false):post()
end

-- Handle trigger patterns like "# ", "## ", "> "
local function handleKeyEvent(event)
    local app = hs.application.frontmostApplication()
    if app:bundleID() ~= "com.apple.Notes" then return false end

    if event:getType() == hs.eventtap.event.types.keyDown then
        local key = event:getCharacters()
        if key == " " then
            if inputBuffer == "#" then
                deleteTypedTriggerSafe(1)
                simulateKeyCombo({"cmd", "ctrl"}, "t")
                inputBuffer = ""
                return true
            elseif inputBuffer == "##" then
                deleteTypedTriggerSafe(2)
                simulateKeyCombo({"cmd", "ctrl"}, "h")
                inputBuffer = ""
                return true
            elseif inputBuffer == ">" then
                deleteTypedTriggerSafe(1)
                simulateKeyCombo({"cmd"}, "'")
                inputBuffer = ""
                return true
            end
        elseif key == "#" or key == ">" then
            inputBuffer = inputBuffer .. key
        else
            inputBuffer = ""
        end
    end
    return false
end

-- Start or restart the Markdown trigger watcher
local function restartKeyWatcher()
    if activeWatcher then activeWatcher:stop() end
    activeWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, handleKeyEvent)
    activeWatcher:start()
end

--------------------------------------------------
-- App focus handler
-- Uses bundleID for language-independent app detection
--------------------------------------------------
local function handleGlobalAppEvent(name, event, app)
    if event == hs.application.watcher.activated then
        local bundleID = app:bundleID()

        -- Terminal: disable global hotkeys
        if bundleID == "com.apple.Terminal" then
            disableGlobalHotkeys()
        else
            enableGlobalHotkeys()
        end

        -- Notes.app (com.apple.Notes): enable Markdown watcher
        if bundleID == "com.apple.Notes" then
            restartKeyWatcher()
        else
            if activeWatcher then activeWatcher:stop() end
        end
    end
end

-- Watch for app focus changes
appsWatcher = hs.application.watcher.new(handleGlobalAppEvent)
appsWatcher:start()

-- Enable watcher if current app is Notes on launch
if hs.application.frontmostApplication():bundleID() == "com.apple.Notes" then
    restartKeyWatcher()
end

-- Enable global hotkeys on launch if not in Terminal
if hs.application.frontmostApplication():bundleID() ~= "com.apple.Terminal" then
    enableGlobalHotkeys()
end

--------------------------------------------------
-- Global hotkey remapping (Emacs-style cursor movement)
-- These are always enabled unless in Terminal
-- Forkers: Add your own hotkeys here!
--------------------------------------------------
remapKey({'ctrl'}, 'f', keyCode('right'))     -- Move forward
remapKey({'ctrl'}, 'b', keyCode('left'))      -- Move backward
remapKey({'ctrl'}, 'n', keyCode('down'))      -- Move next line
remapKey({'ctrl'}, 'p', keyCode('up'))        -- Move previous line
remapKey({'ctrl'}, 'a', keyCode('left', {'cmd'}))  -- Line start
remapKey({'ctrl'}, 'e', keyCode('right', {'cmd'})) -- Line end
remapKey({'ctrl'}, 'm', keyCode('return'))    -- Return
remapKey({'ctrl'}, 'g', keyCode('escape'))    -- Cancel
remapKey({'ctrl'}, 'v', keyCode('pagedown'))  -- Page down
remapKey({'alt'},  'v', keyCode('pageup'))    -- Page up
remapKey({'ctrl'}, 'h', keyCode('delete'))    -- Backspace

-- Forkers: You can define additional trigger patterns or global shortcuts below
-- Example: Markdown bold, list items, linking etc.
-- remapKey({'ctrl'}, 'd', keyCode('x')) -- Customize here