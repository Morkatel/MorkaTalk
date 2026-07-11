local addon, ns = ...

ns.is_speaking = false

-- TTS queue and control variables
local tts_lines = {}        -- list of lines to speak
local tts_timer = nil       -- timer object for the current line
local tts_skip_button = nil -- UI button for skipping lines

-- Centralized debug logger: use helper implementation from Helpers.lua
local TTSLog = ns.TTSLog

local ValidateQueue, ExtractCurrentLineText, ReadTextAloud, EstimateLineDuration, ScheduleNextTimerForLine

-- Speak the current queued line (internal)
local function SpeakCurrentLine()
    if not ValidateQueue() then
        -- No more lines to speak
        return
    end

    local text, text_len = ExtractCurrentLineText()

    -- if the text is nil or empty, skip to the next line
    if not text or text_len == 0 then
        ns.TTSLog("Skipping empty line")
        C_Timer.After(0.01, SpeakCurrentLine)
        return
    end

    ReadTextAloud(text)
    local est = EstimateLineDuration(text)
    ScheduleNextTimerForLine(est, text_len)
end

-- Calculate the estimated speech duration
local function EstimateSpeechDuration(text)
    if not text then return 1 end
    if issecretvalue(text) == false then
        return ns.EstimateSpeechDuration(text)
    else
        -- Secret value will not be read
        ns.TTSLog("SECRET SKIPPED")
        return 0
    end
end

-- Schedule the next line based on estimated time
local function ScheduleNextTimer(duration_estimate, tts_timer)
    ns.TTSLog("Scheduling next line timer with estimated duration:", duration_estimate)
    if not C_Timer then return tts_timer end
    if not duration_estimate or duration_estimate <= 0 then
        ns.is_speaking = false
        return tts_timer
    end
    ns.SafeCancelTimer(tts_timer)
    tts_timer = nil
    tts_timer = C_Timer.NewTimer(duration_estimate + 0.2, function()
        SpeakCurrentLine()
    end)
    return tts_timer
end

-- Stop the currently ongoing speech only (keeps the queue intact)
local function StopCurrentSpeech()
    ns.TTSLog("Stopping current speech (queue preserved)")
    ns.is_speaking = false
    if tts_timer and tts_timer.Cancel then
        tts_timer:Cancel()
        tts_timer = nil
    end

    if C_VoiceChat then
        if C_VoiceChat.StopSpeakingText then
            C_VoiceChat.StopSpeakingText()
            ns.TTSLog("Called C_VoiceChat.StopSpeakingText")
        end
    end
end

function ns.ReadText(text)
    local voiceID, rate, volume = ns.GetTTSSettings()
    local text_len = issecretvalue(text) and 1 or #text

    ns.TTSLog("Speak line of", #tts_lines, "len:", text_len)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        C_VoiceChat.SpeakText(voiceID, text, rate, volume, false)
    else
        ns.TTSLog("C_VoiceChat.SpeakText not available")
    end
end

-- Validate if there are lines to speak
ValidateQueue = function()
    if not tts_lines then
        ns.TTSLog("No more lines to speak")
        tts_lines = {}
        if tts_skip_button then
            tts_skip_button:Hide()
        end
        ns.is_speaking = false
        return false
    end
    return true
end

-- Extract text from the current line
ExtractTextFromLine = function()
    local text = table.remove(tts_lines, 1)
    if not text then
        ns.TTSLog("Empty line extracted")
        return nil, 0
    end

    local text_len = issecretvalue(text) and 1 or #text
    return text, text_len
end

-- Extract the current line text
ExtractCurrentLineText = function()
    local text, text_len = ExtractTextFromLine()
    if not text then return nil, 0 end
    return text, text_len
end

-- Read the extracted line aloud
ReadTextAloud = function(text)
    ns.is_speaking = true
    ns.ReadText(text)
end

-- Calculate the duration for the current line
EstimateLineDuration = function(text)
    return EstimateSpeechDuration(text)
end

-- Schedule the next line based on estimated time
ScheduleNextTimerForLine = function(est, text_len)
    tts_timer = ScheduleNextTimer(est, tts_timer)
end

-- Skip current line and move to next
ns.SkipLine = function()
    if not tts_lines then return end
    TTSLog("Skipping line")
    -- stop current speech (preserve queue)
    StopCurrentSpeech()

    -- move to next line and continue
    if 1 <= #tts_lines then
        SpeakCurrentLine()
    else
        -- finished
        tts_lines = {}
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

    -- cancel any running timer
    if tts_timer and tts_timer.Cancel then
        tts_timer:Cancel()
        tts_timer = nil
    end

    if tts_skip_button then
        tts_skip_button:Hide()
    end

    if C_VoiceChat then
        if C_VoiceChat.StopSpeakingText then
            C_VoiceChat.StopSpeakingText()
            ns.TTSLog("Called C_VoiceChat.StopSpeakingText")
        end
    else
        ns.TTSLog("C_VoiceChat not available")
    end
end


-- Validate input for reading
local function ValidateInput()
    if not tts_lines or #tts_lines == 0 then
        ns.TTSLog("Read: no parts to speak")
        return false
    end
    return true
end


-- Process secret values in the TTS lines
local function ProcessSecretValues()
    if #tts_lines > 1 and issecretvalue(tts_lines[2]) then
        local result = ""
        for i = 1, #tts_lines do
            result = string.concat(result, tts_lines[i], " ")
        end
        tts_lines = {}
        ns.TTSLog("Read concatenated secret text")
        ns.ReadText(result)
        return true
    end
    return false
end

-- Queue lines for sequential reading
local function QueueLinesForReading()
    if tts_skip_button then
        tts_skip_button:Show()
    end
    SpeakCurrentLine()
end

-- Handle table input for TTS
local function HandleTableInput(items)
    for _, value in ipairs(items) do
        table.insert(tts_lines, value)
    end
end

-- Handle string input for TTS
local function HandleStringInput(text)
    table.insert(tts_lines, text)
end

-- Handle input for reading
local function HandleInput(items)
    if type(items) == "string" then
        ns.TTSLog("Read: received string input")
        HandleStringInput(items)
    elseif type(items) == "table" then
        ns.TTSLog("Read: received table input with", #items, "items")
        HandleTableInput(items)
    else
        return false
    end
    return true
end

-- Read function: accepts a string or a table of strings and starts queued TTS for them
ns.Read = function(items)
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
        ns.Read(parts)
    else
        ns.TTSLog("OnEvent CTRL: nothing to read")
    end
end
