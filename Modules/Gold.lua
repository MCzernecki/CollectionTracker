local _, CollectionTracker = ...

local Gold = {}

local ROW_HEIGHT = 22
local SUMMARY_VALUE_OFFSET = 180
local SUMMARY_VALUE_WIDTH = 360
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
    if type(CollectionTracker.db.gold.warbandBank) ~= "table" then
        CollectionTracker.db.gold.warbandBank = {}
    end

    return CollectionTracker.db.gold
end

function Gold:GetCharacterKey(characterName, realmName)
    return string.format("%s-%s", realmName, characterName)
end

function Gold:FormatGold(copper)
    return GetCoinTextureString(copper or 0)
end

function Gold:GetWarbandBankType()
    if type(Enum) ~= "table" or type(Enum.BankType) ~= "table" then
        return nil
    end

    return Enum.BankType.Account
end

function Gold:FetchWarbandBankGold()
    if type(C_Bank) ~= "table" or type(C_Bank.FetchDepositedMoney) ~= "function" then
        return nil
    end

    local accountBankType = self:GetWarbandBankType()
    if accountBankType == nil then
        return nil
    end

    local success, depositedMoney = pcall(C_Bank.FetchDepositedMoney, accountBankType)
    if not success then
        return nil
    end

    return tonumber(depositedMoney)
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

function Gold:GetCharactersTotalGold()
    local goldDB = self:EnsureDB()
    local totalGold = 0

    for _, character in pairs(goldDB.characters) do
        if type(character) == "table" then
            totalGold = totalGold + (tonumber(character.gold) or 0)
        end
    end

    return totalGold
end

function Gold:GetWarbandBankGold()
    local warbandBank = self:EnsureDB().warbandBank

    if type(warbandBank) ~= "table" then
        return 0
    end

    return tonumber(warbandBank.gold) or 0
end

function Gold:GetGrandTotalGold()
    return self:GetCharactersTotalGold() + self:GetWarbandBankGold()
end

function Gold:Refresh()
    if self.charactersTotalValue then
        local prefix = self.detailsShown and "[-] " or "[+] "
        self.charactersTotalValue:SetText(prefix .. self:FormatGold(self:GetCharactersTotalGold()))
    end

    if self.warbandBankValue then
        self.warbandBankValue:SetText(self:FormatGold(self:GetWarbandBankGold()))
    end

    if self.grandTotalValue then
        self.grandTotalValue:SetText(self:FormatGold(self:GetGrandTotalGold()))
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

function Gold:SaveWarbandBankGold()
    local gold = self:FetchWarbandBankGold()

    if gold == nil then
        return false
    end

    local goldDB = self:EnsureDB()
    goldDB.warbandBank.gold = gold
    goldDB.warbandBank.lastUpdated = time()

    self:Refresh()

    return true
end

function Gold:UpdateWarbandBankGold()
    self:SaveWarbandBankGold()

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0.5, function()
            Gold:SaveWarbandBankGold()
        end)
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

    local charactersTotalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    charactersTotalLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    charactersTotalLabel:SetText("Characters Total Gold")

    local charactersTotalButton = CreateFrame("Button", nil, parent)
    charactersTotalButton:SetPoint("LEFT", charactersTotalLabel, "LEFT", SUMMARY_VALUE_OFFSET - 4, 0)
    charactersTotalButton:SetSize(SUMMARY_VALUE_WIDTH, ROW_HEIGHT)
    charactersTotalButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    charactersTotalButton:SetScript("OnClick", function()
        Gold:ToggleDetails()
    end)

    local charactersTotalValue = charactersTotalButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    charactersTotalValue:SetPoint("LEFT", charactersTotalButton, "LEFT", 4, 0)
    charactersTotalValue:SetWidth(SUMMARY_VALUE_WIDTH)
    charactersTotalValue:SetJustifyH("LEFT")
    charactersTotalValue:SetWordWrap(false)
    charactersTotalValue:SetText(self:FormatGold(0))

    local warbandBankLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warbandBankLabel:SetPoint("TOPLEFT", charactersTotalLabel, "BOTTOMLEFT", 0, -12)
    warbandBankLabel:SetText("Warband Bank Gold")

    local warbandBankValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    warbandBankValue:SetPoint("LEFT", warbandBankLabel, "LEFT", SUMMARY_VALUE_OFFSET, 0)
    warbandBankValue:SetWidth(SUMMARY_VALUE_WIDTH)
    warbandBankValue:SetJustifyH("LEFT")
    warbandBankValue:SetWordWrap(false)
    warbandBankValue:SetText(self:FormatGold(0))

    local grandTotalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    grandTotalLabel:SetPoint("TOPLEFT", warbandBankLabel, "BOTTOMLEFT", 0, -12)
    grandTotalLabel:SetText("Grand Total Gold")

    local grandTotalValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    grandTotalValue:SetPoint("LEFT", grandTotalLabel, "LEFT", SUMMARY_VALUE_OFFSET, 0)
    grandTotalValue:SetWidth(SUMMARY_VALUE_WIDTH)
    grandTotalValue:SetJustifyH("LEFT")
    grandTotalValue:SetWordWrap(false)
    grandTotalValue:SetText(self:FormatGold(0))

    local detailsPanel = CreateFrame("Frame", nil, parent)
    detailsPanel:SetPoint("TOPLEFT", grandTotalLabel, "BOTTOMLEFT", 0, -20)
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

    self.charactersTotalValue = charactersTotalValue
    self.totalValue = charactersTotalValue
    self.warbandBankValue = warbandBankValue
    self.grandTotalValue = grandTotalValue
    self.detailsPanel = detailsPanel
    self.detailsScrollChild = scrollChild
    self.detailRows = {}
    self.emptyText = emptyText
    self:Refresh()
end

local eventFrame = CreateFrame("Frame")
local function RegisterEventSafely(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventSafely("PLAYER_LOGIN")
RegisterEventSafely("PLAYER_MONEY")
RegisterEventSafely("BANKFRAME_OPENED")
RegisterEventSafely("ACCOUNT_BANK_PANEL_OPENED")
RegisterEventSafely("ACCOUNT_BANK_OPENED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_MONEY" then
        Gold:SaveCurrentGold()
    else
        Gold:UpdateWarbandBankGold()
    end
end)

CollectionTracker:RegisterModule("gold", Gold)
