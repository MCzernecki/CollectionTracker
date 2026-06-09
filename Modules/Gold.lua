local _, CollectionTracker = ...

local Gold = {}

-- Creates the Gold tab content. This is only a placeholder for now.
function Gold:CreateContent(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Gold")

    local body = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetText("Gold tracking placeholder.")
end

CollectionTracker:RegisterModule("gold", Gold)
