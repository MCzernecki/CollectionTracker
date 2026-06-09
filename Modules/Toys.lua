local _, CollectionTracker = ...

local Toys = {}

-- Creates the Toys tab content. This module is reserved for future work.
function Toys:CreateContent(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER")
    text:SetText("Coming soon")
end

CollectionTracker:RegisterModule("toys", Toys)
