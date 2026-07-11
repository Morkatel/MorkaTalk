local addon, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
frame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
frame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")

frame:SetScript("OnEvent",
    function(self, event, text, playerName, languageName, channelName, targetName, flags, zoneId, ...)
        local parts = {}

        if issecretvalue(playerName) or issecretvalue(text) then
            table.insert(parts, text)
        else
            table.insert(parts, "NPC " .. playerName .. " said: " .. text)
        end

        ns.Read(parts)
    end)
