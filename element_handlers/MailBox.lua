local addon, ns = ...

local function OnInboxUpdate()
    DevTools_Dump(MailFrame)
    -- Loop through the visible buttons in the list
    local scrollFrame = MailFrame.Inbox.ScrollFrame
    local buttons = scrollFrame.buttons
    local offset = HybridScrollFrame_GetOffset(scrollFrame)
    DevTools_Dump(scrollFrame)
    DevTools_Dump(buttons)
    DevTools_Dump(offset)

    for i, button in ipairs(buttons) do
        -- Calculate the real index of the mail item
        local index = offset + i

        DevTools_Dump(button)
        -- Your custom logic here (e.g., modifying the row)
        -- ns.ModifyMailRow(button, index)
    end
end

ns.OnInboxShown = function()
    local frames = ns.GetFrameStack()
    for i, frame in ipairs(frames) do
        local name = frame:GetName() or "unnamed"
        local text = ns.GetReadableTextFromFrame(frame)
        print(string.format("Frame %d: %s\n  Text: %s\n", i, name, text or "(none)"))
    end
end

-- local f = CreateFrame("Frame")
-- f:RegisterEvent("MAIL_SHOW")
-- f:SetScript("OnEvent", function(self, event)
--     OnInboxShown()
-- end)
