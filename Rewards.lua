-- Rewards.lua: Quest reward overlays, tooltip toggle, and reward key bindings (1..0 and SHIFT-1..0)
local addonName = "DialogKeyWrath"
local DK = _G[addonName.."Frame"]
if not DK then return end
local U = DK.Util
local DB = DK.DB

DK.Rewards = DK.Rewards or {}

-- Overlays
local function RemoveRewardNumberOverlay(btn)
    if btn and btn.dkNumberOverlay then
        btn.dkNumberOverlay:Hide()
        btn.dkNumberOverlay:SetParent(nil)
        btn.dkNumberOverlay = nil
        btn.dkNumberFS = nil
    end
end

local function CreateRewardNumberOverlay(btn, index)
    if not btn then return end
    if btn.dkNumberFS then
        btn.dkNumberFS:SetText(tostring(index))
        btn.dkNumberFS:Show()
        return
    end
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(9999)
    local fs = overlay:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 18, "THICKOUTLINE")
    fs:SetPoint("LEFT", btn, "LEFT", 12.5, 0)
    fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
    fs:SetText(tostring(index)); fs:SetTextColor(1,1,1)
    btn.dkNumberOverlay = overlay
    btn.dkNumberFS = fs
end

-- Tooltip helpers
local function ShowRewardTooltip(btn)
    if not btn or not DB().rewardTooltipOnSelect then return end
    if not GameTooltip or not btn.GetID then return end
    local id = btn:GetID() or 0
    if id <= 0 then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    local t = (btn.type == "reward") and "reward" or "choice"
    if GameTooltip.SetQuestItem then
        GameTooltip:SetQuestItem(t, id)
        GameTooltip:Show()
        -- Comparison tooltips if Shift held or setting enabled
        if (IsShiftKeyDown() or DB().compareTooltips) and GameTooltip_ShowCompareItem then
            pcall(GameTooltip_ShowCompareItem, GameTooltip)
        end
        DK._rewardTooltipBtn = btn
    end
end

local function HideRewardTooltip(btn)
    if GameTooltip and GameTooltip.Hide then
        if (not btn) or DK._rewardTooltipBtn == btn then
            GameTooltip:Hide()
            DK._rewardTooltipBtn = nil
        end
    else
        DK._rewardTooltipBtn = nil
    end
end

-- Only overlay/hide hooks here (tooltip toggle is handled by click hooks below)
local function HookRewardButtons()
    for i = 1, 10 do
        local btn = _G["QuestInfoItem"..i]
        if btn and not btn.dkHooked then
            btn:HookScript("OnShow", function(self)
                if DB().showNumbers and QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() then
                    CreateRewardNumberOverlay(self, self.dkIndex or i)
                else
                    RemoveRewardNumberOverlay(self)
                end
            end)
            btn:HookScript("OnHide", function(self)
                RemoveRewardNumberOverlay(self)
                if DK._rewardTooltipBtn == self then
                    HideRewardTooltip(self)
                end
            end)
            btn.dkHooked = true
        end
    end
end

-- Number visible rewards
local function NumberRewardButtons()
    if not DB().showNumbers or not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsVisible() then
        for i = 1, 10 do local b = _G["QuestInfoItem"..i] if b then RemoveRewardNumberOverlay(b) end end
        return
    end
    HookRewardButtons()
    local count = 1
    for i = 1, 10 do
        local btn = _G["QuestInfoItem"..i]
        if btn and btn:IsVisible() then
            btn.dkIndex = count
            CreateRewardNumberOverlay(btn, count)
            count = count + 1
        else
            if btn then RemoveRewardNumberOverlay(btn) end
        end
    end
end

-- Toggle tooltip on click (mouse or number-key click)
local function InitializeRewardHooks()
    for i = 1, 10 do
        local btn = _G["QuestInfoItem"..i]
        if btn and not btn.dkRewardHooked then
            -- keep existing highlight/selection behavior
            btn:HookScript("OnClick", function(self)
                if DK._selectedReward and DK._selectedReward ~= self then U.RemoveHighlight(DK._selectedReward) end
                if DB().rewardTooltipOnSelect then
                    if DK._rewardTooltipBtn == self then
                        HideRewardTooltip(self)
                    else
                        ShowRewardTooltip(self)
                    end
                end
                DK._selectedReward = self
                U.ApplyHighlight(self)
            end)
            btn:HookScript("OnHide", function(self)
                if DK._rewardTooltipBtn == self then
                    HideRewardTooltip(self)
                end
            end)
            btn.dkRewardHooked = true
        end
    end
end

-- Bind number keys for quest rewards (also bind SHIFT-<digit> + optional NUMPAD keys)
local function BindNumberKeysForRewards()
    local owner = DK._bindingOwner
    if not owner then return end
    local ct = 1
    for i = 1, 10 do
        local btn = _G["QuestInfoItem"..i]
        if btn and btn:IsVisible() then
            if ct <= 10 then
                local key = (ct < 10) and tostring(ct) or "0"
                local click = "CLICK "..btn:GetName()..":LeftButton"
                SetOverrideBinding(owner, false, key, click)
                SetOverrideBinding(owner, false, "SHIFT-"..key, click)
                if DB().allowNumPadKeys then
                    local nk = (key == "0") and "NUMPAD0" or ("NUMPAD"..key)
                    SetOverrideBinding(owner, false, nk, click)
                    SetOverrideBinding(owner, false, "SHIFT-"..nk, click)
                end
            end
            ct = ct + 1
            if ct > 10 then break end
        end
    end
end

-- Exports for Core/GUI
DK.Rewards.RemoveRewardNumberOverlay = RemoveRewardNumberOverlay
DK.Rewards.CreateRewardNumberOverlay = CreateRewardNumberOverlay
DK.NumberRewardButtons = NumberRewardButtons
DK.Rewards.BindNumberKeysForRewards = BindNumberKeysForRewards
DK.Rewards.InitializeRewardHooks = InitializeRewardHooks
DK.Rewards.HideTooltip = HideRewardTooltip