local addon, ns = ...

ns.LAST_HOVERED_AH_ITEM_BUY = nil
ns.LAST_HOVERED_AH_ITEM_SELL = nil
ns.LAST_HOVERED_AH_ITEM_OWN = nil


-- Format auction buy info
local function FormatAuctionBuyInfo(item)
    return item.itemName .. ', Price: ' .. ns.GetFormattedPrice(item.price) .. ', Quantity: ' .. item.totalQuantity
end

-- Format auction sell info
local function FormatAuctionSellInfo(item)
    return 'Price: ' ..
        ns.GetFormattedPrice(item.price) ..
        ', Quantity: ' .. item.totalQuantity .. ' from ' .. item.sellers .. ' sellers'
end

-- Format auction own info
local function FormatAuctionOwnInfo(item)
    return item.itemName ..
        ', Price: ' .. ns.GetFormattedPrice(item.price) .. ', ' .. SecondsToTime(item.timeLeft) .. ' remaining'
end

-- Gather auction parts for reading
function ns.GatherAuctionParts(parts)
    if ns.LAST_HOVERED_AH_ITEM_BUY then
        table.insert(parts, FormatAuctionBuyInfo(ns.LAST_HOVERED_AH_ITEM_BUY))
    elseif ns.LAST_HOVERED_AH_ITEM_SELL then
        table.insert(parts, FormatAuctionSellInfo(ns.LAST_HOVERED_AH_ITEM_SELL))
    elseif ns.LAST_HOVERED_AH_ITEM_OWN then
        table.insert(parts, FormatAuctionOwnInfo(ns.LAST_HOVERED_AH_ITEM_OWN))
    end
end

function ns.OnBrowserRowAcquired(_, frame, _, _)
    -- Ensure we only hook once per frame instance
    if not frame.MyOnEnterHooked then
        frame:HookScript("OnEnter", function(row)
            local info = row.rowData
            local price = info.minPrice or info.buyoutAmount or info.unitPrice or 0
            local itemInfo = C_AuctionHouse.GetItemKeyInfo(info.itemKey)
            local itemName = itemInfo and itemInfo.itemName or "unknown item"

            ns.LAST_HOVERED_AH_ITEM_BUY = {
                itemName = itemName,
                price = price,
                totalQuantity = info
                    .totalQuantity
            }
        end)

        frame:HookScript("OnLeave", function(row)
            ns.LAST_HOVERED_AH_ITEM_BUY = nil
        end)

        frame.MyOnEnterHooked = true
    end
end

function ns.OnSellListRowAcquired(_, frame, _, _)
    -- Ensure we only hook once per frame instance
    if frame and not frame.MyOnEnterHooked then
        frame:HookScript("OnEnter", function(row)
            local info = row.rowData -- Often contains the item info

            ns.LAST_HOVERED_AH_ITEM_SELL = {
                price = info.unitPrice,
                totalQuantity = info.quantity,
                sellers = info.totalNumberOfOwners
            }
        end)

        frame:HookScript("OnLeave", function(row)
            ns.LAST_HOVERED_AH_ITEM_SELL = nil
        end)

        frame.MyOnEnterHooked = true
    end
end

function ns.OnAllAuctionsRowAcquired(_, frame, _, _)
    -- Ensure we only hook once per frame instance
    if not frame.MyOnEnterHooked then
        frame:HookScript("OnEnter", function(row)
            local info = row.rowData
            local price = info.minPrice or info.buyoutAmount or info.unitPrice or 0
            local itemInfo = C_AuctionHouse.GetItemKeyInfo(info.itemKey)
            local itemName = itemInfo and itemInfo.itemName or "unknown item"

            ns.LAST_HOVERED_AH_ITEM_OWN = {
                itemName = itemName,
                price = price,
                timeLeft = info
                    .timeLeftSeconds
            }
        end)

        frame:HookScript("OnLeave", function(row)
            ns.LAST_HOVERED_AH_ITEM_OWN = nil
        end)

        frame.MyOnEnterHooked = true
    end
end

local f = CreateFrame("Frame")

-- 1. Listen for the AH UI to load (it's Load-On-Demand)
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_AuctionHouseUI" then
        local browseScrollBox = AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox
        local sellScrollBox = AuctionHouseFrame.CommoditiesSellList.ScrollBox
        local allAuctionsScrollBox = AuctionHouseFrameAuctionsFrame.AllAuctionsList.ScrollBox

        browseScrollBox:RegisterCallback("OnAcquiredFrame", ns.OnBrowserRowAcquired, f)
        sellScrollBox:RegisterCallback("OnAcquiredFrame", ns.OnSellListRowAcquired, f)
        allAuctionsScrollBox:RegisterCallback("OnAcquiredFrame", ns.OnAllAuctionsRowAcquired, f)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)
