local _, CollectionTracker = ...

local Pets = {}

-- Creates the Pets tab content. This module is reserved for future work.
function Pets:CreateContent(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER")
    text:SetText("Coming soon")
end

CollectionTracker:RegisterModule("pets", Pets)
