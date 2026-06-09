local _, CollectionTracker = ...

local Mounts = {}

-- Creates the Mounts tab content. Real collection checks will be added later.
function Mounts:CreateContent(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mounts")

    local body = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetText("Mount tracking placeholder.")
end

CollectionTracker:RegisterModule("mounts", Mounts)
