local addon, ns = ...

-- Gather lines from the GameTooltip
function ns.GatherTooltipLines()
    if not GameTooltip or not GameTooltip:IsShown() then return nil end

    local parts = {}
    local n = GameTooltip:NumLines() or 0
    for i = 1, n do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        local l = left and left.GetText and left:GetText()
        local r = right and right.GetText and right:GetText()
        local text = nil
        if l and r then
            text = l .. " " .. r
        elseif l then
            text = l
        elseif r then
            text = r
        end
        if text then table.insert(parts, text) end
    end

    return parts
end
