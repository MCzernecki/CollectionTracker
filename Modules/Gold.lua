local _, CollectionTracker = ...

local Gold = {}

function Gold:EnsureDB()
    CollectionTrackerDB = CollectionTrackerDB or {}
    CollectionTracker.db = CollectionTracker.db or CollectionTrackerDB
    CollectionTracker.db.gold = CollectionTracker.db.gold or {}
    CollectionTracker.db.gold.characters = CollectionTracker.db.gold.characters or {}

    return CollectionTracker.db.gold
end

function Gold:GetCharacterKey(characterName, realmName)
    return string.format("%s-%s", realmName, characterName)
end

function Gold:FormatGold(copper)
    return GetCoinTextureString(copper or 0)
end

function Gold:GetTotalGold()
    local goldDB = self:EnsureDB()
    local totalGold = 0

    for _, character in pairs(goldDB.characters) do
        if type(character) == "table" and type(character.gold) == "number" then
            totalGold = totalGold + character.gold
        end
    end

    return totalGold
end

function Gold:Refresh()
    if self.totalValue then
        self.totalValue:SetText(self:FormatGold(self:GetTotalGold()))
    end
end

function Gold:SaveCurrentGold()
    local characterName = UnitName("player")
    local realmName = GetRealmName()
    local localizedClassName, class = UnitClass("player")

    if not characterName or not realmName then
        return
    end

    local gold = GetMoney()
    local characterKey = self:GetCharacterKey(characterName, realmName)
    local goldDB = self:EnsureDB()

    goldDB.characters[characterKey] = {
        characterName = characterName,
        realmName = realmName,
        class = class or localizedClassName,
        gold = gold,
        lastUpdated = time(),
    }

    print(string.format(
        "|cff33ff99CollectionTracker:|r Debug: saved gold for %s: %s",
        characterKey,
        self:FormatGold(gold)
    ))

    self:Refresh()
end

-- Creates the Gold tab content.
function Gold:CreateContent(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Gold")

    local totalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    totalLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    totalLabel:SetText("Total Gold")

    local totalValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalValue:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -8)
    totalValue:SetText(self:FormatGold(0))

    self.totalValue = totalValue
    self:Refresh()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:SetScript("OnEvent", function()
    Gold:SaveCurrentGold()
end)

CollectionTracker:RegisterModule("gold", Gold)
