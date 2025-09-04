-- DialogKeyWrath: Preconfigured popup rules (auto-added on load if missing)

local addonName = "DialogKeyWrath"

-- Access saved DB via Core.lua helper if present, else fall back to global
local function DB()
    if _G.DialogKeyWrath and _G.DialogKeyWrath.DB then
        return _G.DialogKeyWrath.DB()
    end
    if _G.DialogKeyWrathFrame and _G.DialogKeyWrathFrame.DB then
        return _G.DialogKeyWrathFrame.DB()
    end
    return _G.DialogKeyWrathDB or {}
end

-- Re-add default rules whenever they are missing (users can disable them instead of deleting)
local function PreconfigureDefaultRules()
    local db = DB()
    if type(db) ~= "table" then return end
    db.popupRules = db.popupRules or {}
    local rules = db.popupRules

    local function norm(s)
        if not s then return "" end
        s = tostring(s)
        s = s:lower()
        s = s:gsub("^%s*(.-)%s*$", "%1") -- trim
        return s
    end

    -- Two defaults:
    -- - "Disabled Addons": match popup text containing "Disable AddOns" -> Action2 (Button2)
    -- - "Destroy Items": match popup text containing "Do you want to destroy" -> Action0 (Ignore)
    local defaultsToAdd = {
        { name = "Disable Addons", matchBy = "text", pattern = "Disable AddOns", action = 2, enabled = true },
        { name = "Destroy Items",   matchBy = "text", pattern = "Do you want to destroy", action = 0, enabled = true },
        { name = "Destroy Quest Items",   matchBy = "text", pattern = "needed for the quest", action = 0, enabled = true },
    }

    -- Build a set of existing rule names (normalized) to avoid duplicates
    local existingNames = {}
    for _, r in ipairs(rules) do
        if r and r.name then existingNames[norm(r.name)] = true end
    end

    local added = false
    for _, dr in ipairs(defaultsToAdd) do
        if not existingNames[norm(dr.name)] then
            table.insert(rules, {
                name    = dr.name,
                matchBy = dr.matchBy,     -- "text"
                pattern = dr.pattern,     -- substring (case-insensitive) match
                action  = dr.action,      -- 0=Ignore, 1=Button1, 2=Button2
                enabled = true,
            })
            added = true
        end
    end

    if added then
        db.popupRules = rules
        -- Silent install. If options panel is open, refresh it.
        local DK = _G[addonName.."Frame"] or _G.DialogKeyWrathFrame
        if DK and DK.optionsPanel and DK.optionsPanel.RefreshRulesUI then
            pcall(DK.optionsPanel.RefreshRulesUI, DK.optionsPanel)
        end
    end
end

-- Export (optional)
local DK = _G[addonName.."Frame"] or _G.DialogKeyWrathFrame
if DK then DK.PreconfigureDefaultRules = PreconfigureDefaultRules end

-- Self-initialize on ADDON_LOADED for this addon
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        pcall(PreconfigureDefaultRules)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
