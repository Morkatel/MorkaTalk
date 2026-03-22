local addon, ns = ...

ns.GetQuestText = function()
    local retval = {}

    if _G and _G.QuestInfoTitleHeader then
        -- print(_G.QuestInfoTitleHeader:GetText())
        table.insert(retval, _G.QuestInfoTitleHeader:GetText())
    end

    if _G and _G.QuestInfoDescriptionText then
        -- print(_G.QuestInfoDescriptionText:GetText())
        table.insert(retval, _G.QuestInfoDescriptionText:GetText())
    end

    if _G and _G.QuestInfoObjectivesText then
        -- print(_G.QuestInfoObjectivesText:GetText())
        table.insert(retval, _G.QuestInfoObjectivesText:GetText())
    end

    if _G and _G.QuestInfoRewardText then
        -- print(_G.QuestInfoRewardText:GetText())
        table.insert(retval, _G.QuestInfoRewardText:GetText())
    end

    if _G and _G.QuestProgressText then
        -- print(_G.QuestProgressText:GetText())
        table.insert(retval, _G.QuestProgressText:GetText())
    end

    if _G and _G.AdventureMapQuestChoiceDialog and _G.AdventureMapQuestChoiceDialog.Details and
        _G.AdventureMapQuestChoiceDialog.Details.Choice and
        _G.AdventureMapQuestChoiceDialog.Details.Choice.DescriptionText then
        print(_G.AdventureMapQuestChoiceDialog.Details.Choice.DescriptionText:GetText())
        table.insert(retval, _G.AdventureMapQuestChoiceDialog.Details.Choice.DescriptionText:GetText())
    end

    -- hooksecurefunc(AdventureMapQuestChoiceDialog, "Show", function(self)
    --     -- The memory is allocated and the nodes are guaranteed to be populated here
    --     if self.Details and self.Details.Choice then
    --         local textNode = self.Details.Choice.DescriptionText
    --         local currentString = textNode:GetText()
    --         if currentString and currentString ~= "" then
    --             print(currentString)
    --         end
    --     end
    -- end)

    return retval
end

ns.IsQuestAvailable = function()
    local parts = ns.GetQuestText()

    if #parts == 0 then
        return false
    end

    return true
end
