local _, CollectionTracker = ...

local Mounts = {}

local DEFAULT_MOUNT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_HEIGHT = 28
local ICON_SIZE = 20
local DETAIL_ICON_SIZE = 42
local DETAILS_HEIGHT = 138

local LIST_COLUMNS = {
    { key = "icon", title = "", width = 28 },
    { key = "name", title = "Name", width = 130 },
    { key = "expansion", title = "Expansion", width = 86 },
    { key = "sourceType", title = "Type", width = 70 },
    { key = "sourceName", title = "Source", width = 150 },
    { key = "dropChance", title = "Drop", width = 44, justifyH = "RIGHT" },
    { key = "collected", title = "Status", width = 72 },
    { key = "attempts", title = "Attempts", width = 56, justifyH = "RIGHT" },
}

local LIST_WIDTH = 0
for _, column in ipairs(LIST_COLUMNS) do
    LIST_WIDTH = LIST_WIDTH + column.width
end

local STATUS_COLORS = {
    Collected = { 0.25, 1, 0.25 },
    Missing = { 1, 0.25, 0.25 },
    Unknown = { 0.85, 0.75, 0.3 },
}

local function CreateCell(parent, fontObject, xOffset, width, justifyH)
    local cell = parent:CreateFontString(nil, "OVERLAY", fontObject)
    cell:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    cell:SetWidth(width)
    cell:SetJustifyH(justifyH or "LEFT")
    cell:SetWordWrap(false)

    return cell
end

local function DisplayText(value)
    if value == nil or value == "" then
        return "-"
    end

    return tostring(value)
end

local function DetailLine(label, value)
    return string.format("%s: %s", label, DisplayText(value))
end

function Mounts:GetMounts()
    local mountData = CollectionTracker.Data and CollectionTracker.Data.Mounts

    if type(mountData) ~= "table" or type(mountData.mounts) ~= "table" then
        return {}
    end

    return mountData.mounts
end

function Mounts:GetJournalInfo(mount)
    if type(mount) ~= "table" or not mount.mountID then
        return {
            icon = DEFAULT_MOUNT_ICON,
            collectedStatus = "Unknown",
        }
    end

    if type(C_MountJournal) ~= "table" or type(C_MountJournal.GetMountInfoByID) ~= "function" then
        return {
            icon = DEFAULT_MOUNT_ICON,
            collectedStatus = "Unknown",
        }
    end

    local success, journalName, spellID, icon, active, isUsable, sourceType, isFavorite,
        isFactionSpecific, faction, shouldHideOnChar, isCollected =
        pcall(C_MountJournal.GetMountInfoByID, mount.mountID)

    if not success or not journalName then
        return {
            icon = DEFAULT_MOUNT_ICON,
            collectedStatus = "Unknown",
        }
    end

    if isCollected == nil then
        return {
            icon = icon or DEFAULT_MOUNT_ICON,
            collectedStatus = "Unknown",
        }
    end

    return {
        icon = icon or DEFAULT_MOUNT_ICON,
        collectedStatus = isCollected and "Collected" or "Missing",
    }
end

function Mounts:GetTotalAttempts(mount)
    if type(mount) ~= "table" then
        return 0
    end

    if type(mount.totalAttempts) == "number" then
        return mount.totalAttempts
    end

    local db = CollectionTracker.db or CollectionTrackerDB
    local mountAttempts = db and db.mountAttempts

    if type(mountAttempts) == "table" and mount.mountID and type(mountAttempts[mount.mountID]) == "number" then
        return mountAttempts[mount.mountID]
    end

    return 0
end

function Mounts:SetStatusColor(fontString, status)
    local color = STATUS_COLORS[status] or STATUS_COLORS.Unknown
    fontString:SetTextColor(color[1], color[2], color[3], 1)
end

function Mounts:CreateHeader(parent)
    local xOffset = 0

    for _, column in ipairs(LIST_COLUMNS) do
        local cell = CreateCell(parent, "GameFontNormalSmall", xOffset, column.width, column.justifyH)
        cell:SetText(column.title)
        xOffset = xOffset + column.width
    end
end

function Mounts:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.scrollChild)
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:EnableMouse(true)
    row.cells = {}

    local selectedTexture = row:CreateTexture(nil, "BACKGROUND")
    selectedTexture:SetAllPoints(row)
    selectedTexture:SetColorTexture(0.2, 0.5, 1, 0.16)
    selectedTexture:Hide()
    row.selectedTexture = selectedTexture

    local highlightTexture = row:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(row)
    highlightTexture:SetColorTexture(1, 1, 1, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.cells.icon = icon

    local xOffset = LIST_COLUMNS[1].width
    for index = 2, #LIST_COLUMNS do
        local column = LIST_COLUMNS[index]
        row.cells[column.key] = CreateCell(row, "GameFontHighlightSmall", xOffset, column.width, column.justifyH)
        xOffset = xOffset + column.width
    end

    row:SetScript("OnMouseUp", function()
        Mounts:SelectMount(row.mount)
    end)

    self.rows[index] = row

    return row
end

function Mounts:SetRowSelected(row, isSelected)
    if row.selectedTexture then
        if isSelected then
            row.selectedTexture:Show()
        else
            row.selectedTexture:Hide()
        end
    end
end

function Mounts:PopulateRow(row, mount)
    mount = mount or {}
    row.mount = mount

    local journalInfo = self:GetJournalInfo(mount)
    local attempts = self:GetTotalAttempts(mount)

    row.cells.icon:SetTexture(journalInfo.icon or DEFAULT_MOUNT_ICON)
    row.cells.name:SetText(DisplayText(mount.name))
    row.cells.expansion:SetText(DisplayText(mount.expansion))
    row.cells.sourceType:SetText(DisplayText(mount.sourceType))
    row.cells.sourceName:SetText(DisplayText(mount.sourceName))
    row.cells.dropChance:SetText(DisplayText(mount.dropChance))
    row.cells.collected:SetText(journalInfo.collectedStatus)
    row.cells.attempts:SetText(tostring(attempts))
    self:SetStatusColor(row.cells.collected, journalInfo.collectedStatus)

    if journalInfo.collectedStatus == "Collected" then
        row:SetAlpha(0.72)
    else
        row:SetAlpha(1)
    end

    self:SetRowSelected(row, self.selectedMount == mount)
end

function Mounts:BuildDetailsText(mount, journalInfo)
    local attempts = self:GetTotalAttempts(mount)
    local details = {
        DetailLine("Expansion", mount.expansion),
        DetailLine("Source Type", mount.sourceType),
        DetailLine("Source", mount.sourceName),
        DetailLine("Boss", mount.bossName),
        DetailLine("Encounter ID", mount.encounterID),
        DetailLine("Item ID", mount.itemID),
        DetailLine("Drop Chance", mount.dropChance),
        DetailLine("Collected", journalInfo.collectedStatus),
        DetailLine("Total Attempts", attempts),
        "",
        DetailLine("How to Obtain", mount.obtainMethod),
        "",
        DetailLine("Notes", mount.notes),
    }

    return table.concat(details, "\n")
end

function Mounts:RefreshDetails()
    if not self.detailsPanel then
        return
    end

    if not self.selectedMount then
        self.detailsIcon:SetTexture(DEFAULT_MOUNT_ICON)
        self.detailsName:SetText("Select a mount to see details.")
        self.detailsStatus:SetText("")
        self.detailsText:SetText("")
        self.detailsScrollChild:SetHeight(1)
        return
    end

    local mount = self.selectedMount
    local journalInfo = self:GetJournalInfo(mount)

    self.detailsIcon:SetTexture(journalInfo.icon or DEFAULT_MOUNT_ICON)
    self.detailsName:SetText(DisplayText(mount.name))
    self.detailsStatus:SetText(journalInfo.collectedStatus)
    self:SetStatusColor(self.detailsStatus, journalInfo.collectedStatus)
    self.detailsText:SetText(self:BuildDetailsText(mount, journalInfo))

    local textHeight = self.detailsText:GetStringHeight() or 1
    self.detailsScrollChild:SetHeight(math.max(textHeight + 8, 1))
end

function Mounts:SelectMount(mount)
    self.selectedMount = mount

    for _, row in ipairs(self.rows or {}) do
        self:SetRowSelected(row, row.mount == mount)
    end

    self:RefreshDetails()
end

function Mounts:Refresh()
    if not self.scrollChild then
        return
    end

    local mounts = self:GetMounts()

    if self.emptyText then
        if #mounts == 0 then
            self.emptyText:Show()
        else
            self.emptyText:Hide()
        end
    end

    for index, mount in ipairs(mounts) do
        local row = self.rows[index] or self:CreateRow(index)
        self:PopulateRow(row, mount)
        row:Show()
    end

    for index = #mounts + 1, #self.rows do
        self.rows[index]:Hide()
    end

    self.scrollChild:SetSize(LIST_WIDTH, math.max(#mounts * ROW_HEIGHT, ROW_HEIGHT))
    self:RefreshDetails()
end

function Mounts:CreateDetailsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    panel:SetHeight(DETAILS_HEIGHT)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.05, 0.85)
    panel:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    icon:SetSize(DETAIL_ICON_SIZE, DETAIL_ICON_SIZE)

    local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    name:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    status:SetJustifyH("LEFT")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(LIST_WIDTH - 30, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local detailText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    detailText:SetWidth(LIST_WIDTH - 48)
    detailText:SetJustifyH("LEFT")
    detailText:SetJustifyV("TOP")
    detailText:SetWordWrap(true)

    self.detailsPanel = panel
    self.detailsIcon = icon
    self.detailsName = name
    self.detailsStatus = status
    self.detailsScrollChild = scrollChild
    self.detailsText = detailText
end

-- Creates the Mounts tab content.
function Mounts:CreateContent(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mounts")

    local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("LEFT", title, "RIGHT", 12, 0)
    countText:SetText(string.format("%d mounts", #self:GetMounts()))

    self:CreateDetailsPanel(parent)

    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    header:SetSize(LIST_WIDTH, 18)
    self:CreateHeader(header)

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.detailsPanel, "TOPRIGHT", -14, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(LIST_WIDTH, ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -4)
    emptyText:SetText("No mount data loaded.")
    emptyText:Hide()

    self.rows = {}
    self.scrollChild = scrollChild
    self.emptyText = emptyText

    self:Refresh()
end

CollectionTracker:RegisterModule("mounts", Mounts)
