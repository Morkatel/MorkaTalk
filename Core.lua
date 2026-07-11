local addon, ns = ...

ns.TTS_DEBUG = false -- set to true to enable verbose TTS debug logging

-- Flags for presence of certain UI APIs

-- Centralized debug logger: use helper implementation from Helpers.lua
local TTSLog = ns.TTSLog

-- Gather default parts for reading
local function GatherDefaultParts(parts)
    local priceText = ns.GetMerchantPriceText()
    local questTextParts = ns.GetQuestText()
    local hoverText = ns.GetTextUnderMouse()
    local tooltipParts = ns.GatherTooltipLines()
    local mapText = ns.GetTextFromFrames({ WorldMapFrame.ScrollContainer })

    if priceText then table.insert(parts, priceText) end
    if tooltipParts then
        ns.TTSLog("TooltipAvailable")
        for i = 1, #tooltipParts do table.insert(parts, tooltipParts[i]) end
    elseif hoverText then
        ns.TTSLog("HoverAvailable " .. hoverText)
        table.insert(parts, hoverText)
    elseif ns.IsQuestAvailable() then
        ns.TTSLog("QuestAvailable")
        for i = 1, #questTextParts do table.insert(parts, questTextParts[i]) end
    elseif mapText then
        ns.TTSLog("MapAvailable")
        table.insert(parts, mapText)
    end
end

-- Gather parts for reading based on context
local function GatherPartsForReading()
    local parts = {}
    ns.GatherAuctionParts(parts)
    if #parts == 0 then
        GatherDefaultParts(parts)
    end
    return parts
end

local function HandleStartAction()
    TTSLog("OnEvent START (CTRL)")
    local parts = GatherPartsForReading()
    ns.ProcessPartsForReading(parts)
end

local function HandleStopAction()
    TTSLog("OnEvent STOP")
    ns.StopSpeaking()
end

local function HandleSkipAction()
    TTSLog("OnEvent SKIP")
    ns.SkipLine()
end


-- Maps action name -> handler function.
local actionHandlers = {
    start = HandleStartAction,
    stop  = HandleStopAction,
    skip  = HandleSkipAction,
}


local tooltip_key_listener = CreateFrame("Frame", "BSTooltipKeyListener")
tooltip_key_listener:RegisterEvent("MODIFIER_STATE_CHANGED")
tooltip_key_listener:SetScript("OnEvent", function(self, event, key, down)
    if not key or down ~= 1 then return end
    ns.TTSLog(event .. " " .. key .. " " .. down)
    for action, boundKey in pairs(MorkaTalkDB.keys) do
        if key == boundKey then
            local handler = actionHandlers[action]
            if handler then handler() end
            return
        end
    end
end)

-- Create a simple Skip button shown while reading
local tts_skip_button = CreateFrame("Button", "MorkaTalk_TTS_SkipButton", UIParent, "UIPanelButtonTemplate")
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

-- Slash command to toggle TTS debug logging
SLASH_MorkaTalk_TTSDEBUG1 = "/morkattsdebug"
SlashCmdList["MorkaTalk_TTSDEBUG"] = function(msg)
    ns.TTS_DEBUG = not ns.TTS_DEBUG
    print("MorkaTalk TTS debug:", ns.TTS_DEBUG and "ON" or "OFF")
end
