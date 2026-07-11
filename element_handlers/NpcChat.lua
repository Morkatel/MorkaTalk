local addon, ns = ...

local talk_enabled = true

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
frame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
frame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")

frame:SetScript("OnEvent",
    function(self, event, text, playerName, languageName, channelName, targetName, flags, zoneId, ...)
        if not talk_enabled then return end

        local parts = {}

        if issecretvalue(playerName) or issecretvalue(text) then
            table.insert(parts, text)
        else
            table.insert(parts, "NPC " .. playerName .. " said: " .. text)
        end

        ns.Read(parts)
    end)

local instance_enter_listener = CreateFrame("Frame")
instance_enter_listener:RegisterEvent("PLAYER_ENTERING_WORLD")
instance_enter_listener:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()

    talk_enabled = instanceType == "none"
end)
