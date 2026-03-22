local addon, ns = ...

ns.is_speaking = false
ns.TTS_DEBUG = false -- set to true to enable verbose TTS debug logging

-- TTS queue and control variables
local tts_lines = {}        -- list of lines to speak
local tts_idx = 0           -- current line index in tts_lines (1-based)
local tts_timer = nil       -- timer object for the current line
local tts_skip_button = nil -- UI button for skipping lines
-- Flags for presence of certain UI APIs

-- Centralized debug logger: use helper implementation from Helpers.lua
local TTSLog = ns.TTSLog

-- Stop the currently ongoing speech only (keeps the queue intact)
local function StopCurrentSpeech()
    TTSLog("Stopping current speech (queue preserved)")
    ns.is_speaking = false
    if tts_timer and tts_timer.Cancel then
        tts_timer:Cancel()
        tts_timer = nil
    end

    if C_VoiceChat then
        if C_VoiceChat.StopSpeakingText then
            C_VoiceChat.StopSpeakingText()
            TTSLog("Called C_VoiceChat.StopSpeakingText")
        end
    end
end

ns.ReadText = function(text)
    local voiceID, rate, volume = ns.GetTTSSettings()
    local text_len = issecretvalue(text) and 1 or #text

    TTSLog("Speak line", tts_idx, "of", #tts_lines, "len:", text_len)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        C_VoiceChat.SpeakText(voiceID, text, rate, volume, false)
    else
        TTSLog("C_VoiceChat.SpeakText not available")
    end
end

-- Validate if there are lines to speak
local function ValidateQueue()
    if not tts_lines or tts_idx == 0 or tts_idx > #tts_lines then
        TTSLog("No more lines to speak")
        tts_lines = {}
        tts_idx = 0
        if tts_skip_button then
            tts_skip_button:Hide()
        end
        ns.is_speaking = false
        return false
    end
    return true
end



-- Extract the current line text
local function ExtractCurrentLineText()
    local text, text_len, new_tts_idx = ns.ExtractTextFromLine(tts_lines, tts_idx)
    if not text then return nil, 0 end
    return text, text_len, new_tts_idx
end

-- Read the extracted line aloud
local function ReadCurrentLineAloud(text)
    ns.ReadTextAloud(text, ns)
end

-- Calculate the duration for the current line
local function CalculateLineDuration(text)
    return ns.CalculateSpeechDuration(text, ns)
end

-- Schedule the next line based on estimated time
local function ScheduleNextTimerForLine(est, text_len)
    tts_timer, tts_idx = ns.ScheduleNextTimer(est, tts_timer, tts_idx, ns)
end

-- Speak the current queued line (internal)
ns.SpeakCurrentLine = function()
    if not ValidateQueue() then
        return
    end

    local text, text_len, new_tts_idx = ExtractCurrentLineText()
    if not text then return end
    ReadCurrentLineAloud(text)
    local est = CalculateLineDuration(text)
    ScheduleNextTimerForLine(est, text_len)
end

-- Skip current line and move to next
local function SkipLine()
    if not tts_lines or tts_idx == 0 then return end
    TTSLog("Skipping line", tts_idx)
    -- stop current speech (preserve queue)
    StopCurrentSpeech()

    -- move to next line and continue
    tts_idx = tts_idx + 1
    if tts_idx <= #tts_lines then
        ns.SpeakCurrentLine()
    else
        -- finished
        tts_lines = {}
        tts_idx = 0
        if tts_skip_button then
            tts_skip_button:Hide()
        end
    end
end

-- Gather lines from the GameTooltip
local function GatherTooltipLines()
    if not GameTooltip or not GameTooltip:IsShown() then return nil end

    local parts = {}
    local n = GameTooltip:NumLines() or 0
    for i = 1, n do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        local l = left and left.GetText and left:GetText()
        local r = right and right.GetText and right:GetText()
        local text = nil
        if l and r then
            text = l .. " " .. r
        elseif l then
            text = l
        elseif r then
            text = r
        end
        if text then table.insert(parts, text) end
    end

    return parts
end

-- Read all visible GameTooltip lines and return them as a table of strings (gather-only)
local function ReadAndSpeakGameTooltip()
    local parts = GatherTooltipLines()
    if not parts or #parts == 0 then return nil end

    TTSLog("Tooltip gather lines:", #parts)
    return parts
end

-- Trigger tooltip read when Ctrl key is pressed; stop reading when released

local function StopSpeaking()
    TTSLog("Attempt to STOP SPEAKING")

    -- clear speaking state and queued lines
    ns.is_speaking = false
    tts_lines = {}
    tts_idx = 0

    -- cancel any running timer
    if tts_timer and tts_timer.Cancel then
        tts_timer:Cancel()
        tts_timer = nil
    end

    if tts_skip_button then
        tts_skip_button:Hide()
    end

    -- try common C_VoiceChat stop/cancel APIs safely
    if C_VoiceChat then
        if C_VoiceChat.StopSpeakingText then
            C_VoiceChat.StopSpeakingText()
            TTSLog("Called C_VoiceChat.StopSpeakingText")
        end
        if C_VoiceChat.CancelSpeakText then
            C_VoiceChat.CancelSpeakText()
            TTSLog("Called C_VoiceChat.CancelSpeakText")
        end
        if C_VoiceChat.CancelSpeaking then
            C_VoiceChat.CancelSpeaking()
            TTSLog("Called C_VoiceChat.CancelSpeaking")
        end
    else
        TTSLog("C_VoiceChat not available")
    end
end

-- Helper: attempt to extract readable text from a frame (heuristics)
-- GetReadableTextFromFrame moved to `Helpers.lua` and exported as `ns.GetReadableTextFromFrame`
-- See: Helpers.lua


-- Get the frame currently under the mouse
local function GetHoveredFrame()
    TTSLog("Hover gather started")
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

-- Extract text from a frame
local function ExtractFrameText(frame)
    if not frame then return nil end
    return ns.ExtractFrameText(frame)
end

-- Extract the frame currently under the mouse
local function ExtractHoveredFrame()
    local focus = GetHoveredFrame()
    if not focus then
        TTSLog("Hover gather: no frame under mouse")
        return nil
    end
    return focus
end

-- Read out hovered control (gather-only). Returns gathered text string or nil.
local function ReadHoveredButton()
    local frame = ExtractHoveredFrame()
    if not frame then return nil end
    return ExtractFrameText(frame)
end

-- Handle string input for TTS
local function HandleStringInput(text)
    table.insert(tts_lines, text)
end

-- Handle table input for TTS
local function HandleTableInput(items)
    for _, value in ipairs(items) do
        table.insert(tts_lines, value)
    end
end

-- Process secret values in the TTS lines
local function ProcessSecretValues()
    if #tts_lines > 1 and issecretvalue(tts_lines[2]) then
        local result = ""
        for i = 1, #tts_lines do
            result = string.concat(result, tts_lines[i], " ")
        end
        tts_lines = {}
        TTSLog("Read concatenated secret text")
        ns.ReadText(result)
        return true
    end
    return false
end

-- Queue lines for sequential reading
local function QueueLinesForReading()
    tts_idx = 1
    if tts_skip_button then
        tts_skip_button:Show()
    end
    ns.SpeakCurrentLine()
end

-- Read function: accepts a string or a table of strings and starts queued TTS for them
local function Read(items)
    -- if ns.is_speaking then
    --     TTSLog("Read suppressed: already speaking")
    --     return false
    -- end

    if type(items) == "string" then
        HandleStringInput(items)
    elseif type(items) == "table" then
        HandleTableInput(items)
    else
        return false
    end

    if not tts_lines or #tts_lines == 0 then
        TTSLog("Read: no parts to speak")
        return false
    end

    if ProcessSecretValues() then
        return true
    end

    QueueLinesForReading()
    return true
end

-- Format auction buy info
local function FormatAuctionBuyInfo(item)
    return item.itemName .. ', Price: ' .. ns.GetFormattedPrice(item.price) .. ', Quantity: ' .. item.totalQuantity
end

-- Format auction sell info
local function FormatAuctionSellInfo(item)
    return 'Price: ' ..
        ns.GetFormattedPrice(item.price) ..
        ', Quantity: ' .. item.totalQuantity .. ' from ' .. item.sellers .. ' sellers'
end

-- Format auction own info
local function FormatAuctionOwnInfo(item)
    return item.itemName ..
        ', Price: ' .. ns.GetFormattedPrice(item.price) .. ', ' .. SecondsToTime(item.timeLeft) .. ' remaining'
end

-- Add default parts for reading
local function AddDefaultParts(parts)
    local priceText = ns.GetMerchantPriceText()
    local questTextParts = ns.GetQuestText()
    local hoverText = ns.GetTextUnderMouse()
    local tooltipParts = ReadAndSpeakGameTooltip()

    if priceText then table.insert(parts, priceText) end
    if tooltipParts then
        for i = 1, #tooltipParts do table.insert(parts, tooltipParts[i]) end
    elseif hoverText then
        table.insert(parts, hoverText)
    elseif ns.IsQuestAvailable() then
        for i = 1, #questTextParts do table.insert(parts, questTextParts[i]) end
    end
end

-- Gather parts for reading based on context
local function GatherPartsForReading()
    local parts = {}

    if ns.LAST_HOVERED_AH_ITEM_BUY then
        table.insert(parts, FormatAuctionBuyInfo(ns.LAST_HOVERED_AH_ITEM_BUY))
    elseif ns.LAST_HOVERED_AH_ITEM_SELL then
        table.insert(parts, FormatAuctionSellInfo(ns.LAST_HOVERED_AH_ITEM_SELL))
    elseif ns.LAST_HOVERED_AH_ITEM_OWN then
        table.insert(parts, FormatAuctionOwnInfo(ns.LAST_HOVERED_AH_ITEM_OWN))
    else
        AddDefaultParts(parts)
    end

    return parts
end

-- Handle CTRL key press event
local function HandleCtrlKeyPress()
    TTSLog("OnEvent START (CTRL)")
    local parts = GatherPartsForReading()

    if #parts > 0 then
        Read(parts)
    else
        TTSLog("OnEvent CTRL: nothing to read")
    end
end

-- Handle LSHIFT key press event
local function HandleShiftKeyPress()
    TTSLog("OnEvent STOP")
    StopSpeaking()
end

-- Handle LALT key press event
local function HandleAltKeyPress()
    TTSLog("OnEvent SKIP")
    SkipLine()
end

local tooltipKeyListener = CreateFrame("Frame", "BSTooltipKeyListener")
tooltipKeyListener:RegisterEvent("MODIFIER_STATE_CHANGED")
tooltipKeyListener:SetScript("OnEvent", function(self, event, key, down)
    if not key then return end
    TTSLog(event .. " " .. key .. " " .. down)
    if string.find(key, "CTRL") and down == 1 then
        HandleCtrlKeyPress()
    elseif string.find(key, "LSHIFT") and down == 1 then
        HandleShiftKeyPress()
    elseif string.find(key, "LALT") and down == 1 then
        HandleAltKeyPress()
    end
end)

-- Create a simple Skip button shown while reading
tts_skip_button = CreateFrame("Button", "MorkaUI_TTS_SkipButton", UIParent, "UIPanelButtonTemplate")
tts_skip_button:SetSize(80, 22)
tts_skip_button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
tts_skip_button:SetText("Skip")
tts_skip_button:Hide()
tts_skip_button:SetScript("OnClick", function() SkipLine() end)
tts_skip_button:SetScript("OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Skip current line")
    end)
tts_skip_button:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Expose functions for other modules / testing
ns.SkipLine = SkipLine
ns.StopSpeaking = StopSpeaking
ns.ReadHoveredButton = ReadHoveredButton
ns.ReadAndSpeakGameTooltip = ReadAndSpeakGameTooltip
ns.Read = Read

-- Slash command to toggle TTS debug logging
SLASH_MORKAUI_TTSDEBUG1 = "/morkattsdebug"
SlashCmdList["MORKAUI_TTSDEBUG"] = function(msg)
    ns.TTS_DEBUG = not ns.TTS_DEBUG
    print("MorkaUI TTS debug:", ns.TTS_DEBUG and "ON" or "OFF")
end
