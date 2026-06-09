local _, CollectionTracker = ...

local Transmog = {}

-- Creates the Transmog tab content. This module is reserved for future work.
function Transmog:CreateContent(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER")
    text:SetText("Coming soon")
end

CollectionTracker:RegisterModule("transmog", Transmog)
