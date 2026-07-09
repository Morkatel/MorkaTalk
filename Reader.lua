local addon, ns = ...

ns.is_speaking = false

-- TTS queue and control variables
local tts_lines = {}        -- list of lines to speak
local tts_idx = 0           -- current line index in tts_lines (1-based)
local tts_timer = nil       -- timer object for the current line
local tts_skip_button = nil -- UI button for skipping lines

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
ns.SkipLine = function()
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

ns.StopSpeaking = function()
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

-- Handle table input for TTS
local function HandleTableInput(items)
    for _, value in ipairs(items) do
        table.insert(tts_lines, value)
    end
end


-- Validate input for reading
local function ValidateInput()
    if not tts_lines or #tts_lines == 0 then
        TTSLog("Read: no parts to speak")
        return false
    end
    return true
end

-- Handle string input for TTS
local function HandleStringInput(text)
    table.insert(tts_lines, text)
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

-- Handle input for reading
local function HandleInput(items)
    if type(items) == "string" then
        HandleStringInput(items)
    elseif type(items) == "table" then
        HandleTableInput(items)
    else
        return false
    end
    return true
end

-- Read function: accepts a string or a table of strings and starts queued TTS for them
local function Read(items)
    if not HandleInput(items) then
        return false
    end
    if not ValidateInput() then
        return false
    end
    if ProcessSecretValues() then
        return true
    end
    QueueLinesForReading()
    return true
end


-- Process gathered parts for reading
ns.ProcessPartsForReading = function(parts)
    if #parts > 0 then
        Read(parts)
    else
        TTSLog("OnEvent CTRL: nothing to read")
    end
end
