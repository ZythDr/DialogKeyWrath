-- Dialogs.lua: Gossip/Quest greeting numbering + best-target logic (SPACE priority)
local addonName = "DialogKeyWrath"
local DK = _G[addonName.."Frame"]
if not DK then return end
local U = DK.Util

DK.Dialogs = DK.Dialogs or {}

-- Gossip & Quest numbering
local function NumberGossipButtons()
    if not DK.settings.showNumbers or not GossipFrame or not GossipFrame:IsVisible() then
        for i = 1, 32 do local b = _G["GossipTitleButton"..i] if b then U.RestoreOriginalText(b) end end
        return
    end
    local count = 1
    for i = 1, 32 do
        local btn = _G["GossipTitleButton"..i]
        if btn and btn:IsVisible() then
            local fs = U.SafeGetFontString(btn)
            local txt = fs and fs:GetText()
            if txt and txt ~= "" then
                if count <= 10 then
                    local stripped = txt:gsub("^%d+%.%s+", "")
                    btn.dkOrigText = stripped
                    local ok, r,g,b = pcall(fs.GetTextColor, fs)
                    btn.dkOrigColor = ok and {r,g,b} or {1,1,1}
                    fs:SetText(("%d. %s"):format(count, stripped))
                    pcall(fs.SetTextColor, fs, unpack(btn.dkOrigColor))
                else
                    U.RestoreOriginalText(btn)
                end
                count = count + 1
            else
                U.RestoreOriginalText(btn)
            end
        else
            if btn then U.RestoreOriginalText(btn) end
        end
    end
end

local function NumberQuestButtons()
    if not DK.settings.showNumbers or not QuestFrameGreetingPanel or not QuestFrameGreetingPanel:IsVisible() then
        for i = 1, 10 do local b = _G["QuestTitleButton"..i] if b then U.RestoreOriginalText(b) end end
        return
    end
    local useElv = false
    if DK.settings.detectElvUI ~= false then
        if IsAddOnLoaded and IsAddOnLoaded("ElvUI") then useElv = true end
        if not useElv and _G.ElvUI then useElv = true end
    end
    local count = 1
    for i = 1, 10 do
        local btn = _G["QuestTitleButton"..i]
        if btn and btn:IsVisible() then
            local fs = U.SafeGetFontString(btn)
            local txt = fs and fs:GetText()
            if txt and txt ~= "" then
                if count <= 10 then
                    local stripped = txt:gsub("^%d+%.%s+", "")
                    btn.dkOrigText = stripped
                    local ok, r,g,b = pcall(fs.GetTextColor, fs)
                    btn.dkOrigColor = ok and {r,g,b} or {1,1,1}
                    fs:SetText(("%d. %s"):format(count, stripped))
                    if useElv then pcall(fs.SetTextColor, fs, 1,1,0) else pcall(fs.SetTextColor, fs, unpack(btn.dkOrigColor)) end
                else
                    U.RestoreOriginalText(btn)
                end
                count = count + 1
            else
                U.RestoreOriginalText(btn)
            end
        else
            if btn then U.RestoreOriginalText(btn) end
        end
    end
end

-- Icon classification & best list item
local function GetIconPathFromButton(btn)
    if not btn then return nil end

    -- 1) Direct child references commonly used by greeting buttons
    if btn.Icon and btn.Icon.IsShown and btn.Icon:IsShown() and btn.Icon.GetTexture then
        local p = btn.Icon:GetTexture()
        if type(p) == "string" and p ~= "" then return p end
    end
    local n = btn.GetName and btn:GetName()
    if n then
        local ic = _G[n.."Icon"]
        if ic and ic.IsShown and ic:IsShown() and ic.GetTexture then
            local p = ic:GetTexture()
            if type(p) == "string" and p ~= "" then return p end
        end
    end

    -- 2) Normal texture
    if btn.GetNormalTexture then
        local nt = btn:GetNormalTexture()
        if nt and nt.GetTexture then
            local p = nt:GetTexture()
            if type(p) == "string" and p ~= "" then return p end
        end
    end

    -- 3) Region scan (wider and more permissive)
    for i = 1, 20 do
        local r = select(i, btn:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.IsShown and r:IsShown() then
            local w = (r.GetWidth and r:GetWidth()) or 0
            local h = (r.GetHeight and r:GetHeight()) or 0
            if w >= 8 and w <= 32 and h >= 8 and h <= 32 then
                if r.GetTexture then
                    local p = r:GetTexture()
                    if type(p) == "string" and p ~= "" then
                        return p
                    end
                end
            end
        end
    end

    return nil
end

local function ClassifyQuestIcon(btn)
    local path = GetIconPathFromButton(btn)
    if not path or type(path) ~= "string" then return 0 end
    local p = string.lower(path)
    if string.find(p, "activequesticon", 1, true) then return 3
    elseif string.find(p, "availablequesticon", 1, true) then return 2
    elseif string.find(p, "incompletequesticon", 1, true) then return 1
    else return 0 end
end

local function FirstVisibleListButton(prefix, max)
    for i = 1, max do
        local btn = _G[prefix..i]
        if btn and btn:IsVisible() and btn:IsEnabled() then
            local fs = U.SafeGetFontString(btn)
            local txt = fs and fs:GetText()
            if txt and txt ~= "" then return btn end
        end
    end
    return nil
end

local function BestQuestOrGossipButton()
    local best, bestScore, bestIdx

    local function considerList(prefix, max)
        for i = 1, max do
            local btn = _G[prefix..i]
            if btn and btn:IsVisible() and btn:IsEnabled() then
                local fs = U.SafeGetFontString(btn)
                local txt = fs and fs:GetText()
                if txt and txt ~= "" then
                    local score = ClassifyQuestIcon(btn) -- 3 (Completed) > 2 (Available) > 1 (In-progress)
                    if score > 0 and (not best or score > bestScore or (score == bestScore and i < bestIdx)) then
                        best, bestScore, bestIdx = btn, score, i
                    end
                end
            end
        end
    end

    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
        considerList("QuestTitleButton", 10)
        if not best then
            -- If icons not yet detected (frame just refreshed), stick to last best if still valid
            local lb = DK._lastBestListTarget
            if lb and lb:IsVisible() and lb:IsEnabled() then
                return lb
            end
            -- As last resort, top visible
            best = FirstVisibleListButton("QuestTitleButton", 10)
        end
    elseif GossipFrame and GossipFrame:IsVisible() then
        considerList("GossipTitleButton", 32)
        if not best then
            local lb = DK._lastBestListTarget
            if lb and lb:IsVisible() and lb:IsEnabled() then
                return lb
            end
            best = FirstVisibleListButton("GossipTitleButton", 32)
        end
    end

    -- Remember for stability across transient UI changes (e.g., after popups)
    if best then DK._lastBestListTarget = best end

    return best
end

-- Initialize list/gossip/staticpopup button hover/click highlights (uses Core's handler)
local function InitializeListButtons()
    for i = 1, 10 do if _G["QuestTitleButton"..i] then DK._HandleButtonMouseEvents(_G["QuestTitleButton"..i]) end end
    for i = 1, 32 do if _G["GossipTitleButton"..i] then DK._HandleButtonMouseEvents(_G["GossipTitleButton"..i]) end end
    for _, b in pairs({ QuestFrameAcceptButton, QuestFrameCompleteButton, QuestFrameCompleteQuestButton }) do
        if b then DK._HandleButtonMouseEvents(b) end
    end
    for i = 1, 4 do
        local sp = _G["StaticPopup"..i]
        if sp then for j = 1, 4 do local btn = sp["button"..j] if btn then DK._HandleButtonMouseEvents(btn) end end end
    end
end

-- Exports
DK.Dialogs.GetIconPathFromButton = GetIconPathFromButton
DK.Dialogs.ClassifyQuestIcon = ClassifyQuestIcon
DK.Dialogs.BestQuestOrGossipButton = BestQuestOrGossipButton
DK.NumberGossipButtons = NumberGossipButtons
DK.NumberQuestButtons = NumberQuestButtons
DK.Dialogs.InitializeListButtons = InitializeListButtons