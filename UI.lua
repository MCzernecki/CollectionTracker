local _, CollectionTracker = ...

local UI = {}
CollectionTracker.UI = UI

local TAB_DEFINITIONS = {
    { key = "gold", title = "Gold" },
    { key = "mounts", title = "Mounts" },
    { key = "pets", title = "Pets" },
    { key = "toys", title = "Toys" },
    { key = "transmog", title = "Transmog" },
}

local MIN_WINDOW_WIDTH = 900
local MIN_WINDOW_HEIGHT = 550

local function SetSolidTexture(texture, red, green, blue, alpha)
    if texture.SetColorTexture then
        texture:SetColorTexture(red, green, blue, alpha)
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(red, green, blue, alpha)
    end
end

function UI:ClampWindowSize()
    if not self.frame then
        return
    end

    local width, height = self.frame:GetSize()
    local clampedWidth = math.max(width or MIN_WINDOW_WIDTH, MIN_WINDOW_WIDTH)
    local clampedHeight = math.max(height or MIN_WINDOW_HEIGHT, MIN_WINDOW_HEIGHT)

    if clampedWidth ~= width or clampedHeight ~= height then
        self.frame:SetSize(clampedWidth, clampedHeight)
    end
end

function UI:RestoreSize()
    if not self.frame or not CollectionTracker.db then
        return
    end

    local window = CollectionTracker.db.window
    local width = math.max(tonumber(window.width) or MIN_WINDOW_WIDTH, MIN_WINDOW_WIDTH)
    local height = math.max(tonumber(window.height) or MIN_WINDOW_HEIGHT, MIN_WINDOW_HEIGHT)

    self.frame:SetSize(width, height)
end

function UI:SaveSize()
    if not self.frame or not CollectionTracker.db then
        return
    end

    local width, height = self.frame:GetSize()

    CollectionTracker.db.window.width = math.max(math.floor((width or MIN_WINDOW_WIDTH) + 0.5), MIN_WINDOW_WIDTH)
    CollectionTracker.db.window.height = math.max(math.floor((height or MIN_WINDOW_HEIGHT) + 0.5), MIN_WINDOW_HEIGHT)
end

-- Restores the frame position saved in CollectionTrackerDB.
function UI:RestorePosition()
    if not self.frame or not CollectionTracker.db then
        return
    end

    local window = CollectionTracker.db.window

    self.frame:ClearAllPoints()
    self.frame:SetPoint(window.point, UIParent, window.relativePoint, window.x, window.y)
end

-- Saves the frame position after dragging ends.
function UI:SavePosition()
    if not self.frame or not CollectionTracker.db then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)

    CollectionTracker.db.window.point = point or "CENTER"
    CollectionTracker.db.window.relativePoint = relativePoint or "CENTER"
    CollectionTracker.db.window.x = x or 0
    CollectionTracker.db.window.y = y or 0
end

-- Builds a simple content panel for a tab and lets its module populate it.
function UI:CreateTabContent(key)
    local content = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -82)
    content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 16)
    content:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    content:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    content:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    content:Hide()

    local module = CollectionTracker.modules[key]

    if module and module.CreateContent then
        module:CreateContent(content)
    end

    self.contentFrames[key] = content
end

-- Switches visible tab content and updates button states.
function UI:SelectTab(key)
    for tabKey, content in pairs(self.contentFrames) do
        content:SetShown(tabKey == key)
    end

    for tabKey, button in pairs(self.tabButtons) do
        if tabKey == key then
            button:SetButtonState("PUSHED", true)
            button:LockHighlight()
        else
            button:SetButtonState("NORMAL", false)
            button:UnlockHighlight()
        end
    end

    self.selectedTab = key
end

-- Creates the movable main window and its tab buttons.
function UI:CreateMainWindow()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "CollectionTrackerMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    if frame.SetResizable then
        frame:SetResizable(true)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.1, 0.98)
    frame:Hide()

    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    self.frame = frame
    self.tabButtons = {}
    self.contentFrames = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText("CollectionTracker")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -6, -6)

    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    resizeButton:SetSize(16, 16)
    resizeButton:EnableMouse(true)

    local resizeTexture = resizeButton:CreateTexture(nil, "OVERLAY")
    resizeTexture:SetAllPoints(resizeButton)
    SetSolidTexture(resizeTexture, 1, 1, 1, 0.18)

    local resizeHighlight = resizeButton:CreateTexture(nil, "HIGHLIGHT")
    resizeHighlight:SetAllPoints(resizeButton)
    SetSolidTexture(resizeHighlight, 1, 0.82, 0, 0.25)

    resizeButton:SetScript("OnMouseDown", function()
        if frame.StartSizing then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeButton:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:ClampWindowSize()
        self:SaveSize()
        self:SavePosition()
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
    end)

    for index, tab in ipairs(TAB_DEFINITIONS) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(126, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + ((index - 1) * 132), -48)
        button:SetText(tab.title)
        button:SetScript("OnClick", function()
            if self.selectedTab ~= tab.key then
                self:SelectTab(tab.key)
            end
        end)

        self.tabButtons[tab.key] = button
        self:CreateTabContent(tab.key)
    end

    self:RestoreSize()
    self:RestorePosition()
    self:SelectTab("gold")

    return frame
end

-- Opens the main window if hidden, or closes it if already visible.
function UI:ToggleMainWindow()
    local frame = self:CreateMainWindow()

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
