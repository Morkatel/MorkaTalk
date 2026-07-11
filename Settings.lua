local addon, ns = ...

MorkaTalkDB = MorkaTalkDB or {
    -- Default key bindings used on first load or when SavedVariables are absent.
    -- Keys are exact WoW modifier key names (LCTRL, RCTRL, LSHIFT, RSHIFT, LALT, RALT).
    defaultKeys = {
        start = "LCTRL",
        stop  = "LALT",
        skip  = "",
    },
    talking_enabled_general = true,
    talking_enabled = {
        instance = false,
        world = true,
    },
}

local UpdateMinimapIcon
local LDBObject

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= addon then return end
    RegisterMinimapIcon()

    -- backfill any keys added in newer versions.
    MorkaTalkDB.keys = MorkaTalkDB.keys or CopyTable(MorkaTalkDB.defaultKeys)
    for action, key in pairs(MorkaTalkDB.defaultKeys) do
        if MorkaTalkDB.keys[action] == nil then
            MorkaTalkDB.keys[action] = key
        end
    end
    self:UnregisterEvent("ADDON_LOADED")
end)

function RegisterMinimapIcon()
    LDBObject = {
        type = "launcher",
        icon = "Interface\\AddOns\\MorkaTalk\\icons\\minimap_on.tga",
        label = addon,
        text = addon,
        OnClick = function(self, btn)
            if btn == "LeftButton" then
                MorkaTalkDB.talking_enabled_general = not MorkaTalkDB.talking_enabled_general
                UpdateMinimapIcon()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then
                return
            end

            tooltip:AddLine(addon .. "\n\nLeft-click: Toggle Talking", nil, nil, nil, nil)
        end,
    };

    local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(addon, LDBObject);
    local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true);
    if MorkaTalkDB.MinimapIcon == nil then
        MorkaTalkDB.MinimapIcon = {
            hide = false,
            minimapPos = 220,
            radius = 80
        };
    end
    if LDBIcon then
        LDBIcon:Register(addon, LDB, MorkaTalkDB.MinimapIcon);
    end
end

UpdateMinimapIcon = function()
    LDBObject.icon = not MorkaTalkDB.talking_enabled_general and
        "Interface\\AddOns\\MorkaTalk\\icons\\minimap_off.tga" or
        "Interface\\AddOns\\MorkaTalk\\icons\\minimap_on.tga"
end
