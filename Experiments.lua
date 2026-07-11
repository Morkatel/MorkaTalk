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
function ns.GetReadableTextFromFrame(frame)
    if not frame then return nil end

    local t = TryGetTextFromFrame(frame)
    if t then return t end

    t = TryGetTextFromChildren(frame)
    if t then return t end

    t = TryGetTextFromAncestors(frame)
    if t then return t end

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

-- Iterate through framestack and find readable text
function ns.ReadFrameStackAndFindText()
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

function ns.DebugFrameStack()
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
