local function HighlightSpaceButton(btn)
   if spaceHighlight and spaceHighlight ~= btn then
       RemoveHighlight(spaceHighlight)
   end
   if btn then
       ApplyHighlight(btn)
   end
   spaceHighlight = btn
end

local function ClearSpaceHighlight()
   if spaceHighlight then
       RemoveHighlight(spaceHighlight)
   end
   spaceHighlight = nil
end

local function ClearAllButtonHighlights()
   for i = 1, 10 do
       local b = _G["QuestTitleButton"..i]
       if b then
           RemoveHighlight(b)
       end
   end
end

local function EnableOverride(frame)
   -- Create a secure frame for the action that is being overridden
   local secureFrame = CreateFrame("Frame", "DialogKeyWrathSecureFrame", UIParent)
   secureFrame:SetAttribute("type", "button")
   secureFrame:SetAttribute("text", "SecureFrame")
   secureFrame:SetAttribute("width", 100)
   secureFrame:SetAttribute("height", 100)

   -- Set the secure frame as the target for the keybinding
   local keybinding = _G["QuestFrameRewardButton"]:GetKeybinding()
   keybinding:SetTarget(secureFrame)

   -- Redirect the keybinding to the secure frame
   keybinding:SetScript("OnPress", function()
       secureFrame:Fire()
   end)

   -- Highlight the secure frame
   HighlightSpaceButton(secureFrame)
end

local function DisableOverride(frame)
   -- Remove the secure frame
   if secureFrame then
       secureFrame:Hide()
       secureFrame:Release()
       secureFrame = nil
   end

   -- Remove the keybinding target
   local keybinding = _G["QuestFrameRewardButton"]:GetKeybinding()
   keybinding:SetTarget(nil)

   -- Remove the keybinding script
   keybinding:SetScript("OnPress", nil)
end

-- Enable the override mechanic when the quest frame is visible
local function EnableOverrideOnQuestFrameShow()
   local questFrame = _G.QuestFrame
   if questFrame then
       EnableOverride(questFrame)
   end
end

-- Disable the override mechanic when the quest frame is hidden
local function DisableOverrideOnQuestFrameHide()
   local questFrame = _G.QuestFrame
   if questFrame then
       DisableOverride(questFrame)
   end
end

-- Update the override state when the user enters or exits combat
local function UpdateOverrideState()
   local player = _G.Player
   if player then
       if player.InCombat then
           DisableOverride(player.QuestFrame)
       else
           EnableOverride(player.QuestFrame)
       end
   end
end

-- Register the events for the override mechanic
local function RegisterEvents()
   -- Register the quest frame show and hide events
   _G.QuestFrame:Hide()
   _G.QuestFrame:Show()
   _G.QuestFrame:Hide()

   -- Register the combat enter and exit events
   local player = _G.Player
   if player then
       player.EnterCombat:Register()
       player.LeaveCombat:Register()
   end
end

-- Initialize the override mechanic
local function InitializeOverride()
   -- Create the secure frames for the quest rewards
   EnableOverride(QuestFrameRewardButton)

   -- Register the events for the override mechanic
   RegisterEvents()
end

-- Cleanup the override mechanic
local function CleanupOverride()
   -- Remove the secure frames for the quest rewards
   DisableOverride(QuestFrameRewardButton)

   -- Unregister the events for the override mechanic
   UnregisterEvents()
end

-- Update the override state when the user enters or exits combat
UpdateOverrideState()

-- Initialize the override mechanic
InitializeOverride()

-- Cleanup the override mechanic when the addon is unloaded
local function Unload()
   CleanupOverride()
end

-- Export the functions for the override mechanic
local function EnableOverride(frame)
   -- Create a secure frame for the action that is being overridden
   local secureFrame = CreateFrame("Frame", "DialogKeyWrathSecureFrame", UIParent)
   secureFrame:SetAttribute("type", "button")
   secureFrame:SetAttribute("text", "SecureFrame")
   secureFrame:SetAttribute("width", 100)
   secureFrame:SetAttribute("height", 100)

   -- Set the secure frame as the target for the keybinding
   local keybinding = _G["QuestTitleButton1"]:GetKeybinding()
   keybinding:SetTarget(secureFrame)

   -- Redirect the keybinding to the secure frame
   keybinding:SetScript("OnPress", function()
       secureFrame:Fire()
   end)

   -- Highlight the secure frame
   HighlightSpaceButton(secureFrame)
end

local function DisableOverride(frame)
   -- Remove the secure frame
   if secureFrame then
       secureFrame:Hide()
       secureFrame:Release()
       secureFrame = nil
   end

   -- Remove the keybinding target
   local keybinding = _G["QuestTitleButton1"]:GetKeybinding()
   keybinding:SetTarget(nil)

   -- Remove the keybinding script
   keybinding:SetScript("OnPress", nil)
end

-- Export the functions for the override mechanic
local function UpdateOverrideState()
   local player = _G.Player
   if player then
       if player.InCombat then
           DisableOverride(player.QuestFrame)
       else
           EnableOverride(player.QuestFrame)
       end
   end
end

local function RegisterEvents()
   -- Register the quest frame show and hide events
   _G.QuestFrame:Hide()
   _G.QuestFrame:Show()
   _G.QuestFrame:Hide()

   -- Register the combat enter and exit events
   local player = _G.Player
   if player then
       player.EnterCombat:Register()
       player.LeaveCombat:Register()
   end
end

local function UnregisterEvents()
   -- Unregister the quest frame show and hide events
   _G.QuestFrame:Hide()
   _G.QuestFrame:Show()

   -- Unregister the combat enter and exit events
   local player = _G.Player
   if player then
       player.EnterCombat:Unregister()
       player.LeaveCombat:Unregister()
   end
end

-- Export the functions for the override mechanic
local function InitializeOverride()
   -- Create the secure frames for the quest rewards
   EnableOverride(QuestFrameRewardButton)

   -- Register the events for the override mechanic
   RegisterEvents()
end

local function CleanupOverride()
   -- Remove the secure frames for the quest rewards
   DisableOverride(QuestFrameRewardButton)

   -- Unregister the events for the override mechanic
   UnregisterEvents()
end