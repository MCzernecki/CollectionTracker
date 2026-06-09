local addonName, CollectionTracker = ...

-- Expose the addon table for debugging and for future extension.
_G.CollectionTracker = CollectionTracker

CollectionTracker.addonName = addonName
CollectionTracker.version = "0.1.0"
CollectionTracker.modules = CollectionTracker.modules or {}
CollectionTracker.moduleOrder = CollectionTracker.moduleOrder or {}

-- SavedVariables defaults. More settings can be added here later.
CollectionTracker.defaults = {
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

-- Copies missing values from defaults without overwriting saved user settings.
function CollectionTracker:ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            self:ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Registers a tab module. Modules stay intentionally small and self-contained.
function CollectionTracker:RegisterModule(key, module)
    if not key or type(module) ~= "table" then
        return
    end

    module.key = key
    self.modules[key] = module
    table.insert(self.moduleOrder, key)
end

-- Returns registered modules in load order for future module-driven features.
function CollectionTracker:GetModulesInOrder()
    local orderedModules = {}

    for _, key in ipairs(self.moduleOrder) do
        table.insert(orderedModules, self.modules[key])
    end

    return orderedModules
end

-- Slash command entry point. UI.lua supplies the actual frame implementation.
function CollectionTracker:ToggleMainWindow()
    if self.UI and self.UI.ToggleMainWindow then
        self.UI:ToggleMainWindow()
    else
        print("|cff33ff99CollectionTracker:|r UI is not ready yet.")
    end
end

SLASH_COLLECTIONTRACKER1 = "/ct"
SlashCmdList.COLLECTIONTRACKER = function()
    CollectionTracker:ToggleMainWindow()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    -- Initialize SavedVariables once the addon is loaded.
    CollectionTrackerDB = CollectionTrackerDB or {}
    CollectionTracker.db = CollectionTrackerDB
    CollectionTracker:ApplyDefaults(CollectionTracker.db, CollectionTracker.defaults)
end)
