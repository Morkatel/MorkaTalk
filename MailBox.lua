local addon, ns = ...

ns.LAST_HOVERED_AH_ITEM_BUY = nil
ns.LAST_HOVERED_AH_ITEM_SELL = nil
ns.LAST_HOVERED_AH_ITEM_OWN = nil

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
    local frames = GetMouseFoci()
    -- DevTools_Dump(frames)
    -- for frame in frames do
    --     print("------------------")
    --     DevTools_Dump(frame)
    --     if frame and frame:GetName() and frame:GetName():find("MailItem%d+Button") then
    --         local index = frame:GetID() -- Returns 1 through 7
    --         -- index now represents the inbox slot currently hovered
    --     end
    -- end

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
