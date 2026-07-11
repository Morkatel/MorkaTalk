local addon, ns = ...

local TryGetTextFromFrame

-- Helper: attempt to extract readable text from a frame (heuristics)
-- Moved here from Core.lua for reuse and clarity
---@param frame Frame
local function TryGetTextFromDirect(frame)
    if not frame then return nil end
    if frame.GetText then
        local t = frame:GetText()
        if t and t ~= "" then return t end
    end
    return nil
end

---@param frame Frame
local function TryGetTextFromFields(frame)
    if not frame then return nil end

    -- Check .text field
    if frame.text then
        if type(frame.text) == "string" then return frame.text end
        if frame.text.GetText then
            local t = frame.text:GetText()
            if t and t ~= "" then return t end
        end
    end

    -- Check .Text field
    if frame.Text then
        if type(frame.Text) == "string" then return frame.Text end
        if frame.Text.GetText then
            local t = frame.Text:GetText()
            if t and t ~= "" then return t end
        end
    end

    return nil
end

---@param frame Frame
local function TryGetTextFromScrollChild(frame)
    if not frame then return nil end
    if frame.GetScrollChild then
        local sc = frame:GetScrollChild()
        if sc then
            return TryGetTextFromFrame(sc)
        end
    end
    return nil
end

---@param frame Frame
local function TryGetTextFromNamedGlobals(frame)
    if not frame then return nil end
    if frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then
            for _, suffix in ipairs({ "Text", "Name", "Label", "Title", "NormalText" }) do
                local g = _G[name .. suffix]
                if g and g.GetText then
                    local t = g:GetText()
                    if not issecretvalue(t) and t and t ~= "" then return t end
                end
            end
        end
    end
    return nil
end

---@param frame Frame
local function TryGetTextFromAllChildren(frame)
    if not frame then return nil end
    if frame.GetChildren then
        local i = 1
        while true do
            local child = select(i, frame:GetChildren())
            if not child then break end
            if child.GetText then
                local t = child:GetText()
                if t and t ~= "" then return t end
            end
            i = i + 1
        end
    end
    return nil
end

-- Helper: attempt to extract readable text from children of a frame
local function TryGetTextFromChildren(frame)
    if not frame then return nil end
    local t = TryGetTextFromFrame(frame)
    if t then return t end

    -- walk up a few ancestors to catch dropdown/combobox label placements
    local parent = frame.GetParent and frame:GetParent()
    local depth = 0
    while parent and depth < 5 do
        t = TryGetTextFromFrame(parent)
        if t then return t end
        parent = parent.GetParent and parent:GetParent()
        depth = depth + 1
    end

    return nil
end
---@param frame Frame
local function TryGetTextFromRegions(frame)
    if not frame then return nil end
    if frame.GetRegions then
        local regs = { frame:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.GetText then
                local t = r:GetText()
                if not issecretvalue(t) and t and t ~= "" then return t end
            end
        end
    end
    return nil
end

---@param frame Frame
TryGetTextFromFrame = function(frame)
    local text = TryGetTextFromDirect(frame)
    if text then return text end

    text = TryGetTextFromFields(frame)
    if text then return text end

    text = TryGetTextFromScrollChild(frame)
    if text then return text end

    text = TryGetTextFromNamedGlobals(frame)
    if text then return text end

    text = TryGetTextFromChildren(frame)
    if text then return text end

    text = TryGetTextFromRegions(frame)
    if text then return text end

    return nil
end

-- Additional heuristic: check known DropDownList buttons (DropDownList1..4Button1..n)
local function TryGetTextFromAncestors(frame)
    for listIdx = 1, 4 do
        local list = _G["DropDownList" .. listIdx]
        if list then
            for btnIdx = 1, 32 do
                local btn = _G["DropDownList" .. listIdx .. "Button" .. btnIdx]
                if not btn then break end
                if frame == btn or (btn.GetParent and frame == btn:GetParent()) or frame == btn:GetName() then
                    -- try its children/normal text
                    local txt = nil
                    if btn.GetText then txt = btn:GetText() end
                    if (not txt or txt == "") then
                        local n = btn:GetName()
                        if n and n ~= "" then
                            local g = _G[n .. "NormalText"] or _G[n .. "Text"]
                            if g and g.GetText then txt = g:GetText() end
                        end
                    end
                    if (not txt or txt == "") then
                        local i = 1
                        while true do
                            local c = select(i, btn:GetChildren())
                            if not c then break end
                            if c.GetText then
                                local t2 = c:GetText()
                                if t2 and t2 ~= "" then
                                    txt = t2
                                    break
                                end
                            end
                            i = i + 1
                        end
                    end
                    if txt and txt ~= "" then return txt end
                end
            end
        end
    end

    return nil
end

---@param frame Frame
local function GetReadableTextFromFrame(frame)
    if not frame then return nil end
    local t = TryGetTextFromFrame(frame)
    if t then return t end
    t = TryGetTextFromChildren(frame)
    if t then return t end
    t = TryGetTextFromAncestors(frame)
    if t then return t end
    return nil
end

ns.GetReadableTextFromFrame = GetReadableTextFromFrame

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

-- Iterate through framestack and find readable text
ns.ReadFrameStackAndFindText = function()
    local frames = ns.GetFrameStack()
    if #frames == 0 then
        ns.TTSLog("No frames in stack")
        return nil
    end

    ns.TTSLog("Frame stack has", #frames, "frames")

    -- Try each frame from top to bottom
    for i, frame in ipairs(frames) do
        local frameName = frame:GetName() or "unnamed"
        local text = ns.GetReadableTextFromFrame(frame)

        ns.TTSLog("Frame", i, ":", frameName, "- text:", text or "(none)")

        if text and text ~= "" then
            return text, frame, i
        end
    end

    return nil
end

ns.DebugFrameStack = function()
    -- local frames = ns.GetFrameStack()
    local frames = GetMouseFoci()
    -- for i, frame in ipairs(frames) do
    --     print(i, frame:GetName() or "Anonymous Frame", frame)
    -- end
    debugFrame.scrollFrame = scrollFrame
    debugFrame.editBox = editBox

    -- Build output text
    local output = {}
    table.insert(output, string.format("Frame Stack (%d frames)\n", #frames))
    table.insert(output, "=====================================\n")

    for i, frame in ipairs(frames) do
        local name = frame:GetName() or "unnamed"
        local text = ns.GetReadableTextFromFrame(frame)
        table.insert(output, string.format("Frame %d: %s\n  Text: %s\n", i, name, text or "(none)"))
    end

    -- Update and show frame
    debugFrame.editBox:SetText(table.concat(output))
    debugFrame.editBox:SetCursorPosition(0)
    debugFrame:Show()
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

ns.GetTextUnderMouse = function()
    local frames = GetMouseFoci()
    local foundText = {}
    local seenText = {} -- The lookup set (hash map)

    for _, frame in ipairs(frames) do
        -- 1. Check if the frame itself has text (e.g., EditBoxes)
        ExtractTextFromObject(frame, foundText, seenText)

        -- 2. Check all regions (FontStrings usually live here)
        ExtractTextFromRegions(frame, foundText, seenText)

        -- 3. Check immediate children (for complex composite frames)
        ExtractTextFromChildren(frame, foundText, seenText)
    end

    for _, frame in ipairs(frames) do
        local name = frame:GetName() or "unnamed"
        local text = ns.GetReadableTextFromFrame(frame)
        ns.TTSLog("Hover gather: frame", name, "text:", text or "(none)")
    end

    -- Syntax: table.concat(table, separator)
    local singleString = table.concat(foundText, " ")
    return singleString
end

local function GetHoveredAHListing()
    -- Get the frame currently under the mouse cursor
    -- local regions = GetMouseFoci()
    -- for _, region in ipairs(regions) do
    --     -- DevTools_Dump(region)
    -- end

    local frame = select(1, regions)

    -- Ensure the frame exists and is part of the Auction House ItemList
    if frame and frame.GetElementData then
        local data = frame:GetElementData()

        -- The AH UI stores 'BrowseResultInfo' tables directly in the element data
        if data and data.itemKey then
            local itemID = data.itemKey.itemID
            local itemName = C_Item.GetItemNameByID(itemID) or "Unknown Item"
            local minPrice = data.minPrice or 0

            print(string.format("|cFF00FF00AH Hover:|r %s (ID: %d)", itemName, itemID))
            print(string.format("|cFFFFFF00Min Price:|r %.4g gold", minPrice / 10000))
            print(string.format("|cFFFFFF00Total Qty:|r %d", data.totalQuantity))
        else
            print("No AH listing data found under mouse.")
        end
    else
        print("Mouse is not over a valid UI element.")
    end
end

-- Extract price from auction data
local function ExtractAuctionPrice(rowData)
    return rowData.minPrice or rowData.buyoutAmount or rowData.unitPrice or 0
end

-- Extract item name from auction data
local function ExtractItemName(rowData)
    local itemName = "Unknown Item"
    local itemID = rowData.itemKey and rowData.itemKey.itemID or rowData.itemID

    if itemID and _G.GetItemInfo then
        local name = GetItemInfo(itemID)
        if name then itemName = name end
    end

    return itemName
end

-- Helper for Price Formatting
function ns.GetFormattedPrice(price)
    if not price or price == 0 then return "No Price" end
    local gold = math.floor(price / 10000)
    local silver = math.floor((price % 10000) / 100)
    return string.format("%d Gold, %d Silver", gold, silver)
end
