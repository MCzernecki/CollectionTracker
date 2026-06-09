local _, CollectionTracker = ...

local Gold = {}

local ROW_HEIGHT = 22
local DETAIL_COLUMNS = {
    { key = "characterName", title = "Character", width = 120 },
    { key = "realmName", title = "Realm", width = 120 },
    { key = "class", title = "Class", width = 90 },
    { key = "gold", title = "Gold", width = 150, justifyH = "RIGHT" },
    { key = "lastUpdated", title = "Last Updated", width = 140 },
}

local DETAIL_WIDTH = 0
for _, column in ipairs(DETAIL_COLUMNS) do
    DETAIL_WIDTH = DETAIL_WIDTH + column.width
end

local function CreateCell(parent, fontObject, xOffset, width, justifyH)
    local cell = parent:CreateFontString(nil, "OVERLAY", fontObject)
    cell:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    cell:SetWidth(width)
    cell:SetJustifyH(justifyH or "LEFT")
    cell:SetWordWrap(false)

    return cell
end

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

function Gold:FormatLastUpdated(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return "Unknown"
    end

    return date("%Y-%m-%d %H:%M", timestamp)
end

function Gold:GetSortedCharacters()
    local goldDB = self:EnsureDB()
    local characters = {}

    for _, character in pairs(goldDB.characters) do
        if type(character) == "table" then
            table.insert(characters, {
                characterName = character.characterName or "Unknown",
                realmName = character.realmName or "Unknown",
                class = character.class or "Unknown",
                gold = tonumber(character.gold) or 0,
                lastUpdated = character.lastUpdated,
            })
        end
    end

    table.sort(characters, function(left, right)
        if left.gold == right.gold then
            return left.characterName < right.characterName
        end

        return left.gold > right.gold
    end)

    return characters
end

function Gold:GetTotalGold()
    local goldDB = self:EnsureDB()
    local totalGold = 0

    for _, character in pairs(goldDB.characters) do
        if type(character) == "table" then
            totalGold = totalGold + (tonumber(character.gold) or 0)
        end
    end

    return totalGold
end

function Gold:Refresh()
    if self.totalValue then
        local prefix = self.detailsShown and "[-] " or "[+] "
        self.totalValue:SetText(prefix .. self:FormatGold(self:GetTotalGold()))
    end

    if self.detailsShown then
        self:RefreshDetails()
    end
end

function Gold:ToggleDetails()
    self.detailsShown = not self.detailsShown

    if self.detailsPanel then
        if self.detailsShown then
            self.detailsPanel:Show()
        else
            self.detailsPanel:Hide()
        end
    end

    self:Refresh()
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

function Gold:CreateDetailsHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetSize(DETAIL_WIDTH, ROW_HEIGHT)

    local xOffset = 0
    for _, column in ipairs(DETAIL_COLUMNS) do
        local cell = CreateCell(header, "GameFontNormalSmall", xOffset, column.width, column.justifyH)
        cell:SetText(column.title)
        xOffset = xOffset + column.width
    end
end

function Gold:CreateDetailRow(index)
    local row = CreateFrame("Frame", nil, self.detailsScrollChild)
    row:SetPoint("TOPLEFT", self.detailsScrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetSize(DETAIL_WIDTH, ROW_HEIGHT)
    row.cells = {}

    local xOffset = 0
    for _, column in ipairs(DETAIL_COLUMNS) do
        row.cells[column.key] = CreateCell(row, "GameFontHighlightSmall", xOffset, column.width, column.justifyH)
        xOffset = xOffset + column.width
    end

    self.detailRows[index] = row

    return row
end

function Gold:RefreshDetails()
    if not self.detailsScrollChild then
        return
    end

    local characters = self:GetSortedCharacters()

    if self.emptyText then
        if #characters == 0 then
            self.emptyText:Show()
        else
            self.emptyText:Hide()
        end
    end

    for index, character in ipairs(characters) do
        local row = self.detailRows[index] or self:CreateDetailRow(index)

        row.cells.characterName:SetText(character.characterName)
        row.cells.realmName:SetText(character.realmName)
        row.cells.class:SetText(character.class)
        row.cells.gold:SetText(self:FormatGold(character.gold))
        row.cells.lastUpdated:SetText(self:FormatLastUpdated(character.lastUpdated))
        row:Show()
    end

    for index = #characters + 1, #self.detailRows do
        self.detailRows[index]:Hide()
    end

    self.detailsScrollChild:SetSize(DETAIL_WIDTH, math.max(#characters * ROW_HEIGHT, ROW_HEIGHT))
end

-- Creates the Gold tab content.
function Gold:CreateContent(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Gold")

    local totalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    totalLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    totalLabel:SetText("Total Gold")

    local totalButton = CreateFrame("Button", nil, parent)
    totalButton:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", -4, -6)
    totalButton:SetSize(300, 28)
    totalButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    totalButton:SetScript("OnClick", function()
        Gold:ToggleDetails()
    end)

    local totalValue = totalButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalValue:SetPoint("LEFT", totalButton, "LEFT", 4, 0)
    totalValue:SetJustifyH("LEFT")
    totalValue:SetText(self:FormatGold(0))

    local detailsPanel = CreateFrame("Frame", nil, parent)
    detailsPanel:SetPoint("TOPLEFT", totalButton, "BOTTOMLEFT", 4, -18)
    detailsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    detailsPanel:Hide()

    self:CreateDetailsHeader(detailsPanel)

    local scrollFrame = CreateFrame("ScrollFrame", nil, detailsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 0, -ROW_HEIGHT - 8)
    scrollFrame:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -28, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(DETAIL_WIDTH, ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    local emptyText = detailsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -4)
    emptyText:SetText("No character gold saved yet.")

    self.totalValue = totalValue
    self.detailsPanel = detailsPanel
    self.detailsScrollChild = scrollChild
    self.detailRows = {}
    self.emptyText = emptyText
    self:Refresh()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:SetScript("OnEvent", function()
    Gold:SaveCurrentGold()
end)

CollectionTracker:RegisterModule("gold", Gold)
