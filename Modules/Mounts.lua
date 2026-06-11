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
local FILTER_CONTROLS_HEIGHT = 166
local COLLECTION_CHECK_DELAY = 2

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

local STATUS_FILTERS = {
    { key = "all", label = "All" },
    { key = "collected", label = "Collected only" },
    { key = "missing", label = "Missing only" },
}

local SOURCE_TYPE_OPTIONS = {
    "Raid",
    "Dungeon",
    "World Boss",
    "Rare",
    "Achievement",
    "Reputation",
    "Vendor",
    "Profession",
    "Quest",
    "Event",
    "Trading Post",
    "Other",
}

local SOURCE_TYPE_SORT_ORDER = {}
for index, sourceType in ipairs(SOURCE_TYPE_OPTIONS) do
    SOURCE_TYPE_SORT_ORDER[sourceType] = index
end

local SORT_OPTIONS = {
    { key = "nameAsc", label = "Name A-Z" },
    { key = "nameDesc", label = "Name Z-A" },
    { key = "expansion", label = "Expansion" },
    { key = "sourceType", label = "Source Type" },
    { key = "dropAsc", label = "Drop Chance Low" },
    { key = "dropDesc", label = "Drop Chance High" },
    { key = "attemptsAsc", label = "Attempts Low" },
    { key = "attemptsDesc", label = "Attempts High" },
    { key = "status", label = "Collected/Missing" },
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

local function CompareText(left, right)
    left = string.lower(DisplayText(left))
    right = string.lower(DisplayText(right))

    if left == right then
        return nil
    end

    return left < right
end

local function CompareByNameThenID(left, right)
    local comparison = CompareText(left and left.name, right and right.name)
    if comparison ~= nil then
        return comparison
    end

    return (tonumber(left and left.mountID) or 0) < (tonumber(right and right.mountID) or 0)
end

local function CreateFilterLabel(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 80)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)

    return label
end

local function CreateFilterButton(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width or 72, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)

    return button
end

local function CreateFilterCheckbox(parent, text, x, y, width, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox:SetSize(18, 18)
    checkbox:SetScript("OnClick", onClick)

    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    label:SetWidth(width or 100)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    checkbox.label = label

    return checkbox
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

function Mounts:GetCharacterKey()
    local characterName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"

    return string.format("%s-%s", realmName, characterName)
end

function Mounts:EnsureAttemptDB()
    CollectionTrackerDB = CollectionTrackerDB or {}
    CollectionTracker.db = CollectionTracker.db or CollectionTrackerDB

    if type(CollectionTracker.db.mountAttempts) ~= "table" then
        CollectionTracker.db.mountAttempts = {}
    end

    return CollectionTracker.db.mountAttempts
end

function Mounts:GetAttemptRecord(mount)
    if type(mount) ~= "table" or not mount.mountID then
        return nil
    end

    local mountAttempts = self:EnsureAttemptDB()
    local mountID = mount.mountID
    local record = mountAttempts[mountID]

    if type(record) == "number" then
        record = {
            totalAttempts = record,
            attemptsByCharacter = {},
            lastAttemptDate = nil,
            lastAttemptCharacter = nil,
            collected = false,
            collectedDate = nil,
            collectedCharacter = nil,
            collectedAtAttempt = nil,
        }
        mountAttempts[mountID] = record
    elseif type(record) ~= "table" then
        record = {
            totalAttempts = 0,
            attemptsByCharacter = {},
            lastAttemptDate = nil,
            lastAttemptCharacter = nil,
            collected = false,
            collectedDate = nil,
            collectedCharacter = nil,
            collectedAtAttempt = nil,
        }
        mountAttempts[mountID] = record
    end

    if type(record.attemptsByCharacter) ~= "table" then
        if type(record.characters) == "table" then
            record.attemptsByCharacter = record.characters
            record.characters = nil
        else
            record.attemptsByCharacter = {}
        end
    end

    record.totalAttempts = tonumber(record.totalAttempts) or 0

    return record
end

function Mounts:GetTotalAttempts(mount)
    if type(mount) ~= "table" then
        return 0
    end

    local db = CollectionTracker.db or CollectionTrackerDB
    local mountAttempts = db and db.mountAttempts

    if type(mountAttempts) == "table" and mount.mountID then
        local record = mountAttempts[mount.mountID]

        if type(record) == "number" then
            return record
        end

        if type(record) == "table" then
            return tonumber(record.totalAttempts) or 0
        end
    end

    return tonumber(mount.totalAttempts) or 0
end

function Mounts:GetMountsByEncounterID(encounterID)
    local normalizedEncounterID = tonumber(encounterID)
    local matches = {}

    if not normalizedEncounterID then
        return matches
    end

    for _, mount in ipairs(self:GetMounts()) do
        if tonumber(mount.encounterID) == normalizedEncounterID then
            table.insert(matches, mount)
        end
    end

    return matches
end

function Mounts:GetMountByID(mountID)
    local normalizedMountID = tonumber(mountID)

    if not normalizedMountID then
        return nil
    end

    for _, mount in ipairs(self:GetMounts()) do
        if tonumber(mount.mountID) == normalizedMountID then
            return mount
        end
    end

    return nil
end

function Mounts:AddAttempt(mount, options)
    options = options or {}

    if type(mount) ~= "table" or not mount.mountID then
        return false, 0, "invalid mount"
    end

    local journalInfo = self:GetJournalInfo(mount)
    local record = self:GetAttemptRecord(mount)

    if not record then
        return false, self:GetTotalAttempts(mount), "attempt record unavailable"
    end

    if record.collected == true or journalInfo.collectedStatus == "Collected" then
        if not options.suppressSkipMessage then
            print(string.format("|cff33ff99CollectionTracker:|r %s is already collected. Attempt not added.", DisplayText(mount.name)))
        end

        return false, record.totalAttempts, "already collected"
    end

    local characterKey = self:GetCharacterKey()

    record.totalAttempts = (tonumber(record.totalAttempts) or 0) + 1
    record.attemptsByCharacter[characterKey] = (tonumber(record.attemptsByCharacter[characterKey]) or 0) + 1
    record.lastAttemptDate = time()
    record.lastAttemptCharacter = characterKey

    if options.selectMount ~= false then
        self.selectedMount = mount
    end

    self:Refresh()

    return true, record.totalAttempts
end

function Mounts:MarkMountCollected(mount, collectedAtAttempt)
    local record = self:GetAttemptRecord(mount)

    if not record or record.collected == true then
        return false
    end

    local journalInfo = self:GetJournalInfo(mount)
    if journalInfo.collectedStatus ~= "Collected" then
        return false
    end

    record.collected = true
    record.collectedDate = time()
    record.collectedCharacter = self:GetCharacterKey()
    record.collectedAtAttempt = tonumber(collectedAtAttempt) or tonumber(record.totalAttempts) or 0

    self:Refresh()

    print("[CollectionTracker]")
    print("Congratulations!")
    print(string.format("%s collected after %d attempts.", DisplayText(mount.name), record.collectedAtAttempt))

    return true
end

function Mounts:ScheduleCollectionCheck(mount, collectedAtAttempt)
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        print(string.format("[CollectionTracker] Debug: collection check skipped for %s (timer API unavailable).", DisplayText(mount and mount.name)))
        return
    end

    local mountID = mount and mount.mountID

    C_Timer.After(COLLECTION_CHECK_DELAY, function()
        local currentMount = Mounts:GetMountByID(mountID)

        if currentMount then
            Mounts:MarkMountCollected(currentMount, collectedAtAttempt)
        end
    end)
end

function Mounts:HandleEncounterEnd(encounterID, success)
    print(string.format("[CollectionTracker] Debug: encounterID: %s", tostring(encounterID)))

    if success ~= 1 and success ~= true then
        print(string.format("[CollectionTracker] Debug: attempt skipped for encounterID %s (encounter was not successful).", tostring(encounterID)))
        return
    end

    local matchingMounts = self:GetMountsByEncounterID(encounterID)

    if #matchingMounts == 0 then
        print(string.format("[CollectionTracker] Debug: attempt skipped for encounterID %s (no matching mount).", tostring(encounterID)))
        return
    end

    for _, mount in ipairs(matchingMounts) do
        local mountName = DisplayText(mount.name)
        print(string.format("[CollectionTracker] Debug: matched mount: %s", mountName))

        local added, totalAttempts, skipReason = self:AddAttempt(mount, {
            selectMount = false,
            suppressSkipMessage = true,
        })

        if added then
            print("[CollectionTracker]")
            print(string.format("Attempt added for %s.", mountName))
            print(string.format("Total attempts: %d", totalAttempts))
            self:ScheduleCollectionCheck(mount, totalAttempts)
        else
            print(string.format("[CollectionTracker] Debug: attempt skipped for %s (%s).", mountName, skipReason or "unknown reason"))
        end
    end
end

function Mounts:HandleAddAttemptCommand(arguments)
    local mountID = tonumber(string.match(arguments or "", "^%s*(%d+)%s*$"))

    if not mountID then
        print("[CollectionTracker] Usage: /ct addattempt <mountID>")
        return
    end

    local mount = self:GetMountByID(mountID)

    if not mount then
        print(string.format("[CollectionTracker] No mount found with mountID %d.", mountID))
        return
    end

    local mountName = DisplayText(mount.name)
    local added, totalAttempts, skipReason = self:AddAttempt(mount, {
        selectMount = false,
        suppressSkipMessage = true,
    })

    if added then
        print(string.format("[CollectionTracker] Test attempt added for %s.", mountName))
        print(string.format("Total attempts: %d", totalAttempts))
    else
        print(string.format("[CollectionTracker] Test attempt skipped for %s (%s).", mountName, skipReason or "unknown reason"))
    end
end

function Mounts:SetStatusColor(fontString, status)
    local color = STATUS_COLORS[status] or STATUS_COLORS.Unknown
    fontString:SetTextColor(color[1], color[2], color[3], 1)
end

function Mounts:GetSourceTypeOptions()
    return SOURCE_TYPE_OPTIONS
end

function Mounts:GetExpansionOptions()
    local expansionMap = {}
    local expansions = {}

    for _, mount in ipairs(self:GetMounts()) do
        if mount.expansion and mount.expansion ~= "" and not expansionMap[mount.expansion] then
            expansionMap[mount.expansion] = {
                name = mount.expansion,
                expansionOrder = tonumber(mount.expansionOrder) or 999,
            }
            table.insert(expansions, expansionMap[mount.expansion])
        elseif mount.expansion and expansionMap[mount.expansion] then
            local order = tonumber(mount.expansionOrder)
            if order and order < expansionMap[mount.expansion].expansionOrder then
                expansionMap[mount.expansion].expansionOrder = order
            end
        end
    end

    table.sort(expansions, function(left, right)
        if left.expansionOrder == right.expansionOrder then
            return left.name < right.name
        end

        return left.expansionOrder < right.expansionOrder
    end)

    return expansions
end

function Mounts:EnsureFilterState()
    if type(self.filters) ~= "table" then
        self.filters = {
            status = "all",
            sourceTypes = {},
            expansions = {},
        }
    end

    if type(self.filters.sourceTypes) ~= "table" then
        self.filters.sourceTypes = {}
    end

    if type(self.filters.expansions) ~= "table" then
        self.filters.expansions = {}
    end

    for _, sourceType in ipairs(self:GetSourceTypeOptions()) do
        if self.filters.sourceTypes[sourceType] == nil then
            self.filters.sourceTypes[sourceType] = true
        end
    end

    for _, expansion in ipairs(self:GetExpansionOptions()) do
        if self.filters.expansions[expansion.name] == nil then
            self.filters.expansions[expansion.name] = true
        end
    end

    self.sortKey = self.sortKey or SORT_OPTIONS[1].key
end

function Mounts:GetSortOption()
    self:EnsureFilterState()

    for index, option in ipairs(SORT_OPTIONS) do
        if option.key == self.sortKey then
            return option, index
        end
    end

    self.sortKey = SORT_OPTIONS[1].key
    return SORT_OPTIONS[1], 1
end

function Mounts:CycleSortOption()
    local _, index = self:GetSortOption()
    index = index + 1

    if index > #SORT_OPTIONS then
        index = 1
    end

    self.sortKey = SORT_OPTIONS[index].key
    self:Refresh()
end

function Mounts:SetStatusFilter(status)
    self:EnsureFilterState()
    self.filters.status = status or "all"
    self:Refresh()
end

function Mounts:SetSourceTypeFilter(sourceType, enabled)
    self:EnsureFilterState()
    self.filters.sourceTypes[sourceType] = enabled and true or false
    self:Refresh()
end

function Mounts:SetExpansionFilter(expansion, enabled)
    self:EnsureFilterState()
    self.filters.expansions[expansion] = enabled and true or false
    self:Refresh()
end

function Mounts:MountPassesFilters(mount)
    self:EnsureFilterState()
    mount = mount or {}

    local status = self:GetJournalInfo(mount).collectedStatus
    if self.filters.status == "collected" and status ~= "Collected" then
        return false
    end

    if self.filters.status == "missing" and status ~= "Missing" then
        return false
    end

    if mount.sourceType and self.filters.sourceTypes[mount.sourceType] == false then
        return false
    end

    if mount.expansion and self.filters.expansions[mount.expansion] == false then
        return false
    end

    return true
end

function Mounts:CompareByDropChance(left, right, descending)
    local leftDrop = tonumber(left.dropChance)
    local rightDrop = tonumber(right.dropChance)

    if leftDrop and rightDrop then
        if leftDrop == rightDrop then
            return CompareByNameThenID(left, right)
        end

        if descending then
            return leftDrop > rightDrop
        end

        return leftDrop < rightDrop
    end

    if leftDrop then
        return true
    end

    if rightDrop then
        return false
    end

    return CompareByNameThenID(left, right)
end

function Mounts:CompareMounts(left, right)
    local sortKey = (self:GetSortOption()).key

    if sortKey == "nameDesc" then
        local comparison = CompareText(left.name, right.name)
        if comparison ~= nil then
            return not comparison
        end
    elseif sortKey == "expansion" then
        local leftOrder = tonumber(left.expansionOrder) or 999
        local rightOrder = tonumber(right.expansionOrder) or 999

        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
    elseif sortKey == "sourceType" then
        local leftOrder = SOURCE_TYPE_SORT_ORDER[left.sourceType] or 999
        local rightOrder = SOURCE_TYPE_SORT_ORDER[right.sourceType] or 999

        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
    elseif sortKey == "dropAsc" then
        return self:CompareByDropChance(left, right, false)
    elseif sortKey == "dropDesc" then
        return self:CompareByDropChance(left, right, true)
    elseif sortKey == "attemptsAsc" or sortKey == "attemptsDesc" then
        local leftAttempts = self:GetTotalAttempts(left)
        local rightAttempts = self:GetTotalAttempts(right)

        if leftAttempts ~= rightAttempts then
            if sortKey == "attemptsDesc" then
                return leftAttempts > rightAttempts
            end

            return leftAttempts < rightAttempts
        end
    elseif sortKey == "status" then
        local statusOrder = {
            Collected = 1,
            Missing = 2,
            Unknown = 3,
        }
        local leftStatus = statusOrder[self:GetJournalInfo(left).collectedStatus] or 3
        local rightStatus = statusOrder[self:GetJournalInfo(right).collectedStatus] or 3

        if leftStatus ~= rightStatus then
            return leftStatus < rightStatus
        end
    else
        local comparison = CompareText(left.name, right.name)
        if comparison ~= nil then
            return comparison
        end
    end

    local nameComparison = CompareText(left.name, right.name)
    if nameComparison ~= nil then
        return nameComparison
    end

    return CompareByNameThenID(left, right)
end

function Mounts:GetVisibleMounts()
    self:EnsureFilterState()

    local visibleMounts = {}

    for _, mount in ipairs(self:GetMounts()) do
        if self:MountPassesFilters(mount) then
            table.insert(visibleMounts, mount)
        end
    end

    table.sort(visibleMounts, function(left, right)
        return Mounts:CompareMounts(left, right)
    end)

    return visibleMounts
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
    local missing = 0

    for _, mount in ipairs(mounts) do
        local journalInfo = self:GetJournalInfo(mount)
        if journalInfo.collectedStatus == "Collected" then
            collected = collected + 1
        elseif journalInfo.collectedStatus == "Missing" then
            missing = missing + 1
        end
    end

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
    local selectedMountVisible = false

    for _, mount in ipairs(mounts) do
        if mount == self.selectedMount then
            selectedMountVisible = true
            break
        end
    end

    if self.selectedMount and not selectedMountVisible then
        self.selectedMount = nil
    end

    self:UpdateFilterControls()
    self:RefreshStats(mounts)
    self:ApplyListLayout()

    if self.emptyText then
        if #mounts == 0 then
            self.emptyText:SetText("No mounts match current filters.")
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

function Mounts:UpdateFilterControls()
    self:EnsureFilterState()

    if self.statusButtons then
        for key, button in pairs(self.statusButtons) do
            if key == self.filters.status then
                button:SetButtonState("PUSHED", true)
                button:LockHighlight()
            else
                button:SetButtonState("NORMAL", false)
                button:UnlockHighlight()
            end
        end
    end

    if self.sourceTypeCheckboxes then
        for sourceType, checkbox in pairs(self.sourceTypeCheckboxes) do
            checkbox:SetChecked(self.filters.sourceTypes[sourceType] ~= false)
        end
    end

    if self.expansionCheckboxes then
        for expansion, checkbox in pairs(self.expansionCheckboxes) do
            checkbox:SetChecked(self.filters.expansions[expansion] ~= false)
        end
    end

    if self.sortButton then
        local sortOption = self:GetSortOption()
        self.sortButton:SetText("Sort: " .. sortOption.label)
    end
end

function Mounts:CreateFilterControls(parent)
    self:EnsureFilterState()

    local expansions = self:GetExpansionOptions()
    local expansionRows = math.max(1, math.ceil(#expansions / 4))
    local controlsHeight = math.max(FILTER_CONTROLS_HEIGHT, 110 + (expansionRows * 20))

    local controlsFrame = CreateFrame("Frame", nil, parent)
    controlsFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_PANEL_PADDING, -LIST_PANEL_PADDING)
    controlsFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -LIST_PANEL_PADDING, -LIST_PANEL_PADDING)
    controlsFrame:SetHeight(controlsHeight)

    self.statusButtons = {}
    self.sourceTypeCheckboxes = {}
    self.expansionCheckboxes = {}

    CreateFilterLabel(controlsFrame, "Status", 0, 0, 46)

    local statusX = 50
    for _, status in ipairs(STATUS_FILTERS) do
        local statusKey = status.key
        local button = CreateFilterButton(controlsFrame, status.label, statusX, 2, statusKey == "all" and 42 or 92, function()
            Mounts:SetStatusFilter(statusKey)
        end)

        self.statusButtons[statusKey] = button
        statusX = statusX + (statusKey == "all" and 48 or 98)
    end

    local sortButton = CreateFilterButton(controlsFrame, "Sort: Name A-Z", 300, 2, 178, function()
        Mounts:CycleSortOption()
    end)
    self.sortButton = sortButton

    CreateFilterLabel(controlsFrame, "Source", 0, -28, 54)

    local sourceColumnWidth = 116
    local sourceStartX = 60
    local sourceStartY = -26
    for index, sourceType in ipairs(self:GetSourceTypeOptions()) do
        local sourceTypeKey = sourceType
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        local checkbox = CreateFilterCheckbox(controlsFrame, sourceTypeKey, sourceStartX + (column * sourceColumnWidth), sourceStartY - (row * 20), sourceColumnWidth - 24, function(button)
            Mounts:SetSourceTypeFilter(sourceTypeKey, button:GetChecked())
        end)

        self.sourceTypeCheckboxes[sourceTypeKey] = checkbox
    end

    CreateFilterLabel(controlsFrame, "Expansion", 0, -88, 74)

    local expansionColumnWidth = 128
    local expansionStartY = -106
    for index, expansion in ipairs(expansions) do
        local expansionName = expansion.name
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        local checkbox = CreateFilterCheckbox(controlsFrame, expansionName, column * expansionColumnWidth, expansionStartY - (row * 20), expansionColumnWidth - 24, function(button)
            Mounts:SetExpansionFilter(expansionName, button:GetChecked())
        end)

        self.expansionCheckboxes[expansionName] = checkbox
    end

    self:UpdateFilterControls()

    return controlsFrame
end

-- Creates the Mounts tab content.
function Mounts:CreateContent(parent)
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

    local controlsFrame = self:CreateFilterControls(listPanel)

    local header = CreateFrame("Frame", nil, listPanel)
    header:SetPoint("TOPLEFT", controlsFrame, "BOTTOMLEFT", 0, -6)
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
    self.controlsFrame = controlsFrame
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

local encounterEventFrame = CreateFrame("Frame")
encounterEventFrame:RegisterEvent("ENCOUNTER_END")
encounterEventFrame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, groupSize, success)
    if event == "ENCOUNTER_END" then
        Mounts:HandleEncounterEnd(encounterID, success)
    end
end)

CollectionTracker:RegisterModule("mounts", Mounts)
