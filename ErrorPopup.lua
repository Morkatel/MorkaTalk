local addon, ns = ...

local tts_timer = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, errorType, message)
    -- errorType is a numeric ID (e.g., from LE_GAME_ERR_...)
    -- message is the localized string shown to the player
    -- print("Intercepted Error: " .. message)
    if ns.is_speaking then
        ns.TTSLog("Error message received but currently speaking, skipping: " .. message)
        return
    end

    if issecretvalue(message) then
        ns.is_speaking = true
        ns.ReadText("Error: ")
        ns.ReadText(message)
        ns.is_speaking = false
    else
        ns.is_speaking = true
        ns.ReadText("Error: " .. message)
        local est = ns.EstimateSpeechDuration(message)

        ns.SafeCancelTimer(tts_timer)
        tts_timer = nil
        tts_timer = C_Timer.NewTimer(est + 0.2, function()
            ns.is_speaking = false
        end)
    end
end)
