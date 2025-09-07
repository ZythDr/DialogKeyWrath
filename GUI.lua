-- DialogKeyWrath GUI (WotLK 3.3.5a)
-- Panels:
-- - General: core options
-- - Create Rule: add rules (dropdowns)
-- - Existing Rules: scrollable cards with vertical layout and live-edit controls

local addonName = "DialogKeyWrath"
local DK = _G[addonName.."Frame"] or _G.DialogKeyWrathFrame or CreateFrame("Frame", addonName.."Frame", UIParent)

-- Saved DB accessor (via Core or SavedVariables)
local function DB()
    if DK.DB and type(DK.DB) == "function" then return DK.DB() end
    _G.DialogKeyWrathDB = _G.DialogKeyWrathDB or {}
    return _G.DialogKeyWrathDB
end

-- Layout constants
local LEFT   = 16
local TOPGAP = 16
local ROWGAP = 8

-- Cards (Existing Rules)
local CARD_MIN_WIDTH  = 360
local CARD_MAX_WIDTH  = 540
local CARD_PAD        = 10
local CARD_SPACING_Y  = 12
local SCROLLBAR_RESERVE = 36

-- NEW: radio horizontal spacing controls
local MATCH_RADIO_GAP_X  = 46 -- spacing between Match radios (Text vs Frame)
local ACTION_RADIO_GAP_X = 22 -- spacing between Action radios

-- Global "click-outside to unfocus" state (overlay disabled to allow first-click actions)
local ActiveEditBox
local FocusCatcher = CreateFrame("Frame", addonName.."FocusCatcher", UIParent)
FocusCatcher:Hide()

local function AttachOutsideClickBlur(eb)
    if not eb then return end
    eb:HookScript("OnEditFocusGained", function(self)
        ActiveEditBox = self
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        if ActiveEditBox == self then
            ActiveEditBox = nil
        end
    end)
    eb:HookScript("OnHide", function(self)
        if ActiveEditBox == self then
            ActiveEditBox = nil
        end
    end)
end

local function ClearActiveEditFocus()
    if ActiveEditBox and ActiveEditBox.ClearFocus then
        ActiveEditBox:ClearFocus()
    end
end

local function HookClearFocusOnMouseDown(frame)
    if not frame or frame._dkClearFocusHooked then return end
    frame:HookScript("OnMouseDown", ClearActiveEditFocus)
    frame._dkClearFocusHooked = true
end

-- Small UI helpers
local function AddTitle(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT, -LEFT)
    fs:SetText(text or addonName)
    return fs
end

local function Tooltipify(frame, title, body)
    if not frame then return end
    local function showTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        if title then GameTooltip:SetText(title, 1, 0.82, 0) end
        if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, true) end
        GameTooltip:Show()
    end
    local function hideTip() GameTooltip:Hide() end

    if frame.HookScript then
        frame:HookScript("OnEnter", showTip)
        frame:HookScript("OnLeave", hideTip)
    elseif frame.SetScript and frame.EnableMouse then
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", showTip)
        frame:SetScript("OnLeave", hideTip)
    end
end

local function CreateNamedDropdown(name, parent, width)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    if width and UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width) end
    return dd
end

local function HideDropDownBlizzardTextures(dd)
    if not dd or not dd.GetName then return end
    local n = dd:GetName()
    for _, suf in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled"}) do
        local r = _G[n..suf]
        if r then
            if r.Hide then r:Hide() end
            if r.SetAlpha then r:SetAlpha(0) end
            if r.SetTexture then r:SetTexture(nil) end
            r.Show = function() end
        end
    end
    local bd = dd.backdrop or dd.Backdrop or dd.BackDrop
    if bd then if bd.Hide then bd:Hide() end; if bd.SetAlpha then bd:SetAlpha(0) end end
end

local function SetDropdownText(dd, text)
    local n = dd and dd.GetName and dd:GetName()
    local t = n and _G[n.."Text"]
    if t and t.SetText then t:SetText(text or "") end
end

local function SetShownCompat(f, shown)
    if not f then return end
    if shown then if f.Show then f:Show() end else if f.Hide then f:Hide() end end
end

local function CreateNamedCheckbox(name, parent, label)
    local cb = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    local l = _G[name.."Text"]
    if l then
        l:SetText(label or "")
        l:ClearAllPoints()
        l:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    end
    return cb, l
end

local function CreateSmallCheckbox(parent, labelText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(18, 18)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetText(labelText or "")
    label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    local function updateHitRect()
        local w = (label:GetStringWidth() or 0)
        cb:SetHitRectInsets(0, - (w + 1), 0, 0)
    end
    updateHitRect()
    cb._dkUpdateHitRect = updateHitRect
    return cb, label
end

local function CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 120, height or 22)
    btn:SetText(text or "OK")
    HookClearFocusOnMouseDown(btn)
    return btn
end

local function CreateEditBox(parent, width)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetAutoFocus(false)
    eb:SetSize(width or 240, 20)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(6, 6, 2, 2)
    eb:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    eb:SetBackdropColor(0,0,0,0.4)
    eb:SetBackdropBorderColor(0.3,0.3,0.3,1)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    AttachOutsideClickBlur(eb)
    return eb
end

local function RestyleDropdown(dd, width)
    if not dd or not dd.GetName then return end
    local n = dd:GetName()
    if width and UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width) end
    dd:SetHeight(22)

    HideDropDownBlizzardTextures(dd)

    local btn = _G[n.."Button"]
    local txt = _G[n.."Text"]

    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("RIGHT", dd, "RIGHT", 0, 0)
        btn:SetSize(22, 22)
        if btn.SetNormalTexture   then btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up") end
        if btn.SetPushedTexture   then btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down") end
        if btn.SetDisabledTexture then btn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled") end
        if btn.SetHighlightTexture then btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight") end

        if not dd._dkCover then
            local cover = CreateFrame("Button", nil, dd)
            cover:SetAllPoints(dd)
            cover:SetFrameLevel(dd:GetFrameLevel() + 3)
            cover:RegisterForClicks("LeftButtonDown")
            cover:SetScript("OnClick", function()
                ClearActiveEditFocus()
                ToggleDropDownMenu(1, nil, dd, dd, 0, 0)
            end)
            dd._dkCover = cover
        end
    end

    if txt then
        txt:ClearAllPoints()
        txt:SetPoint("LEFT", dd, "LEFT", 10, 0)
        if btn then txt:SetPoint("RIGHT", btn, "LEFT", -4, 0) else txt:SetPoint("RIGHT", dd, "RIGHT", -4, 0) end
        txt:SetJustifyH("LEFT")
    end

    if not dd.dkFill then
        dd.dkFill = dd:CreateTexture(nil, "BACKGROUND")
        dd.dkFill:SetPoint("TOPLEFT", dd, "TOPLEFT", 1, -1)
        dd.dkFill:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", -1, 1)
        dd.dkFill:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        dd.dkFill:SetVertexColor(0,0,0,0.25)
    end
    if not dd.dkBorder then
        dd.dkBorder = CreateFrame("Frame", nil, dd)
        dd.dkBorder:SetPoint("TOPLEFT", dd, "TOPLEFT", 0, 0)
        dd.dkBorder:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", 0, 0)
        dd.dkBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        dd.dkBorder:SetBackdropBorderColor(0.3,0.3,0.3,1)
    end

    if not dd._dkHeightClamped then
        dd._dkHeightClamped = true
        local orig = dd.SetHeight
        dd.SetHeight = function(self, h) return orig(self, 22) end
        dd:HookScript("OnSizeChanged", function(self) if self:GetHeight() ~= 22 then orig(self, 22) end end)
    end

    local pl = (dd:GetParent() and dd:GetParent():GetFrameLevel()) or 1
    dd:SetFrameLevel(pl + 2)
end

-- Parent panel (folder entry)
local parentPanel = CreateFrame("Frame", addonName.."OptionsPanel", UIParent)
parentPanel.name = addonName

do
    local title = AddTitle(parentPanel, "DialogKeyWrath")
    local blurb = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -ROWGAP)
    blurb:SetJustifyH("LEFT")
    blurb:SetText("Use the sub-categories:\n- General\n- Create Rule\n- Existing Rules")
end

-- Child panels
local generalPanel  = CreateFrame("Frame", addonName.."GeneralPanel", UIParent)
generalPanel.name   = "General"
generalPanel.parent = addonName

local createPanel   = CreateFrame("Frame", addonName.."CreateRulePanel", UIParent)
createPanel.name    = "Create Rule"
createPanel.parent  = addonName

local existingPanel = CreateFrame("Frame", addonName.."ExistingRulesPanel", UIParent)
existingPanel.name  = "Existing Rules"
existingPanel.parent= addonName

InterfaceOptions_AddCategory(parentPanel)
InterfaceOptions_AddCategory(generalPanel)
InterfaceOptions_AddCategory(createPanel)
InterfaceOptions_AddCategory(existingPanel)

DK.optionsPanel = generalPanel

function generalPanel:RefreshRulesUI()
    if existingPanel and existingPanel.RefreshRulesUI then existingPanel:RefreshRulesUI() end
end

-- Clear focus when clicking blank space on panels
HookClearFocusOnMouseDown(generalPanel)
HookClearFocusOnMouseDown(createPanel)
HookClearFocusOnMouseDown(existingPanel)

-- ======================
-- General panel
-- ======================
do
    local title = AddTitle(generalPanel, "DialogKeyWrath - General")

    local numpadCheck      = CreateNamedCheckbox(addonName.."AllowNumPadCheck", generalPanel, "Allow NumPad keys")
    numpadCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TOPGAP)
    Tooltipify(numpadCheck, "Allow NumPad keys", "Bind NUMPAD1..NUMPAD0 in addition to 1..0")

    local showNumbersCheck = CreateNamedCheckbox(addonName.."ShowNumbersCheck", generalPanel, "Show numbers on dialog & quest lists")
    showNumbersCheck:SetPoint("TOPLEFT", numpadCheck, "BOTTOMLEFT", 0, -ROWGAP)

    -- NEW: Quest Rewards Tooltip on number selection
    local rewardsTooltipCheck = CreateNamedCheckbox(addonName.."RewardsTooltipCheck", generalPanel, "Show tooltip for quest rewards when pressing 1..0")
    rewardsTooltipCheck:SetPoint("TOPLEFT", showNumbersCheck, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(rewardsTooltipCheck, "Quest Rewards Tooltip", "When completing a quest, pressing 1..0 to select a reward will also show that item's tooltip.\nPressing the same number again will hide the tooltip.")

    -- NEW: Compare tooltips (child)
    local rewardsCompareCheck = CreateNamedCheckbox(addonName.."RewardsCompareCheck", generalPanel, "Also show comparison tooltips")
    rewardsCompareCheck:SetPoint("TOPLEFT", rewardsTooltipCheck, "BOTTOMLEFT", 20, -ROWGAP)
    Tooltipify(rewardsCompareCheck, "Comparison Tooltips", "Also show side-by-side comparison tooltips (as if Shift is held). Requires 'Quest Rewards Tooltip' to be enabled.")

    local popupSelectCheck = CreateNamedCheckbox(addonName.."PopupSelectCheck", generalPanel, "Require number input for popup frames")
    popupSelectCheck:SetPoint("TOPLEFT", rewardsCompareCheck, "BOTTOMLEFT", -20, -ROWGAP)
    Tooltipify(popupSelectCheck, "Popup selection", "Use number keys to select a popup button; SPACE disabled until chosen (when enabled).")

    -- NEW: Whitelist mode (only handle popups with matching rules)
    local whitelistCheck = CreateNamedCheckbox(addonName.."PopupWhitelistCheck", generalPanel, "Only handle popups with matching rules (Whitelist mode)")
    whitelistCheck:SetPoint("TOPLEFT", popupSelectCheck, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(whitelistCheck, "Whitelist mode", "When enabled, DialogKeyWrath will ONLY target StaticPopup buttons if a matching rule exists.\nNo rule = popup ignored.")

    -- NEW: Master disable for all popup interactions
    local disablePopupsCheck = CreateNamedCheckbox(addonName.."DisablePopupsCheck", generalPanel, "Disable popup interactions (ignore all popups)")
    disablePopupsCheck:SetPoint("TOPLEFT", whitelistCheck, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(disablePopupsCheck, "Disable popups", "Ignore every StaticPopup in the game, regardless of rules or settings.")

    local postalCheck      = CreateNamedCheckbox(addonName.."PostalOpenAllCheck", generalPanel, "Use Postal 'Open All' with Spacebar")
    postalCheck:SetPoint("TOPLEFT", disablePopupsCheck, "BOTTOMLEFT", 0, -ROWGAP)

    local wheelCheck       = CreateNamedCheckbox(addonName.."WheelSelectCheck", generalPanel, "Scroll wheel moves selection in dialog lists")
    wheelCheck:SetPoint("TOPLEFT", postalCheck, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(wheelCheck, "Scroll wheel selection", "When talking to NPCs (Gossip/Quest greeting), use the mouse wheel to move the SPACE target up/down the visible list.\nIgnores popups.")

    local resetBtn = CreateButton(generalPanel, "Reset to Defaults", 160, 24)
    resetBtn:SetPoint("TOPLEFT", wheelCheck, "BOTTOMLEFT", 0, -TOPGAP)

    -- Sync + wiring
    local function UpdateCompareEnabled()
        local tooltipsEnabled = rewardsTooltipCheck:GetChecked()
        if rewardsCompareCheck.Enable and rewardsCompareCheck.Disable then
            if tooltipsEnabled then rewardsCompareCheck:Enable() else rewardsCompareCheck:Disable() end
        end
        if not tooltipsEnabled then
            rewardsCompareCheck:SetChecked(false)
            DB().compareTooltips = false
        end
    end

    local function ApplyCheckboxStatesFromDB()
        local db = DB()
        numpadCheck:SetChecked(db.allowNumPadKeys and true or false)
        showNumbersCheck:SetChecked(db.showNumbers and true or false)
        rewardsTooltipCheck:SetChecked(db.rewardTooltipOnSelect and true or false)
        rewardsCompareCheck:SetChecked(db.compareTooltips and true or false)
        popupSelectCheck:SetChecked(db.popupButtonSelection and true or false)
        whitelistCheck:SetChecked(db.popupWhitelistMode and true or false)
        disablePopupsCheck:SetChecked(db.disablePopupInteractions and true or false)
        postalCheck:SetChecked(db.usePostalOpenAll and true or false)
        wheelCheck:SetChecked((db.scrollWheelSelect ~= false) and (db.scrollWheelSelect == true or (DK.settings and DK.settings.scrollWheelSelect)))

        -- UI affordance: disabling popups greys out whitelist + popupSelect (no functional change needed)
        local disabled = db.disablePopupInteractions and true or false
        if whitelistCheck.Enable and whitelistCheck.Disable then
            if disabled then whitelistCheck:Disable() else whitelistCheck:Enable() end
        end
        if popupSelectCheck.Enable and popupSelectCheck.Disable then
            if disabled then popupSelectCheck:Disable() else popupSelectCheck:Enable() end
        end

        UpdateCompareEnabled()
    end

    numpadCheck:SetScript("OnClick", function(self)
        DB().allowNumPadKeys = self:GetChecked() and true or false
        if DK.EnableOverrides then DK.EnableOverrides() end
    end)
    showNumbersCheck:SetScript("OnClick", function(self)
        DB().showNumbers = self:GetChecked() and true or false
        if DK.NumberGossipButtons then DK.NumberGossipButtons() end
        if DK.NumberQuestButtons then DK.NumberQuestButtons() end
        if DK.NumberRewardButtons then DK.NumberRewardButtons() end
    end)
    rewardsTooltipCheck:SetScript("OnClick", function(self)
        DB().rewardTooltipOnSelect = self:GetChecked() and true or false
        if not DB().rewardTooltipOnSelect and GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
        UpdateCompareEnabled()
    end)
    rewardsCompareCheck:SetScript("OnClick", function(self)
        DB().compareTooltips = self:GetChecked() and true or false
    end)
    popupSelectCheck:SetScript("OnClick", function(self)
        DB().popupButtonSelection = self:GetChecked() and true or false
        if DK.EnableOverrides then DK.EnableOverrides() end
    end)
    whitelistCheck:SetScript("OnClick", function(self)
        DB().popupWhitelistMode = self:GetChecked() and true or false
        if DK.EnableOverrides then DK.EnableOverrides() end
        ApplyCheckboxStatesFromDB()
    end)
    disablePopupsCheck:SetScript("OnClick", function(self)
        DB().disablePopupInteractions = self:GetChecked() and true or false
        if DK.EnableOverrides then DK.EnableOverrides() end
        ApplyCheckboxStatesFromDB()
    end)
    postalCheck:SetScript("OnClick", function(self)
        DB().usePostalOpenAll = self:GetChecked() and true or false
        if DK.EnableOverrides then DK.EnableOverrides() end
    end)
    wheelCheck:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        DB().scrollWheelSelect = enabled
        if DK.SetScrollWheelSelectEnabled then DK.SetScrollWheelSelectEnabled(enabled) end
    end)

    resetBtn:SetScript("OnClick", function()
        local db = DB()
        db.allowNumPadKeys = false
        db.showNumbers = true
        db.rewardTooltipOnSelect = true
        db.compareTooltips = false
        db.popupButtonSelection = false
        db.popupWhitelistMode = false
        db.disablePopupInteractions = false
        db.usePostalOpenAll = true
        db.scrollWheelSelect = false
        if existingPanel.RefreshRulesUI then existingPanel:RefreshRulesUI() end
        DEFAULT_CHAT_FRAME:AddMessage(addonName..": settings reset to defaults")
        if DK.EnableOverrides then DK.EnableOverrides() end
        if DK.SetScrollWheelSelectEnabled then DK.SetScrollWheelSelectEnabled(db.scrollWheelSelect) end
        ApplyCheckboxStatesFromDB()
    end)

    generalPanel:SetScript("OnShow", function()
        ApplyCheckboxStatesFromDB()
    end)
end

-- ======================
-- Create Rule panel
-- ======================
do
    local title = AddTitle(createPanel, "Create Rule")

    local matchLabel = createPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    matchLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TOPGAP)
    matchLabel:SetText("Match by:")

    local matchHolder = CreateFrame("Frame", nil, createPanel); matchHolder:SetSize(160, 22)
    matchHolder:SetPoint("TOPLEFT", matchLabel, "BOTTOMLEFT", 0, -6)
    HookClearFocusOnMouseDown(matchHolder)
    local matchDD = CreateNamedDropdown(addonName.."Create_MatchByDD", matchHolder, 160)
    matchDD:SetAllPoints(matchHolder)
    local matchByState = "text"
    UIDropDownMenu_Initialize(matchDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Text";  info.func = function() matchByState = "text";  SetDropdownText(matchDD, "Text")  end; UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Frame"; info.func = function() matchByState = "frame"; SetDropdownText(matchDD, "Frame") end; UIDropDownMenu_AddButton(info, level)
    end)
    SetDropdownText(matchDD, "Text")
    Tooltipify(matchDD, "Match by", "Text: scans popup body and button labels for a CASE-INSENSITIVE substring match.\nFrame: triggers when a popup with the exact frame name (e.g., StaticPopup1) is visible.")
    HideDropDownBlizzardTextures(matchDD); RestyleDropdown(matchDD, 160)

    local actionLabel = createPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    actionLabel:SetPoint("TOPLEFT", matchHolder, "BOTTOMLEFT", 0, -TOPGAP)
    actionLabel:SetText("Action:")

    local actionHolder = CreateFrame("Frame", nil, createPanel); actionHolder:SetSize(200, 22)
    actionHolder:SetPoint("TOPLEFT", actionLabel, "BOTTOMLEFT", 0, -6)
    HookClearFocusOnMouseDown(actionHolder)
    local actionDD = CreateNamedDropdown(addonName.."Create_ActionDD", actionHolder, 200)
    actionDD:SetAllPoints(actionHolder)
    local actionState = 2
    UIDropDownMenu_Initialize(actionDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Ignore (0)";  info.func = function() actionState = 0; SetDropdownText(actionDD, "Ignore (0)") end; UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Button1 (1)"; info.func = function() actionState = 1; SetDropdownText(actionDD, "Button1 (1)") end; UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Button2 (2)"; info.func = function() actionState = 2; SetDropdownText(actionDD, "Button2 (2)") end; UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Button3 (3)"; info.func = function() actionState = 3; SetDropdownText(actionDD, "Button3 (3)") end; UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Button4 (4)"; info.func = function() actionState = 4; SetDropdownText(actionDD, "Button4 (4)") end; UIDropDownMenu_AddButton(info, level)
    end)
    SetDropdownText(actionDD, "Button2 (2)")
    Tooltipify(actionDD, "Action", "0: Ignore (do nothing)\n1: Click Button1 (primary)\n2: Click Button2 (secondary)\n3: Click Button3\n4: Click Button4")
    HideDropDownBlizzardTextures(actionDD); RestyleDropdown(actionDD, 200)

    local nameLabel = createPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", actionHolder, "BOTTOMLEFT", 0, -TOPGAP)
    nameLabel:SetText("Rule name:")

    local nameEdit = CreateEditBox(createPanel, 420)
    nameEdit:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(nameEdit, "Rule name", "Friendly name to identify this rule (must be unique).")

    local patLabel = createPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    patLabel:SetPoint("TOPLEFT", nameEdit, "BOTTOMLEFT", 0, -TOPGAP)
    patLabel:SetText("Pattern / frame name:")

    local patEdit = CreateEditBox(createPanel, 420)
    patEdit:SetPoint("TOPLEFT", patLabel, "BOTTOMLEFT", 0, -ROWGAP)
    Tooltipify(patEdit, "Pattern or frame", "Text mode: case-insensitive substring search in popup body and button labels.\nFrame mode: exact StaticPopup frame name, e.g., StaticPopup1.")

    -- Right-side utility buttons
    local prefillBtn = CreateButton(createPanel, "Prefill from popup", 160, 22)
    prefillBtn:ClearAllPoints()
    prefillBtn:SetPoint("TOPRIGHT", patEdit, "BOTTOMRIGHT", 0, -TOPGAP)
    Tooltipify(prefillBtn, "Prefill", "If a popup is visible, capture its frame name and set Match by = Frame.")

    local testBtn = CreateButton(createPanel, "Test match", 160, 22)
    testBtn:SetPoint("TOPRIGHT", prefillBtn, "BOTTOMRIGHT", 0, -ROWGAP)
    Tooltipify(testBtn, "Test", "Test the current pattern against the visible popup (if any).")

    local fstackBtn = CreateButton(createPanel, "Toggle fstack", 160, 22)
    fstackBtn:SetPoint("TOPRIGHT", testBtn, "BOTTOMRIGHT", 0, -ROWGAP)
    Tooltipify(fstackBtn, "Toggle fstack", "Show/hide Blizzard Frame Stack to inspect frame names.")
    local function ToggleFStack()
        if UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_DebugTools") end
        if FrameStackTooltip_Toggle then FrameStackTooltip_Toggle()
        elseif FrameStackTooltip then
            if FrameStackTooltip:IsShown() then FrameStackTooltip:Hide() else FrameStackTooltip:Show() end
        end
    end
    fstackBtn:SetScript("OnClick", ToggleFStack)

    local addBtn = CreateButton(createPanel, "Add Rule", 140, 24)
    addBtn:SetPoint("BOTTOMLEFT", createPanel, "BOTTOMLEFT", LEFT, LEFT)
    Tooltipify(addBtn, "Add Rule", "Create a new rule using the fields above (name must be unique).")

    local function GetVisiblePopupInfo()
        for i = 1, 4 do
            local sp = _G["StaticPopup"..i]
            if sp and sp:IsVisible() then
                local frameName = sp:GetName() or ("StaticPopup"..i)
                local textObj = _G[frameName.."Text"]
                local popupText = (textObj and textObj.GetText and textObj:GetText()) or ""
                return frameName, popupText
            end
        end
        return nil, nil
    end

    addBtn:SetScript("OnClick", function()
        ClearActiveEditFocus()
        local name = (nameEdit:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        local pat  = (patEdit:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        if name == "" then DEFAULT_CHAT_FRAME:AddMessage(addonName..": rule name cannot be empty"); return end
        if pat  == "" then DEFAULT_CHAT_FRAME:AddMessage(addonName..": pattern cannot be empty"); return end

        local rules = DB().popupRules or {}
        for _, r in ipairs(rules) do
            if type(r.name) == "string" and string.lower(r.name) == string.lower(name) then
                DEFAULT_CHAT_FRAME:AddMessage(addonName..": a rule named '"..name.."' already exists")
                return
            end
        end

        if not DK.AddPopupRule then
            DEFAULT_CHAT_FRAME:AddMessage(addonName..": rule subsystem not available"); return
        end
        local ok, err = DK.AddPopupRule(matchByState, pat, tonumber(actionState) or 0)
        if ok then
            local rr = DB().popupRules or {}
            if rr[#rr] then rr[#rr].name = name; DB().popupRules = rr end
            nameEdit:SetText(""); patEdit:SetText("")
            DEFAULT_CHAT_FRAME:AddMessage(addonName..": rule added")
            if existingPanel.RefreshRulesUI then existingPanel:RefreshRulesUI() end
        else
            DEFAULT_CHAT_FRAME:AddMessage(addonName..": failed to add rule: "..tostring(err))
        end
    end)

    prefillBtn:SetScript("OnClick", function()
        ClearActiveEditFocus()
        local frameName, _ = GetVisiblePopupInfo()
        if frameName then
            matchByState = "frame"; SetDropdownText(matchDD, "Frame"); RestyleDropdown(matchDD, 160)
            actionState = 2; SetDropdownText(actionDD, "Button2 (2)"); RestyleDropdown(actionDD, 200)
            local nm = "From "..frameName
            if nm:len() > 64 then nm = nm:sub(1, 64) end
            nameEdit:SetText(nm)
            patEdit:SetText(frameName)
        else
            DEFAULT_CHAT_FRAME:AddMessage(addonName..": no visible popup was detected")
        end
    end)

    testBtn:SetScript("OnClick", function()
        ClearActiveEditFocus()
        local frameName, popupText = GetVisiblePopupInfo()
        if not frameName then DEFAULT_CHAT_FRAME:AddMessage(addonName..": no visible popup to test"); return end
        local pat = (patEdit:GetText() or "")
        local matched = false
        if matchByState == "frame" then
            matched = (pat ~= "" and frameName == pat)
        else
            local text = string.lower(popupText or "")
            matched = (pat ~= "" and text:find(string.lower(pat), 1, true) ~= nil)
        end
        DEFAULT_CHAT_FRAME:AddMessage(addonName..": Test result -> "..(matched and "|cff00ff00MATCH|r" or "|cffff2020NO MATCH|r"))
    end)

    local function RelayoutCreate()
        local w = math.max(360, (createPanel:GetWidth() or 600) - LEFT*2)
        local ebW = math.min(520, w)
        nameEdit:SetWidth(ebW)
        patEdit:SetWidth(ebW)
        RestyleDropdown(matchDD, 160)
        RestyleDropdown(actionDD, 200)
    end
    createPanel:SetScript("OnSizeChanged", RelayoutCreate)
    createPanel:SetScript("OnShow", function()
        RestyleDropdown(matchDD, 160)
        RestyleDropdown(actionDD, 200)
        RelayoutCreate()
    end)
end

-- ======================
-- Existing Rules panel (filter + scrollable cards; vertical controls; click-to-rename in place)
-- ======================
do
    local title = AddTitle(existingPanel, "Existing Rules")

    local filterEdit = CreateEditBox(existingPanel, 260)
    filterEdit:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TOPGAP)
    filterEdit:SetAutoFocus(false)
    filterEdit:SetText("")
    HookClearFocusOnMouseDown(existingPanel)
    local hint = existingPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", filterEdit, "LEFT", 8, 0)
    hint:SetText("Search rules by name or pattern...")
    hint:SetTextColor(0.8, 0.8, 0.8, 0.8)
    local function SetShownCompat(f, shown) if not f then return end; if shown then if f.Show then f:Show() end else if f.Hide then f:Hide() end end end
    local function UpdateFilterHint()
        local txt = filterEdit:GetText() or ""
        local focused = false
        if filterEdit.HasFocus then focused = filterEdit:HasFocus() end
        SetShownCompat(hint, (txt == "" and not focused))
    end
    filterEdit:HookScript("OnTextChanged", UpdateFilterHint)
    filterEdit:HookScript("OnEditFocusGained", UpdateFilterHint)
    filterEdit:HookScript("OnEditFocusLost", UpdateFilterHint)
    UpdateFilterHint()
    Tooltipify(filterEdit, "Filter", "Type to filter rules by name or pattern")

    local scroll = CreateFrame("ScrollFrame", addonName.."Existing_Scroll", existingPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filterEdit, "BOTTOMLEFT", 0, -TOPGAP)
    scroll:SetPoint("BOTTOMRIGHT", existingPanel, "BOTTOMRIGHT", -(LEFT + 14), LEFT)
    HookClearFocusOnMouseDown(scroll)

    local content = CreateFrame("Frame", addonName.."Existing_Content", scroll)
    content:SetPoint("TOPLEFT"); content:SetSize(1,1)
    scroll:SetScrollChild(content)
    HookClearFocusOnMouseDown(content)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local sb = _G[self:GetName().."ScrollBar"]; if not sb then return end
        local step = 24
        local new = (sb:GetValue() or 0) - delta * step
        local minV, maxV = sb:GetMinMaxValues()
        if new < minV then new = minV end
        if new > maxV then new = maxV end
        sb:SetValue(new); self:SetVerticalScroll(new)
    end)

    local function computeCardWidth()
        local panelW = existingPanel:GetWidth() or 600
        local viewW = panelW - LEFT - (SCROLLBAR_RESERVE or 36)
        return math.min(CARD_MAX_WIDTH or 540, math.max(CARD_MIN_WIDTH or 360, viewW))
    end

    local function CreateRadio(parent, labelText, group, onChange, value, tooltipTitle, tooltipBody)
        local cb, lbl = CreateSmallCheckbox(parent, labelText)
        if tooltipTitle or tooltipBody then Tooltipify(cb, tooltipTitle, tooltipBody) end
        cb:SetScript("OnClick", function(self)
            for _, b in ipairs(group) do b:SetChecked(false) end
            self:SetChecked(true)
            if onChange then onChange(value) end
        end)
        table.insert(group, cb)
        return cb, lbl
    end

    local function CreateRuleCard(parent, index, rule, cardWidth)
        local card = CreateFrame("Frame", addonName.."RuleCard"..index, parent)
        card:SetWidth(cardWidth)
        card:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        card:SetBackdropColor(0,0,0,0.25)
        card:SetBackdropBorderColor(0.3,0.3,0.3,1)
        card:SetFrameLevel((parent:GetFrameLevel() or 1) + 1)

        local x = CARD_PAD
        local y = -CARD_PAD

        local titleFS = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        titleFS:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
        titleFS:SetJustifyH("LEFT")
        titleFS:SetText((rule.name and rule.name ~= "" and rule.name) or "Unnamed rule")

        local titleBtn = CreateFrame("Button", nil, card)
        titleBtn:SetPoint("TOPLEFT", titleFS, "TOPLEFT", -2, 2)
        titleBtn:SetPoint("BOTTOMRIGHT", titleFS, "BOTTOMRIGHT", 2, -2)
        titleBtn:RegisterForClicks("LeftButtonDown")
        Tooltipify(titleBtn, "Rename", "Click the title to rename this rule")
        titleBtn:SetScript("OnClick", function()
            local nameEB = CreateEditBox(card, (cardWidth or 400) - CARD_PAD*2)
            nameEB:ClearAllPoints()
            nameEB:SetPoint("TOPLEFT", titleFS, "TOPLEFT", -2, 2)
            nameEB:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
            local rowH = math.max(22, (titleFS.GetStringHeight and titleFS:GetStringHeight()) or 22)
            nameEB:SetHeight(rowH + 6)

            local original = titleFS:GetText() or ""
            nameEB:SetText(original)
            nameEB:HighlightText(0, -1)
            nameEB:SetFocus()

            nameEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            nameEB:SetScript("OnEscapePressed", function(self) self:SetText(original); self:ClearFocus() end)
            nameEB:HookScript("OnEditFocusLost", function(self)
                local nv = (self:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
                rule.name = nv
                titleFS:SetText(nv ~= "" and nv or "Unnamed rule")
                if ActiveEditBox == self then ActiveEditBox = nil end
                self:Hide(); self:SetParent(nil)
            end)
        end)

        local titleH = (titleFS.GetStringHeight and titleFS:GetStringHeight()) or 22
        y = y - math.max(titleH, 22) - 10

        local matchLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        matchLabel:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
        matchLabel:SetText("Match:")

        local radiosMatch = {}
        local function updatePatternTitle()
            if card._patLabel then
                card._patLabel:SetText((rule.matchBy == "frame") and "Name:" or "Pattern:")
                if card._patEB then
                    if rule.matchBy == "frame" then
                        Tooltipify(card._patEB, "Name", "Exact StaticPopup frame name, e.g., StaticPopup1. Triggers when that frame is visible.")
                    else
                        Tooltipify(card._patEB, "Pattern", "Case-insensitive substring search across the popup body and button labels.")
                    end
                end
            end
        end

        local rText  = CreateRadio(card, "Text",  radiosMatch, function() rule.matchBy = "text";  updatePatternTitle() end, "text", "Match mode", "Text: case-insensitive substring of popup body or buttons")
        rText:SetPoint("LEFT", matchLabel, "RIGHT", 16, 0)
        local rFrame = CreateRadio(card, "Frame", radiosMatch, function() rule.matchBy = "frame"; updatePatternTitle() end, "frame", "Match mode", "Frame: exact StaticPopup frame name (e.g., StaticPopup1)")
        rFrame:SetPoint("LEFT", rText, "RIGHT", MATCH_RADIO_GAP_X, 0)
        if (rule.matchBy == "frame") then rFrame:SetChecked(true) else rText:SetChecked(true) end
        if rText._dkUpdateHitRect then rText:_dkUpdateHitRect() end
        if rFrame._dkUpdateHitRect then rFrame:_dkUpdateHitRect() end

        local rowH1 = rText:GetHeight() or 18
        y = y - rowH1 - 12

        local patLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        card._patLabel = patLabel
        patLabel:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
        patLabel:SetText((rule.matchBy == "frame") and "Name:" or "Pattern:")
        local labelW = (patLabel:GetStringWidth() or 50)

        local patEB = CreateEditBox(card, cardWidth - CARD_PAD*2 - labelW - 8)
        card._patEB = patEB
        patEB:ClearAllPoints()
        patEB:SetPoint("LEFT", patLabel, "RIGHT", 8, 0)
        patEB:SetText(rule.pattern or "")
        patEB:HookScript("OnEditFocusLost", function(self) rule.pattern = (self:GetText() or "") end)
        if rule.matchBy == "frame" then
            Tooltipify(patEB, "Name", "Exact StaticPopup frame name, e.g., StaticPopup1. Triggers when that frame is visible.")
        else
            Tooltipify(patEB, "Pattern", "Case-insensitive substring search across the popup body and button labels.")
        end

        local patRowH = math.max(patEB:GetHeight() or 20, 18)
        y = y - patRowH - 12

        local actionLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        actionLabel:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
        actionLabel:SetText("Action:")

        local radiosAction = {}
        local ra0 = CreateRadio(card, "0", radiosAction, function() rule.action = 0 end, 0, "Action 0: Ignore", "Do nothing when this rule matches the popup.")
        ra0:SetPoint("LEFT", actionLabel, "RIGHT", 16, 0)
        local ra1 = CreateRadio(card, "1", radiosAction, function() rule.action = 1 end, 1, "Action 1: Button1", "Click the primary (left) button of the popup.")
        ra1:SetPoint("LEFT", ra0, "RIGHT", ACTION_RADIO_GAP_X, 0)
        local ra2 = CreateRadio(card, "2", radiosAction, function() rule.action = 2 end, 2, "Action 2: Button2", "Click the secondary (right) button of the popup.")
        ra2:SetPoint("LEFT", ra1, "RIGHT", ACTION_RADIO_GAP_X, 0)
        local ra3 = CreateRadio(card, "3", radiosAction, function() rule.action = 3 end, 3, "Action 3: Button3", "Click the third button of the popup.")
        ra3:SetPoint("LEFT", ra2, "RIGHT", ACTION_RADIO_GAP_X, 0)
        local ra4 = CreateRadio(card, "4", radiosAction, function() rule.action = 4 end, 4, "Action 4: Button4", "Click the fourth button of the popup.")
        ra4:SetPoint("LEFT", ra3, "RIGHT", ACTION_RADIO_GAP_X, 0)

        local a = tonumber(rule.action) or 0
        if a == 1 then ra1:SetChecked(true)
        elseif a == 2 then ra2:SetChecked(true)
        elseif a == 3 then ra3:SetChecked(true)
        elseif a == 4 then ra4:SetChecked(true)
        else ra0:SetChecked(true) end

        for _, r in ipairs({ra0,ra1,ra2,ra3,ra4}) do if r._dkUpdateHitRect then r:_dkUpdateHitRect() end end

        local rowH2 = ra0:GetHeight() or 18
        y = y - rowH2 - 12

        local enableCB = CreateSmallCheckbox(card, "Enabled")
        enableCB:SetPoint("TOPLEFT", card, "TOPLEFT", x-2, y)
        enableCB:SetChecked(rule.enabled ~= false)
        enableCB:SetScript("OnClick", function(self) rule.enabled = self:GetChecked() and true or false end)

        local removeBtn = CreateButton(card, "Delete", 90, 20)
        removeBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, y - 2)
        Tooltipify(removeBtn, "Delete rule", "Hold Shift and click to permanently delete this rule.")
        removeBtn:SetScript("OnClick", function()
            ClearActiveEditFocus()
            if not IsShiftKeyDown() then
                DEFAULT_CHAT_FRAME:AddMessage(addonName..": Hold Shift and click Delete to remove this rule.")
                return
            end
            if DK.RemovePopupRule then DK.RemovePopupRule(index)
            else
                local rules = DB().popupRules or {}
                table.remove(rules, index); DB().popupRules = rules
            end
            if existingPanel.RefreshRulesUI then existingPanel:RefreshRulesUI() end
        end)

        local rowH3 = math.max(enableCB:GetHeight() or 18, removeBtn:GetHeight() or 20)
        y = y - rowH3 - CARD_PAD

        card:SetHeight(-y)
        return card
    end

    function existingPanel:RefreshRulesUI()
        if content._cards then
            for _, f in ipairs(content._cards) do f:Hide(); f:SetParent(nil) end
        end
        content._cards = {}

        local filter = string.lower((filterEdit:GetText() or "")):gsub("^%s+",""):gsub("%s+$","")
        local rules  = DB().popupRules or {}
        local cardW  = computeCardWidth()

        local y = 0
        for i, r in ipairs(rules) do
            local name = r.name or ""
            local pat  = r.pattern or ""
            if filter == "" or string.find(string.lower(name), filter, 1, true) or string.find(string.lower(pat), filter, 1, true) then
                local card = CreateRuleCard(content, i, r, cardW)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                table.insert(content._cards, card)
                y = y + (card:GetHeight() or 180) + (CARD_SPACING_Y or 12)
            end
        end

        content:SetWidth(cardW)
        content:SetHeight(math.max(1, y))

        local sb = _G[scroll:GetName().."ScrollBar"]
        if sb then
            local childH = content:GetHeight() or 0
            local frameH = scroll:GetHeight() or 0
            local yRange = math.max(0, childH - frameH)
            sb:SetMinMaxValues(0, yRange)
            local cur = sb:GetValue() or 0
            if cur > yRange then cur = yRange end
            sb:SetValue(cur)
            scroll:SetVerticalScroll(cur)
            SetShownCompat(sb, yRange > 0)
            if yRange == 0 then scroll:SetVerticalScroll(0) end
        end
    end

    local function RefreshResponsive()
        existingPanel:RefreshRulesUI()
        UpdateFilterHint()
    end
    existingPanel:SetScript("OnSizeChanged", RefreshResponsive)
    existingPanel:SetScript("OnShow", RefreshResponsive)
    filterEdit:SetScript("OnTextChanged", RefreshResponsive)
end