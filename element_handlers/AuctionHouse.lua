local addon, ns = ...

ns.LAST_HOVERED_AH_ITEM_BUY = nil
ns.LAST_HOVERED_AH_ITEM_SELL = nil
ns.LAST_HOVERED_AH_ITEM_OWN = nil

ns.OnBrowserRowAcquired = function(_, frame, _, _)
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

ns.OnSellListRowAcquired = function(_, frame, _, _)
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

ns.OnAllAuctionsRowAcquired = function(_, frame, _, _)
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
