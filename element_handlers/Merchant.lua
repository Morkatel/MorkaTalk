local addon, ns = ...


-- Helper function to format standard gold/silver/copper prices
local function FormatStandardPrice(price)
    local gold = math.floor(price / 10000)
    local silver = math.floor((price % 10000) / 100)
    local copper = price % 100

    local parts = {}
    if gold > 0 then table.insert(parts, gold .. " Gold") end
    if silver > 0 then table.insert(parts, silver .. " Silver") end
    if copper > 0 then table.insert(parts, copper .. " Copper") end

    return table.concat(parts, ", ")
end

-- Helper function to format alternative currency prices
local function FormatAlternativePrice(frameID, costCount)
    local costParts = {}
    for i = 1, costCount do
        local _, amount, link, currencyName = GetMerchantItemCostItem(frameID, i)

        if link then
            local itemName = link:match("%[(.*)%]") or "Unknown Item"
            table.insert(costParts, amount .. " " .. itemName)
        elseif currencyName then
            table.insert(costParts, amount .. " " .. currencyName)
        end
    end

    if #costParts > 0 then
        return table.concat(costParts, ", ")
    end
    return ""
end


ns.GetMerchantPriceText = function(frame)
    if not (MerchantFrame and MerchantFrame:IsShown()) then return "" end

    for _, f in ipairs(GetMouseFoci()) do
        if f == MerchantFrame or RegionUtil.IsDescendantOf(f, MerchantFrame) then
            local id = f:GetID()
            if not id or id == 0 then return nil end

            local inf = C_MerchantFrame.GetItemInfo(id)
            if not inf then return "" end

            if inf.price > 0 then
                return FormatStandardPrice(inf.price)
            end

            if inf.hasExtendedCost then
                return FormatAlternativePrice(id, GetMerchantItemCostInfo(id))
            end
        end
    end

    return ""
end
