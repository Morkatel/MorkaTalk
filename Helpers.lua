local addon, ns = ...


---@param frame Frame
local function ExtractFrameText(frame)
    if not frame then return nil end
    local frameName = frame:GetName() or "unnamed"
    ns.TTSLog("Hover gather: found frame", frameName, "ref:", frame)

    local actionName = (ns.GetActionButtonName and ns.GetActionButtonName(frame)) or nil
    local text = actionName or ((ns.GetReadableTextFromFrame and ns.GetReadableTextFromFrame(frame)) or nil)

    if not text or text == "" then
        ns.TTSLog("Hover gather: no readable text on hovered frame")
        return nil
    end

    if ns.IsCheckbox(frame) and frame.GetChecked then
        local ok, val = pcall(function() return frame:GetChecked() end)
        if ok and val ~= nil then
            text = text .. (val and " (checked)" or " (not checked)")
        end
    end

    ns.TTSLog("Hover gather: frame", frameName, "text:", text)
    return text
end

-- Get the frame currently under the mouse
local function GetHoveredFrame()
    ns.TTSLog("Hover gather started")
    local focus = nil
    local gm_foci = rawget(_G, "GetMouseFoci")
    if gm_foci then
        local a, b, c, d = gm_foci()
        if type(a) == "table" then
            for i = 1, #a do
                if a[i] then
                    focus = a[i]
                    break
                end
            end
        else
            focus = a or b or c or d
        end
    end
    return focus
end

-- Extract the frame currently under the mouse
local function ExtractHoveredFrame()
    local focus = GetHoveredFrame()
    if not focus then
        ns.TTSLog("Hover gather: no frame under mouse")
        return nil
    end
    return focus
end

-- Read out hovered control (gather-only). Returns gathered text string or nil.
local function ReadHoveredButton()
    local frame = ExtractHoveredFrame()
    if not frame then return nil end
    return ns.ExtractFrameText(frame)
end

-- Central TTS helpers
ns.TTSLog = function(...)
    if not ns.TTS_DEBUG then return end
    local n = select('#', ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring(select(i, ...)) end
    print("MorkaTalk TTS:", table.concat(parts, " "))
end

ns.GetTTSSettings = function()
    local volume, rate, voiceID = 100, 0, 0
    if C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetVoiceOptionID then
        volume = C_TTSSettings.GetSpeechVolume() or volume
        rate = C_TTSSettings.GetSpeechRate() or rate
        local voiceType = (Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard) or 0
        voiceID = C_TTSSettings.GetVoiceOptionID(voiceType) or voiceID
    end
    return voiceID, rate, volume
end

ns.EstimateSpeechDuration = function(text)
    if not text then return 1 end
    return math.max(1, math.floor(#text / 15))
end

ns.UnbindSkipButton = function(btn)
    if not btn then return false end
    if _G and _G.ClearOverrideBindings then
        _G.ClearOverrideBindings(btn)
        return true
    end
    return false
end

ns.SafeCancelTimer = function(timer)
    if timer and timer.Cancel then timer:Cancel() end
end

-- Return a readable name for an action bar button frame, if applicable
function GetActionButtonName(frame)
    if not frame then return nil end
    -- Try attribute "action" first
    local action = nil
    if frame.GetAttribute then
        action = frame:GetAttribute("action")
    end
    if not action and frame.action then action = frame.action end
    -- Try ActionButton_GetPagedID if available
    if not action and _G and _G.ActionButton_GetPagedID then
        action = ActionButton_GetPagedID(frame)
    end
    if not action then
        -- fallback to frame:GetID when reasonable
        if frame.GetID then
            action = frame:GetID()
        end
    end
    if not action then return nil end

    -- GetActionInfo returns type, id, ...
    if not _G.GetActionInfo then return nil end
    local atype, id = GetActionInfo(action)
    if not atype then return nil end

    if atype == "spell" then
        if _G.GetSpellInfo then
            return GetSpellInfo(id)
        end
    elseif atype == "item" then
        if _G.GetItemInfo then
            return GetItemInfo(id)
        end
    elseif atype == "macro" then
        if _G.GetMacroInfo then
            local name = GetMacroInfo(id)
            if name and name ~= "" then return name end
        end
    elseif atype == "companion" then
        -- companions have id and not a named lookup; return tostring
        return tostring(id)
    end

    -- Try the visible action button text overlay as a last resort
    if _G.GetActionText then
        local t = GetActionText(action)
        if t and t ~= "" then return t end
    end

    return nil
end

function ns.IsCheckbox(frame)
    return frame and frame.IsObjectType and frame:IsObjectType("CheckButton")
end

-- Get all frames in the hovered framestack (top to bottom)
ns.GetFrameStack = function()
    local gm_foci = rawget(_G, "GetMouseFoci")
    if not gm_foci then return {} end

    local frames = {}
    local a, b, c, d = gm_foci()
    if type(a) == "table" then
        for i = 1, #a do
            if a[i] then table.insert(frames, a[i]) end
        end
    else
        for frame in pairs({ a, b, c, d }) do
            if frame then table.insert(frames, frame) end
        end
    end
    return frames
end


-- Extract text from a frame or region
local function ExtractTextFromObject(obj, foundText, seenText)
    if obj.GetText and obj:IsVisible() then
        local text = obj:GetText()
        if text and text ~= "" and not seenText[text] then
            table.insert(foundText, text)
            seenText[text] = true
        end
    end
end

-- Extract text from regions of a frame
local function ExtractTextFromRegions(frame, foundText, seenText)
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region:GetObjectType() == "FontString" then
            ExtractTextFromObject(region, foundText, seenText)
        end
    end
end

-- Extract text from children of a frame
local function ExtractTextFromChildren(frame, foundText, seenText)
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if not child:IsMouseEnabled() then
            ExtractTextFromObject(child, foundText, seenText)
            local childRegions = { child:GetRegions() }
            for _, cr in ipairs(childRegions) do
                if cr:GetObjectType() == "FontString" then
                    ExtractTextFromObject(cr, foundText, seenText)
                end
            end
        end
    end
end

-- @return string: concatenated text from all frames
function ns.GetTextFromFrames(frames)
    local foundText = {}
    local seenText = {} -- The lookup set (hash map)

    for _, frame in ipairs(frames) do
        print("GetTextFromFrames: examining frame", frame:GetName() or "unnamed", "ref:", frame)
        -- 1. Check if the frame itself has text (e.g., EditBoxes)
        ExtractTextFromObject(frame, foundText, seenText)

        -- 2. Check all regions (FontStrings usually live here)
        ExtractTextFromRegions(frame, foundText, seenText)

        -- 3. Check immediate children (for complex composite frames)
        ExtractTextFromChildren(frame, foundText, seenText)
    end

    -- Syntax: table.concat(table, separator)
    local singleString = table.concat(foundText, " ")
    if singleString == "" then
        ns.TTSLog("GetTextFromFrames: no readable text found in frames")
        return nil
    end

    ns.TTSLog("GetTextFromFrames: found text:", singleString)
    return singleString
end

function ns.GetTextUnderMouse()
    local frames = GetMouseFoci()
    return ns.GetTextFromFrames(frames)
end

-- Helper for Price Formatting
function ns.GetFormattedPrice(price)
    if not price or price == 0 then return "No Price" end
    local gold = math.floor(price / 10000)
    local silver = math.floor((price % 10000) / 100)
    return string.format("%d Gold, %d Silver", gold, silver)
end
