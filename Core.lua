-- DialogKeyWrath: Keyboard controls for dialogs (Wrath 3.3.5a)
-- Core: orchestrator (SavedVariables, bindings, wheel, popup rules, events). UI numbering in Dialogs.lua. Rewards overlays/tooltips/binds in Rewards.lua.

local addonName = "DialogKeyWrath"
local DK = CreateFrame("Frame", addonName.."Frame", UIParent)

-- SavedVariables table (declared in .toc)
if type(DialogKeyWrathDB) ~= "table" then DialogKeyWrathDB = {} end

-- Defaults persisted in DialogKeyWrathDB
local defaults = {
    detectElvUI = true,
    allowNumPadKeys = false,
    showNumbers = true,
    popupRules = {},
    popupButtonSelection = false,
    usePostalOpenAll = true,
    -- Wheel selection (opt-in)
    scrollWheelSelect = false,
    -- Popup whitelist mode and master disable
    popupWhitelistMode = false,          -- only handle popups that match a rule
    disablePopupInteractions = false,    -- ignore all popups (overrides whitelist/rules)
    -- Quest rewards tooltip settings
    rewardTooltipOnSelect = true,        -- show tooltip for selected reward
    compareTooltips = false,             -- also show comparison tooltips
}

-- Merge defaults into saved table
for k, v in pairs(defaults) do
    if DialogKeyWrathDB[k] == nil then DialogKeyWrathDB[k] = v end
end

-- Saved DB accessor
local function DB() return DialogKeyWrathDB end

-- Expose DB/defaults
DK.DB = DB
DK.defaults = defaults

-- Back-compat passthrough (DK.settings.<key>)
DK.settings = DK.settings or {}
setmetatable(DK.settings, {
    __index = function(_, key) return DB()[key] end,
    __newindex = function(_, key, val) DB()[key] = val end,
})

-- Trim helper (WotLK compat)
if not string.trim then
    function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
end

-- Internal handler frame & fallback macro button (for SPACE)
local handler = CreateFrame("Frame", addonName.."OverrideFrame", UIParent)
DK._bindingOwner = handler -- expose for modules

local spaceBtn = CreateFrame("Button", addonName.."SpaceButton", UIParent, "SecureActionButtonTemplate")
spaceBtn:SetAttribute("type", "macro")
spaceBtn:SetAttribute("macrotext",
    "/click QuestFrameAcceptButton\n" ..
    "/click QuestFrameCompleteButton\n" ..
    "/click QuestFrameCompleteQuestButton\n" ..
    "/click QuestTitleButton1\n" ..
    "/click GossipTitleButton1"
)

-- Highlight state and flags
local spaceHighlight
local manualHighlights = {}
local overridesActive = false
DK._selectedReward = nil

-- Popup selection state
DK.popupNumTargets = {}
DK.numSelectButtons = {}
DK._popupSelectedButton = nil

-- Wheel selection state
DK._scrollSelectedButton = nil
DK._scrollIndex = nil
DK._wheelUsed = false   -- becomes true only after actual scroll wheel usage

-- List targeting memory (guards priority across transient UI changes)
DK._lastBestListTarget = nil

-- Combat gating
DK._inCombat = false
DK._pendingEnable = false

-- Track tooltip target for quest rewards (used by Rewards.lua too)
DK._rewardTooltipBtn = nil

-- -----------------------
-- Shared UI helpers (exported for modules)
-- -----------------------
local function SafeGetFontString(btn)
    if not btn then return nil end
    if btn.GetFontString then return btn:GetFontString() end
    for i = 1, 20 do
        local r = select(i, btn:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
            return r
        end
    end
    return nil
end

local function ApplyHighlight(btn)
    if not btn then return end
    if btn.LockHighlight then
        btn:LockHighlight()
    elseif btn.GetHighlightTexture then
        local tex = btn:GetHighlightTexture()
        if tex then tex:Show() end
    end
end

local function RemoveHighlight(btn)
    if not btn then return end
    if btn.UnlockHighlight then
        btn:UnlockHighlight()
    elseif btn.GetHighlightTexture then
        local tex = btn:GetHighlightTexture()
        if tex then tex:Hide() end
    end
end

local function RestoreOriginalText(btn)
    local fs = SafeGetFontString(btn)
    if fs and btn and btn.dkOrigText then
        fs:SetText(btn.dkOrigText)
        if btn.dkOrigColor then pcall(fs.SetTextColor, fs, unpack(btn.dkOrigColor)) end
    end
    btn.dkOrigText = nil
    btn.dkOrigColor = nil
end

DK.Util = {
    SafeGetFontString = SafeGetFontString,
    ApplyHighlight = ApplyHighlight,
    RemoveHighlight = RemoveHighlight,
    RestoreOriginalText = RestoreOriginalText,
}

local function HighlightSpaceButton(btn)
    if spaceHighlight and spaceHighlight ~= btn then RemoveHighlight(spaceHighlight) end
    if btn then ApplyHighlight(btn) end
    spaceHighlight = btn
end

local function ClearSpaceHighlight()
    if spaceHighlight then RemoveHighlight(spaceHighlight) end
    spaceHighlight = nil
end

local function ClearAllButtonHighlights()
    for i = 1, 10 do local b = _G["QuestTitleButton"..i] if b then RemoveHighlight(b) end end
    for i = 1, 32 do local b = _G["GossipTitleButton"..i] if b then RemoveHighlight(b) end end
    for _, b in pairs({ QuestFrameAcceptButton, QuestFrameCompleteButton, QuestFrameCompleteQuestButton }) do if b then RemoveHighlight(b) end end
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp then for j = 1, 4 do local btn = sp["button"..j] if btn then RemoveHighlight(btn) end end end
    end
    if PostalOpenAllButton then RemoveHighlight(PostalOpenAllButton) end
    for i = 1, 10 do local b = _G["QuestInfoItem"..i] if b then RemoveHighlight(b) end end
    DK._selectedReward = nil
    DK._popupSelectedButton = nil
end

local function ClearStaticPopupHighlights()
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then
            for j = 1, 4 do local b = sp["button"..j] if b then RemoveHighlight(b) end end
        end
    end
end

-- Strong selection overlay for popup selection
local function EnsureSelOverlay(btn)
    if not btn then return end
    if btn.dkSelFrame and btn.dkSelTex then return end
    local f = CreateFrame("Frame", nil, btn)
    f:SetAllPoints(btn)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(1000)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(f)
    t:SetTexture(1, 1, 1)
    t:SetBlendMode("ADD")
    t:SetAlpha(0.20)
    t:SetVertexColor(1, 1, 0)
    btn.dkSelFrame = f
    btn.dkSelTex = t
    f:Hide()
end

local function ShowSelectionOverlay(btn)
    if not btn then return end
    EnsureSelOverlay(btn)
    ApplyHighlight(btn)
    if btn.dkSelFrame then btn.dkSelFrame:Show() end
end

local function HideSelectionOverlay(btn)
    if not btn then return end
    if btn.dkSelFrame then btn.dkSelFrame:Hide() end
    RemoveHighlight(btn)
end

-- -----------------------
-- Popup rules subsystem (unchanged behavior)
-- -----------------------
if type(DB().popupRules) ~= "table" then DB().popupRules = {} end

local function AddPopupRule(matchBy, pattern, action)
    if not matchBy or not pattern then return false, "missing parameters" end
    matchBy = tostring(matchBy)
    if matchBy ~= "text" and matchBy ~= "frame" then return false, "matchBy must be 'text' or 'frame'" end
    action = tonumber(action) or 0
    if action < 0 or action > 4 then action = 0 end
    local rules = DB().popupRules or {}
    table.insert(rules, { matchBy = matchBy, pattern = tostring(pattern), action = action, enabled = true })
    DB().popupRules = rules
    if DK.optionsPanel and DK.optionsPanel.RefreshRulesUI then DK.optionsPanel:RefreshRulesUI() end
    return true
end

local function RemovePopupRule(idx)
    idx = tonumber(idx)
    local rules = DB().popupRules or {}
    if not idx or idx < 1 or idx > #rules then return false end
    table.remove(rules, idx)
    DB().popupRules = rules
    if DK.optionsPanel and DK.optionsPanel.RefreshRulesUI then DK.optionsPanel:RefreshRulesUI() end
    DEFAULT_CHAT_FRAME:AddMessage(addonName..": popup rule removed")
    return true
end

local function ListPopupRules()
    local out = {}
    for i, r in ipairs(DB().popupRules or {}) do
        out[#out+1] = string.format("%d) [%s] %s => action=%d %s", i, r.matchBy, r.pattern, r.action, r.enabled and "" or "(disabled)")
    end
    return out
end

-- Robust button label text retrieval
local function GetButtonLabelText(btn)
    if not btn then return nil end
    if btn.GetText then
        local ok, t = pcall(btn.GetText, btn)
        if ok and t and t ~= "" then return t end
    end
    if btn.Text and btn.Text.GetText then
        local ok, t = pcall(btn.Text.GetText, btn.Text)
        if ok and t and t ~= "" then return t end
    end
    local n = btn.GetName and btn:GetName()
    if n then
        local g = _G[n.."Text"]
        if g and g.GetText then
            local ok, t = pcall(g.GetText, g)
            if ok and t and t ~= "" then return t end
        end
    end
    local fs = SafeGetFontString(btn)
    if fs and fs.GetText then
        local ok, t = pcall(fs.GetText, fs)
        if ok and t and t ~= "" then return t end
    end
    return nil
end

-- Rule matching against a StaticPopup frame
local function FindPopupRuleForFrame(sp)
    if not sp or not sp.GetName then return nil end
    local frameName = sp:GetName()
    local popupText = nil
    local textObj = _G[frameName.."Text"]
    if textObj and textObj.GetText then
        local ok, t = pcall(textObj.GetText, textObj)
        if ok and t then popupText = t end
    end
    local lowerText = popupText and string.lower(popupText) or ""

    local lb = {}
    for j = 1, 4 do
        local btn = sp["button"..j]
        if btn then
            local lab = GetButtonLabelText(btn)
            lb[j] = lab and string.lower(lab) or ""
        else
            lb[j] = ""
        end
    end

    for _, rule in ipairs(DB().popupRules or {}) do
        if rule.enabled then
            if rule.matchBy == "frame" then
                if rule.pattern == frameName then return rule end
            else
                if rule.pattern ~= "" then
                    local pat = string.lower(rule.pattern)
                    if (lowerText ~= "" and string.find(lowerText, pat, 1, true)) then return rule end
                    for j = 1, 4 do
                        if lb[j] ~= "" and string.find(lb[j], pat, 1, true) then return rule end
                    end
                end
            end
        end
    end
    return nil
end

-- Whether current visible popup should be number-selectable (and not ignored)
local function PopupHasNumberSelection()
    if DB().disablePopupInteractions then return false end
    if not DB().popupButtonSelection then return false end
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then
            local rule = FindPopupRuleForFrame(sp)
            -- In whitelist mode: require a matching rule with action != 0
            if DB().popupWhitelistMode then
                if not rule or rule.action == 0 then return false end
            else
                if rule and rule.action == 0 then return false end
            end
            for j = 1, 4 do
                local btn = sp["button"..j]
                if btn and btn:IsShown() and btn:IsEnabled() then return true end
            end
        end
    end
    return false
end

-- StaticPopup numbering & selection helpers
local function RestoreStaticPopupButtonTexts()
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp then
            for j = 1, 4 do
                local btn = sp["button"..j]
                if btn and btn.dkOrigText then
                    local fs = SafeGetFontString(btn)
                    if fs then
                        pcall(fs.SetText, fs, btn.dkOrigText)
                        if btn.dkOrigColor then pcall(fs.SetTextColor, fs, unpack(btn.dkOrigColor)) end
                    end
                    btn.dkOrigText = nil
                    btn.dkOrigColor = nil
                end
            end
        end
    end
end

local function NumberStaticPopupButtons()
    if DB().disablePopupInteractions then return end
    if not DB().popupButtonSelection then return end
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then
            local rule = FindPopupRuleForFrame(sp)
            -- Whitelist: only number if matched and not ignored
            if DB().popupWhitelistMode then
                if not rule or rule.action == 0 then return end
            else
                if rule and rule.action == 0 then return end
            end
            for j = 1, 4 do
                local btn = sp["button"..j]
                if btn and btn:IsShown() then
                    local fs = SafeGetFontString(btn)
                    if fs then
                        if not btn.dkOrigText then
                            btn.dkOrigText = fs:GetText() or ""
                            local ok, r,g,b = pcall(fs.GetTextColor, fs)
                            if ok then btn.dkOrigColor = { r,g,b } end
                        end
                        local keyLabel = tostring(j)
                        pcall(fs.SetText, fs, keyLabel..". "..(btn.dkOrigText or ""))
                        if btn.dkOrigColor then pcall(fs.SetTextColor, fs, unpack(btn.dkOrigColor)) end
                    end
                end
            end
            return
        end
    end
end

-- Intermediary secure buttons for popup number selection
local function EnsureNumSelectButtons()
    if DK.numSelectButtons and #DK.numSelectButtons >= 4 then return end
    DK.numSelectButtons = {}
    for j = 1, 4 do
        local name = addonName.."NumSelect"..j
        local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        btn:SetSize(1,1); btn:Hide()
        btn.index = j
        btn:SetScript("OnClick", function(self)
            local targ = DK.popupNumTargets[self.index]
            if not targ or not targ:IsVisible() or not targ:IsEnabled() then
                if DK._popupSelectedButton then
                    HideSelectionOverlay(DK._popupSelectedButton)
                end
                DK._popupSelectedButton = nil
                SetOverrideBinding(handler, false, "SPACE", "")
                return
            end
            if DK._popupSelectedButton and DK._popupSelectedButton ~= targ then
                HideSelectionOverlay(DK._popupSelectedButton)
            end
            DK._popupSelectedButton = targ
            ShowSelectionOverlay(targ)
            if targ and targ.GetName and targ:GetName() then
                SetOverrideBindingClick(handler, false, "SPACE", targ:GetName(), "LeftButton")
            end
        end)
        DK.numSelectButtons[j] = btn
    end
end

local function ClearPopupSelection()
    if DK._popupSelectedButton then
        HideSelectionOverlay(DK._popupSelectedButton)
        DK._popupSelectedButton = nil
    end
    DK.popupNumTargets = {}
    if DB().popupButtonSelection then
        SetOverrideBinding(handler, false, "SPACE", "")
        ClearSpaceHighlight()
    end
end

local function BindNumberKeysForPopup()
    if DB().disablePopupInteractions then return end
    if not DB().popupButtonSelection then return end
    EnsureNumSelectButtons()
    DK.popupNumTargets = {}
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then
            local rule = FindPopupRuleForFrame(sp)
            -- Whitelist gating
            if DB().popupWhitelistMode and not (rule and rule.action ~= 0) then
                ClearPopupSelection()
                return
            end
            if (not DB().popupWhitelistMode) and rule and rule.action == 0 then
                ClearPopupSelection()
                return
            end
            for j = 1, 4 do
                local btn = sp["button"..j]
                if btn and btn:IsShown() and btn:IsEnabled() and btn.GetName then
                    local key = tostring(j) -- 1..4
                    DK.popupNumTargets[j] = btn
                    local numBtn = DK.numSelectButtons[j]
                    if numBtn and numBtn:GetName() then
                        SetOverrideBindingClick(handler, false, key, numBtn:GetName())
                        if DB().allowNumPadKeys then
                            local nk = "NUMPAD"..key
                            SetOverrideBindingClick(handler, false, nk, numBtn:GetName())
                        end
                    end
                else
                    DK.popupNumTargets[j] = nil
                end
            end
            return
        end
    end
    DK.popupNumTargets = {}
end

-- Mail helpers (Postal)
local function HasUnreadMail()
    if not GetInboxNumItems or not GetInboxHeaderInfo then return false end
    local n = GetInboxNumItems() or 0
    if n <= 0 then return false end
    for i = 1, n do
        local _, _, _, _, _, _, _, _, wasRead = GetInboxHeaderInfo(i)
        if wasRead == nil or wasRead == false then return true end
    end
    return false
end

local function IsMailboxActive()
    return DB().usePostalOpenAll and InboxFrame and InboxFrame:IsVisible() and PostalOpenAllButton and HasUnreadMail()
end

-- Utility helpers for scroll-wheel selection
local function AnyStaticPopupVisible()
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then return true end
    end
    return false
end

local function BuildVisibleList()
    local list = {}
    local prefix, max
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
        prefix, max = "QuestTitleButton", 10
    elseif GossipFrame and GossipFrame:IsVisible() then
        prefix, max = "GossipTitleButton", 32
    else
        return list
    end
    for i = 1, max do
        local btn = _G[prefix..i]
        if btn and btn:IsVisible() and btn:IsEnabled() then
            local fs = SafeGetFontString(btn)
            local txt = fs and fs:GetText()
            if txt and txt ~= "" then table.insert(list, btn) end
        end
    end
    return list
end

local function SetSpaceTargetTo(btn)
    if btn and btn.IsVisible and btn:IsVisible() and btn.IsEnabled and btn:IsEnabled() and btn.GetName and btn:GetName() then
        HighlightSpaceButton(btn)
        SetOverrideBindingClick(handler, false, "SPACE", btn:GetName(), "LeftButton")
        return true
    end
    return false
end

local function WheelSelect(delta)
    if not DB().scrollWheelSelect then return end
    if AnyStaticPopupVisible() then return end
    if not ((GossipFrame and GossipFrame:IsVisible()) or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible())) then return end

    DK._wheelUsed = true

    local list = BuildVisibleList()
    local n = #list
    if n == 0 then return end

    local idx = DK._scrollIndex
    if not idx or not DK._scrollSelectedButton or not DK._scrollSelectedButton:IsVisible() then
        -- Start from current best target when list opens
        local current = DK.Dialogs and DK.Dialogs.BestQuestOrGossipButton and DK.Dialogs.BestQuestOrGossipButton() or nil
        idx = 1
        for i, b in ipairs(list) do if b == current then idx = i break end end
    end

    -- delta < 0 = next, delta > 0 = previous
    if delta < 0 then idx = math.min(n, idx + 1) else idx = math.max(1, idx - 1) end

    DK._scrollIndex = idx
    DK._scrollSelectedButton = list[idx]
    SetSpaceTargetTo(list[idx])
end

local function HookWheelTargets()
    if GossipFrame and not GossipFrame._dkWheel then
        GossipFrame:EnableMouseWheel(true)
        GossipFrame:HookScript("OnMouseWheel", function(_, delta) WheelSelect(delta) end)
        GossipFrame._dkWheel = true
    end
    if QuestFrameGreetingPanel and not QuestFrameGreetingPanel._dkWheel then
        QuestFrameGreetingPanel:EnableMouseWheel(true)
        QuestFrameGreetingPanel:HookScript("OnMouseWheel", function(_, delta) WheelSelect(delta) end)
        QuestFrameGreetingPanel._dkWheel = true
    end
end

local DetermineSpaceTarget
local UpdateWheelOverrideBinding

-- Public API to toggle wheel selection (called by GUI)
function DK.SetScrollWheelSelectEnabled(enabled)
    DB().scrollWheelSelect = enabled and true or false
    if not DB().scrollWheelSelect then
        DK._scrollSelectedButton = nil
        DK._scrollIndex = nil
        DK._wheelUsed = false
    end
    HookWheelTargets()
    local tgt = select(1, DetermineSpaceTarget())
    UpdateWheelOverrideBinding(tgt)
end

-- Hidden buttons + override binding for global mouse wheel
local wheelUpBtn, wheelDownBtn
local function EnsureWheelButtons()
    if wheelUpBtn and wheelDownBtn then return end
    wheelUpBtn = CreateFrame("Button", addonName.."WheelUpButton", UIParent)
    wheelDownBtn = CreateFrame("Button", addonName.."WheelDownButton", UIParent)
    wheelUpBtn:SetScript("OnClick", function() WheelSelect(1) end)      -- up = previous
    wheelDownBtn:SetScript("OnClick", function() WheelSelect(-1) end)   -- down = next
end

function UpdateWheelOverrideBinding(currentSpaceTarget)
    if not DB().scrollWheelSelect then
        SetOverrideBinding(handler, false, "MOUSEWHEELUP", "")
        SetOverrideBinding(handler, false, "MOUSEWHEELDOWN", "")
        return
    end
    local onList = (GossipFrame and GossipFrame:IsVisible()) or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible())
    if currentSpaceTarget and onList and not AnyStaticPopupVisible() then
        EnsureWheelButtons()
        SetOverrideBindingClick(handler, false, "MOUSEWHEELUP", wheelUpBtn:GetName())
        SetOverrideBindingClick(handler, false, "MOUSEWHEELDOWN", wheelDownBtn:GetName())
    else
        SetOverrideBinding(handler, false, "MOUSEWHEELUP", "")
        SetOverrideBinding(handler, false, "MOUSEWHEELDOWN", "")
    end
end

-- Heartbeat to sanitize stray highlights on StaticPopups
local function Heartbeat()
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp and sp:IsVisible() then
            for j = 1, 4 do
                local btn = sp["button"..j]
                if btn then
                    local hovered = btn.IsMouseOver and btn:IsMouseOver()
                    local manual = manualHighlights[btn]
                    local isTarget = (btn == spaceHighlight)
                    local isSelected = (btn == DK._popupSelectedButton)
                    if not (hovered or manual or isTarget or isSelected) then
                        if btn.dkSelFrame then btn.dkSelFrame:Hide() end
                        RemoveHighlight(btn)
                    else
                        if isSelected then ShowSelectionOverlay(btn) end
                    end
                end
            end
        end
    end
end

-- helper to decide if any dialog/mail UI that we care about is visible
local function AnyDialogVisible()
    return (GossipFrame and GossipFrame:IsVisible()) or
           (QuestFrame and QuestFrame:IsVisible()) or
           (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible()) or
           (QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible()) or
           (StaticPopup1 and StaticPopup1:IsVisible()) or
           IsMailboxActive()
end

-- force-release all overrides immediately (safe in combat)
local function ForceReleaseOverrides()
    -- Stop background loop
    DK:SetScript("OnUpdate", nil)
    DK._anyVisibleTimer, DK._lastUpdate = nil, 0

    -- Clear key overrides
    ClearOverrideBindings(handler)
    SetOverrideBinding(handler, false, "MOUSEWHEELUP", "")
    SetOverrideBinding(handler, false, "MOUSEWHEELDOWN", "")
    SetOverrideBinding(handler, false, "SPACE", "")

    -- Reset selection/highlights and wheel state
    ClearSpaceHighlight()
    ClearStaticPopupHighlights()
    manualHighlights = {}
    DK._scrollSelectedButton = nil
    DK._scrollIndex = nil
    DK._wheelUsed = false
    DK._popupSelectedButton = nil
    DK.popupNumTargets = {}

    -- Hide any reward tooltip
    if DK.Rewards and DK.Rewards.HideTooltip then DK.Rewards.HideTooltip(nil) end

    overridesActive = false
end

-- Determine SPACE target (respects popup rules and popupButtonSelection + whitelist/disable)
function DetermineSpaceTarget()
    local ignoredPopupFound = false

    -- If in combat, never set overrides; release and bail
    if DK._inCombat then
        return nil, true
    end

    -- Wheel selection only after the user actually scrolls
    if DB().scrollWheelSelect and DK._wheelUsed and not AnyStaticPopupVisible() and DK._scrollSelectedButton and DK._scrollSelectedButton:IsVisible() then
        if (GossipFrame and GossipFrame:IsVisible()) or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible()) then
            return DK._scrollSelectedButton, false
        end
    end

    if DK._popupSelectedButton and DK._popupSelectedButton:IsVisible() and DK._popupSelectedButton:IsEnabled() then
        return DK._popupSelectedButton, false
    end

    -- Popup handling (respects disable + whitelist)
    if not DB().disablePopupInteractions then
        for i = 1, 4 do
            local sp = _G["StaticPopup"..i]
            if sp and sp:IsVisible() then
                local rule = FindPopupRuleForFrame(sp)
                if DB().popupWhitelistMode then
                    -- Whitelist: only interact if a rule exists and is not action 0
                    if not rule or rule.action == 0 then
                        ignoredPopupFound = true
                    else
                        local desired = sp["button"..tostring(rule.action)]
                        if desired and desired:IsEnabled() then return desired, false end
                    end
                else
                    -- Normal mode (legacy): rule 0 ignores, else fall back to default behavior
                    if rule then
                        if rule.action == 0 then
                            ignoredPopupFound = true
                        else
                            local desired = sp["button"..tostring(rule.action)]
                            if desired and desired:IsEnabled() then return desired, false end
                        end
                    else
                        if DB().popupButtonSelection and PopupHasNumberSelection() then
                            return nil, false
                        else
                            if sp.button1 and sp.button1:IsEnabled() then return sp.button1, false end
                        end
                    end
                end
            end
        end
    else
        -- When fully disabled, treat any visible popup as ignored for SPACE
        for i = 1, 4 do
            local sp = _G["StaticPopup"..i]
            if sp and sp:IsVisible() then ignoredPopupFound = true break end
        end
    end

    if DB().usePostalOpenAll and InboxFrame and InboxFrame:IsVisible() and PostalOpenAllButton and PostalOpenAllButton:IsEnabled() then
        if HasUnreadMail() then
            return PostalOpenAllButton, false
        end
    end

    if QuestFrame and QuestFrame:IsVisible() then
        if QuestFrameAcceptButton and QuestFrameAcceptButton:IsVisible() and QuestFrameAcceptButton:IsEnabled() then
            return QuestFrameAcceptButton, false
        elseif QuestFrameCompleteButton and QuestFrameCompleteButton:IsVisible() and QuestFrameCompleteButton:IsEnabled() then
            return QuestFrameCompleteButton, false
        elseif QuestFrameCompleteQuestButton and QuestFrameCompleteQuestButton:IsVisible() and QuestFrameCompleteQuestButton:IsEnabled() then
            return QuestFrameCompleteQuestButton, false
        end
    end

    -- Lists: Completed (3) > Available (2) > In-progress (1), with memory fallback
    local best = DK.Dialogs and DK.Dialogs.BestQuestOrGossipButton and DK.Dialogs.BestQuestOrGossipButton() or nil
    if best then return best, false end

    return nil, ignoredPopupFound
end

local function IsAwaitingPopupNumberSelection()
    return DB().popupButtonSelection and (not DB().disablePopupInteractions) and PopupHasNumberSelection() and not DK._popupSelectedButton
end

local function UpdateSpaceHighlightAndBinding()
    -- Hard-guard in combat: ensure SPACE is unbound, do not rebind
    if DK._inCombat then
        ClearStaticPopupHighlights()
        ClearSpaceHighlight()
        SetOverrideBinding(handler, false, "SPACE", "")
        UpdateWheelOverrideBinding(nil)
        return nil
    end

    if IsAwaitingPopupNumberSelection() then
        ClearStaticPopupHighlights()
        ClearSpaceHighlight()
        SetOverrideBinding(handler, false, "SPACE", "")
        UpdateWheelOverrideBinding(nil)
        return nil
    end

    local target, ignored = DetermineSpaceTarget()

    if DK._popupSelectedButton and DK._popupSelectedButton == target then
        ShowSelectionOverlay(DK._popupSelectedButton)
    else
        HighlightSpaceButton(target)
    end

    if ignored and not target then
        SetOverrideBinding(handler, false, "SPACE", "")
    else
        if target and target.GetName and target:GetName() then
            SetOverrideBindingClick(handler, false, "SPACE", target:GetName(), "LeftButton")
        else
            SetOverrideBinding(handler, false, "SPACE", "CLICK "..spaceBtn:GetName()..":LeftButton")
        end
    end

    UpdateWheelOverrideBinding(target)

    return target
end

-- Bind number keys for lists (reused)
local function BindKeyForButton(keyName, btn)
    if not keyName or not btn or not btn.GetName then return end
    SetOverrideBinding(handler, false, keyName, "CLICK "..btn:GetName()..":LeftButton")
    if DB().allowNumPadKeys then
        local nk = (keyName == "0") and "NUMPAD0" or ("NUMPAD"..keyName)
        SetOverrideBinding(handler, false, nk, "CLICK "..btn:GetName()..":LeftButton")
    end
end

local function BindNumberKeysForList(prefix, max)
    local ct = 1
    for i = 1, max do
        local btn = _G[prefix..i]
        if btn and btn:IsVisible() then
            local fs = SafeGetFontString(btn)
            local txt = fs and fs:GetText()
            if txt and txt ~= "" then
                if ct <= 10 then
                    local key = (ct < 10) and tostring(ct) or "0"
                    BindKeyForButton(key, btn)
                end
                ct = ct + 1
                if ct > 10 then break end
            end
        end
    end
end

-- Enable / Disable overrides
local function NumberEverythingVisible()
    if GossipFrame and GossipFrame:IsVisible() and DK.NumberGossipButtons then DK.NumberGossipButtons() end
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() and DK.NumberQuestButtons then DK.NumberQuestButtons() end
    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and DK.NumberRewardButtons then DK.NumberRewardButtons() end
    NumberStaticPopupButtons()
end

local ONUPDATE_INTERVAL = 0.05
local function EnableOverrides()
    -- Never set or refresh overrides while in combat; defer until safe
    if DK._inCombat then
        DK._pendingEnable = true
        -- Ensure everything is released right now
        ForceReleaseOverrides()
        return
    end

    if overridesActive then
        HookWheelTargets()
        local tgt = UpdateSpaceHighlightAndBinding()
        NumberStaticPopupButtons()
        BindNumberKeysForPopup()
        UpdateWheelOverrideBinding(tgt)
        Heartbeat()
        return
    end
    overridesActive = true
    ClearOverrideBindings(handler)

    if GossipFrame and GossipFrame:IsVisible() then BindNumberKeysForList("GossipTitleButton", 32) end
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then BindNumberKeysForList("QuestTitleButton", 10) end
    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and DK.Rewards and DK.Rewards.BindNumberKeysForRewards then
        DK.Rewards.BindNumberKeysForRewards()
    end

    if DB().popupButtonSelection then
        RestoreStaticPopupButtonTexts()
        NumberStaticPopupButtons()
        BindNumberKeysForPopup()
    else
        ClearPopupSelection()
        RestoreStaticPopupButtonTexts()
    end

    HookWheelTargets()
    local tgt = UpdateSpaceHighlightAndBinding()
    UpdateWheelOverrideBinding(tgt)
    NumberEverythingVisible()
    Heartbeat()

    if not DK._anyVisibleTimer then
        DK._lastUpdate = 0
        DK._anyVisibleTimer = true
        DK:SetScript("OnUpdate", function(self, elapsed)
            self._lastUpdate = (self._lastUpdate or 0) + elapsed
            if self._lastUpdate < ONUPDATE_INTERVAL then return end
            self._lastUpdate = 0

            local anyVisible = AnyDialogVisible()

            if anyVisible and not DK._inCombat then
                if DB().popupButtonSelection then
                    if DK._popupSelectedButton then
                        if DK._popupSelectedButton:IsVisible() and DK._popupSelectedButton:IsEnabled() then
                            ShowSelectionOverlay(DK._popupSelectedButton)
                        else
                            HideSelectionOverlay(DK._popupSelectedButton)
                            DK._popupSelectedButton = nil
                        end
                    else
                        RestoreStaticPopupButtonTexts()
                        NumberStaticPopupButtons()
                        BindNumberKeysForPopup()
                    end
                end

                local tgt2 = UpdateSpaceHighlightAndBinding()
                UpdateWheelOverrideBinding(tgt2)
                Heartbeat()
            else
                DK:SetScript("OnUpdate", nil)
                DK._anyVisibleTimer, DK._lastUpdate = nil, 0
                overridesActive = false
                ClearOverrideBindings(handler)
                ClearSpaceHighlight()
                if DK.Rewards and DK.Rewards.HideTooltip then DK.Rewards.HideTooltip(nil) end
            end
        end)
    end
end

local function DisableOverrides()
    if not overridesActive then return end
    overridesActive = false
    ClearOverrideBindings(handler)
    SetOverrideBinding(handler, false, "MOUSEWHEELUP", "")
    SetOverrideBinding(handler, false, "MOUSEWHEELDOWN", "")
    DK._scrollSelectedButton = nil
    DK._scrollIndex = nil
    DK._wheelUsed = false

    ClearSpaceHighlight()
    manualHighlights = {}
    ClearAllButtonHighlights()
    if DK.Rewards and DK.Rewards.HideTooltip then DK.Rewards.HideTooltip(nil) end

    for i = 1, 10 do local b = _G["QuestTitleButton"..i] if b then RestoreOriginalText(b) end end
    for i = 1, 32 do local b = _G["GossipTitleButton"..i] if b then RestoreOriginalText(b) end end
    if DK.Rewards and DK.Rewards.RemoveRewardNumberOverlay then
        for i = 1, 10 do local b = _G["QuestInfoItem"..i] if b then DK.Rewards.RemoveRewardNumberOverlay(b) end end
    end

    RestoreStaticPopupButtonTexts()
    ClearPopupSelection()
end

-- Hooks & initialization (StaticPopup)
for i = 1, 4 do
    local sp = _G["StaticPopup"..i]
    if sp then
        sp:HookScript("OnShow", function()
            ClearPopupSelection()
            if DB().popupButtonSelection then SetOverrideBinding(handler, false, "SPACE", "") end
            EnableOverrides()
        end)
        sp:HookScript("OnHide", function()
            ClearPopupSelection()
            -- Do NOT clear last-best; it helps keep priority stable when returning to lists
            if AnyDialogVisible() then
                EnableOverrides()
            else
                DisableOverrides()
            end
        end)
    end
end

-- Mailbox hooks
if InboxFrame then
    InboxFrame:HookScript("OnShow", function()
        if IsMailboxActive() then
            EnableOverrides()
        else
            DisableOverrides()
        end
    end)
    InboxFrame:HookScript("OnHide", DisableOverrides)
end

-- Reward panel cleanup
if QuestFrameRewardPanel then
    QuestFrameRewardPanel:HookScript("OnHide", function()
        if DK.Rewards and DK.Rewards.RemoveRewardNumberOverlay then
            for i = 1, 10 do local b = _G["QuestInfoItem"..i] if b then DK.Rewards.RemoveRewardNumberOverlay(b) end end
        end
        if DK.Rewards and DK.Rewards.HideTooltip then DK.Rewards.HideTooltip(nil) end
    end)
end

-- SavedVariables lifecycle + combat gating
DK:RegisterEvent("ADDON_LOADED")
DK:RegisterEvent("PLAYER_LOGOUT")
DK:RegisterEvent("PLAYER_REGEN_DISABLED")
DK:RegisterEvent("PLAYER_REGEN_ENABLED")

DK:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        for k, v in pairs(defaults) do if DB()[k] == nil then DB()[k] = v end end
        if type(DB().popupRules) ~= "table" then DB().popupRules = {} end
        DK.SetScrollWheelSelectEnabled(DB().scrollWheelSelect)
        -- Initialize UI hooks in modules
        if DK.Dialogs and DK.Dialogs.InitializeListButtons then DK.Dialogs.InitializeListButtons() end
        if DK.Rewards and DK.Rewards.InitializeRewardHooks then DK.Rewards.InitializeRewardHooks() end
    elseif event == "PLAYER_LOGOUT" then
        DB().__lastSaved = time()
    elseif event == "PLAYER_REGEN_DISABLED" then
        DK._inCombat = true
        DK._pendingEnable = AnyDialogVisible() or DK._pendingEnable
        ForceReleaseOverrides()
    elseif event == "PLAYER_REGEN_ENABLED" then
        DK._inCombat = false
        if AnyDialogVisible() or DK._pendingEnable then
            DK._pendingEnable = false
            EnableOverrides()
        end
    end
end)

-- Event proxy for dialog/gossip/quest and mail
local eventFrame = CreateFrame("Frame")
DK._eventsFrame = eventFrame
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_PROGRESS")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_FINISHED")
eventFrame:RegisterEvent("QUEST_CLOSED")
eventFrame:RegisterEvent("QUEST_GREETING")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("MAIL_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GOSSIP_SHOW" then
        if DK.NumberGossipButtons then DK.NumberGossipButtons() end
        DK._scrollSelectedButton, DK._scrollIndex = nil, nil
        DK._wheelUsed = false
        DK._lastBestListTarget = nil
        EnableOverrides()
    elseif event == "QUEST_GREETING" then
        if DK.NumberQuestButtons then DK.NumberQuestButtons() end
        DK._scrollSelectedButton, DK._scrollIndex = nil, nil
        DK._wheelUsed = false
        DK._lastBestListTarget = nil
        EnableOverrides()
    elseif event == "QUEST_COMPLETE" then
        EnableOverrides()
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "QUEST_CLOSED" then
        DK._scrollSelectedButton, DK._scrollIndex = nil, nil
        DK._wheelUsed = false
        DK._lastBestListTarget = nil
        DisableOverrides()
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" then
        EnableOverrides()
    elseif event == "MAIL_SHOW" then
        if IsMailboxActive() then
            EnableOverrides()
        else
            DisableOverrides()
        end
    elseif event == "MAIL_INBOX_UPDATE" then
        if InboxFrame and InboxFrame:IsVisible() then
            if IsMailboxActive() then
                EnableOverrides()
            else
                DisableOverrides()
            end
        end
    elseif event == "MAIL_CLOSED" then
        DisableOverrides()
    end
end)

-- Export for GUI.lua
DK.AddPopupRule = AddPopupRule
DK.RemovePopupRule = RemovePopupRule
DK.ListPopupRules = ListPopupRules
-- Dialog numbering/exported from module
-- These will be set after Dialogs.lua loads:
-- DK.NumberGossipButtons
-- DK.NumberQuestButtons
-- DK.NumberRewardButtons
DK.EnableOverrides = EnableOverrides
DK.SetScrollWheelSelectEnabled = DK.SetScrollWheelSelectEnabled

-- Simple highlights for mouse interactions on list/popup buttons
local function HandleButtonMouseEvents(btn)
    if not btn or btn.dkMouseHooked then return end
    btn:HookScript("OnEnter", function() ApplyHighlight(btn) end)
    btn:HookScript("OnLeave", function()
        if not manualHighlights[btn] and btn ~= spaceHighlight and DK._selectedReward ~= btn and DK._popupSelectedButton ~= btn then
            RemoveHighlight(btn)
            if btn.dkSelFrame then btn.dkSelFrame:Hide() end
        end
    end)
    btn:HookScript("OnClick", function() ApplyHighlight(btn) end)
    btn:HookScript("OnMouseDown", function()
        manualHighlights[btn] = true
        ApplyHighlight(btn)
    end)
    btn:HookScript("OnMouseUp", function()
        manualHighlights[btn] = nil
        if btn ~= spaceHighlight and DK._selectedReward ~= btn and DK._popupSelectedButton ~= btn then
            RemoveHighlight(btn)
            if btn.dkSelFrame then btn.dkSelFrame:Hide() end
        end
    end)
    btn.dkMouseHooked = true
end

-- Expose a list-buttons initializer for Dialogs module to call
function DK._HandleButtonMouseEvents(btn) HandleButtonMouseEvents(btn) end

-- Slash: open options (double-call pattern to ensure panel focuses)
SLASH_DKW1 = "/dkw"
SlashCmdList["DKW"] = function()
    if not InterfaceOptionsFrame_OpenToCategory and LoadAddOn then
        pcall(LoadAddOn, "Blizzard_InterfaceOptions")
    end
    if DK.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(DK.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(DK.optionsPanel)
    else
        DEFAULT_CHAT_FRAME:AddMessage(addonName..": options panel not available. Open Interface -> AddOns -> "..addonName)
    end
end

-- Debug helpers
SLASH_DKDBG1 = "/dkw debug"
SlashCmdList["DKDBG"] = function()
    local db = DB()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s settings: detectElvUI=%s allowNumPadKeys=%s showNumbers=%s popupButtonSelection=%s usePostalOpenAll=%s scrollWheelSelect=%s whitelist=%s disablePopups=%s rewardTooltip=%s compare=%s rules=%d",
        addonName, tostring(db.detectElvUI), tostring(db.allowNumPadKeys), tostring(db.showNumbers), tostring(db.popupButtonSelection), tostring(db.usePostalOpenAll), tostring(db.scrollWheelSelect), tostring(db.popupWhitelistMode), tostring(db.disablePopupInteractions), tostring(db.rewardTooltipOnSelect), tostring(db.compareTooltips), #(db.popupRules or {})))
end