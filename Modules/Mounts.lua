local _, CollectionTracker = ...

local Mounts = {}

local DEFAULT_MOUNT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_HEIGHT = 28
local ICON_SIZE = 20
local DETAIL_ICON_SIZE = 52
local OUTER_PADDING = 16
local PANEL_GUTTER = 12
local DETAILS_WIDTH_RATIO = 0.33
local LIST_MIN_WIDTH = 540
local DETAILS_MIN_WIDTH = 280
local LIST_PANEL_PADDING = 8
local SCROLLBAR_WIDTH = 28

local LIST_COLUMNS = {
    { key = "icon", title = "", minWidth = 26 },
    { key = "name", title = "Name", minWidth = 100, flex = 2 },
    { key = "expansion", title = "Expansion", minWidth = 66, flex = 1 },
    { key = "sourceType", title = "Type", minWidth = 54, flex = 1 },
    { key = "sourceName", title = "Source", minWidth = 100, flex = 2 },
    { key = "dropChance", title = "Drop", minWidth = 42, justifyH = "RIGHT" },
    { key = "collected", title = "Status", minWidth = 58 },
    { key = "attempts", title = "Attempts", minWidth = 50, justifyH = "RIGHT" },
}

local LIST_MIN_INNER_WIDTH = 0
local LIST_FLEX_TOTAL = 0
for _, column in ipairs(LIST_COLUMNS) do
    LIST_MIN_INNER_WIDTH = LIST_MIN_INNER_WIDTH + column.minWidth
    LIST_FLEX_TOTAL = LIST_FLEX_TOTAL + (column.flex or 0)
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

local function FormatDropChance(value)
    local dropChance = tonumber(value)

    if not dropChance then
        return nil
    end

    return string.format("%g%%", dropChance)
end

local function DisplayDropChance(value)
    return FormatDropChance(value) or "-"
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

function Mounts:GetVisibleMounts()
    return self:GetMounts()
end

function Mounts:CalculateColumnWidths(totalWidth)
    totalWidth = math.max(math.floor(totalWidth or LIST_MIN_INNER_WIDTH), LIST_MIN_INNER_WIDTH)

    local widths = {}
    local extraWidth = math.max(totalWidth - LIST_MIN_INNER_WIDTH, 0)
    local assignedWidth = 0

    for _, column in ipairs(LIST_COLUMNS) do
        local width = column.minWidth

        if extraWidth > 0 and (column.flex or 0) > 0 and LIST_FLEX_TOTAL > 0 then
            width = width + math.floor(extraWidth * column.flex / LIST_FLEX_TOTAL)
        end

        widths[column.key] = width
        assignedWidth = assignedWidth + width
    end

    local remainder = totalWidth - assignedWidth
    if remainder > 0 then
        widths.sourceName = widths.sourceName + remainder
    end

    return widths
end

function Mounts:LayoutCells(frame, widths, isRow)
    local xOffset = 0

    for _, column in ipairs(LIST_COLUMNS) do
        local cell = frame.cells and frame.cells[column.key]
        local width = widths[column.key] or column.minWidth

        if cell then
            cell:ClearAllPoints()

            if isRow and column.key == "icon" then
                cell:SetPoint("LEFT", frame, "LEFT", xOffset + 3, 0)
                cell:SetSize(math.min(ICON_SIZE, math.max(width - 6, 12)), ICON_SIZE)
            else
                cell:SetPoint("LEFT", frame, "LEFT", xOffset, 0)
                cell:SetWidth(width)
            end
        end

        xOffset = xOffset + width
    end
end

function Mounts:ApplyListLayout()
    if not self.listPanel then
        return
    end

    local panelWidth = self.listPanel:GetWidth() or LIST_MIN_WIDTH
    local listInnerWidth = math.max(math.floor(panelWidth - LIST_PANEL_PADDING - SCROLLBAR_WIDTH), LIST_MIN_INNER_WIDTH)
    local widths = self:CalculateColumnWidths(listInnerWidth)

    self.listInnerWidth = listInnerWidth
    self.columnWidths = widths

    if self.header then
        self.header:SetWidth(listInnerWidth)
        self:LayoutCells(self.header, widths, false)
    end

    if self.scrollChild then
        local height = self.scrollChild:GetHeight() or ROW_HEIGHT
        self.scrollChild:SetSize(listInnerWidth, math.max(height, ROW_HEIGHT))
    end

    for _, row in ipairs(self.rows or {}) do
        row:SetWidth(listInnerWidth)
        self:LayoutCells(row, widths, true)
    end
end

function Mounts:CreateHeader(parent)
    parent.cells = {}

    local xOffset = 0
    for _, column in ipairs(LIST_COLUMNS) do
        parent.cells[column.key] = CreateCell(parent, "GameFontNormalSmall", xOffset, column.minWidth, column.justifyH)
        parent.cells[column.key]:SetText(column.title)
        xOffset = xOffset + column.minWidth
    end
end

function Mounts:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.scrollChild)
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetSize(self.listInnerWidth or LIST_MIN_INNER_WIDTH, ROW_HEIGHT)
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

    local xOffset = LIST_COLUMNS[1].minWidth
    for index = 2, #LIST_COLUMNS do
        local column = LIST_COLUMNS[index]
        row.cells[column.key] = CreateCell(row, "GameFontHighlightSmall", xOffset, column.minWidth, column.justifyH)
        xOffset = xOffset + column.minWidth
    end

    row:SetScript("OnMouseUp", function()
        Mounts:SelectMount(row.mount)
    end)

    self.rows[index] = row
    if self.columnWidths then
        self:LayoutCells(row, self.columnWidths, true)
    end

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
    row.cells.dropChance:SetText(DisplayDropChance(mount.dropChance))
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
    local details = {}
    local dropChance = FormatDropChance(mount.dropChance)

    table.insert(details, DetailLine("Expansion", mount.expansion))
    table.insert(details, DetailLine("Source Type", mount.sourceType))
    table.insert(details, DetailLine("Source", mount.sourceName))

    if mount.bossName and mount.bossName ~= "" then
        table.insert(details, DetailLine("Boss", mount.bossName))
    end

    if dropChance then
        table.insert(details, DetailLine("Drop Chance", dropChance))
    end

    if mount.encounterID then
        table.insert(details, DetailLine("Encounter ID", mount.encounterID))
    end

    if mount.itemID then
        table.insert(details, DetailLine("Item ID", mount.itemID))
    end

    table.insert(details, DetailLine("Total Attempts", attempts))
    table.insert(details, "")
    table.insert(details, DetailLine("How to Obtain", mount.obtainMethod))
    table.insert(details, "")
    table.insert(details, DetailLine("Notes", mount.notes))

    return table.concat(details, "\n")
end

function Mounts:RefreshStats(mounts)
    if not self.statTexts then
        return
    end

    mounts = mounts or self:GetVisibleMounts()

    local total = #mounts
    local collected = 0

    for _, mount in ipairs(mounts) do
        local journalInfo = self:GetJournalInfo(mount)
        if journalInfo.collectedStatus == "Collected" then
            collected = collected + 1
        end
    end

    local missing = math.max(total - collected, 0)
    local completion = 0

    if total > 0 then
        completion = math.floor((collected / total) * 100 + 0.5)
    end

    self.statTexts.total:SetText(string.format("Total: %d", total))
    self.statTexts.collected:SetText(string.format("Collected: %d", collected))
    self.statTexts.missing:SetText(string.format("Missing: %d", missing))
    self.statTexts.completion:SetText(string.format("Completion: %d%%", completion))
end

function Mounts:UpdateDetailsTextWidth()
    if not self.detailsPanel or not self.detailsText or not self.detailsScrollChild then
        return
    end

    local panelWidth = self.detailsPanel:GetWidth() or DETAILS_MIN_WIDTH
    local textWidth = math.max(math.floor(panelWidth - 48), 160)

    self.detailsScrollChild:SetWidth(textWidth)
    self.detailsText:SetWidth(textWidth)
end

function Mounts:LayoutPanels()
    print("CollectionTracker: LayoutPanels")
    if not self.bodyFrame or not self.listPanel or not self.detailsPanel then
        return
    end

    local width = self.bodyFrame:GetWidth() or 0
    local height = self.bodyFrame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        return
    end

    local detailsWidth = math.floor(width * DETAILS_WIDTH_RATIO)
    local maxDetailsWidth = math.floor(width * 0.35)
    local availableDetailsWidth = width - LIST_MIN_WIDTH - PANEL_GUTTER

    detailsWidth = math.max(detailsWidth, DETAILS_MIN_WIDTH)
    detailsWidth = math.min(detailsWidth, maxDetailsWidth)

    if availableDetailsWidth > 0 then
        detailsWidth = math.min(detailsWidth, availableDetailsWidth)
    end

    local listWidth = width - detailsWidth - PANEL_GUTTER
    if listWidth < LIST_MIN_WIDTH and width > DETAILS_MIN_WIDTH + PANEL_GUTTER then
        detailsWidth = math.max(width - LIST_MIN_WIDTH - PANEL_GUTTER, DETAILS_MIN_WIDTH)
        listWidth = width - detailsWidth - PANEL_GUTTER
    end

    self.detailsPanel:ClearAllPoints()
    self.detailsPanel:SetPoint("TOPRIGHT", self.bodyFrame, "TOPRIGHT", 0, 0)
    self.detailsPanel:SetSize(math.max(detailsWidth, DETAILS_MIN_WIDTH), height)

    self.listPanel:ClearAllPoints()
    self.listPanel:SetPoint("TOPLEFT", self.bodyFrame, "TOPLEFT", 0, 0)
    self.listPanel:SetSize(math.max(listWidth, 1), height)

    self:ApplyListLayout()
    self:UpdateDetailsTextWidth()
    self:RefreshDetails()
end

function Mounts:RefreshDetails()
    if not self.detailsPanel then
        return
    end

    self:UpdateDetailsTextWidth()

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
    self.detailsStatus:SetText("Status: " .. journalInfo.collectedStatus)
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

    local mounts = self:GetVisibleMounts()

    self:RefreshStats(mounts)
    self:ApplyListLayout()

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

    self.scrollChild:SetSize(self.listInnerWidth or LIST_MIN_INNER_WIDTH, math.max(#mounts * ROW_HEIGHT, ROW_HEIGHT))
    self:ApplyListLayout()
    self:RefreshDetails()
end

function Mounts:CreateDetailsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
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
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    icon:SetSize(DETAIL_ICON_SIZE, DETAIL_ICON_SIZE)

    local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    name:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    status:SetJustifyH("LEFT")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -78)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 12)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(DETAILS_MIN_WIDTH - 48, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local detailText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    detailText:SetWidth(DETAILS_MIN_WIDTH - 48)
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

function Mounts:CreateStatsArea(parent)
    local statsFrame = CreateFrame("Frame", nil, parent)
    statsFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", OUTER_PADDING, -46)
    statsFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -OUTER_PADDING, -46)
    statsFrame:SetHeight(36)

    local statDefinitions = {
        { key = "total", x = 0 },
        { key = "collected", x = 120 },
        { key = "missing", x = 270 },
        { key = "completion", x = 410 },
    }

    self.statTexts = {}

    for _, stat in ipairs(statDefinitions) do
        local text = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", stat.x, 0)
        text:SetWidth(140)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        self.statTexts[stat.key] = text
    end

    return statsFrame
end

-- Creates the Mounts tab content.
function Mounts:CreateContent(parent)
    print("CollectionTracker: Mounts CreateContent")
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", OUTER_PADDING, -16)
    title:SetText("Mounts")

    local statsFrame = self:CreateStatsArea(parent)

    local bodyFrame = CreateFrame("Frame", nil, parent)
    bodyFrame:SetPoint("TOPLEFT", statsFrame, "BOTTOMLEFT", 0, -10)
    bodyFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -OUTER_PADDING, OUTER_PADDING)

    local listPanel = CreateFrame("Frame", nil, bodyFrame, "BackdropTemplate")
    listPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listPanel:SetBackdropColor(0.03, 0.03, 0.04, 0.25)
    listPanel:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.8)

    local header = CreateFrame("Frame", nil, listPanel)
    header:SetPoint("TOPLEFT", listPanel, "TOPLEFT", LIST_PANEL_PADDING, -LIST_PANEL_PADDING)
    header:SetSize(LIST_MIN_INNER_WIDTH, 18)
    self:CreateHeader(header)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, LIST_PANEL_PADDING)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(LIST_MIN_INNER_WIDTH, ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    local emptyText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -4)
    emptyText:SetText("No mount data loaded.")
    emptyText:Hide()

    self:CreateDetailsPanel(bodyFrame)

    self.rows = {}
    self.parent = parent
    self.bodyFrame = bodyFrame
    self.listPanel = listPanel
    self.header = header
    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.emptyText = emptyText

    bodyFrame:SetScript("OnSizeChanged", function()
        Mounts:LayoutPanels()
    end)
    parent:SetScript("OnShow", function()
        Mounts:LayoutPanels()
        Mounts:Refresh()

        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0, function()
                Mounts:LayoutPanels()
                Mounts:Refresh()
            end)
        end
    end)

    self:LayoutPanels()
    self:Refresh()
end
print("CollectionTracker: Mounts.lua loaded")
CollectionTracker:RegisterModule("mounts", Mounts)
