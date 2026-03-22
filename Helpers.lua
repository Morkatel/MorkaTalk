local addon, ns = ...

-- Helper: attempt to extract readable text from a frame (heuristics)
-- Moved here from Core.lua for reuse and clarity
---@param frame Frame
local function TryGetTextFromFrame(f)
    if not f then return nil end

    -- 1) direct text via GetText
    if f.GetText then
        local t = f:GetText()
        if t and t ~= "" then return t end
    end

    -- 2) common table/text fields (checkboxes sometimes store .text FontString or plain .text)
    if f.text then
        if type(f.text) == "string" then return f.text end
        if f.text.GetText then
            local t = f.text:GetText()
            if t and t ~= "" then return t end
        end
    end
    if f.Text then
        if type(f.Text) == "string" then return f.Text end
        if f.Text.GetText then
            local t = f.Text:GetText()
            if t and t ~= "" then return t end
        end
    end

    -- 3) scroll frames: try the scroll child
    if f.GetScrollChild then
        local sc = f:GetScrollChild()
        if sc then
            local t = TryGetTextFromFrame(sc)
            if t and t ~= "" then return t end
        end
    end

    -- 4) named globals like MyFrameText / MyFrameName / MyFrameLabel
    if f.GetName then
        local name = f:GetName()
        if name and name ~= "" then
            for _, suffix in ipairs({ "Text", "Name", "Label", "Title", "NormalText" }) do
                local g = _G[name .. suffix]
                if g and g.GetText then
                    local t = g:GetText()
                    if t and t ~= "" then return t end
                end
            end
        end
    end

    -- 5) scan direct children for text-bearing widgets
    if f.GetChildren then
        local i = 1
        while true do
            local child = select(i, f:GetChildren())
            if not child then break end
            if child.GetText then
                local t = child:GetText()
                if t and t ~= "" then return t end
            end
            i = i + 1
        end
    end

    -- 6) scan regions (FontStrings) which often hold labels for checkboxes and dropdowns
    if f.GetRegions then
        local regs = { f:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.GetText then
                local t = r:GetText()
                if t and t ~= "" then return t end
            end
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

-- Central TTS helpers
ns.TTSLog = function(...)
    if not ns.TTS_DEBUG then return end
    local n = select('#', ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring(select(i, ...)) end
    print("MorkaUI TTS:", table.concat(parts, " "))
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
ns.GetActionButtonName = function(frame)
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
        TTSLog("No frames in stack")
        return nil
    end

    TTSLog("Frame stack has", #frames, "frames")

    -- Try each frame from top to bottom
    for i, frame in ipairs(frames) do
        local frameName = frame:GetName() or "unnamed"
        local text = ns.GetReadableTextFromFrame(frame)

        TTSLog("Frame", i, ":", frameName, "- text:", text or "(none)")

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

ns.GetTextUnderMouse = function()
    local frames = GetMouseFoci()
    local foundText = {}
    local seenText = {} -- The lookup set (hash map)

    -- Helper to check a specific frame/region for text
    local function extractText(obj)
        if obj.GetText and obj:IsVisible() then
            local text = obj:GetText()
            if text and text ~= "" and not seenText[text] then
                table.insert(foundText, text)
                seenText[text] = true
            end
        end
    end

    for _, frame in ipairs(frames) do
        -- 1. Check if the frame itself has text (e.g., EditBoxes)
        extractText(frame)

        -- 2. Check all regions (FontStrings usually live here)
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "FontString" then
                extractText(region)
            end
        end

        -- 3. Check immediate children (for complex composite frames)
        -- Careful: Deep recursion here can be slow; usually 1 level is enough.
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            -- Only check children that don't capture mouse input themselves
            -- (otherwise they'd already be in GetMouseFoci)
            if not child:IsMouseEnabled() then
                extractText(child)
                -- Check child regions too
                local childRegions = { child:GetRegions() }
                for _, cr in ipairs(childRegions) do
                    if cr:GetObjectType() == "FontString" then
                        extractText(cr)
                    end
                end
            end
        end
    end
    -- Syntax: table.concat(table, separator)
    local singleString = table.concat(foundText, " ")
    return singleString
end

ns.GetMerchantPriceText = function(frame)
    local frames = GetMouseFoci()
    for _, frame in ipairs(frames) do
        -- Ensure we are looking at a valid merchant slot
        if not frame.GetID or frame:GetID() == 0 then return nil end

        -- Get price from the API
        local inf = C_MerchantFrame.GetItemInfo(frame:GetID())
        if not inf then return "" end

        -- Case 1: Standard Gold/Silver/Copper
        if inf.price > 0 then
            local gold = math.floor(inf.price / 10000)
            local silver = math.floor((inf.price % 10000) / 100)
            local copper = inf.price % 100

            local parts = {}
            if gold > 0 then table.insert(parts, gold .. " Gold") end
            if silver > 0 then table.insert(parts, silver .. " Silver") end
            if copper > 0 then table.insert(parts, copper .. " Copper") end

            return table.concat(parts, ", ")
        end

        -- Case 2: Alternative Currencies (Honor, Tokens, etc.)
        if inf.hasExtendedCost then
            -- Get number of distinct alternative costs
            local costCount = GetMerchantItemCostInfo(frame:GetID())
            local costParts = {}
            for i = 1, costCount do
                -- returns: texture, amount, itemLink, currencyName
                local _, amount, link, currencyName = GetMerchantItemCostItem(frame:GetID(), i)

                if link then
                    -- It is an Item (e.g., "Mark of Honor")
                    -- Extract clean name from link "[Name]" -> "Name"
                    local itemName = link:match("%[(.*)%]") or "Unknown Item"
                    table.insert(costParts, amount .. " " .. itemName)
                elseif currencyName then
                    -- It is a Currency (e.g., "Honor Points")
                    table.insert(costParts, amount .. " " .. currencyName)
                end
            end

            -- 5. Return formatted string or nil if free
            if #costParts > 0 then
                return table.concat(costParts, ", ")
            end
        end
    end

    return ""
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

ns.GetAuctionInfoUnderMouse = function()
    GetHoveredAHListing()

    -- GetMouseFoci returns multiple values, not a table
    local focus = select(1, GetMouseFoci())
    if not focus then return "" end

    -- 1. Traverse up to find the row frame (which holds the data)
    -- The mouse might be over a child element (like the icon or a texture), so we check parents.
    local rowData = nil
    local current = focus

    while current do
        if current.GetElementData then
            rowData = current:GetElementData()
            -- Verify this is actual AH data (look for common keys)
            if rowData and type(rowData) == "table" and (rowData.itemKey or rowData.minPrice or rowData.unitPrice) then
                break
            end
        end
        if current.GetParent then
            current = current:GetParent()
        else
            return ""
        end
    end

    if not rowData then return "" end

    -- 2. Extract Price (Price fields differ between Commodities and Items)
    local price = rowData.minPrice or rowData.buyoutAmount or rowData.unitPrice or 0

    -- 3. Extract Item Name
    local itemName = "Unknown Item"
    local itemID = nil

    if rowData.itemKey then
        itemID = rowData.itemKey.itemID
    elseif rowData.itemID then
        itemID = rowData.itemID
    end

    if itemID and _G.GetItemInfo then
        -- GetItemInfo is instant if data is cached (which it usually is for AH)
        local name = GetItemInfo(itemID)
        if name then itemName = name end
    end

    -- 4. Format Output
    local priceString = ns.GetFormattedPrice(price)
    return string.format("%s. Price: %s", itemName, priceString)
end

-- Helper for Price Formatting
function ns.GetFormattedPrice(price)
    if not price or price == 0 then return "No Price" end
    local gold = math.floor(price / 10000)
    local silver = math.floor((price % 10000) / 100)
    return string.format("%d Gold, %d Silver", gold, silver)
end
