--[[------------------------------------------------------------------------------------------------
Title:					STimer
Author:					Static_Recharge
Version:				3.0.0
Description:		Allows for the creation of a custom countdown timer. The settings menu allows the
                user to save presets.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local CS = CHAT_SYSTEM
local SM = SCENE_MANAGER
local WM = WINDOW_MANAGER


--[[------------------------------------------------------------------------------------------------
Initialization
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
ST Class Initialization
ST    - (obj) Parent object containing all functions, tables, variables, constants and timer objects.
------------------------------------------------------------------------------------------------]]--
local ST = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
function ST:Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, slash commands and event callbacks. Fired from the
              creation of the ST class.
------------------------------------------------------------------------------------------------]]--
function ST:Initialize()
  self.addonName = "STimer"
  self.version = "3.0.0"
  self.author = "Static_Recharge"
  self.chatPrefix = "|c9966FF[STimer]: |cFFFFFF"
  self.chatSuffix = "|r"
  self.alerted = false
  self.duration = nil
  self.inProgress = false
  self.paused = false
  self.updateInterval = 1 -- seconds
  self.Defaults = {bgHidden = false, left = 0, top = 0}

  self.SavedVars = ZO_SavedVars:NewAccountWide("STimerSV", 1, nil, self.Defaults, nil)

  SLASH_COMMANDS["/st"] = function(...) self:CommandParse(...) end

  --[[self.PauseButton = WM:GetControlByName("ST_PanelPauseButton")
  self.PauseButton:SetHandler("onMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, "Pause/Resume") end)
  self.PauseButton:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)]]--
  self.Panel = WM:GetControlByName("ST_Panel")
  self.Panel:SetHandler("OnUpdate", function() self:OnUpdate() end)
  self.Panel:SetHandler("OnMoveStop", function() self:OnMoveStop() end)
  self.Label = WM:GetControlByName("ST_PanelLabel")
  self.BG = WM:GetControlByName("ST_PanelBG")

  self:RestorePanel()

  local scene = SM:GetScene("hud")
  scene:RegisterCallback("StateChange", function(oldState, newState) self:HUDSceneChange(oldState, newState) end)
  local scene = SM:GetScene("hudui")
  scene:RegisterCallback("StateChange", function(oldState, newState) self:HUDUISceneChange(oldState, newState) end)

  -- Event Registration
  EM:RegisterForEvent(self.addonName, EVENT_PLAYER_ACTIVATED, function(eventCode, initial) self:OnPlayerActivated(eventCode, initial) end)
  EM:RegisterForEvent(self.addonName, EVENT_PLAYER_DEACTIVATED, function(eventCode) self:OnPlayerDeactivated(eventCode) end)
end


--[[------------------------------------------------------------------------------------------------
General Functions
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
function ST:SendToChat(inputString, ...)
Inputs:				inputString							- (string/number/bool) The input string to be formatted and sent to chat.
							...											- (string/number/bool) More inputs to be placed on new lines within the same message.
Outputs:			None
Description:	Formats text to be sent to the chat box for the user. Bools will be converted to "true" or "false" text formats. All inputs after the first will be placed on a new line within the message. Only the first line gets the library prefix.
------------------------------------------------------------------------------------------------]]--
function ST:SendToChat(inputString, ...)
	if not inputString then return end
	local Args = {...}
	local Output = {}
  if type(inputString) == boolean then
    if inputString then inputString = "true" else inputString = "false" end
  end
	table.insert(Output, self.chatPrefix)
	table.insert(Output, inputString) 
	table.insert(Output, self.chatSuffix)
	if #Args > 0 then
		for i,v in ipairs(Args) do
			if type(v) == boolean then
				if v then v = "true" else v = "false" end
			end
		  table.insert(Output, "\n")
	    table.insert(Output, v) 
	    table.insert(Output, self.chatSuffix)
		end
	end
	CS:AddMessage(table.concat(Output))
end


function ST:CommandParse(args)
	local Options = {}
	for match in (args .. " "):gmatch("(.-)" .. " ") do
    table.insert(Options, match);
  end

	if Options[1] == "" then
		ST.SendToChat("Command List\n|cFFFFFF/st start # - starts a timer for # minutes.\n|cFFFFFF/st stop - stops the current timer.\n|cFFFFFF/st pause - toggles pausing and resuming the current timer.\n|cFFFFFF/st hidebg - toggles the background visibility of the timer.")
	elseif Options[1] == "start" then
    self:Start(tonumber(Options[2]))
  elseif Options[1] == "stop" then
    self:Stop()
  elseif Options[1] == "hidebg" then
    self:HideBG()
  elseif Options[1] == "pause" then
    self:Pause()
  elseif Options[1] == "debug" then
    self:Debug()
  else
    self:SendToChat("Invalid command")
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:Debug()
Inputs:				None							
																		
Outputs:			Debugging information
Description:	For testing purposes only
------------------------------------------------------------------------------------------------]]--
function ST:Debug()
  d(LT)
end


--[[------------------------------------------------------------------------------------------------
Event Callbacks
------------------------------------------------------------------------------------------------]]--
function ST:OnMoveStop()
  self.SavedVars.left = self.Panel:GetLeft()
  self.SavedVars.top = self.Panel:GetTop()
end


function ST:OnUpdate()
  local now = GetFrameTimeSeconds()
  if self.inProgress then
    if now >= self.nextUpdate then
      self.duration = self.duration - self.updateInterval
      self.nextUpdate = self.nextUpdate + self.updateInterval
      self:UpdateTimer()
    end
  end
end


function ST:OnPlayerActivated(eventCode, initial)
  if not initial then
    local now = GetFrameTimeSeconds()
    self.duration = self.SavedVars.duration
    self.nextUpdate = now + self.SavedVars.partialUpdate
    self.inProgress = self.SavedVars.inProgress
    self.paused = self.SavedVars.paused

    if self.inProgress or self.paused then
      self:UpdateTimer()
      self:ShowPanel(true)
    end
  end
end


function ST:OnPlayerDeactivated(eventCode)
  local now = GetFrameTimeSeconds()
  self.SavedVars.duration = self.duration
  self.SavedVars.partialUpdate = self.nextUpdate - now
  self.SavedVars.inProgress = self.inProgress
  self.SavedVars.paused = self.paused
end


EM:RegisterForEvent("STimer", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
  if addonName == "STimer" then
    EM:UnregisterForEvent("STimer", EVENT_ADD_ON_LOADED)
    STimer = ST:New()
  end
end)


--[[------------------------------------------------------------------------------------------------
Window Control
------------------------------------------------------------------------------------------------]]--
function ST:RestorePanel()
	local left = self.SavedVars.left
	local top = self.SavedVars.top
  local width, height = self.Label:GetTextDimensions()
  local bgHidden = self.SavedVars.bgHidden
  self.Panel:SetDimensions(width + 18, height + 6)
	if left ~= nil and top ~= nil then
		self.Panel:ClearAnchors()
		self.Panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
	end
  self.BG:SetHidden(bgHidden)
end


function ST:HideBG()
  self.BG:SetHidden(not self.BG:IsHidden())
  self.SavedVars.bgHidden = self.BG:IsHidden()
end


function ST:HUDSceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and self.showPanel then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


function ST:HUDUISceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and self.showPanel then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


function ST:ShowPanel(show)
  self.showPanel = show
  local sceneName = SM:GetCurrentScene():GetName()
  if show and (sceneName == "hud" or sceneName == "hudui") then
    self.Panel:SetHidden(false)
  else
    self.Panel:SetHidden(true)
  end
end


function ST:UpdateTimer()
  local value = self.duration
  local hours = math.floor(value/3600)
  local minutes = math.floor(value/60)%60
  local seconds = value%60
  if hours > 0 then
    self.Label:SetText(string.format("%02i:%02i:%02i", hours, minutes, seconds))
  elseif minutes > 0 then
    self.Label:SetText(string.format("%02i:%02i", minutes, seconds))
  else
    self.Label:SetText(string.format("%02i", seconds))
  end
  self:RestorePanel()
  if self.duration <= 0 then
    self:AlarmTimer()
  end
end


function ST:AlarmTimer()
  self.inProgress = false
  self:SendToChat("Finished.")
end


--[[------------------------------------------------------------------------------------------------
Timer Control
------------------------------------------------------------------------------------------------]]--
function ST:Start(duration)
  self.start = math.floor(duration * 60)
  self.duration = self.start
  self.nextUpdate = GetFrameTimeSeconds() + self.updateInterval
  self:UpdateTimer()
  self:ShowPanel(true)
  self.inProgress = true
end


function ST:Stop()
  self.inProgress = false
  self:ShowPanel(false)
  self:SendToChat("Stopped.")
end


function ST:Pause()
  local now = GetFrameTimeSeconds()
  if self.paused then
    self.nextUpdate = now + self.partialUpdate
    self.inProgress = true
    self.paused = false
  else
    self.partialUpdate = self.nextUpdate - now
    self.inProgress = flase
    self.paused = true
  end
end