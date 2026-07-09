local addon, ns = ...

ns.TTS_DEBUG = false -- set to true to enable verbose TTS debug logging

-- Flags for presence of certain UI APIs

-- Centralized debug logger: use helper implementation from Helpers.lua
local TTSLog = ns.TTSLog

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

-- Gather auction parts for reading
local function GatherAuctionParts(parts)
    if ns.LAST_HOVERED_AH_ITEM_BUY then
        table.insert(parts, FormatAuctionBuyInfo(ns.LAST_HOVERED_AH_ITEM_BUY))
    elseif ns.LAST_HOVERED_AH_ITEM_SELL then
        table.insert(parts, FormatAuctionSellInfo(ns.LAST_HOVERED_AH_ITEM_SELL))
    elseif ns.LAST_HOVERED_AH_ITEM_OWN then
        table.insert(parts, FormatAuctionOwnInfo(ns.LAST_HOVERED_AH_ITEM_OWN))
    end
end

-- Gather default parts for reading
local function GatherDefaultParts(parts)
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
    GatherAuctionParts(parts)
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


local tooltipKeyListener = CreateFrame("Frame", "BSTooltipKeyListener")
tooltipKeyListener:RegisterEvent("MODIFIER_STATE_CHANGED")
tooltipKeyListener:SetScript("OnEvent", function(self, event, key, down)
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
