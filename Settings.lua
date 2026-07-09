local addon_name, ns = ...

MorkaTalkDB = MorkaTalkDB or {
    -- Default key bindings used on first load or when SavedVariables are absent.
    -- Keys are exact WoW modifier key names (LCTRL, RCTRL, LSHIFT, RSHIFT, LALT, RALT).
    defaultKeys = {
        start = "LCTRL",
        stop  = "LALT",
        skip  = "",
    },
}
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= addon_name then return end

    print(MorkaTalkDB.keys)
    print(MorkaTalkDB.defaultKeys)
    -- backfill any keys added in newer versions.
    MorkaTalkDB.keys = MorkaTalkDB.keys or CopyTable(MorkaTalkDB.defaultKeys)
    for action, key in pairs(MorkaTalkDB.defaultKeys) do
        if MorkaTalkDB.keys[action] == nil then
            MorkaTalkDB.keys[action] = key
        end
    end
    self:UnregisterEvent("ADDON_LOADED")
end)


local addon = LibStub("AceAddon-3.0"):NewAddon("MorkaTalk")
MorkaTalkMinimapButton = LibStub("LibDBIcon-1.0", true)

local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("MorkaTalk", {
    type = "data source",
    text = "MorkaTalk",
    icon = "Interface\\AddOns\\MorkaTalk\\icons\\minimap.tga",
    OnClick = function(self, btn)
        -- if btn == "LeftButton" then
        --     MorkaTalk:ToggleMainFrame()
        -- elseif btn == "RightButton" then
        --     if settingsFrame:IsShown() then
        --         settingsFrame:Hide()
        --     else
        --         settingsFrame:Show()
        --     end
        -- end
    end,

    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then
            return
        end

        tooltip:AddLine("MorkaTalk\n\nLeft-click: Open MorkaTalk\nRight-click: Open MorkaTalk Settings", nil, nil, nil,
            nil)
    end,
})

function addon:OnInitialize()
    print("MorkaTalk Addon Initialized")
    self.db = LibStub("AceDB-3.0"):New("MMorkaTalkMinimapPOS", {
        profile = {
            minimap = {
                hide = false,
            },
        },
    })

    MorkaTalkMinimapButton:Register("MorkaTalk", miniButton, self.db.profile.minimap)
end

MorkaTalkMinimapButton:Show("MorkaTalk")
print("MorkaTalk Minimap Button Shown")
